-- 長者穿戴監控：health_connections / health_metrics / alert_rules /
-- alert_events / notification_outbox
-- 請在 Supabase SQL Editor 貼上並執行。

-- ---------------------------------------------------------------------------
-- health_connections：長輩裝置綁定狀態（Health Connect，本機授權，非 OAuth token）
-- ---------------------------------------------------------------------------
create table if not exists public.health_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  provider text not null default 'health_connect',
  status text not null default 'linked',
  scopes jsonb not null default '[]'::jsonb,
  device_platform text,
  last_sync_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint health_connections_provider_check
    check (provider in ('health_connect')),
  constraint health_connections_status_check
    check (status in ('linked', 'revoked')),
  constraint health_connections_user_provider_unique
    unique (user_id, provider)
);

create index if not exists health_connections_user_idx
  on public.health_connections (user_id);

-- ---------------------------------------------------------------------------
-- health_metrics：時序指標（長輩端 upsert；志工端唯讀）
-- ---------------------------------------------------------------------------
create table if not exists public.health_metrics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  metric_type text not null,
  value numeric not null,
  unit text,
  recorded_at timestamptz not null,
  source text not null default 'health_connect',
  created_at timestamptz not null default now(),
  constraint health_metrics_type_check
    check (
      metric_type in (
        'heart_rate', 'steps', 'sleep_minutes',
        'blood_oxygen', 'resting_heart_rate'
      )
    ),
  constraint health_metrics_user_type_time_source_unique
    unique (user_id, metric_type, recorded_at, source)
);

create index if not exists health_metrics_user_recorded_idx
  on public.health_metrics (user_id, recorded_at desc);

create index if not exists health_metrics_user_type_idx
  on public.health_metrics (user_id, metric_type, recorded_at desc);

-- ---------------------------------------------------------------------------
-- alert_rules：全域預設規則（Edge Function 讀取；authenticated 唯讀）
-- ---------------------------------------------------------------------------
create table if not exists public.alert_rules (
  id uuid primary key default gen_random_uuid(),
  metric_type text not null,
  min_value numeric,
  max_value numeric,
  severity text not null default 'warning',
  enabled boolean not null default true,
  cooldown_minutes int not null default 60,
  created_at timestamptz not null default now(),
  constraint alert_rules_severity_check
    check (severity in ('info', 'warning', 'critical'))
);

-- 預設規則（心率、靜息心率、血氧）
insert into public.alert_rules (metric_type, min_value, max_value, severity, cooldown_minutes)
select 'heart_rate', 50, 120, 'warning', 60
where not exists (
  select 1 from public.alert_rules where metric_type = 'heart_rate'
);
insert into public.alert_rules (metric_type, min_value, max_value, severity, cooldown_minutes)
select 'resting_heart_rate', 45, 100, 'warning', 120
where not exists (
  select 1 from public.alert_rules where metric_type = 'resting_heart_rate'
);
insert into public.alert_rules (metric_type, min_value, max_value, severity, cooldown_minutes)
select 'blood_oxygen', 90, null, 'critical', 30
where not exists (
  select 1 from public.alert_rules where metric_type = 'blood_oxygen'
);

-- ---------------------------------------------------------------------------
-- alert_events：已觸發紀錄（冷卻防重複）
-- ---------------------------------------------------------------------------
create table if not exists public.alert_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  rule_id uuid not null references public.alert_rules (id) on delete cascade,
  metric_type text not null,
  metric_value numeric not null,
  triggered_at timestamptz not null default now(),
  acknowledged_at timestamptz
);

create index if not exists alert_events_user_triggered_idx
  on public.alert_events (user_id, triggered_at desc);

-- ---------------------------------------------------------------------------
-- notification_outbox：本機通知派送佇列
-- ---------------------------------------------------------------------------
create table if not exists public.notification_outbox (
  id uuid primary key default gen_random_uuid(),
  target_user_id uuid not null references auth.users (id) on delete cascade,
  elder_user_id uuid references auth.users (id) on delete cascade,
  title text not null,
  body text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  constraint notification_outbox_status_check
    check (status in ('pending', 'sent', 'failed'))
);

create index if not exists notification_outbox_target_status_idx
  on public.notification_outbox (target_user_id, status, created_at desc);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.health_connections    enable row level security;
alter table public.health_metrics        enable row level security;
alter table public.alert_rules           enable row level security;
alter table public.alert_events          enable row level security;
alter table public.notification_outbox   enable row level security;

grant select, insert, update, delete on public.health_connections  to authenticated;
grant select, insert, update          on public.health_metrics      to authenticated;
grant select                           on public.alert_rules         to authenticated;
grant select                           on public.alert_events        to authenticated;
grant select, insert, update           on public.notification_outbox to authenticated;

-- health_connections：長輩 CRUD 自己；志工唯讀
drop policy if exists "hconn_own_select"      on public.health_connections;
drop policy if exists "hconn_own_insert"      on public.health_connections;
drop policy if exists "hconn_own_update"      on public.health_connections;
drop policy if exists "hconn_own_delete"      on public.health_connections;
drop policy if exists "hconn_vol_select"      on public.health_connections;

create policy "hconn_own_select"
  on public.health_connections for select to authenticated
  using (auth.uid() = user_id);

create policy "hconn_own_insert"
  on public.health_connections for insert to authenticated
  with check (auth.uid() = user_id);

create policy "hconn_own_update"
  on public.health_connections for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "hconn_own_delete"
  on public.health_connections for delete to authenticated
  using (auth.uid() = user_id);

create policy "hconn_vol_select"
  on public.health_connections for select to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'volunteer'
    )
  );

-- health_metrics：長輩 insert/select 自己；志工唯讀
drop policy if exists "hmet_own_select"  on public.health_metrics;
drop policy if exists "hmet_own_insert"  on public.health_metrics;
drop policy if exists "hmet_vol_select"  on public.health_metrics;

create policy "hmet_own_select"
  on public.health_metrics for select to authenticated
  using (auth.uid() = user_id);

create policy "hmet_own_insert"
  on public.health_metrics for insert to authenticated
  with check (auth.uid() = user_id);

create policy "hmet_vol_select"
  on public.health_metrics for select to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'volunteer'
    )
  );

-- alert_rules：任何登入者可讀
drop policy if exists "arules_select_all" on public.alert_rules;
create policy "arules_select_all"
  on public.alert_rules for select to authenticated
  using (true);

-- alert_events：長輩看自己；志工看全部
drop policy if exists "aevt_own_select" on public.alert_events;
drop policy if exists "aevt_vol_select" on public.alert_events;

create policy "aevt_own_select"
  on public.alert_events for select to authenticated
  using (auth.uid() = user_id);

create policy "aevt_vol_select"
  on public.alert_events for select to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'volunteer'
    )
  );

-- notification_outbox：收件者讀/更新自己
drop policy if exists "outbox_target_select" on public.notification_outbox;
drop policy if exists "outbox_target_update" on public.notification_outbox;

create policy "outbox_target_select"
  on public.notification_outbox for select to authenticated
  using (auth.uid() = target_user_id);

create policy "outbox_target_update"
  on public.notification_outbox for update to authenticated
  using (auth.uid() = target_user_id)
  with check (auth.uid() = target_user_id);

-- ---------------------------------------------------------------------------
-- Realtime：讓 App 收到 INSERT/UPDATE 推送
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'health_metrics'
  ) then
    alter publication supabase_realtime add table public.health_metrics;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'notification_outbox'
  ) then
    alter publication supabase_realtime add table public.notification_outbox;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'health_connections'
  ) then
    alter publication supabase_realtime add table public.health_connections;
  end if;
end $$;
