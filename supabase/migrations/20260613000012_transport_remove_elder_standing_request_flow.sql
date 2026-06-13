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

drop function if exists public.create_standing_ride_request(
  text, text, text, time without time zone, integer, boolean,
  time without time zone, text, text, date, date
);
drop function if exists public.approve_standing_ride_request(uuid);
drop function if exists public.reject_standing_ride_request(uuid, text);
drop function if exists public.cancel_standing_ride_request(uuid);
drop function if exists public.generate_standing_ride_requests(uuid);

drop policy if exists "standing_ride_requests_insert_elder_self"
on public.standing_ride_requests;
drop policy if exists "standing_ride_requests_update_owner_or_admin"
on public.standing_ride_requests;

revoke insert, update on table public.standing_ride_requests
from authenticated;
grant select on table public.standing_ride_requests
to authenticated;

alter table public.standing_ride_requests
drop column if exists recurrence_pattern;

revoke execute on function public.select_driver_standing_ride_offer(uuid)
from public, anon;
grant execute on function public.select_driver_standing_ride_offer(uuid)
to authenticated;
