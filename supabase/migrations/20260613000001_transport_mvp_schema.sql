create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  phone text,
  role text not null default 'elder' check (role in ('elder', 'driver', 'admin')),
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.drivers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  name text not null,
  phone text not null,
  address text not null,
  car_plate text not null,
  car_model text,
  max_passengers integer not null check (max_passengers > 0),
  approval_status text not null default 'pending' check (approval_status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ride_requests (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references public.profiles(id) on delete cascade,
  pickup_location text not null,
  destination text not null,
  custom_destination text,
  ride_date date not null,
  ride_time time not null,
  passenger_count integer not null check (passenger_count > 0),
  need_return boolean not null default false,
  return_time time,
  note text,
  distance_km numeric,
  estimated_price integer,
  status text not null default 'pending' check (status in ('pending', 'matched', 'picked_up', 'on_the_way', 'completed', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ride_matches (
  id uuid primary key default gen_random_uuid(),
  ride_request_id uuid not null unique references public.ride_requests(id) on delete cascade,
  driver_id uuid not null references public.drivers(id) on delete restrict,
  matched_by uuid references public.profiles(id) on delete set null,
  match_type text not null check (match_type in ('manual', 'driver_accept', 'auto')),
  status text not null default 'matched' check (status in ('matched', 'picked_up', 'on_the_way', 'completed', 'cancelled')),
  estimated_arrival_minutes integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  message text not null,
  type text not null,
  is_read boolean not null default false,
  related_ride_request_id uuid references public.ride_requests(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists ride_requests_elder_id_idx on public.ride_requests(elder_id);
create index if not exists ride_requests_status_idx on public.ride_requests(status);
create index if not exists ride_requests_ride_date_idx on public.ride_requests(ride_date);
create index if not exists ride_matches_driver_id_idx on public.ride_matches(driver_id);
create index if not exists notifications_user_id_created_at_idx on public.notifications(user_id, created_at desc);

create or replace function private.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- [smart_bp 整合] 移除 profiles 的 updated_at 觸發器：smart_bp 既有 profiles
-- 不保證有 updated_at 欄位，且其註冊/更新流程自成一套，避免干擾。
create trigger set_drivers_updated_at
before update on public.drivers
for each row execute function private.set_updated_at();

create trigger set_ride_requests_updated_at
before update on public.ride_requests
for each row execute function private.set_updated_at();

create trigger set_ride_matches_updated_at
before update on public.ride_matches
for each row execute function private.set_updated_at();

create or replace function private.current_user_role()
returns text
language sql
stable
security definer
set search_path = public, private
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  -- [smart_bp 整合] 志工(volunteer)在交通模組中視同管理員。
  select coalesce(private.current_user_role() in ('admin', 'volunteer'), false);
$$;

create or replace function private.is_approved_driver()
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select exists (
    select 1 from public.drivers
    where user_id = auth.uid()
      and approval_status = 'approved'
  );
$$;

create or replace function private.is_current_user_driver(p_driver_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select exists (
    select 1
    from public.drivers
    where id = p_driver_id
      and user_id = auth.uid()
      and approval_status = 'approved'
  );
$$;

create or replace function private.is_assigned_driver_for_request(p_ride_request_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select exists (
    select 1
    from public.ride_matches rm
    join public.drivers d on d.id = rm.driver_id
    where rm.ride_request_id = p_ride_request_id
      and d.user_id = auth.uid()
  );
$$;

create or replace function private.is_current_user_elder_for_request(p_ride_request_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select exists (
    select 1
    from public.ride_requests
    where id = p_ride_request_id
      and elder_id = auth.uid()
  );
$$;

create or replace function private.can_current_user_view_driver(p_driver_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select exists (
    select 1
    from public.ride_matches rm
    join public.ride_requests rr on rr.id = rm.ride_request_id
    where rm.driver_id = p_driver_id
      and rr.elder_id = auth.uid()
  );
$$;

create or replace function private.calculate_price(distance_km numeric)
returns integer
language sql
immutable
as $$
  select case
    when distance_km is null then null
    when distance_km <= 5 then 20
    when distance_km <= 10 then 50
    else 100
  end;
$$;

-- [smart_bp 整合] 移除 louis 的 handle_new_user / on_auth_user_created：
-- smart_bp 由 App 端 (ProfileNotifier._bootstrapProfileIfMissing) 建立 profiles，
-- 並使用 name 欄位。沿用 louis 觸發器會以 full_name/email 覆寫註冊流程並破壞 smart_bp。
--
-- 同時移除 protect_profile_columns：它檢查 new.email，而 smart_bp profiles
-- 不保證有 email 欄位，會讓 smart_bp 既有的 profiles 更新整批失敗。

create or replace function private.protect_driver_columns()
returns trigger
language plpgsql
as $$
begin
  if new.id <> old.id or new.user_id <> old.user_id then
    raise exception 'driver identity columns cannot be changed';
  end if;

  if new.approval_status <> old.approval_status and not private.is_admin() then
    raise exception 'only admins can change driver approval status';
  end if;

  return new;
end;
$$;

create trigger protect_driver_columns
before update on public.drivers
for each row execute function private.protect_driver_columns();

create or replace function private.calculate_ride_price()
returns trigger
language plpgsql
as $$
begin
  new.estimated_price = private.calculate_price(new.distance_km);
  return new;
end;
$$;

create trigger calculate_ride_price
before insert or update of distance_km on public.ride_requests
for each row execute function private.calculate_ride_price();

create or replace function private.notify_admins(
  p_title text,
  p_message text,
  p_type text,
  p_related_ride_request_id uuid default null
)
returns void
language sql
security definer
set search_path = public, private
as $$
  insert into public.notifications (user_id, title, message, type, related_ride_request_id)
  select id, p_title, p_message, p_type, p_related_ride_request_id
  from public.profiles
  -- [smart_bp 整合] 志工(volunteer)在交通模組中視同管理員，一併收到通知。
  where role in ('admin', 'volunteer');
$$;

create or replace function private.notify_new_ride_request()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
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

create trigger notify_new_ride_request
after insert on public.ride_requests
for each row execute function private.notify_new_ride_request();

create or replace function private.handle_driver_review()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if old.approval_status is distinct from new.approval_status then
    if new.approval_status = 'approved' then
      update public.profiles
      set role = 'driver'
      where id = new.user_id;

      insert into public.notifications (user_id, title, message, type)
      values (
        new.user_id,
        '司機審核通過',
        '你已通過審核，可以開始接送。',
        'driver_approved'
      );
    elsif new.approval_status = 'rejected' then
      insert into public.notifications (user_id, title, message, type)
      values (
        new.user_id,
        '司機申請未通過',
        '你的司機申請未通過，請聯絡管理員確認。',
        'driver_rejected'
      );
    end if;
  end if;

  return new;
end;
$$;

create trigger handle_driver_review
after update of approval_status on public.drivers
for each row execute function private.handle_driver_review();

create or replace function private.validate_new_match()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_request public.ride_requests;
  v_driver public.drivers;
begin
  select * into v_request from public.ride_requests where id = new.ride_request_id for update;
  if v_request.id is null then
    raise exception 'ride request not found';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'ride request is no longer pending';
  end if;

  select * into v_driver from public.drivers where id = new.driver_id;
  if v_driver.id is null or v_driver.approval_status <> 'approved' then
    raise exception 'driver is not approved';
  end if;
  if v_request.passenger_count > v_driver.max_passengers then
    raise exception 'passenger count exceeds driver capacity';
  end if;

  if new.match_type = 'driver_accept' and v_driver.user_id <> auth.uid() then
    raise exception 'drivers can only accept rides for themselves';
  end if;

  if new.match_type = 'manual' and not private.is_admin() then
    raise exception 'only admins can manually match rides';
  end if;

  return new;
end;
$$;

create trigger validate_new_match
before insert on public.ride_matches
for each row execute function private.validate_new_match();

create or replace function private.sync_new_match()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_elder_id uuid;
  v_driver_user_id uuid;
  v_driver_name text;
  v_driver_phone text;
  v_driver_plate text;
begin
  update public.ride_requests
  set status = 'matched'
  where id = new.ride_request_id
  returning elder_id into v_elder_id;

  select user_id, name, phone, car_plate
  into v_driver_user_id, v_driver_name, v_driver_phone, v_driver_plate
  from public.drivers
  where id = new.driver_id;

  insert into public.notifications (user_id, title, message, type, related_ride_request_id)
  values (
    v_elder_id,
    '已媒合司機',
    format('司機：%s，電話：%s，車牌：%s。', v_driver_name, v_driver_phone, v_driver_plate),
    'ride_matched',
    new.ride_request_id
  );

  if new.match_type = 'manual' then
    insert into public.notifications (user_id, title, message, type, related_ride_request_id)
    values (
      v_driver_user_id,
      '你有新的接送任務',
      '管理員已指派一筆新的接送任務給你。',
      'ride_matched',
      new.ride_request_id
    );
  elsif new.match_type = 'driver_accept' then
    perform private.notify_admins(
      '有司機接案',
      '一筆接送申請已由司機主動接案。',
      'ride_matched',
      new.ride_request_id
    );
  end if;

  return new;
end;
$$;

create trigger sync_new_match
after insert on public.ride_matches
for each row execute function private.sync_new_match();

create or replace function private.validate_match_status_transition()
returns trigger
language plpgsql
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
    (old.status = 'picked_up' and new.status in ('on_the_way', 'cancelled')) or
    (old.status = 'on_the_way' and new.status in ('completed', 'cancelled'))
  ) then
    raise exception 'invalid ride match status transition from % to %', old.status, new.status;
  end if;

  return new;
end;
$$;

create trigger validate_match_status_transition
before update on public.ride_matches
for each row execute function private.validate_match_status_transition();

create or replace function private.sync_match_status()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_elder_id uuid;
begin
  if old.status is distinct from new.status then
    update public.ride_requests
    set status = new.status
    where id = new.ride_request_id
    returning elder_id into v_elder_id;

    if new.status in ('picked_up', 'on_the_way', 'completed') then
      insert into public.notifications (user_id, title, message, type, related_ride_request_id)
      values (
        v_elder_id,
        case new.status
          when 'picked_up' then '司機已接到人'
          when 'on_the_way' then '目前路途中'
          when 'completed' then '已送達'
        end,
        case new.status
          when 'picked_up' then '司機已接到人。'
          when 'on_the_way' then '目前路途中。'
          when 'completed' then '已送達目的地。'
        end,
        'ride_status_updated',
        new.ride_request_id
      );

      perform private.notify_admins(
        case new.status
          when 'picked_up' then '司機已接到人'
          when 'on_the_way' then '目前路途中'
          when 'completed' then '已送達'
        end,
        case new.status
          when 'picked_up' then '司機已接到人。'
          when 'on_the_way' then '目前路途中。'
          when 'completed' then '已送達目的地。'
        end,
        'ride_status_updated',
        new.ride_request_id
      );
    end if;
  end if;

  return new;
end;
$$;

create trigger sync_match_status
after update of status on public.ride_matches
for each row execute function private.sync_match_status();

-- [smart_bp 整合] 不更動 public.profiles 的 RLS：保留 smart_bp 既有的
-- profiles 權限設定，避免影響健康/物資/志工等既有模組對 profiles 的存取。
alter table public.drivers enable row level security;
alter table public.ride_requests enable row level security;
alter table public.ride_matches enable row level security;
alter table public.notifications enable row level security;

create policy "drivers_select_authorized"
on public.drivers for select
using (
  user_id = auth.uid()
  or private.is_admin()
  or private.can_current_user_view_driver(id)
);

create policy "drivers_insert_self"
on public.drivers for insert
with check (
  user_id = auth.uid()
  and approval_status = 'pending'
);

create policy "drivers_update_self_or_admin"
on public.drivers for update
using (user_id = auth.uid() or private.is_admin())
with check (user_id = auth.uid() or private.is_admin());

create policy "ride_requests_select_authorized"
on public.ride_requests for select
using (
  elder_id = auth.uid()
  or private.is_admin()
  or (
    private.is_approved_driver()
    and status = 'pending'
  )
  or private.is_assigned_driver_for_request(id)
);

create policy "ride_requests_insert_elder_self"
on public.ride_requests for insert
with check (
  elder_id = auth.uid()
  and private.current_user_role() = 'elder'
  and status = 'pending'
);

create policy "ride_requests_update_admin_only"
on public.ride_requests for update
using (private.is_admin())
with check (private.is_admin());

create policy "ride_matches_select_authorized"
on public.ride_matches for select
using (
  private.is_admin()
  or private.is_current_user_driver(driver_id)
  or private.is_current_user_elder_for_request(ride_request_id)
);

create policy "ride_matches_insert_driver_or_admin"
on public.ride_matches for insert
with check (
  private.is_admin()
  or private.is_current_user_driver(driver_id)
);

create policy "ride_matches_update_driver_or_admin"
on public.ride_matches for update
using (
  private.is_admin()
  or private.is_current_user_driver(driver_id)
)
with check (
  private.is_admin()
  or private.is_current_user_driver(driver_id)
);

create policy "notifications_select_self"
on public.notifications for select
using (user_id = auth.uid());

create policy "notifications_update_self"
on public.notifications for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.drivers to authenticated;
grant select, insert, update on public.ride_requests to authenticated;
grant select, insert, update on public.ride_matches to authenticated;
grant select, update on public.notifications to authenticated;

grant usage on schema private to authenticated;
grant execute on function private.current_user_role() to authenticated;
grant execute on function private.is_admin() to authenticated;
grant execute on function private.is_approved_driver() to authenticated;
grant execute on function private.is_current_user_driver(uuid) to authenticated;
grant execute on function private.is_assigned_driver_for_request(uuid) to authenticated;
grant execute on function private.is_current_user_elder_for_request(uuid) to authenticated;
grant execute on function private.can_current_user_view_driver(uuid) to authenticated;

create or replace function public.accept_ride(p_ride_request_id uuid)
returns public.ride_matches
language plpgsql
security invoker
set search_path = public, private
as $$
declare
  v_driver_id uuid;
  v_match public.ride_matches;
begin
  select id into v_driver_id
  from public.drivers
  where user_id = auth.uid()
    and approval_status = 'approved';

  if v_driver_id is null then
    raise exception 'approved driver profile not found';
  end if;

  insert into public.ride_matches (
    ride_request_id,
    driver_id,
    matched_by,
    match_type
  ) values (
    p_ride_request_id,
    v_driver_id,
    null,
    'driver_accept'
  )
  returning * into v_match;

  return v_match;
end;
$$;

create or replace function public.manual_match_ride(
  p_ride_request_id uuid,
  p_driver_id uuid,
  p_distance_km numeric
)
returns public.ride_matches
language plpgsql
security invoker
set search_path = public, private
as $$
declare
  v_match public.ride_matches;
begin
  if not private.is_admin() then
    raise exception 'only admins can manually match rides';
  end if;

  update public.ride_requests
  set distance_km = p_distance_km
  where id = p_ride_request_id
    and status = 'pending';

  if not found then
    raise exception 'ride request is no longer pending';
  end if;

  insert into public.ride_matches (
    ride_request_id,
    driver_id,
    matched_by,
    match_type
  ) values (
    p_ride_request_id,
    p_driver_id,
    auth.uid(),
    'manual'
  )
  returning * into v_match;

  return v_match;
end;
$$;

grant execute on function public.accept_ride(uuid) to authenticated;
grant execute on function public.manual_match_ride(uuid, uuid, numeric) to authenticated;

-- [smart_bp 整合] 改為冪等寫法，避免 profiles 等表已在 publication 時報錯。
do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'profiles', 'drivers', 'ride_requests', 'ride_matches', 'notifications'
  ]
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = v_table
    ) then
      execute format('alter publication supabase_realtime add table public.%I', v_table);
    end if;
  end loop;
end $$;
