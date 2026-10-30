-- Add Supabase persistence to the existing internship information board.
begin;

create table if not exists public.internships (
    id uuid primary key default gen_random_uuid(),
    title varchar(255) not null,
    company_name varchar(255) not null,
    description text,
    created_at timestamptz default now()
);
alter table public.internships
    add column if not exists responsibilities text[] not null default '{}',
    add column if not exists skills text[] not null default '{}',
    add column if not exists is_open boolean not null default true,
    add column if not exists posted_by uuid references auth.users(id) on delete set null;
create index if not exists internships_posted_by on public.internships(posted_by);

-- Only the checked RPCs below expose listings to the app. Legacy data and its
-- created_by foreign key to public.users are preserved.
alter table public.internships enable row level security;
revoke all on public.internships from public, anon, authenticated;
grant all on public.internships to service_role;

create or replace function public.matter_forte_list_internships()
returns setof public.internships
language plpgsql stable security definer set search_path = ''
as $$
declare is_admin boolean := public.matter_forte_is_admin();
begin
    if not is_admin and not exists (
        select 1 from auth.users where id = auth.uid() and raw_app_meta_data ->> 'role' = 'employer'
    ) then
        raise exception 'Administrator or employer access required' using errcode = '42501';
    end if;
    return query select i.* from public.internships i
    where is_admin or i.posted_by = auth.uid()
    order by i.created_at desc nulls last, i.id;
end;
$$;
revoke all on function public.matter_forte_list_internships() from public, anon;
grant execute on function public.matter_forte_list_internships() to authenticated;

create or replace function public.matter_forte_save_internship(details jsonb)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
    saved public.internships;
    role_title text := btrim(coalesce(details ->> 'title', ''));
    company text := btrim(coalesce(details ->> 'company_name', ''));
    about_role text := btrim(coalesce(details ->> 'description', ''));
    role_responsibilities text[];
    role_skills text[];
begin
    if not public.matter_forte_is_admin() and not exists (
        select 1 from auth.users where id = auth.uid() and raw_app_meta_data ->> 'role' = 'employer'
    ) then
        raise exception 'Administrator or employer access required' using errcode = '42501';
    end if;
    if role_title = '' or length(role_title) > 255 or company = '' or length(company) > 255 or about_role = '' then
        raise exception 'Enter a title, organisation and description (title and organisation: maximum 255 characters)' using errcode = '22023';
    end if;
    select coalesce(array_agg(btrim(value) order by ord), '{}'::text[]) into role_responsibilities
    from jsonb_array_elements_text(case when jsonb_typeof(details -> 'responsibilities') = 'array'
        then details -> 'responsibilities' else '[]'::jsonb end) with ordinality as item(value, ord)
    where btrim(value) <> '';
    select coalesce(array_agg(btrim(value) order by ord), '{}'::text[]) into role_skills
    from jsonb_array_elements_text(case when jsonb_typeof(details -> 'skills') = 'array'
        then details -> 'skills' else '[]'::jsonb end) with ordinality as item(value, ord)
    where btrim(value) <> '';
    if cardinality(role_responsibilities) = 0 or cardinality(role_skills) = 0 then
        raise exception 'Enter responsibilities and skills' using errcode = '22023';
    end if;
    -- A stable client draft ID makes retries safe after a lost response.
    insert into public.internships(id, title, company_name, description, responsibilities, skills, is_open, posted_by)
    values (coalesce(nullif(details ->> 'id', '')::uuid, gen_random_uuid()), role_title, company,
        about_role, role_responsibilities, role_skills, coalesce((details ->> 'is_open')::boolean, true), auth.uid())
    on conflict (id) do update set title = excluded.title, company_name = excluded.company_name,
        description = excluded.description, responsibilities = excluded.responsibilities,
        skills = excluded.skills, is_open = excluded.is_open
    where internships.posted_by = auth.uid()
    returning * into saved;
    if saved.id is null then
        raise exception 'This internship belongs to another account' using errcode = '42501';
    end if;
    return to_jsonb(saved);
end;
$$;
revoke all on function public.matter_forte_save_internship(jsonb) from public, anon;
grant execute on function public.matter_forte_save_internship(jsonb) to authenticated;

create or replace function public.matter_forte_dashboard_snapshot()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare student_count bigint; pending_count bigint; internship_count bigint; activity jsonb;
begin
    if not public.matter_forte_is_admin() then
        raise exception 'Administrator access required' using errcode = '42501';
    end if;
    select count(*) into student_count from public.matter_forte_students;
    select count(*) into internship_count from public.internships where is_open;
    select count(*) into pending_count from public.matter_forte_admin_requests where status = 'pending';
    select coalesce(jsonb_agg(jsonb_build_object(
        'id', recent.id, 'userName', recent.name, 'action', recent.action, 'timestamp', recent.created_at
    ) order by recent.created_at desc), '[]'::jsonb) into activity from (
        select s.id, s.full_name as name, 'Student portfolio created'::text as action, s.created_at
        from public.matter_forte_students s
        union all
        select u.id, coalesce(u.raw_user_meta_data ->> 'full_name', 'Administrator'),
            'Administrator account created'::text, u.created_at
        from auth.users u where u.raw_app_meta_data ->> 'role' = 'admin'
        union all
        select i.id, i.company_name, 'Internship posted'::text, i.created_at
        from public.internships i
        order by created_at desc nulls last limit 3
    ) recent;
    return jsonb_build_object('totalStudents', student_count, 'activeInternships', internship_count,
        'pendingApprovals', pending_count, 'reportedIssues', 0,
        'unreadNotifications', pending_count, 'recentActivity', activity);
end;
$$;
revoke all on function public.matter_forte_dashboard_snapshot() from public, anon;
grant execute on function public.matter_forte_dashboard_snapshot() to authenticated;
notify pgrst, 'reload schema';
commit;
