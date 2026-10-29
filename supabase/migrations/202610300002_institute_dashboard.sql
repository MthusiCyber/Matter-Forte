-- Apply after 202610300001_admin_approvals.sql.
-- Reads institute membership from Supabase Auth metadata; no duplicate user table.
begin;

create or replace function public.matter_forte_list_students()
returns table (id uuid, full_name text, email text, institute text, programme text, student_number text)
language plpgsql stable security definer set search_path = ''
as $$
begin
    if not public.matter_forte_is_admin() then
        raise exception 'Administrator access required' using errcode = '42501';
    end if;
    return query
    select u.id, coalesce(u.raw_user_meta_data ->> 'full_name', 'Student'),
        coalesce(u.email::text, ''), coalesce(u.raw_user_meta_data ->> 'institute', ''),
        coalesce(u.raw_user_meta_data ->> 'programme', ''),
        coalesce(u.raw_user_meta_data ->> 'student_number', '')
    from auth.users u where u.raw_app_meta_data ->> 'role' = 'student'
    order by u.raw_user_meta_data ->> 'full_name', u.id;
end;
$$;
revoke all on function public.matter_forte_list_students() from public, anon;
grant execute on function public.matter_forte_list_students() to authenticated;

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
