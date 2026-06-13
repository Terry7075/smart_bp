-- 一鍵修復：Supabase Dashboard → SQL Editor → 貼上整段 → Run
-- 解決：infinite recursion detected in policy for relation "profiles"

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.role::text from public.profiles p where p.id = auth.uid()),
    'elder'
  );
$$;

create or replace function public.is_staff_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select p.role::text in ('volunteer', 'admin')
      from public.profiles p
      where p.id = auth.uid()
    ),
    false
  );
$$;

revoke all on function public.current_user_role() from public;
grant execute on function public.current_user_role() to authenticated;
revoke all on function public.is_staff_user() from public;
grant execute on function public.is_staff_user() to authenticated;

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_admin" on public.profiles;
drop policy if exists "profiles_select_self" on public.profiles;
drop policy if exists "profiles_select_volunteer_demo" on public.profiles;
drop policy if exists "profiles_select_staff" on public.profiles;
drop policy if exists "profiles_insert_self" on public.profiles;
drop policy if exists "profiles_update_self" on public.profiles;

create policy "profiles_select_self"
on public.profiles for select to authenticated
using (auth.uid() = id);

create policy "profiles_select_staff"
on public.profiles for select to authenticated
using (public.is_staff_user());

create policy "profiles_insert_self"
on public.profiles for insert to authenticated
with check (auth.uid() = id);

create policy "profiles_update_self"
on public.profiles for update to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);
