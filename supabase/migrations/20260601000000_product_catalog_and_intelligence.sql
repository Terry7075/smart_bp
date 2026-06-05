-- 物資子系統五階段升級：商品目錄、推薦、批次採買、路線規劃
-- 依賴：chapter5_shop_assistant_schema.sql、order_line_items_shopping_snapshot.sql

-- =============================================================================
-- 第一階段：商品目錄
-- =============================================================================
create table if not exists public.product_categories (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  label text not null,
  default_unit_label text not null default '包',
  keywords text[] not null default '{}',
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.product_brands (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.product_categories(id) on delete cascade,
  brand_name text not null,
  display_name text not null,
  spec text,
  unit_label text,
  ref_price numeric,
  px_search_keyword text,
  template_option_id text,
  image_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (category_id, template_option_id)
);

create table if not exists public.product_synonyms (
  id uuid primary key default gen_random_uuid(),
  term text not null,
  target_type text not null check (target_type in ('category', 'brand', 'attribute')),
  target_id uuid not null,
  weight numeric not null default 1.0,
  created_at timestamptz not null default now()
);

create index if not exists product_synonyms_term_idx on public.product_synonyms (term);

create table if not exists public.product_attributes (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.product_categories(id) on delete cascade,
  attr_key text not null,
  label text not null,
  synonyms text[] not null default '{}'
);

alter table public.demand_record_items
  add column if not exists category_id uuid references public.product_categories(id),
  add column if not exists brand_id uuid references public.product_brands(id),
  add column if not exists normalized_at timestamptz,
  add column if not exists normalize_confidence numeric,
  add column if not exists batch_line_id uuid;

-- =============================================================================
-- 第二階段：推薦
-- =============================================================================
create table if not exists public.purchase_events (
  id uuid primary key default gen_random_uuid(),
  demand_record_id uuid references public.demand_records(id) on delete set null,
  demand_item_id uuid references public.demand_record_items(id) on delete set null,
  location_point_id uuid references public.location_points(id),
  category_id uuid references public.product_categories(id),
  brand_id uuid references public.product_brands(id),
  quantity int not null default 1,
  unit_price numeric,
  volunteer_id uuid references auth.users(id),
  fulfilled_at timestamptz not null default now()
);

create index if not exists purchase_events_location_brand_idx
  on public.purchase_events (location_point_id, brand_id, fulfilled_at desc);

create table if not exists public.brand_recommendation_stats (
  id uuid primary key default gen_random_uuid(),
  location_point_id uuid references public.location_points(id),
  brand_id uuid not null references public.product_brands(id) on delete cascade,
  order_count_90d int not null default 0,
  volunteer_pick_count_90d int not null default 0,
  last_price numeric,
  updated_at timestamptz not null default now(),
  unique (location_point_id, brand_id)
);

create table if not exists public.recommendation_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category_id uuid references public.product_categories(id),
  shown_brand_ids uuid[] not null default '{}',
  chosen_brand_id uuid references public.product_brands(id),
  created_at timestamptz not null default now()
);

-- =============================================================================
-- 第三階段：批次採買
-- =============================================================================
create table if not exists public.volunteer_purchase_batches (
  id uuid primary key default gen_random_uuid(),
  location_point_id uuid not null references public.location_points(id),
  volunteer_id uuid not null references auth.users(id),
  status text not null default 'collecting'
    check (status in ('collecting', 'locked', 'shopping', 'completed', 'cancelled')),
  planned_route_json jsonb,
  total_estimated_cost numeric,
  created_at timestamptz not null default now(),
  locked_at timestamptz,
  completed_at timestamptz
);

create table if not exists public.volunteer_purchase_batch_lines (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.volunteer_purchase_batches(id) on delete cascade,
  category_id uuid references public.product_categories(id),
  brand_id uuid references public.product_brands(id),
  category_label text not null,
  brand_label text,
  aggregated_quantity int not null check (aggregated_quantity > 0),
  unit_label text,
  source_item_ids uuid[] not null default '{}',
  completed boolean not null default false
);

alter table public.demand_record_items
  add column if not exists batch_line_id uuid references public.volunteer_purchase_batch_lines(id);

create table if not exists public.volunteer_purchase_batch_members (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.volunteer_purchase_batches(id) on delete cascade,
  demand_record_id uuid not null references public.demand_records(id) on delete cascade,
  elder_user_id uuid not null references auth.users(id),
  unique (batch_id, demand_record_id)
);

-- =============================================================================
-- 第四階段：路線
-- =============================================================================
alter table public.location_points
  add column if not exists lat numeric,
  add column if not exists lng numeric;

create table if not exists public.purchase_locations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text,
  lat numeric not null,
  lng numeric not null,
  location_type text not null default 'supermarket'
    check (location_type in ('supermarket', 'pharmacy', 'hub')),
  px_keyword text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- 種子：據點座標（苗栗示例）與全聯
update public.location_points
set lat = 24.5640, lng = 120.8215
where name like '%明德%' and lat is null;

insert into public.purchase_locations (name, address, lat, lng, location_type, px_keyword)
select '全聯福利中心 苗栗店', '苗栗市示例', 24.5700, 120.8150, 'supermarket', '全聯'
where not exists (select 1 from public.purchase_locations where name = '全聯福利中心 苗栗店');

-- =============================================================================
-- 觸發器：submitted 時寫入 purchase_events
-- =============================================================================
create or replace function public.trg_demand_record_submitted_purchase_event()
returns trigger language plpgsql security definer as $$
begin
  if new.status = 'submitted' and (old.status is distinct from 'submitted') then
    insert into public.purchase_events (
      demand_record_id, demand_item_id, location_point_id,
      category_id, brand_id, quantity, unit_price
    )
    select
      new.id, i.id, new.location_point_id,
      i.category_id, i.brand_id, i.quantity, i.unit_price
    from public.demand_record_items i
    where i.demand_record_id = new.id and i.cancelled = false;
  end if;
  return new;
end;
$$;

drop trigger if exists demand_records_submitted_purchase_event on public.demand_records;
create trigger demand_records_submitted_purchase_event
  after update on public.demand_records
  for each row execute function public.trg_demand_record_submitted_purchase_event();

-- RPC：品牌推薦
create or replace function public.recommend_brands(
  p_location_point_id uuid,
  p_category_id uuid,
  p_limit int default 3
)
returns table (
  brand_id uuid,
  brand_name text,
  display_name text,
  score numeric,
  ref_price numeric,
  template_option_id text
) language sql stable as $$
  with candidates as (
    select b.id, b.brand_name, b.display_name, b.ref_price, b.template_option_id
    from public.product_brands b
    where b.category_id = p_category_id and b.is_active and b.brand_name <> '其他'
  ),
  scored as (
    select
      c.id,
      c.brand_name,
      c.display_name,
      c.ref_price,
      c.template_option_id,
      (
        0.45 * coalesce(s.order_count_90d::numeric / nullif(max(s.order_count_90d) over (), 0), 0)
        + 0.30 * coalesce(s.volunteer_pick_count_90d::numeric / nullif(max(s.volunteer_pick_count_90d) over (), 0), 0)
        + 0.25 * case when c.ref_price is null then 0
             else 1.0 - (c.ref_price / nullif(max(c.ref_price) over (), 0)) end
      ) as score
    from candidates c
    left join public.brand_recommendation_stats s
      on s.brand_id = c.id
      and (s.location_point_id = p_location_point_id or p_location_point_id is null)
  )
  select id, brand_name, display_name, score, ref_price, template_option_id
  from scored
  order by score desc nulls last, brand_name
  limit greatest(p_limit, 1);
$$;

-- RLS
alter table public.product_categories enable row level security;
alter table public.product_brands enable row level security;
alter table public.product_synonyms enable row level security;
alter table public.purchase_events enable row level security;
alter table public.brand_recommendation_stats enable row level security;
alter table public.recommendation_logs enable row level security;
alter table public.volunteer_purchase_batches enable row level security;
alter table public.volunteer_purchase_batch_lines enable row level security;
alter table public.volunteer_purchase_batch_members enable row level security;
alter table public.purchase_locations enable row level security;

drop policy if exists "product_categories_select" on public.product_categories;
create policy "product_categories_select" on public.product_categories
  for select to authenticated using (true);

drop policy if exists "product_brands_select" on public.product_brands;
create policy "product_brands_select" on public.product_brands
  for select to authenticated using (true);

drop policy if exists "product_synonyms_select" on public.product_synonyms;
create policy "product_synonyms_select" on public.product_synonyms
  for select to authenticated using (true);

drop policy if exists "purchase_locations_select" on public.purchase_locations;
create policy "purchase_locations_select" on public.purchase_locations
  for select to authenticated using (true);

drop policy if exists "purchase_events_volunteer_admin" on public.purchase_events;
create policy "purchase_events_volunteer_admin" on public.purchase_events
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('volunteer', 'admin')));

drop policy if exists "brand_stats_select" on public.brand_recommendation_stats;
create policy "brand_stats_select" on public.brand_recommendation_stats
  for select to authenticated using (true);

drop policy if exists "recommendation_logs_own" on public.recommendation_logs;
create policy "recommendation_logs_own" on public.recommendation_logs
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "volunteer_batches_rw" on public.volunteer_purchase_batches;
create policy "volunteer_batches_rw" on public.volunteer_purchase_batches
  for all to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('volunteer', 'admin')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('volunteer', 'admin')));

drop policy if exists "volunteer_batch_lines_rw" on public.volunteer_purchase_batch_lines;
create policy "volunteer_batch_lines_rw" on public.volunteer_purchase_batch_lines
  for all to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('volunteer', 'admin')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('volunteer', 'admin')));

drop policy if exists "volunteer_batch_members_rw" on public.volunteer_purchase_batch_members;
create policy "volunteer_batch_members_rw" on public.volunteer_purchase_batch_members
  for all to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('volunteer', 'admin')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('volunteer', 'admin')));

grant execute on function public.recommend_brands(uuid, uuid, int) to authenticated;
