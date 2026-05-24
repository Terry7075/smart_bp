-- =============================================================================
-- 第五章：物資訂購與智慧小幫手 — demand_records / price_references /
-- location_points / chat_histories（view）
-- 請在 orders_schema、graduation_enhancement_schema 之後執行。
-- =============================================================================

-- 1) 據點
create table if not exists public.location_points (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text,
  contact_phone text,
  notes text,
  created_at timestamptz not null default now()
);

comment on table public.location_points is '社區據點（志工採買分組、管理員資產）';

insert into public.location_points (name, address, contact_phone, notes)
select '明德里活動中心', '示例地址（請於後台修改）', null, '預設據點'
where not exists (select 1 from public.location_points limit 1);

-- 2) 價格參考（全聯常用品）
create table if not exists public.price_references (
  id uuid primary key default gen_random_uuid(),
  product_id text,
  product_name text not null,
  unit_price numeric,
  unit_label text,
  category text,
  source_note text,
  updated_at timestamptz not null default now()
);

create index if not exists price_references_name_idx
  on public.price_references (product_name);

comment on table public.price_references is '全聯／柑仔店參考價（小幫手查價、價格頁）';

-- 3) 需求單主檔（draft → submitted 可對應 orders）
create table if not exists public.demand_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  location_point_id uuid references public.location_points(id),
  status text not null default 'draft'
    check (status in ('draft', 'submitted', 'cancelled')),
  note text,
  order_id uuid references public.orders(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists demand_records_user_status_idx
  on public.demand_records (user_id, status, updated_at desc);

-- 4) 需求明細
create table if not exists public.demand_record_items (
  id uuid primary key default gen_random_uuid(),
  demand_record_id uuid not null references public.demand_records(id) on delete cascade,
  product_id text,
  product_name text not null,
  quantity int not null default 1 check (quantity > 0),
  unit_price numeric,
  cancelled boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists demand_record_items_record_idx
  on public.demand_record_items (demand_record_id);

-- 5) 據點物品（管理員）
create table if not exists public.location_assets (
  id uuid primary key default gen_random_uuid(),
  location_point_id uuid not null references public.location_points(id) on delete cascade,
  item_name text not null,
  quantity int not null default 0,
  notes text,
  updated_at timestamptz not null default now()
);

-- 6) orders 可選據點
alter table public.orders
  add column if not exists location_point_id uuid references public.location_points(id);

alter table public.profiles
  add column if not exists location_point_id uuid references public.location_points(id);

-- 7) chat_histories：報告用檢視（實際仍寫 assistant_chat_sessions）
create or replace view public.chat_histories as
select
  id,
  user_id,
  title,
  messages,
  started_at,
  updated_at
from public.assistant_chat_sessions;

comment on view public.chat_histories is '對話歷史檢視（底層 assistant_chat_sessions）';

-- 8) updated_at trigger
create or replace function public.set_demand_records_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists demand_records_updated_at on public.demand_records;
create trigger demand_records_updated_at
  before update on public.demand_records
  for each row execute function public.set_demand_records_updated_at();

-- 9) RLS
alter table public.location_points enable row level security;
alter table public.price_references enable row level security;
alter table public.demand_records enable row level security;
alter table public.demand_record_items enable row level security;
alter table public.location_assets enable row level security;

drop policy if exists "location_points_select_all_auth" on public.location_points;
create policy "location_points_select_all_auth"
  on public.location_points for select to authenticated using (true);

drop policy if exists "price_references_select_all_auth" on public.price_references;
create policy "price_references_select_all_auth"
  on public.price_references for select to authenticated using (true);

drop policy if exists "demand_records_own" on public.demand_records;
create policy "demand_records_own"
  on public.demand_records for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "demand_items_via_own_record" on public.demand_record_items;
create policy "demand_items_via_own_record"
  on public.demand_record_items for all to authenticated
  using (
    exists (
      select 1 from public.demand_records d
      where d.id = demand_record_id and d.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.demand_records d
      where d.id = demand_record_id and d.user_id = auth.uid()
    )
  );

drop policy if exists "demand_records_volunteer_read" on public.demand_records;
create policy "demand_records_volunteer_read"
  on public.demand_records for select to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('volunteer', 'admin')
    )
  );

drop policy if exists "demand_items_volunteer_read" on public.demand_record_items;
create policy "demand_items_volunteer_read"
  on public.demand_record_items for select to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('volunteer', 'admin')
    )
  );

drop policy if exists "location_assets_admin" on public.location_assets;
create policy "location_assets_admin"
  on public.location_assets for all to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  )
  with check (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  );

drop policy if exists "location_assets_select_auth" on public.location_assets;
create policy "location_assets_select_auth"
  on public.location_assets for select to authenticated using (true);

-- 10) Realtime（可選，於 Dashboard → Database → Replication 啟用）
-- alter publication supabase_realtime add table public.demand_records;
