create table if not exists public.standing_ride_requests (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references public.profiles(id) on delete cascade,
  pickup_location text not null,
  destination text not null,
  custom_destination text,
  ride_time time not null,
  passenger_count integer not null check (passenger_count > 0),
  need_return boolean not null default false,
  return_time time,
  note text,
  recurrence_pattern text not null check (recurrence_pattern in ('daily', 'weekdays')),
  start_date date not null,
  end_date date,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date is null or end_date >= start_date),
  check (need_return or return_time is null)
);

alter table public.ride_requests
  add column if not exists standing_ride_request_id uuid
  references public.standing_ride_requests(id) on delete set null;

create unique index if not exists ride_requests_one_per_standing_day_idx
  on public.ride_requests(standing_ride_request_id, ride_date)
  where standing_ride_request_id is not null;

create index if not exists standing_ride_requests_elder_id_idx
  on public.standing_ride_requests(elder_id);
create index if not exists standing_ride_requests_status_idx
  on public.standing_ride_requests(status);
create index if not exists standing_ride_requests_start_date_idx
  on public.standing_ride_requests(start_date);

drop trigger if exists set_standing_ride_requests_updated_at on public.standing_ride_requests;
create trigger set_standing_ride_requests_updated_at
before update on public.standing_ride_requests
for each row execute function private.set_updated_at();

alter table public.standing_ride_requests enable row level security;

drop policy if exists "standing_ride_requests_select_authorized" on public.standing_ride_requests;
create policy "standing_ride_requests_select_authorized"
on public.standing_ride_requests for select
using (elder_id = (select auth.uid()) or private.is_admin());

drop policy if exists "standing_ride_requests_insert_elder_self" on public.standing_ride_requests;
create policy "standing_ride_requests_insert_elder_self"
on public.standing_ride_requests for insert
with check (
  elder_id = (select auth.uid())
  and private.current_user_role() = 'elder'
  and status = 'pending'
);

drop policy if exists "standing_ride_requests_update_owner_or_admin" on public.standing_ride_requests;
create policy "standing_ride_requests_update_owner_or_admin"
on public.standing_ride_requests for update
using (elder_id = (select auth.uid()) or private.is_admin())
with check (elder_id = (select auth.uid()) or private.is_admin());

grant select, insert on public.standing_ride_requests to authenticated;

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
    where v_request.recurrence_pattern = 'daily'
       or (
         v_request.recurrence_pattern = 'weekdays'
         and extract(isodow from day) between 1 and 5
       )
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
    returning 1
  )
  select count(*) into v_inserted from inserted;

  return v_inserted;
end;
$$;

create or replace function public.create_standing_ride_request(
  p_pickup_location text,
  p_destination text,
  p_custom_destination text,
  p_ride_time time,
  p_passenger_count integer,
  p_need_return boolean,
  p_return_time time,
  p_note text,
  p_recurrence_pattern text,
  p_start_date date,
  p_end_date date default null
)
returns public.standing_ride_requests
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_request public.standing_ride_requests;
begin
  if private.current_user_role() <> 'elder' then
    raise exception 'only elders can create standing ride requests';
  end if;

  if p_recurrence_pattern not in ('daily', 'weekdays') then
    raise exception 'unsupported recurrence pattern';
  end if;

  if p_start_date < current_date then
    raise exception 'start date cannot be in the past';
  end if;

  if p_end_date is not null and p_end_date < p_start_date then
    raise exception 'end date cannot be before start date';
  end if;

  insert into public.standing_ride_requests (
    elder_id,
    pickup_location,
    destination,
    custom_destination,
    ride_time,
    passenger_count,
    need_return,
    return_time,
    note,
    recurrence_pattern,
    start_date,
    end_date
  )
  values (
    (select auth.uid()),
    nullif(trim(p_pickup_location), ''),
    nullif(trim(p_destination), ''),
    nullif(trim(p_custom_destination), ''),
    p_ride_time,
    p_passenger_count,
    coalesce(p_need_return, false),
    case when coalesce(p_need_return, false) then p_return_time else null end,
    nullif(trim(p_note), ''),
    p_recurrence_pattern,
    p_start_date,
    p_end_date
  )
  returning * into v_request;

  perform private.notify_admins(
    '有新的長期接送申請',
    '長者提出長期接送申請，等待審核。',
    'standing_ride_request_created',
    null
  );

  return v_request;
end;
$$;

create or replace function public.approve_standing_ride_request(
  p_standing_ride_request_id uuid
)
returns public.standing_ride_requests
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_request public.standing_ride_requests;
  v_generated_count integer;
begin
  if not private.is_admin() then
    raise exception 'only admins can approve standing ride requests';
  end if;

  update public.standing_ride_requests
  set status = 'approved',
      reviewed_by = (select auth.uid()),
      reviewed_at = now(),
      rejection_reason = null
  where id = p_standing_ride_request_id
    and status = 'pending'
  returning * into v_request;

  if v_request.id is null then
    raise exception 'standing ride request is not pending';
  end if;

  v_generated_count := private.materialize_standing_ride_requests(v_request.id);

  insert into public.notifications (user_id, title, message, type)
  values (
    v_request.elder_id,
    '長期接送申請已通過',
    format('管理員已通過申請，已建立 %s 筆近期接送。', v_generated_count),
    'standing_ride_approved'
  );

  return v_request;
end;
$$;

create or replace function public.reject_standing_ride_request(
  p_standing_ride_request_id uuid,
  p_reason text default null
)
returns public.standing_ride_requests
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_request public.standing_ride_requests;
begin
  if not private.is_admin() then
    raise exception 'only admins can reject standing ride requests';
  end if;

  update public.standing_ride_requests
  set status = 'rejected',
      reviewed_by = (select auth.uid()),
      reviewed_at = now(),
      rejection_reason = nullif(trim(p_reason), '')
  where id = p_standing_ride_request_id
    and status = 'pending'
  returning * into v_request;

  if v_request.id is null then
    raise exception 'standing ride request is not pending';
  end if;

  insert into public.notifications (user_id, title, message, type)
  values (
    v_request.elder_id,
    '長期接送申請未通過',
    coalesce(nullif(trim(p_reason), ''), '管理員未通過你的長期接送申請。'),
    'standing_ride_rejected'
  );

  return v_request;
end;
$$;

create or replace function public.cancel_standing_ride_request(
  p_standing_ride_request_id uuid
)
returns public.standing_ride_requests
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_request public.standing_ride_requests;
  v_is_admin boolean;
begin
  select * into v_request
  from public.standing_ride_requests
  where id = p_standing_ride_request_id
  for update;

  if v_request.id is null then
    raise exception 'standing ride request not found';
  end if;

  v_is_admin := private.is_admin();
  if not v_is_admin and v_request.elder_id <> (select auth.uid()) then
    raise exception 'only the elder or an admin can cancel this standing ride request';
  end if;

  if v_request.status in ('rejected', 'cancelled') then
    raise exception 'standing ride request cannot be cancelled';
  end if;

  update public.standing_ride_requests
  set status = 'cancelled'
  where id = p_standing_ride_request_id
  returning * into v_request;

  update public.ride_requests
  set status = 'cancelled'
  where standing_ride_request_id = p_standing_ride_request_id
    and status = 'pending'
    and ride_date >= current_date;

  if v_is_admin then
    insert into public.notifications (user_id, title, message, type)
    values (
      v_request.elder_id,
      '長期接送已取消',
      '管理員已取消長期接送申請，未媒合的未來接送已取消。',
      'standing_ride_cancelled'
    );
  else
    perform private.notify_admins(
      '長者取消長期接送',
      '長者已取消長期接送申請。',
      'standing_ride_cancelled',
      null
    );
  end if;

  return v_request;
end;
$$;

create or replace function public.generate_standing_ride_requests(
  p_standing_ride_request_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if not private.is_admin() then
    raise exception 'only admins can generate standing ride requests';
  end if;

  return private.materialize_standing_ride_requests(p_standing_ride_request_id);
end;
$$;

grant execute on function public.create_standing_ride_request(text, text, text, time, integer, boolean, time, text, text, date, date) to authenticated;
grant execute on function public.approve_standing_ride_request(uuid) to authenticated;
grant execute on function public.reject_standing_ride_request(uuid, text) to authenticated;
grant execute on function public.cancel_standing_ride_request(uuid) to authenticated;
grant execute on function public.generate_standing_ride_requests(uuid) to authenticated;

create or replace function private.notify_new_ride_request()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if new.standing_ride_request_id is not null then
    return new;
  end if;

  insert into public.notifications (user_id, title, message, type, related_ride_request_id)
  values (
    new.elder_id,
    '已建立接送申請',
    '你的接送申請已建立，等待媒合。',
    'ride_request_created',
    new.id
  );

  perform private.notify_admins(
    '有新的接送申請',
    '有新的接送申請等待媒合。',
    'ride_request_created',
    new.id
  );

  return new;
end;
$$;

alter publication supabase_realtime add table public.standing_ride_requests;
