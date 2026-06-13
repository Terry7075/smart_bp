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
  alter column remaining_seats set default 0,
  add constraint drivers_remaining_seats_non_negative
  check (remaining_seats >= 0);

alter table public.ride_requests
  add column if not exists pickup_latitude double precision,
  add column if not exists pickup_longitude double precision,
  add column if not exists matched_driver_id uuid references public.drivers(id) on delete set null;

create index if not exists drivers_greedy_matching_idx
  on public.drivers (
    status,
    approval_status,
    available_destination,
    available_ride_date,
    available_ride_time
  );

create index if not exists ride_requests_matched_driver_id_idx
  on public.ride_requests(matched_driver_id);

create or replace function public.apply_greedy_match(
  p_ride_request_id uuid,
  p_driver_id uuid,
  p_distance_km numeric
)
returns public.ride_matches
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_request public.ride_requests;
  v_driver public.drivers;
  v_match public.ride_matches;
begin
  select *
  into v_request
  from public.ride_requests
  where id = p_ride_request_id
  for update;

  if v_request.id is null then
    raise exception 'ride request not found';
  end if;

  if v_request.status <> 'pending' then
    return null;
  end if;

  select *
  into v_driver
  from public.drivers
  where id = p_driver_id
  for update;

  if v_driver.id is null then
    raise exception 'driver not found';
  end if;

  if v_driver.approval_status <> 'approved'
    or v_driver.status <> 'online'
    or coalesce(v_driver.remaining_seats, v_driver.max_passengers) < v_request.passenger_count
    or v_driver.available_destination is distinct from v_request.destination
    or v_driver.available_ride_date is distinct from v_request.ride_date
    or v_driver.available_ride_time < (v_request.ride_time - interval '30 minutes')::time
    or v_driver.available_ride_time > (v_request.ride_time + interval '30 minutes')::time
  then
    raise exception 'driver is not eligible for greedy matching';
  end if;

  update public.ride_requests
  set
    distance_km = p_distance_km,
    matched_driver_id = p_driver_id
  where id = p_ride_request_id;

  insert into public.ride_matches (
    ride_request_id,
    driver_id,
    matched_by,
    match_type
  ) values (
    p_ride_request_id,
    p_driver_id,
    null,
    'auto'
  )
  returning * into v_match;

  update public.drivers
  set remaining_seats = greatest(
    coalesce(remaining_seats, max_passengers) - v_request.passenger_count,
    0
  )
  where id = p_driver_id;

  insert into public.notifications (
    user_id,
    title,
    message,
    type,
    related_ride_request_id
  ) values (
    v_driver.user_id,
    '新的自動媒合任務',
    '系統已依距離與條件自動媒合一筆接送任務，請前往司機任務查看。',
    'ride_matched',
    p_ride_request_id
  );

  return v_match;
end;
$$;

revoke execute on function public.apply_greedy_match(uuid, uuid, numeric)
from public, anon;

grant execute on function public.apply_greedy_match(uuid, uuid, numeric)
to authenticated;
