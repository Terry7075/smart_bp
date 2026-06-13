create or replace function private.service_weekdays_valid(
  p_service_weekdays smallint[]
)
returns boolean
language sql
immutable
as $$
  select p_service_weekdays is not null
    and cardinality(p_service_weekdays) > 0
    and p_service_weekdays <@ array[1,2,3,4,5,6,7]::smallint[]
    and cardinality(p_service_weekdays) = (
      select count(distinct weekday)::integer
      from unnest(p_service_weekdays) as weekday
    );
$$;

create table if not exists public.driver_standing_ride_offers (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers(id) on delete cascade,
  pickup_location text not null,
  destination text not null,
  custom_destination text,
  ride_time time not null,
  passenger_count integer not null check (passenger_count > 0),
  need_return boolean not null default false,
  return_time time,
  note text,
  service_weekdays smallint[] not null,
  start_date date not null,
  end_date date,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'booked', 'cancelled')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  rejection_reason text,
  booked_by uuid references public.profiles(id) on delete set null,
  booked_at timestamptz,
  standing_ride_request_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (private.service_weekdays_valid(service_weekdays)),
  check (end_date is null or end_date >= start_date),
  check (need_return or return_time is null)
);

alter table public.standing_ride_requests
  add column if not exists driver_id uuid references public.drivers(id) on delete set null,
  add column if not exists driver_standing_ride_offer_id uuid
    references public.driver_standing_ride_offers(id) on delete set null,
  add column if not exists service_weekdays smallint[];

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'driver_standing_ride_offers_request_fk'
  ) then
    alter table public.driver_standing_ride_offers
      add constraint driver_standing_ride_offers_request_fk
      foreign key (standing_ride_request_id)
      references public.standing_ride_requests(id)
      on delete set null;
  end if;
end $$;

update public.standing_ride_requests
set service_weekdays = case recurrence_pattern
  when 'daily' then array[1,2,3,4,5,6,7]::smallint[]
  else array[1,2,3,4,5]::smallint[]
end
where service_weekdays is null;

alter table public.standing_ride_requests
  alter column service_weekdays set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'standing_ride_requests_service_weekdays_valid'
  ) then
    alter table public.standing_ride_requests
      add constraint standing_ride_requests_service_weekdays_valid
      check (private.service_weekdays_valid(service_weekdays));
  end if;
end $$;

create unique index if not exists driver_standing_ride_offers_request_id_idx
  on public.driver_standing_ride_offers(standing_ride_request_id)
  where standing_ride_request_id is not null;
create index if not exists driver_standing_ride_offers_driver_id_idx
  on public.driver_standing_ride_offers(driver_id);
create index if not exists driver_standing_ride_offers_status_idx
  on public.driver_standing_ride_offers(status);
create index if not exists driver_standing_ride_offers_start_date_idx
  on public.driver_standing_ride_offers(start_date);
create index if not exists standing_ride_requests_driver_id_idx
  on public.standing_ride_requests(driver_id);
create index if not exists standing_ride_requests_offer_id_idx
  on public.standing_ride_requests(driver_standing_ride_offer_id);

drop trigger if exists set_driver_standing_ride_offers_updated_at
  on public.driver_standing_ride_offers;
create trigger set_driver_standing_ride_offers_updated_at
before update on public.driver_standing_ride_offers
for each row execute function private.set_updated_at();

create or replace function private.protect_driver_standing_ride_offer_columns()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if private.is_admin() then
    return new;
  end if;

  if private.current_user_role() = 'elder'
    and old.status = 'approved'
    and new.status = 'booked'
    and new.id = old.id
    and new.driver_id = old.driver_id
    and new.reviewed_by is not distinct from old.reviewed_by
    and new.reviewed_at is not distinct from old.reviewed_at
    and new.rejection_reason is not distinct from old.rejection_reason
    and new.booked_by = auth.uid()
    and new.booked_at is not null
    and new.standing_ride_request_id is not null
  then
    return new;
  end if;

  if new.id <> old.id
    or new.driver_id <> old.driver_id
    or new.reviewed_by is distinct from old.reviewed_by
    or new.reviewed_at is distinct from old.reviewed_at
    or new.rejection_reason is distinct from old.rejection_reason
    or new.booked_by is distinct from old.booked_by
    or new.booked_at is distinct from old.booked_at
    or new.standing_ride_request_id is distinct from old.standing_ride_request_id
  then
    raise exception 'driver standing ride offer protected columns cannot be changed';
  end if;

  if new.status is distinct from old.status then
    if not (
      old.status in ('pending', 'approved')
      and new.status = 'cancelled'
    ) then
      raise exception 'drivers can only cancel pending or approved offers';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists protect_driver_standing_ride_offer_columns
  on public.driver_standing_ride_offers;
create trigger protect_driver_standing_ride_offer_columns
before update on public.driver_standing_ride_offers
for each row execute function private.protect_driver_standing_ride_offer_columns();

alter table public.driver_standing_ride_offers enable row level security;

create or replace function private.is_current_user_driver_offer(p_offer_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select exists (
    select 1
    from public.driver_standing_ride_offers offer
    join public.drivers driver on driver.id = offer.driver_id
    where offer.id = p_offer_id
      and driver.user_id = auth.uid()
  );
$$;

drop policy if exists "driver_standing_ride_offers_select_authorized"
  on public.driver_standing_ride_offers;
create policy "driver_standing_ride_offers_select_authorized"
on public.driver_standing_ride_offers for select
using (
  private.is_admin()
  or private.is_current_user_driver_offer(id)
  or (
    private.current_user_role() = 'elder'
    and status = 'approved'
    and coalesce(end_date, current_date) >= current_date
  )
);

drop policy if exists "driver_standing_ride_offers_insert_driver"
  on public.driver_standing_ride_offers;
create policy "driver_standing_ride_offers_insert_driver"
on public.driver_standing_ride_offers for insert
with check (
  private.is_current_user_driver(driver_id)
  and status = 'pending'
);

drop policy if exists "driver_standing_ride_offers_update_authorized"
  on public.driver_standing_ride_offers;
create policy "driver_standing_ride_offers_update_authorized"
on public.driver_standing_ride_offers for update
using (private.is_admin() or private.is_current_user_driver_offer(id))
with check (private.is_admin() or private.is_current_user_driver_offer(id));

grant select, insert, update on public.driver_standing_ride_offers to authenticated;
grant execute on function private.is_current_user_driver_offer(uuid) to authenticated;

create or replace function private.normalize_service_weekdays(
  p_service_weekdays smallint[]
)
returns smallint[]
language plpgsql
immutable
as $$
declare
  v_weekdays smallint[];
begin
  select array_agg(distinct weekday order by weekday)
  into v_weekdays
  from unnest(p_service_weekdays) as weekday;

  if v_weekdays is null or cardinality(v_weekdays) = 0 then
    raise exception 'at least one service weekday is required';
  end if;

  if cardinality(v_weekdays) <> cardinality(p_service_weekdays) then
    raise exception 'service weekdays must not contain duplicates';
  end if;

  if not (v_weekdays <@ array[1,2,3,4,5,6,7]::smallint[]) then
    raise exception 'service weekdays must be ISO weekday values 1 through 7';
  end if;

  return v_weekdays;
end;
$$;

create or replace function private.materialize_standing_ride_requests(
  p_standing_ride_request_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_request public.standing_ride_requests;
  v_inserted integer := 0;
begin
  select * into v_request
  from public.standing_ride_requests
  where id = p_standing_ride_request_id;

  if v_request.id is null then
    raise exception 'standing ride request not found';
  end if;

  if v_request.status <> 'approved' then
    return 0;
  end if;

  with generated_dates as (
    select day::date as ride_date
    from generate_series(
      greatest(v_request.start_date, current_date),
      least(coalesce(v_request.end_date, current_date + 29), current_date + 29),
      interval '1 day'
    ) as day
    where extract(isodow from day)::smallint = any(v_request.service_weekdays)
  ),
  inserted as (
    insert into public.ride_requests (
      elder_id,
      pickup_location,
      destination,
      custom_destination,
      ride_date,
      ride_time,
      passenger_count,
      need_return,
      return_time,
      note,
      standing_ride_request_id
    )
    select
      v_request.elder_id,
      v_request.pickup_location,
      v_request.destination,
      v_request.custom_destination,
      generated_dates.ride_date,
      v_request.ride_time,
      v_request.passenger_count,
      v_request.need_return,
      case when v_request.need_return then v_request.return_time else null end,
      v_request.note,
      v_request.id
    from generated_dates
    on conflict (standing_ride_request_id, ride_date)
    where standing_ride_request_id is not null
    do nothing
    returning id
  ),
  matched as (
    insert into public.ride_matches (
      ride_request_id,
      driver_id,
      matched_by,
      match_type
    )
    select id, v_request.driver_id, null, 'auto'
    from inserted
    where v_request.driver_id is not null
    on conflict (ride_request_id) do nothing
    returning 1
  )
  select count(*) into v_inserted from inserted;

  return v_inserted;
end;
$$;

create or replace function public.create_driver_standing_ride_offer(
  p_pickup_location text,
  p_destination text,
  p_custom_destination text,
  p_ride_time time,
  p_passenger_count integer,
  p_need_return boolean,
  p_return_time time,
  p_note text,
  p_service_weekdays smallint[],
  p_start_date date,
  p_end_date date default null
)
returns public.driver_standing_ride_offers
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_driver_id uuid;
  v_offer public.driver_standing_ride_offers;
begin
  select id into v_driver_id
  from public.drivers
  where user_id = auth.uid()
    and approval_status = 'approved';

  if v_driver_id is null then
    raise exception 'approved driver profile not found';
  end if;

  if p_start_date < current_date then
    raise exception 'start date cannot be in the past';
  end if;

  if p_end_date is not null and p_end_date < p_start_date then
    raise exception 'end date cannot be before start date';
  end if;

  insert into public.driver_standing_ride_offers (
    driver_id,
    pickup_location,
    destination,
    custom_destination,
    ride_time,
    passenger_count,
    need_return,
    return_time,
    note,
    service_weekdays,
    start_date,
    end_date
  )
  values (
    v_driver_id,
    nullif(trim(p_pickup_location), ''),
    nullif(trim(p_destination), ''),
    nullif(trim(p_custom_destination), ''),
    p_ride_time,
    p_passenger_count,
    coalesce(p_need_return, false),
    case when coalesce(p_need_return, false) then p_return_time else null end,
    nullif(trim(p_note), ''),
    private.normalize_service_weekdays(p_service_weekdays),
    p_start_date,
    p_end_date
  )
  returning * into v_offer;

  perform private.notify_admins(
    '新的長期接送方案待審',
    '司機已送出長期接送方案，請審核。',
    'driver_standing_ride_offer_created',
    null
  );

  return v_offer;
end;
$$;

create or replace function public.approve_driver_standing_ride_offer(
  p_offer_id uuid
)
returns public.driver_standing_ride_offers
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_offer public.driver_standing_ride_offers;
  v_driver_user_id uuid;
begin
  if not private.is_admin() then
    raise exception 'only admins can approve driver standing ride offers';
  end if;

  update public.driver_standing_ride_offers
  set status = 'approved',
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      rejection_reason = null
  where id = p_offer_id
    and status = 'pending'
  returning * into v_offer;

  if v_offer.id is null then
    raise exception 'driver standing ride offer is not pending';
  end if;

  select user_id into v_driver_user_id
  from public.drivers
  where id = v_offer.driver_id;

  insert into public.notifications (user_id, title, message, type)
  values (
    v_driver_user_id,
    '長期接送方案已核准',
    '你的長期接送方案已顯示給長者選擇。',
    'driver_standing_ride_offer_approved'
  );

  return v_offer;
end;
$$;

create or replace function public.reject_driver_standing_ride_offer(
  p_offer_id uuid,
  p_reason text default null
)
returns public.driver_standing_ride_offers
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_offer public.driver_standing_ride_offers;
  v_driver_user_id uuid;
begin
  if not private.is_admin() then
    raise exception 'only admins can reject driver standing ride offers';
  end if;

  update public.driver_standing_ride_offers
  set status = 'rejected',
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      rejection_reason = nullif(trim(p_reason), '')
  where id = p_offer_id
    and status = 'pending'
  returning * into v_offer;

  if v_offer.id is null then
    raise exception 'driver standing ride offer is not pending';
  end if;

  select user_id into v_driver_user_id
  from public.drivers
  where id = v_offer.driver_id;

  insert into public.notifications (user_id, title, message, type)
  values (
    v_driver_user_id,
    '長期接送方案未通過',
    coalesce(nullif(trim(p_reason), ''), '管理員退回你的長期接送方案。'),
    'driver_standing_ride_offer_rejected'
  );

  return v_offer;
end;
$$;

create or replace function public.cancel_driver_standing_ride_offer(
  p_offer_id uuid
)
returns public.driver_standing_ride_offers
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_offer public.driver_standing_ride_offers;
  v_is_admin boolean;
begin
  select * into v_offer
  from public.driver_standing_ride_offers
  where id = p_offer_id
  for update;

  if v_offer.id is null then
    raise exception 'driver standing ride offer not found';
  end if;

  v_is_admin := private.is_admin();
  if not v_is_admin and not private.is_current_user_driver_offer(p_offer_id) then
    raise exception 'only the driver or an admin can cancel this offer';
  end if;

  if v_offer.status not in ('pending', 'approved') then
    raise exception 'only pending or approved offers can be cancelled';
  end if;

  update public.driver_standing_ride_offers
  set status = 'cancelled'
  where id = p_offer_id
  returning * into v_offer;

  return v_offer;
end;
$$;

create or replace function public.select_driver_standing_ride_offer(
  p_offer_id uuid
)
returns public.standing_ride_requests
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_offer public.driver_standing_ride_offers;
  v_request public.standing_ride_requests;
  v_generated_count integer;
begin
  if private.current_user_role() <> 'elder' then
    raise exception 'only elders can select driver standing ride offers';
  end if;

  select * into v_offer
  from public.driver_standing_ride_offers
  where id = p_offer_id
  for update;

  if v_offer.id is null then
    raise exception 'driver standing ride offer not found';
  end if;

  if v_offer.status <> 'approved' then
    raise exception 'driver standing ride offer is not available';
  end if;

  insert into public.standing_ride_requests (
    elder_id,
    driver_id,
    driver_standing_ride_offer_id,
    pickup_location,
    destination,
    custom_destination,
    ride_time,
    passenger_count,
    need_return,
    return_time,
    note,
    recurrence_pattern,
    service_weekdays,
    start_date,
    end_date,
    status,
    reviewed_by,
    reviewed_at
  )
  values (
    auth.uid(),
    v_offer.driver_id,
    v_offer.id,
    v_offer.pickup_location,
    v_offer.destination,
    v_offer.custom_destination,
    v_offer.ride_time,
    v_offer.passenger_count,
    v_offer.need_return,
    v_offer.return_time,
    v_offer.note,
    'daily',
    v_offer.service_weekdays,
    v_offer.start_date,
    v_offer.end_date,
    'approved',
    null,
    now()
  )
  returning * into v_request;

  update public.driver_standing_ride_offers
  set status = 'booked',
      booked_by = auth.uid(),
      booked_at = now(),
      standing_ride_request_id = v_request.id
  where id = v_offer.id;

  v_generated_count := private.materialize_standing_ride_requests(v_request.id);

  insert into public.notifications (user_id, title, message, type)
  values (
    auth.uid(),
    '已建立長期接送',
    format('已建立長期接送，未來 30 天產生 %s 筆行程。', v_generated_count),
    'standing_ride_selected'
  );

  perform private.notify_admins(
    '長者已選擇長期接送',
    '長者已選擇司機長期接送方案並直接配對。',
    'standing_ride_selected',
    null
  );

  return v_request;
end;
$$;

revoke execute on function public.create_driver_standing_ride_offer(
  text, text, text, time, integer, boolean, time, text, smallint[], date, date
) from public, anon;
revoke execute on function public.approve_driver_standing_ride_offer(uuid)
  from public, anon;
revoke execute on function public.reject_driver_standing_ride_offer(uuid, text)
  from public, anon;
revoke execute on function public.cancel_driver_standing_ride_offer(uuid)
  from public, anon;
revoke execute on function public.select_driver_standing_ride_offer(uuid)
  from public, anon;

grant execute on function public.create_driver_standing_ride_offer(
  text, text, text, time, integer, boolean, time, text, smallint[], date, date
) to authenticated;
grant execute on function public.approve_driver_standing_ride_offer(uuid)
  to authenticated;
grant execute on function public.reject_driver_standing_ride_offer(uuid, text)
  to authenticated;
grant execute on function public.cancel_driver_standing_ride_offer(uuid)
  to authenticated;
grant execute on function public.select_driver_standing_ride_offer(uuid)
  to authenticated;

alter publication supabase_realtime add table public.driver_standing_ride_offers;
