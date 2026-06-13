alter table public.profiles
  add column if not exists emergency_contact_name text,
  add column if not exists emergency_contact_phone text,
  add column if not exists emergency_contact_relation text;

create table if not exists public.driver_locations (
  id uuid primary key default gen_random_uuid(),
  ride_match_id uuid not null unique references public.ride_matches(id) on delete cascade,
  ride_request_id uuid not null references public.ride_requests(id) on delete cascade,
  driver_id uuid not null references public.drivers(id) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  accuracy_meters double precision,
  heading double precision,
  speed_mps double precision,
  updated_at timestamptz not null default now()
);

create table if not exists public.ride_events (
  id uuid primary key default gen_random_uuid(),
  ride_request_id uuid not null references public.ride_requests(id) on delete cascade,
  ride_match_id uuid references public.ride_matches(id) on delete set null,
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  message text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.ride_feedback (
  id uuid primary key default gen_random_uuid(),
  ride_request_id uuid not null references public.ride_requests(id) on delete cascade,
  ride_match_id uuid references public.ride_matches(id) on delete set null,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reporter_role text not null check (reporter_role in ('elder', 'driver', 'admin')),
  rating integer check (rating between 1 and 5),
  comment text,
  issue_type text,
  issue_description text,
  is_resolved boolean not null default false,
  resolved_by uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists driver_locations_ride_request_id_idx
  on public.driver_locations(ride_request_id);
create index if not exists driver_locations_driver_id_idx
  on public.driver_locations(driver_id);
create index if not exists ride_events_ride_request_id_created_at_idx
  on public.ride_events(ride_request_id, created_at desc);
create index if not exists ride_feedback_ride_request_id_idx
  on public.ride_feedback(ride_request_id);
create index if not exists ride_feedback_unresolved_idx
  on public.ride_feedback(is_resolved)
  where issue_type is not null and is_resolved = false;
create unique index if not exists ride_feedback_one_rating_per_reporter_idx
  on public.ride_feedback(ride_request_id, reporter_id)
  where rating is not null;

alter table public.driver_locations enable row level security;
alter table public.ride_events enable row level security;
alter table public.ride_feedback enable row level security;

drop policy if exists "driver_locations_select_authorized" on public.driver_locations;
create policy "driver_locations_select_authorized"
on public.driver_locations for select
using (
  private.is_admin()
  or private.is_current_user_driver(driver_id)
  or private.is_current_user_elder_for_request(ride_request_id)
);

drop policy if exists "driver_locations_upsert_driver" on public.driver_locations;
create policy "driver_locations_upsert_driver"
on public.driver_locations for insert
with check (private.is_current_user_driver(driver_id));

drop policy if exists "driver_locations_update_driver" on public.driver_locations;
create policy "driver_locations_update_driver"
on public.driver_locations for update
using (private.is_current_user_driver(driver_id))
with check (private.is_current_user_driver(driver_id));

drop policy if exists "ride_events_select_authorized" on public.ride_events;
create policy "ride_events_select_authorized"
on public.ride_events for select
using (
  private.is_admin()
  or private.is_current_user_elder_for_request(ride_request_id)
  or exists (
    select 1
    from public.ride_matches rm
    where rm.ride_request_id = ride_events.ride_request_id
      and private.is_current_user_driver(rm.driver_id)
  )
);

drop policy if exists "ride_feedback_select_authorized" on public.ride_feedback;
create policy "ride_feedback_select_authorized"
on public.ride_feedback for select
using (
  private.is_admin()
  or reporter_id = (select auth.uid())
  or private.is_current_user_elder_for_request(ride_request_id)
  or exists (
    select 1
    from public.ride_matches rm
    where rm.ride_request_id = ride_feedback.ride_request_id
      and private.is_current_user_driver(rm.driver_id)
  )
);

drop policy if exists "ride_feedback_insert_self" on public.ride_feedback;
create policy "ride_feedback_insert_self"
on public.ride_feedback for insert
with check (reporter_id = (select auth.uid()));

drop policy if exists "ride_feedback_update_admin" on public.ride_feedback;
create policy "ride_feedback_update_admin"
on public.ride_feedback for update
using (private.is_admin())
with check (private.is_admin());

grant select, insert, update on public.driver_locations to authenticated;
grant select on public.ride_events to authenticated;
grant select, insert, update on public.ride_feedback to authenticated;

create or replace function private.record_ride_event(
  p_ride_request_id uuid,
  p_ride_match_id uuid,
  p_event_type text,
  p_message text,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = public, private
as $$
  insert into public.ride_events (
    ride_request_id,
    ride_match_id,
    actor_id,
    event_type,
    message,
    metadata
  )
  values (
    p_ride_request_id,
    p_ride_match_id,
    (select auth.uid()),
    p_event_type,
    p_message,
    coalesce(p_metadata, '{}'::jsonb)
  );
$$;

create or replace function public.upsert_driver_location(
  p_ride_match_id uuid,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy_meters double precision default null,
  p_heading double precision default null,
  p_speed_mps double precision default null
)
returns public.driver_locations
language plpgsql
security invoker
set search_path = public, private
as $$
declare
  v_match public.ride_matches;
  v_location public.driver_locations;
begin
  select * into v_match
  from public.ride_matches
  where id = p_ride_match_id;

  if v_match.id is null then
    raise exception 'ride match not found';
  end if;

  if not private.is_current_user_driver(v_match.driver_id) then
    raise exception 'only the assigned driver can update location';
  end if;

  if v_match.status in ('completed', 'cancelled') then
    raise exception 'cannot update location for a finished ride';
  end if;

  insert into public.driver_locations (
    ride_match_id,
    ride_request_id,
    driver_id,
    latitude,
    longitude,
    accuracy_meters,
    heading,
    speed_mps,
    updated_at
  )
  values (
    v_match.id,
    v_match.ride_request_id,
    v_match.driver_id,
    p_latitude,
    p_longitude,
    p_accuracy_meters,
    p_heading,
    p_speed_mps,
    now()
  )
  on conflict (ride_match_id) do update set
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    accuracy_meters = excluded.accuracy_meters,
    heading = excluded.heading,
    speed_mps = excluded.speed_mps,
    updated_at = now()
  returning * into v_location;

  return v_location;
end;
$$;

create or replace function public.cancel_ride_request(
  p_ride_request_id uuid,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_request public.ride_requests;
  v_match public.ride_matches;
  v_driver_user_id uuid;
  v_is_admin boolean;
begin
  select * into v_request
  from public.ride_requests
  where id = p_ride_request_id
  for update;

  if v_request.id is null then
    raise exception 'ride request not found';
  end if;

  v_is_admin := private.is_admin();
  if not v_is_admin and v_request.elder_id <> (select auth.uid()) then
    raise exception 'only the elder or an admin can cancel this ride';
  end if;

  if v_request.status in ('completed', 'cancelled') then
    raise exception 'cannot cancel a completed or cancelled ride';
  end if;

  select * into v_match
  from public.ride_matches
  where ride_request_id = p_ride_request_id;

  if v_match.id is not null and v_match.status <> 'cancelled' then
    update public.ride_matches
    set status = 'cancelled'
    where id = v_match.id;

    select user_id into v_driver_user_id
    from public.drivers
    where id = v_match.driver_id;

    insert into public.notifications (user_id, title, message, type, related_ride_request_id)
    values (
      v_driver_user_id,
      '行程已取消',
      coalesce(nullif(p_reason, ''), '接送行程已取消。'),
      'ride_cancelled',
      p_ride_request_id
    );
  end if;

  update public.ride_requests
  set status = 'cancelled'
  where id = p_ride_request_id;

  insert into public.notifications (user_id, title, message, type, related_ride_request_id)
  values (
    v_request.elder_id,
    '行程已取消',
    coalesce(nullif(p_reason, ''), '接送行程已取消。'),
    'ride_cancelled',
    p_ride_request_id
  );

  if not v_is_admin then
    perform private.notify_admins(
      '長者取消行程',
      coalesce(nullif(p_reason, ''), '長者已取消接送行程。'),
      'ride_cancelled',
      p_ride_request_id
    );
  end if;

  perform private.record_ride_event(
    p_ride_request_id,
    v_match.id,
    'ride_cancelled',
    p_reason,
    jsonb_build_object('reason', p_reason)
  );
end;
$$;

create or replace function public.reschedule_ride_request(
  p_ride_request_id uuid,
  p_ride_date date,
  p_ride_time time,
  p_return_time time default null
)
returns public.ride_requests
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_request public.ride_requests;
  v_match public.ride_matches;
  v_driver_user_id uuid;
begin
  if not private.is_admin() then
    raise exception 'only admins can reschedule rides';
  end if;

  select * into v_request
  from public.ride_requests
  where id = p_ride_request_id
  for update;

  if v_request.id is null then
    raise exception 'ride request not found';
  end if;

  if v_request.status in ('completed', 'cancelled') then
    raise exception 'cannot reschedule a completed or cancelled ride';
  end if;

  update public.ride_requests
  set ride_date = p_ride_date,
      ride_time = p_ride_time,
      return_time = case when need_return then p_return_time else null end
  where id = p_ride_request_id
  returning * into v_request;

  select * into v_match from public.ride_matches where ride_request_id = p_ride_request_id;
  if v_match.id is not null then
    select user_id into v_driver_user_id from public.drivers where id = v_match.driver_id;
    insert into public.notifications (user_id, title, message, type, related_ride_request_id)
    values (v_driver_user_id, '行程時間已更新', '管理員已更新接送時間，請查看任務內容。', 'ride_rescheduled', p_ride_request_id);
  end if;

  insert into public.notifications (user_id, title, message, type, related_ride_request_id)
  values (v_request.elder_id, '行程時間已更新', '管理員已更新接送時間。', 'ride_rescheduled', p_ride_request_id);

  perform private.record_ride_event(
    p_ride_request_id,
    v_match.id,
    'ride_rescheduled',
    '管理員更新行程時間。',
    jsonb_build_object('ride_date', p_ride_date, 'ride_time', p_ride_time, 'return_time', p_return_time)
  );

  return v_request;
end;
$$;

create or replace function public.reassign_ride(
  p_ride_request_id uuid,
  p_new_driver_id uuid
)
returns public.ride_matches
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_request public.ride_requests;
  v_old_match public.ride_matches;
  v_new_match public.ride_matches;
  v_driver public.drivers;
  v_old_driver_user_id uuid;
begin
  if not private.is_admin() then
    raise exception 'only admins can reassign rides';
  end if;

  select * into v_request
  from public.ride_requests
  where id = p_ride_request_id
  for update;

  if v_request.id is null then
    raise exception 'ride request not found';
  end if;

  if v_request.status in ('completed', 'cancelled') then
    raise exception 'cannot reassign a completed or cancelled ride';
  end if;

  select * into v_driver
  from public.drivers
  where id = p_new_driver_id
    and approval_status = 'approved';

  if v_driver.id is null then
    raise exception 'new driver is not approved';
  end if;

  if v_request.passenger_count > v_driver.max_passengers then
    raise exception 'passenger count exceeds driver capacity';
  end if;

  select * into v_old_match
  from public.ride_matches
  where ride_request_id = p_ride_request_id;

  if v_old_match.id is not null then
    select user_id into v_old_driver_user_id
    from public.drivers
    where id = v_old_match.driver_id;

    delete from public.driver_locations where ride_match_id = v_old_match.id;
    delete from public.ride_matches where id = v_old_match.id;

    insert into public.notifications (user_id, title, message, type, related_ride_request_id)
    values (v_old_driver_user_id, '行程已改派', '管理員已將接送任務改派給其他司機。', 'ride_reassigned', p_ride_request_id);
  end if;

  update public.ride_requests
  set status = 'pending'
  where id = p_ride_request_id;

  insert into public.ride_matches (
    ride_request_id,
    driver_id,
    matched_by,
    match_type
  )
  values (
    p_ride_request_id,
    p_new_driver_id,
    (select auth.uid()),
    'manual'
  )
  returning * into v_new_match;

  perform private.record_ride_event(
    p_ride_request_id,
    v_new_match.id,
    'ride_reassigned',
    '管理員改派行程。',
    jsonb_build_object('old_driver_id', v_old_match.driver_id, 'new_driver_id', p_new_driver_id)
  );

  return v_new_match;
end;
$$;

create or replace function public.submit_ride_feedback(
  p_ride_request_id uuid,
  p_rating integer default null,
  p_comment text default null,
  p_issue_type text default null,
  p_issue_description text default null
)
returns public.ride_feedback
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_request public.ride_requests;
  v_match public.ride_matches;
  v_role text;
  v_feedback public.ride_feedback;
begin
  select * into v_request
  from public.ride_requests
  where id = p_ride_request_id;

  if v_request.id is null then
    raise exception 'ride request not found';
  end if;

  select * into v_match
  from public.ride_matches
  where ride_request_id = p_ride_request_id;

  if private.is_current_user_elder_for_request(p_ride_request_id) then
    v_role := 'elder';
  elsif v_match.id is not null and private.is_current_user_driver(v_match.driver_id) then
    v_role := 'driver';
  elsif private.is_admin() then
    v_role := 'admin';
  else
    raise exception 'not authorized to submit feedback for this ride';
  end if;

  if p_rating is not null and v_request.status <> 'completed' then
    raise exception 'rating is only available after ride completion';
  end if;

  if p_rating is null and nullif(p_issue_type, '') is null then
    raise exception 'feedback must include a rating or an issue type';
  end if;

  insert into public.ride_feedback (
    ride_request_id,
    ride_match_id,
    reporter_id,
    reporter_role,
    rating,
    comment,
    issue_type,
    issue_description
  )
  values (
    p_ride_request_id,
    v_match.id,
    (select auth.uid()),
    v_role,
    p_rating,
    nullif(p_comment, ''),
    nullif(p_issue_type, ''),
    nullif(p_issue_description, '')
  )
  returning * into v_feedback;

  if nullif(p_issue_type, '') is not null then
    perform private.notify_admins(
      '有新的問題回報',
      coalesce(nullif(p_issue_description, ''), '使用者送出行程問題回報。'),
      'ride_issue_reported',
      p_ride_request_id
    );
  end if;

  perform private.record_ride_event(
    p_ride_request_id,
    v_match.id,
    'ride_feedback_submitted',
    coalesce(p_issue_type, 'rating'),
    jsonb_build_object('rating', p_rating, 'issue_type', p_issue_type)
  );

  return v_feedback;
end;
$$;

create or replace function public.resolve_ride_feedback(
  p_feedback_id uuid
)
returns public.ride_feedback
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_feedback public.ride_feedback;
begin
  if not private.is_admin() then
    raise exception 'only admins can resolve feedback';
  end if;

  update public.ride_feedback
  set is_resolved = true,
      resolved_by = (select auth.uid()),
      resolved_at = now()
  where id = p_feedback_id
  returning * into v_feedback;

  if v_feedback.id is null then
    raise exception 'feedback not found';
  end if;

  perform private.record_ride_event(
    v_feedback.ride_request_id,
    v_feedback.ride_match_id,
    'ride_feedback_resolved',
    '管理員已處理問題回報。',
    jsonb_build_object('feedback_id', p_feedback_id)
  );

  return v_feedback;
end;
$$;

grant execute on function public.upsert_driver_location(uuid, double precision, double precision, double precision, double precision, double precision) to authenticated;
grant execute on function public.cancel_ride_request(uuid, text) to authenticated;
grant execute on function public.reschedule_ride_request(uuid, date, time, time) to authenticated;
grant execute on function public.reassign_ride(uuid, uuid) to authenticated;
grant execute on function public.submit_ride_feedback(uuid, integer, text, text, text) to authenticated;
grant execute on function public.resolve_ride_feedback(uuid) to authenticated;

create or replace function private.validate_match_status_transition()
returns trigger
language plpgsql
set search_path = public, private
as $$
begin
  if new.ride_request_id <> old.ride_request_id or new.driver_id <> old.driver_id then
    raise exception 'match identity columns cannot be changed';
  end if;

  if new.status = old.status then
    return new;
  end if;

  if not (
    (old.status = 'matched' and new.status in ('picked_up', 'cancelled')) or
    (old.status = 'picked_up' and new.status in ('on_the_way', 'completed', 'cancelled')) or
    (old.status = 'on_the_way' and new.status in ('completed', 'cancelled'))
  ) then
    raise exception 'invalid ride match status transition from % to %', old.status, new.status;
  end if;

  return new;
end;
$$;

alter publication supabase_realtime add table public.driver_locations;
alter publication supabase_realtime add table public.ride_events;
alter publication supabase_realtime add table public.ride_feedback;
