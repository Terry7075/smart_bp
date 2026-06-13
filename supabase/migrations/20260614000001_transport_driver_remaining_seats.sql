alter table public.drivers
  add column if not exists remaining_seats integer default 0;

update public.drivers
set remaining_seats = max_passengers
where remaining_seats is null;

alter table public.drivers
  drop constraint if exists drivers_remaining_seats_non_negative;

alter table public.drivers
  add constraint drivers_remaining_seats_non_negative
  check (remaining_seats >= 0);

alter table public.drivers
  add column if not exists status text not null default 'offline';

alter table public.drivers
  drop constraint if exists drivers_status_valid;

alter table public.drivers
  add constraint drivers_status_valid
  check (status in ('online', 'offline'));

grant select, insert, update on table public.drivers to authenticated;

notify pgrst, 'reload schema';
