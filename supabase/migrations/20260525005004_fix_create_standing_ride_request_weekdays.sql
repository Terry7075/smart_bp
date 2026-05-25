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
  v_service_weekdays smallint[];
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

  v_service_weekdays := case p_recurrence_pattern
    when 'daily' then array[1,2,3,4,5,6,7]::smallint[]
    else array[1,2,3,4,5]::smallint[]
  end;

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
    service_weekdays,
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
    v_service_weekdays,
    p_start_date,
    p_end_date
  )
  returning * into v_request;

  perform private.notify_admins(
    '新的定期接送申請',
    '長者已送出定期接送申請，請進行審核。',
    'standing_ride_request_created',
    null
  );

  return v_request;
end;
$$;
