-- Apply after the admin-approval and dashboard migrations.
-- Students are institute portfolios maintained by administrators, not app users.
-- Drop the function first to prevent the 42P13 signature-change error on GitHub
drop function if exists public.matter_forte_list_students();

create function public.matter_forte_list_students()
returns setof public.matter_forte_students
language plpgsql stable security definer set search_path = ''
as $$
begin
    if not public.matter_forte_is_admin() then
        raise exception 'Administrator access required' using errcode = '42501';
    end if;
    return query select s.* from public.matter_forte_students s order by s.full_name, s.id;
end;
$$;
revoke all on function public.matter_forte_list_students() from public, anon;
grant execute on function public.matter_forte_list_students() to authenticated;
begin;

create table if not exists public.matter_forte_students (
    id uuid primary key default gen_random_uuid(),
    full_name text not null check (length(btrim(full_name)) > 0),
    email text not null,
    institute text not null default 'MCRI',
    programme text not null default '',
    student_number text not null default '',
    cohort text not null default 'MCRI',
    biography text not null default '',
    skills text[] not null default '{}',
    essential_skills text[] not null default '{}',
    seed_batch text,
    created_by uuid references auth.users(id) on delete set null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create unique index if not exists matter_forte_students_email
on public.matter_forte_students (lower(email));

alter table public.matter_forte_students enable row level security;
revoke all on public.matter_forte_students from public, anon, authenticated;
grant select, insert, update on public.matter_forte_students to authenticated;
grant all on public.matter_forte_students to service_role;
drop policy if exists "Admins manage institute students" on public.matter_forte_students;
create policy "Admins manage institute students" on public.matter_forte_students
for all to authenticated using ((select public.matter_forte_is_admin()))
with check ((select public.matter_forte_is_admin()));

-- Keep main's signup roles: admin and employer only. Existing student logins
-- remain untouched; the application rejects them instead of deleting accounts.
create or replace function public.matter_forte_assign_signup_role()
returns trigger language plpgsql volatile security definer set search_path = ''
as $$
declare assigned_role text;
begin
    if new.raw_user_meta_data ->> 'requested_role' = 'student' then
        raise exception 'Students are entered by administrators and cannot sign up for app access'
            using errcode = '42501';
    elsif new.raw_user_meta_data ->> 'requested_role' = 'admin' then
        perform pg_advisory_xact_lock(81430, 1);
        if exists (select 1 from auth.users where raw_app_meta_data ->> 'role' = 'admin') then
            assigned_role := 'pending_admin';
        else
            assigned_role := 'admin';
        end if;
        new.raw_app_meta_data := coalesce(new.raw_app_meta_data, '{}'::jsonb)
            || jsonb_build_object('role', assigned_role, 'admin_request_status',
                case when assigned_role = 'admin' then 'approved' else 'pending' end);
    elsif new.raw_user_meta_data ->> 'requested_role' = 'employer' then
        new.raw_app_meta_data := coalesce(new.raw_app_meta_data, '{}'::jsonb)
            || jsonb_build_object('role', 'employer');
    end if;
    return new;
end;
$$;
revoke all on function public.matter_forte_assign_signup_role() from public, anon, authenticated;

-- Preserve any student data created with the earlier test-account draft.
-- App accounts are never created by the portfolio feature.
insert into public.matter_forte_students
    (id, full_name, email, institute, programme, student_number, cohort, biography, seed_batch, created_at)
select u.id, coalesce(u.raw_user_meta_data ->> 'full_name', 'Student'), coalesce(u.email::text, ''),
    coalesce(u.raw_user_meta_data ->> 'institute', 'MCRI'), coalesce(u.raw_user_meta_data ->> 'programme', ''),
    coalesce(u.raw_user_meta_data ->> 'student_number', ''), coalesce(u.raw_user_meta_data ->> 'cohort', 'MCRI'),
    coalesce(u.raw_user_meta_data ->> 'biography', ''), u.raw_app_meta_data ->> 'seed_batch', coalesce(u.created_at, now())
from auth.users u where u.raw_app_meta_data ->> 'role' = 'student'
on conflict do nothing;

drop function if exists public.matter_forte_list_students();
create function public.matter_forte_list_students()
returns setof public.matter_forte_students
language plpgsql stable security definer set search_path = ''
as $$
begin
    if not public.matter_forte_is_admin() then
        raise exception 'Administrator access required' using errcode = '42501';
    end if;
    return query select s.* from public.matter_forte_students s order by s.full_name, s.id;
end;
$$;
revoke all on function public.matter_forte_list_students() from public, anon;
grant execute on function public.matter_forte_list_students() to authenticated;

create or replace function public.matter_forte_save_student(details jsonb)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
    target_id uuid;
    student_name text;
    student_email text;
    student_skills text[];
    student_essential_skills text[];
    saved public.matter_forte_students;
begin
    if not public.matter_forte_is_admin() then
        raise exception 'Administrator access required' using errcode = '42501';
    end if;
    student_name := btrim(coalesce(details ->> 'full_name', ''));
    student_email := btrim(coalesce(details ->> 'email', ''));
    if student_name = '' or length(student_name) > 200
       or student_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
        raise exception 'Enter a valid student name and email' using errcode = '22023';
    end if;
    target_id := nullif(details ->> 'id', '')::uuid;
    select coalesce(array_agg(value), '{}'::text[]) into student_skills
    from jsonb_array_elements_text(case when jsonb_typeof(details -> 'skills') = 'array'
        then details -> 'skills' else '[]'::jsonb end) as item(value);
    select coalesce(array_agg(value), '{}'::text[]) into student_essential_skills
    from jsonb_array_elements_text(case when jsonb_typeof(details -> 'essential_skills') = 'array'
        then details -> 'essential_skills' else '[]'::jsonb end) as item(value);
    if target_id is null then
        insert into public.matter_forte_students
            (full_name, email, institute, programme, cohort, biography, skills, essential_skills, created_by)
        values (student_name, student_email, coalesce(nullif(details ->> 'institute', ''), 'MCRI'),
            coalesce(details ->> 'programme', ''), coalesce(nullif(details ->> 'cohort', ''), 'MCRI'),
            coalesce(details ->> 'biography', ''), student_skills, student_essential_skills, auth.uid())
        returning * into saved;
    else
        update public.matter_forte_students set full_name = student_name, email = student_email,
            institute = coalesce(nullif(details ->> 'institute', ''), 'MCRI'),
            programme = coalesce(details ->> 'programme', ''),
            cohort = coalesce(nullif(details ->> 'cohort', ''), 'MCRI'), biography = coalesce(details ->> 'biography', ''),
            skills = student_skills, essential_skills = student_essential_skills, updated_at = now()
        where id = target_id returning * into saved;
        if not found then
            raise exception 'Student portfolio not found' using errcode = '22023';
        end if;
    end if;
    return to_jsonb(saved);
end;
$$;
revoke all on function public.matter_forte_save_student(jsonb) from public, anon;
grant execute on function public.matter_forte_save_student(jsonb) to authenticated;

create or replace function public.matter_forte_dashboard_snapshot()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare student_count bigint; pending_count bigint; activity jsonb;
begin
    if not public.matter_forte_is_admin() then
        raise exception 'Administrator access required' using errcode = '42501';
    end if;
    select count(*) into student_count from public.matter_forte_students;
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
        order by created_at desc limit 10
    ) recent;
    return jsonb_build_object('totalStudents', student_count, 'activeInternships', 0,
        'pendingApprovals', pending_count, 'reportedIssues', 0,
        'unreadNotifications', pending_count, 'recentActivity', activity);
end;
$$;
revoke all on function public.matter_forte_dashboard_snapshot() from public, anon;
grant execute on function public.matter_forte_dashboard_snapshot() to authenticated;
notify pgrst, 'reload schema';
commit;
