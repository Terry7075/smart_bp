-- Demo 版：需求單（orders / order_items）
-- 目的：讓「柑仔店送出」真的寫進 Supabase，志工端後續可讀取並 Double-check。

-- 1) orders
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'submitted',
  note text null,
  created_at timestamptz not null default now()
);

-- 2) order_items
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id text not null,
  product_name text not null,
  quantity int not null check (quantity > 0),
  unit_price numeric null
);

create index if not exists orders_user_id_created_at_idx on public.orders(user_id, created_at desc);
create index if not exists order_items_order_id_idx on public.order_items(order_id);

-- 3) RLS（先給最小可 Demo：使用者只能看／寫自己的單）
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- orders policies
drop policy if exists "orders_select_own" on public.orders;
create policy "orders_select_own"
on public.orders for select
using (auth.uid() = user_id);

drop policy if exists "orders_insert_own" on public.orders;
create policy "orders_insert_own"
on public.orders for insert
with check (auth.uid() = user_id);

-- order_items policies（只允許對「自己擁有的 orders」寫入與讀取）
drop policy if exists "order_items_select_own" on public.order_items;
create policy "order_items_select_own"
on public.order_items for select
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and o.user_id = auth.uid()
  )
);

drop policy if exists "order_items_insert_own" on public.order_items;
create policy "order_items_insert_own"
on public.order_items for insert
with check (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and o.user_id = auth.uid()
  )
);

-- 志工端之後會需要「能看見多位長輩的訂單」：
-- 建議屆時新增 profiles.role（elder/volunteer/admin）或建立 volunteers mapping 表，
-- 再加對應的 select policy（例如 volunteer 可看自己負責里別的 user_id）。

