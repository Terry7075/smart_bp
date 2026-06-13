alter table public.drivers
  add column if not exists status text not null default 'offline',
  add column if not exists remaining_seats integer,
  add column if not exists current_latitude double precision,
  add column if not exists current_longitude double precision,
  add column if not exists available_destination text,
  add column if not exists available_ride_date date,
  add column if not exists available_ride_time time;

alter table public.drivers
  drop constraint if exists drivers_status_valid;

alter table public.drivers
  add constraint drivers_status_valid
  check (status in ('online', 'offline'));

update public.drivers
set remaining_seats = max_passengers
where remaining_seats is null;

alter table public.drivers
  alter column remaining_seats set default 0;

alter table public.drivers
  drop constraint if exists drivers_remaining_seats_non_negative;

alter table public.drivers
  add constraint drivers_remaining_seats_non_negative
  check (remaining_seats >= 0);

alter table public.drivers enable row level security;

drop policy if exists "drivers_select_authorized" on public.drivers;
drop policy if exists "drivers_insert_self" on public.drivers;
drop policy if exists "drivers_update_self_or_admin" on public.drivers;

create policy "drivers_select_authorized"
on public.drivers
for select
to authenticated
using (
  user_id = (select auth.uid())
  or private.is_admin()
  or private.can_current_user_view_driver(id)
);

create policy "drivers_insert_self"
on public.drivers
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and approval_status = 'pending'
);

create policy "drivers_update_self_or_admin"
on public.drivers
for update
to authenticated
using (user_id = (select auth.uid()) or private.is_admin())
with check (user_id = (select auth.uid()) or private.is_admin());

revoke all on table public.drivers from anon;
grant select, insert, update on table public.drivers to authenticated;
