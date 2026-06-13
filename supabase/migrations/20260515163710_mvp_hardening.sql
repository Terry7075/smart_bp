alter function private.set_updated_at() set search_path = public, private;
alter function private.calculate_price(numeric) set search_path = public, private;
alter function private.protect_profile_columns() set search_path = public, private;
alter function private.protect_driver_columns() set search_path = public, private;
alter function private.calculate_ride_price() set search_path = public, private;
alter function private.validate_match_status_transition() set search_path = public, private;

create index if not exists notifications_related_ride_request_id_idx
  on public.notifications(related_ride_request_id);

create index if not exists ride_matches_matched_by_idx
  on public.ride_matches(matched_by);

drop policy if exists "profiles_select_self_or_admin" on public.profiles;
create policy "profiles_select_self_or_admin"
on public.profiles for select
using (id = (select auth.uid()) or private.is_admin());

drop policy if exists "profiles_insert_self" on public.profiles;
create policy "profiles_insert_self"
on public.profiles for insert
with check (id = (select auth.uid()));

drop policy if exists "profiles_update_self_or_admin" on public.profiles;
create policy "profiles_update_self_or_admin"
on public.profiles for update
using (id = (select auth.uid()) or private.is_admin())
with check (id = (select auth.uid()) or private.is_admin());

drop policy if exists "drivers_select_authorized" on public.drivers;
create policy "drivers_select_authorized"
on public.drivers for select
using (
  user_id = (select auth.uid())
  or private.is_admin()
  or private.can_current_user_view_driver(id)
);

drop policy if exists "drivers_insert_self" on public.drivers;
create policy "drivers_insert_self"
on public.drivers for insert
with check (
  user_id = (select auth.uid())
  and approval_status = 'pending'
);

drop policy if exists "drivers_update_self_or_admin" on public.drivers;
create policy "drivers_update_self_or_admin"
on public.drivers for update
using (user_id = (select auth.uid()) or private.is_admin())
with check (user_id = (select auth.uid()) or private.is_admin());

drop policy if exists "ride_requests_select_authorized" on public.ride_requests;
create policy "ride_requests_select_authorized"
on public.ride_requests for select
using (
  elder_id = (select auth.uid())
  or private.is_admin()
  or (
    private.is_approved_driver()
    and status = 'pending'
  )
  or private.is_assigned_driver_for_request(id)
);

drop policy if exists "ride_requests_insert_elder_self" on public.ride_requests;
create policy "ride_requests_insert_elder_self"
on public.ride_requests for insert
with check (
  elder_id = (select auth.uid())
  and private.current_user_role() = 'elder'
  and status = 'pending'
);

drop policy if exists "notifications_select_self" on public.notifications;
create policy "notifications_select_self"
on public.notifications for select
using (user_id = (select auth.uid()));

drop policy if exists "notifications_update_self" on public.notifications;
create policy "notifications_update_self"
on public.notifications for update
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));
