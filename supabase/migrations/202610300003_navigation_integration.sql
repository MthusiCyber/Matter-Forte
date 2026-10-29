-- Navigation integration: student signup, cohort/profile data and notifications.
-- Apply after the earlier admin approval and dashboard migrations.
begin;
create or replace function public.matter_forte_assign_signup_role()
returns trigger language plpgsql volatile security definer set search_path = ''
as $$
declare assigned_role text;
begin
    if new.raw_user_meta_data ->> 'requested_role' = 'admin' then
        -- Held until commit. VOLATILE gives the following query a fresh snapshot
        -- after a concurrent signup has finished, so it sees that new admin.
        perform pg_advisory_xact_lock(81430, 1);
        if exists (select 1 from auth.users where raw_app_meta_data ->> 'role' = 'admin') then
            assigned_role := 'pending_admin';
        else
            assigned_role := 'admin';
        end if;
        new.raw_app_meta_data := coalesce(new.raw_app_meta_data, '{}'::jsonb)
            || jsonb_build_object('role', assigned_role,
                'admin_request_status', case when assigned_role = 'admin' then 'approved' else 'pending' end);
    elsif new.raw_user_meta_data ->> 'requested_role' in ('employer', 'student') then
        new.raw_app_meta_data := coalesce(new.raw_app_meta_data, '{}'::jsonb)
            || jsonb_build_object('role', new.raw_user_meta_data ->> 'requested_role');
    end if;
    return new;
end;
$$;

revoke all on function public.matter_forte_assign_signup_role() from public, anon, authenticated;

drop function if exists public.matter_forte_list_students();
create function public.matter_forte_list_students()
returns table (id uuid, full_name text, email text, institute text, programme text,
    student_number text, cohort text, biography text, skills jsonb, essential_skills jsonb)
language plpgsql stable security definer set search_path = ''
as $$
begin
    if not public.matter_forte_is_admin() then
        raise exception 'Administrator access required' using errcode = '42501';
    end if;
    return query select u.id, coalesce(u.raw_user_meta_data ->> 'full_name', 'Student'),
        coalesce(u.email::text, ''), coalesce(u.raw_user_meta_data ->> 'institute', 'MCRI'),
        coalesce(u.raw_user_meta_data ->> 'programme', ''), coalesce(u.raw_user_meta_data ->> 'student_number', ''),
        coalesce(u.raw_user_meta_data ->> 'cohort', 'MCRI'), coalesce(u.raw_user_meta_data ->> 'biography', ''),
        case when jsonb_typeof(u.raw_user_meta_data -> 'skills') = 'array' then u.raw_user_meta_data -> 'skills' else '[]'::jsonb end,
        case when jsonb_typeof(u.raw_user_meta_data -> 'essential_skills') = 'array' then u.raw_user_meta_data -> 'essential_skills' else '[]'::jsonb end
    from auth.users u where u.raw_app_meta_data ->> 'role' = 'student'
    order by u.raw_user_meta_data ->> 'full_name', u.id;
end;
$$;
revoke all on function public.matter_forte_list_students() from public, anon;
grant execute on function public.matter_forte_list_students() to authenticated;

-- Populate a student role only for existing student signups awaiting a role.
update auth.users set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"student"}'::jsonb
where raw_user_meta_data ->> 'requested_role' = 'student' and raw_app_meta_data ->> 'role' is null;
create or replace function public.matter_forte_dashboard_snapshot()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare student_count bigint; pending_count bigint; activity jsonb;
begin
    if not public.matter_forte_is_admin() then
        raise exception 'Administrator access required' using errcode = '42501';
    end if;
    select count(*) into student_count from auth.users where raw_app_meta_data ->> 'role' = 'student';
    select count(*) into pending_count from public.matter_forte_admin_requests where status = 'pending';
    select coalesce(jsonb_agg(jsonb_build_object(
        'id', recent.id, 'userName', recent.name,
        'action', recent.action, 'timestamp', recent.created_at
    ) order by recent.created_at desc), '[]'::jsonb) into activity from (
        select id, coalesce(raw_user_meta_data ->> 'full_name', 'Institute member') as name,
            case when raw_app_meta_data ->> 'role' = 'student' then 'Student account created'
                 else 'Administrator account created' end as action, created_at
        from auth.users where raw_app_meta_data ->> 'role' in ('student', 'admin')
        order by created_at desc, id limit 10
    ) recent;
    -- This seed adds accounts only. Internship, issue and notification services
    -- have not been implemented in this project; no records are seeded for them.
    return jsonb_build_object('totalStudents', student_count, 'activeInternships', 0,
        'pendingApprovals', pending_count, 'reportedIssues', 0,
        'unreadNotifications', pending_count, 'recentActivity', activity);
end;
$$;
revoke all on function public.matter_forte_dashboard_snapshot() from public, anon;
grant execute on function public.matter_forte_dashboard_snapshot() to authenticated;

notify pgrst, 'reload schema';
commit;
