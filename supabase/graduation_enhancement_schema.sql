-- =============================================================================
-- 畢專加強版：配送時間軸、訂單擴充欄位（含歷史 family_elder_links，App 未使用）
-- 在 Supabase SQL Editor 執行（需已有 orders / profiles）
-- =============================================================================

-- 1) orders 擴充欄位
alter table public.orders
  add column if not exists assigned_volunteer_id uuid references auth.users(id),
  add column if not exists delivered_at timestamptz,
  add column if not exists delivery_issue text;

-- 2) 配送事件（時間軸）
create table if not exists public.order_delivery_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  event_type text not null,
  note text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists order_delivery_events_order_id_idx
  on public.order_delivery_events (order_id, created_at asc);

comment on table public.order_delivery_events is
  '訂單配送事件：created/accepted/purchasing/delivering/delivered/issue';

-- 3) 家屬—長輩綁定
create table if not exists public.family_elder_links (
  id uuid primary key default gen_random_uuid(),
  family_user_id uuid not null references auth.users(id) on delete cascade,
  elder_user_id uuid not null references auth.users(id) on delete cascade,
  relation text not null default '家屬',
  can_place_order boolean not null default false,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  unique (family_user_id, elder_user_id)
);

create index if not exists family_elder_links_family_idx
  on public.family_elder_links (family_user_id);

-- 4) 角色輔助（profiles.role 支援 family / admin，文字欄位無需改 enum）

-- 5) RLS：配送事件
alter table public.order_delivery_events enable row level security;

drop policy if exists "delivery_events_select" on public.order_delivery_events;
create policy "delivery_events_select"
on public.order_delivery_events for select
using (
  exists (
    select 1 from public.orders o
    where o.id = order_delivery_events.order_id
      and (
        o.user_id = auth.uid()
        or exists (
          select 1 from public.profiles p
          where p.id = auth.uid() and p.role::text in ('volunteer', 'admin')
        )
        or exists (
          select 1 from public.family_elder_links f
          where f.family_user_id = auth.uid()
            and f.elder_user_id = o.user_id
            and f.status = 'active'
        )
      )
  )
);

drop policy if exists "delivery_events_insert_volunteer" on public.order_delivery_events;
create policy "delivery_events_insert_volunteer"
on public.order_delivery_events for insert
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role::text in ('volunteer', 'admin')
  )
);

-- 6) RLS：家屬綁定
alter table public.family_elder_links enable row level security;

drop policy if exists "family_links_select_own" on public.family_elder_links;
create policy "family_links_select_own"
on public.family_elder_links for select
using (
  family_user_id = auth.uid()
  or elder_user_id = auth.uid()
  or exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role::text = 'admin'
  )
);

drop policy if exists "family_links_insert_family" on public.family_elder_links;
create policy "family_links_insert_family"
on public.family_elder_links for insert
with check (family_user_id = auth.uid());

drop policy if exists "family_links_delete_own" on public.family_elder_links;
create policy "family_links_delete_own"
on public.family_elder_links for delete
using (family_user_id = auth.uid());

-- 7) 家屬可讀綁定長輩的 orders（擴充 orders select）
drop policy if exists "orders_select_family" on public.orders;
create policy "orders_select_family"
on public.orders for select
using (
  exists (
    select 1 from public.family_elder_links f
    where f.family_user_id = auth.uid()
      and f.elder_user_id = orders.user_id
      and f.status = 'active'
  )
);

-- 8) 管理員可讀全部 orders
drop policy if exists "orders_select_admin" on public.orders;
create policy "orders_select_admin"
on public.orders for select
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role::text = 'admin'
  )
);

drop policy if exists "order_items_select_family" on public.order_items;
create policy "order_items_select_family"
on public.order_items for select
using (
  exists (
    select 1 from public.orders o
    join public.family_elder_links f on f.elder_user_id = o.user_id
    where o.id = order_items.order_id
      and f.family_user_id = auth.uid()
      and f.status = 'active'
  )
);

drop policy if exists "order_items_select_admin" on public.order_items;
create policy "order_items_select_admin"
on public.order_items for select
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role::text = 'admin'
  )
);

-- 9) 管理員可讀 profiles（統計用）
-- 注意：不可在 profiles 政策內再 SELECT profiles，會 42P17 無限遞迴。
-- 請改跑 supabase/migrations/20260613120000_fix_profiles_rls_recursion.sql
-- drop policy if exists "profiles_select_admin" on public.profiles;
-- create policy "profiles_select_admin" ...
