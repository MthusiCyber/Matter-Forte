-- Apply in Supabase SQL Editor. Supersedes automatic admin access for every signup.
-- First admin is automatic; later admin signups require an existing admin's approval.
begin;

create table if not exists public.matter_forte_admin_requests (
    user_id uuid primary key references auth.users(id) on delete cascade,
    full_name text not null,
    email text not null,
    status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
    created_at timestamptz not null default now(),
    reviewed_at timestamptz,
    reviewed_by uuid references auth.users(id) on delete set null
);

create or replace function public.matter_forte_is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
    select exists (
        select 1 from auth.users
        where id = auth.uid() and raw_app_meta_data ->> 'role' = 'admin'
    );
$$;
revoke all on function public.matter_forte_is_admin() from public, anon;
grant execute on function public.matter_forte_is_admin() to authenticated;

alter table public.matter_forte_admin_requests enable row level security;
revoke all on public.matter_forte_admin_requests from public, anon, authenticated;
grant select on public.matter_forte_admin_requests to authenticated;
drop policy if exists "Read own or administrator requests" on public.matter_forte_admin_requests;
create policy "Read own or administrator requests"
on public.matter_forte_admin_requests for select to authenticated
using (user_id = (select auth.uid()) or (select public.matter_forte_is_admin()));

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
    elsif new.raw_user_meta_data ->> 'requested_role' = 'employer' then
        new.raw_app_meta_data := coalesce(new.raw_app_meta_data, '{}'::jsonb)
            || jsonb_build_object('role', 'employer');
    end if;
    return new;
end;
$$;
revoke all on function public.matter_forte_assign_signup_role() from public, anon, authenticated;
drop trigger if exists matter_forte_assign_signup_role on auth.users;
create trigger matter_forte_assign_signup_role before insert on auth.users
for each row execute function public.matter_forte_assign_signup_role();

create or replace function public.matter_forte_record_admin_request()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
    if new.raw_app_meta_data ->> 'role' = 'pending_admin' then
        insert into public.matter_forte_admin_requests (user_id, full_name, email)
        values (new.id, coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), 'Administrator applicant'),
                coalesce(new.email, ''))
        on conflict (user_id) do nothing;
    end if;
    return new;
end;
$$;
revoke all on function public.matter_forte_record_admin_request() from public, anon, authenticated;
drop trigger if exists matter_forte_record_admin_request on auth.users;
create trigger matter_forte_record_admin_request after insert on auth.users
for each row execute function public.matter_forte_record_admin_request();

create or replace function public.matter_forte_review_admin_request(target_user_id uuid, decision text)
returns void language plpgsql security definer set search_path = ''
as $$
declare request_status text;
begin
    if not public.matter_forte_is_admin() then
        raise exception 'Administrator access required' using errcode = '42501';
    end if;
    if decision not in ('approved', 'rejected') or decision is null then
        raise exception 'Invalid decision' using errcode = '22023';
    end if;
    -- Two administrators cannot approve/decline the same request twice.
    select status into request_status from public.matter_forte_admin_requests
    where user_id = target_user_id for update;
    if not found or request_status <> 'pending' then
        raise exception 'This request has already been reviewed or does not exist' using errcode = '22023';
    end if;
    update auth.users set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
        || jsonb_build_object('role', case when decision = 'approved' then 'admin' else 'admin_rejected' end,
                             'admin_request_status', decision)
    where id = target_user_id and raw_app_meta_data ->> 'role' = 'pending_admin';
    if not found then
        raise exception 'This account no longer has a pending admin request' using errcode = '22023';
    end if;
    update public.matter_forte_admin_requests
    set status = decision, reviewed_at = now(), reviewed_by = auth.uid()
    where user_id = target_user_id;
end;
$$;
revoke all on function public.matter_forte_review_admin_request(uuid, text) from public, anon;
grant execute on function public.matter_forte_review_admin_request(uuid, text) to authenticated;

-- Migrate signups awaiting a role. Preserve all already assigned administrators.
-- If none exists, bootstrap the earliest admin signup; queue all remaining ones.
do $$
declare first_admin uuid;
begin
    perform pg_advisory_xact_lock(81430, 1);
    if not exists (select 1 from auth.users where raw_app_meta_data ->> 'role' = 'admin') then
        select id into first_admin from auth.users
        where raw_user_meta_data ->> 'requested_role' = 'admin'
          and (raw_app_meta_data ->> 'role' is null or raw_app_meta_data ->> 'role' = 'pending_admin')
        order by created_at, id limit 1;
        if first_admin is not null then
            update auth.users set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
                || '{"role":"admin","admin_request_status":"approved"}'::jsonb
            where id = first_admin;
            update public.matter_forte_admin_requests
            set status = 'approved', reviewed_at = now() where user_id = first_admin;
        end if;
    end if;
    update auth.users set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
        || '{"role":"pending_admin","admin_request_status":"pending"}'::jsonb
    where raw_user_meta_data ->> 'requested_role' = 'admin' and raw_app_meta_data ->> 'role' is null;
    insert into public.matter_forte_admin_requests (user_id, full_name, email)
    select id, coalesce(nullif(raw_user_meta_data ->> 'full_name', ''), 'Administrator applicant'), coalesce(email, '')
    from auth.users where raw_app_meta_data ->> 'role' = 'pending_admin'
    on conflict (user_id) do nothing;
end;
$$;

notify pgrst, 'reload schema';
commit;
