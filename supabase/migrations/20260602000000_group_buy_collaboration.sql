-- Hybrid NLU 智慧物資代購協作：SKU、澄清會話、履行狀態、今日採買、推播、分析
-- 依賴：20260601000000_product_catalog_and_intelligence.sql

-- =============================================================================
-- demand_records：今日採買 RPC 所需（與 20260604 相同，須在本檔 RPC 之前）
-- =============================================================================
alter table public.demand_records
  add column if not exists submitted_at timestamptz;

alter table public.demand_records
  drop constraint if exists demand_records_status_check;

alter table public.demand_records
  add constraint demand_records_status_check
  check (status in ('draft', 'submitted', 'cancelled', 'pending', 'processing'));

comment on column public.demand_records.submitted_at is '草稿轉正式需求時間（今日採買清單用）';

-- =============================================================================
-- SKU 標準品 + 別名
-- =============================================================================
create table if not exists public.product_items (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.product_categories(id) on delete cascade,
  brand_id uuid references public.product_brands(id) on delete set null,
  display_name text not null,
  spec text,
  unit_label text not null default '包',
  ref_price numeric,
  is_budget_pick boolean not null default false,
  image_url text,
  px_search_keyword text,
  template_option_id text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (category_id, brand_id, spec, unit_label)
);

create table if not exists public.product_aliases (
  id uuid primary key default gen_random_uuid(),
  term text not null,
  product_item_id uuid not null references public.product_items(id) on delete cascade,
  weight numeric not null default 1.0,
  created_at timestamptz not null default now()
);

create index if not exists product_aliases_term_idx on public.product_aliases (term);

-- 由既有 product_brands 種子 product_items
insert into public.product_items (
  category_id, brand_id, display_name, spec, unit_label, ref_price,
  is_budget_pick, px_search_keyword, template_option_id
)
select
  b.category_id, b.id, b.display_name, b.spec, coalesce(b.unit_label, c.default_unit_label),
  b.ref_price,
  (b.ref_price is not null and b.ref_price = (
    select min(b2.ref_price) from public.product_brands b2
    where b2.category_id = b.category_id and b2.is_active and b2.ref_price is not null
  )),
  b.px_search_keyword, b.template_option_id
from public.product_brands b
join public.product_categories c on c.id = b.category_id
where b.is_active and b.brand_name <> '其他'
on conflict do nothing;

insert into public.product_aliases (term, product_item_id, weight)
select lower(s.term), i.id, s.weight
from public.product_synonyms s
join public.product_brands b on b.id = s.target_id and s.target_type = 'brand'
join public.product_items i on i.brand_id = b.id
where not exists (
  select 1 from public.product_aliases a
  where a.term = lower(s.term) and a.product_item_id = i.id
);

-- =============================================================================
-- 多輪澄清
-- =============================================================================
create table if not exists public.clarification_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'open'
    check (status in ('open', 'resolved', 'expired')),
  missing_fields jsonb not null default '[]',
  partial_nlu jsonb not null default '{}',
  utterance_log jsonb not null default '[]',
  resolved_item_id uuid references public.product_items(id),
  expires_at timestamptz not null default (now() + interval '2 hours'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists clarification_sessions_user_open_idx
  on public.clarification_sessions (user_id, status) where status = 'open';

-- =============================================================================
-- 履行狀態（品項級）
-- =============================================================================
do $$ begin
  create type public.fulfillment_status as enum (
    'pending', 'accepted', 'purchased', 'delivered', 'cancelled', 'substituted'
  );
exception when duplicate_object then null;
end $$;

alter table public.demand_record_items
  add column if not exists product_item_id uuid references public.product_items(id),
  add column if not exists fulfillment_status text not null default 'pending',
  add column if not exists substitute_item_id uuid references public.product_items(id),
  add column if not exists volunteer_id uuid references auth.users(id),
  add column if not exists accepted_at timestamptz,
  add column if not exists purchased_at timestamptz,
  add column if not exists delivered_at timestamptz,
  add column if not exists actual_unit_price numeric;

alter table public.demand_record_items
  drop constraint if exists demand_record_items_fulfillment_status_check;

alter table public.demand_record_items
  add constraint demand_record_items_fulfillment_status_check
  check (fulfillment_status in (
    'pending', 'accepted', 'purchased', 'delivered', 'cancelled', 'substituted'
  ));

create table if not exists public.demand_fulfillment_events (
  id uuid primary key default gen_random_uuid(),
  demand_item_id uuid not null references public.demand_record_items(id) on delete cascade,
  from_status text,
  to_status text not null,
  volunteer_id uuid references auth.users(id),
  note text,
  created_at timestamptz not null default now()
);

-- =============================================================================
-- 今日採買清單（可選持久化；主要用 RPC 即時聚合）
-- =============================================================================
create table if not exists public.daily_shopping_lists (
  id uuid primary key default gen_random_uuid(),
  location_point_id uuid not null references public.location_points(id),
  shopping_date date not null default (timezone('Asia/Taipei', now()))::date,
  status text not null default 'open'
    check (status in ('open', 'locked', 'done')),
  created_at timestamptz not null default now(),
  unique (location_point_id, shopping_date)
);

-- =============================================================================
-- 推播
-- =============================================================================
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fcm_token text not null,
  platform text not null default 'unknown',
  updated_at timestamptz not null default now(),
  unique (user_id, fcm_token)
);

create table if not exists public.push_notifications_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  event_type text not null,
  payload jsonb not null default '{}',
  success boolean not null default false,
  created_at timestamptz not null default now()
);

-- =============================================================================
-- 分析視圖
-- =============================================================================
create or replace view public.elder_item_history as
select
  pe.location_point_id,
  dr.user_id as elder_user_id,
  coalesce(i.product_item_id, i.brand_id) as product_key,
  i.product_item_id,
  i.category_id,
  i.brand_id,
  count(*)::int as order_count,
  max(pe.fulfilled_at) as last_fulfilled_at
from public.purchase_events pe
join public.demand_record_items i on i.id = pe.demand_item_id
join public.demand_records dr on dr.id = pe.demand_record_id
where i.cancelled = false
group by 1, 2, 3, 4, 5, 6;

-- =============================================================================
-- RPC：解析 SKU
-- =============================================================================
create or replace function public.resolve_product_item(
  p_category_key text default null,
  p_brand_name text default null,
  p_spec text default null,
  p_alias_term text default null
)
returns uuid language plpgsql stable as $$
declare
  v_id uuid;
  v_cat uuid;
begin
  if p_alias_term is not null and trim(p_alias_term) <> '' then
    select a.product_item_id into v_id
    from public.product_aliases a
    where a.term = lower(trim(p_alias_term))
    order by a.weight desc
    limit 1;
    if v_id is not null then return v_id; end if;
  end if;

  if p_category_key is not null then
    select id into v_cat from public.product_categories where key = p_category_key limit 1;
  end if;

  select i.id into v_id
  from public.product_items i
  join public.product_brands b on b.id = i.brand_id
  where i.is_active
    and (v_cat is null or i.category_id = v_cat)
    and (p_brand_name is null or b.brand_name ilike '%' || trim(p_brand_name) || '%')
    and (p_spec is null or coalesce(i.spec, '') ilike '%' || trim(p_spec) || '%')
  order by i.is_budget_pick desc, i.ref_price nulls last
  limit 1;

  return v_id;
end;
$$;

-- =============================================================================
-- RPC：澄清會話 upsert
-- =============================================================================
create or replace function public.upsert_clarification_session(
  p_session_id uuid default null,
  p_partial_nlu jsonb default '{}',
  p_missing_fields jsonb default '[]',
  p_utterance text default null,
  p_resolve_item_id uuid default null
)
returns uuid language plpgsql security definer as $$
declare
  v_id uuid;
  v_log jsonb;
begin
  if p_session_id is not null then
    select utterance_log into v_log from public.clarification_sessions where id = p_session_id and user_id = auth.uid();
    if v_log is null then raise exception 'session not found'; end if;
    if p_utterance is not null then
      v_log := v_log || jsonb_build_array(jsonb_build_object('t', now(), 'u', p_utterance));
    end if;
    update public.clarification_sessions set
      partial_nlu = coalesce(partial_nlu, partial_nlu),
      missing_fields = coalesce(p_missing_fields, missing_fields),
      utterance_log = v_log,
      resolved_item_id = coalesce(p_resolve_item_id, resolved_item_id),
      status = case when p_resolve_item_id is not null then 'resolved' else status end,
      updated_at = now()
    where id = p_session_id and user_id = auth.uid()
    returning id into v_id;
    return v_id;
  end if;

  v_log := case when p_utterance is not null
    then jsonb_build_array(jsonb_build_object('t', now(), 'u', p_utterance))
    else '[]'::jsonb end;

  insert into public.clarification_sessions (
    user_id, partial_nlu, missing_fields, utterance_log, resolved_item_id, status
  ) values (
    auth.uid(), coalesce(p_partial_nlu, '{}'), coalesce(p_missing_fields, '[]'),
    v_log, p_resolve_item_id,
    case when p_resolve_item_id is not null then 'resolved' else 'open' end
  )
  returning id into v_id;
  return v_id;
end;
$$;

-- =============================================================================
-- RPC：三卡推薦
-- =============================================================================
create or replace function public.get_recommendation_cards(
  p_user_id uuid default auth.uid(),
  p_category_id uuid default null,
  p_category_key text default null,
  p_location_point_id uuid default null
)
returns jsonb language plpgsql stable security definer as $$
declare
  v_cat uuid;
  v_frequent jsonb;
  v_budget jsonb;
  v_volunteer jsonb;
begin
  if p_category_id is not null then v_cat := p_category_id;
  elsif p_category_key is not null then
    select id into v_cat from public.product_categories where key = p_category_key limit 1;
  end if;
  if v_cat is null then return '{}'::jsonb; end if;

  select jsonb_build_object(
    'product_item_id', i.id,
    'display_name', i.display_name,
    'ref_price', i.ref_price,
    'reason', '您常買這款'
  ) into v_frequent
  from public.elder_item_history h
  join public.product_items i on i.id = h.product_item_id
  where h.elder_user_id = p_user_id and i.category_id = v_cat and h.product_item_id is not null
  order by h.order_count desc, h.last_fulfilled_at desc nulls last
  limit 1;

  select jsonb_build_object(
    'product_item_id', i.id,
    'display_name', i.display_name,
    'ref_price', i.ref_price,
    'reason', '全聯划算款'
  ) into v_budget
  from public.product_items i
  where i.category_id = v_cat and i.is_active
  order by i.is_budget_pick desc, i.ref_price nulls first
  limit 1;

  select jsonb_build_object(
    'product_item_id', i.id,
    'display_name', i.display_name,
    'ref_price', i.ref_price,
    'reason', '志工常幫買'
  ) into v_volunteer
  from public.brand_recommendation_stats s
  join public.product_items i on i.brand_id = s.brand_id and i.category_id = v_cat
  where (s.location_point_id = p_location_point_id or p_location_point_id is null)
  order by s.volunteer_pick_count_90d desc nulls last
  limit 1;

  return jsonb_build_object(
    'frequent', coalesce(v_frequent, 'null'::jsonb),
    'budget', coalesce(v_budget, 'null'::jsonb),
    'volunteer_pick', coalesce(v_volunteer, 'null'::jsonb)
  );
end;
$$;

-- =============================================================================
-- RPC：今日採買清單聚合
-- =============================================================================
create or replace function public.get_daily_shopping_list(
  p_location_point_id uuid,
  p_shopping_date date default (timezone('Asia/Taipei', now()))::date
)
returns jsonb language sql stable security definer as $$
  with items as (
    select
      i.id as item_id,
      i.product_item_id,
      i.category_id,
      i.brand_id,
      coalesce(i.category, c.label, '未分類') as category_label,
      coalesce(i.brand, b.brand_name) as brand_label,
      coalesce(pi.spec, i.spec) as spec_label,
      coalesce(i.unit_label, pi.unit_label, '包') as unit_label,
      i.quantity,
      dr.id as demand_record_id,
      dr.user_id as elder_user_id,
      coalesce(nullif(trim(p.name), ''), dr.user_id::text) as elder_display
    from public.demand_record_items i
    join public.demand_records dr on dr.id = i.demand_record_id
    left join public.product_categories c on c.id = i.category_id
    left join public.product_brands b on b.id = i.brand_id
    left join public.product_items pi on pi.id = i.product_item_id
    left join public.profiles p on p.id = dr.user_id
    where dr.location_point_id = p_location_point_id
      and dr.status in ('submitted', 'pending', 'processing')
      and i.cancelled = false
      and i.fulfillment_status in ('pending', 'accepted')
      and (dr.submitted_at::date = p_shopping_date or dr.created_at::date = p_shopping_date)
  ),
  grouped as (
    select
      coalesce(product_item_id::text, category_id::text, category_label) as group_key,
      product_item_id,
      category_id,
      brand_id,
      category_label,
      brand_label,
      spec_label,
      unit_label,
      sum(quantity)::int as total_qty,
      jsonb_agg(jsonb_build_object(
        'item_id', item_id,
        'elder_user_id', elder_user_id,
        'elder_display', elder_display,
        'quantity', quantity,
        'demand_record_id', demand_record_id
      ) order by elder_display) as elder_lines
    from items
    group by 1, 2, 3, 4, 5, 6, 7, 8
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'group_key', group_key,
    'product_item_id', product_item_id,
    'category_label', category_label,
    'brand_label', brand_label,
    'spec_label', spec_label,
    'unit_label', unit_label,
    'total_qty', total_qty,
    'elder_lines', elder_lines
  ) order by category_label, brand_label), '[]'::jsonb)
  from grouped;
$$;

-- =============================================================================
-- RPC：履行狀態轉移
-- =============================================================================
create or replace function public.update_item_fulfillment(
  p_item_id uuid,
  p_new_status text,
  p_substitute_item_id uuid default null,
  p_actual_unit_price numeric default null,
  p_note text default null
)
returns void language plpgsql security definer as $$
declare
  v_old text;
  v_volunteer uuid := auth.uid();
begin
  if p_new_status not in (
    'pending', 'accepted', 'purchased', 'delivered', 'cancelled', 'substituted'
  ) then
    raise exception 'invalid status';
  end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role in ('volunteer', 'admin')
  ) then
    raise exception 'forbidden';
  end if;

  select fulfillment_status into v_old
  from public.demand_record_items where id = p_item_id for update;

  if v_old is null then raise exception 'item not found'; end if;

  update public.demand_record_items set
    fulfillment_status = p_new_status,
    volunteer_id = coalesce(volunteer_id, v_volunteer),
    substitute_item_id = coalesce(p_substitute_item_id, substitute_item_id),
    actual_unit_price = coalesce(p_actual_unit_price, actual_unit_price),
    accepted_at = case when p_new_status = 'accepted' then coalesce(accepted_at, now()) else accepted_at end,
    purchased_at = case when p_new_status = 'purchased' then coalesce(purchased_at, now()) else purchased_at end,
    delivered_at = case when p_new_status = 'delivered' then coalesce(delivered_at, now()) else delivered_at end
  where id = p_item_id;

  insert into public.demand_fulfillment_events (
    demand_item_id, from_status, to_status, volunteer_id, note
  ) values (p_item_id, v_old, p_new_status, v_volunteer, p_note);
end;
$$;

-- =============================================================================
-- RPC：社區分析
-- =============================================================================
create or replace function public.get_community_analytics(
  p_location_point_id uuid default null,
  p_days int default 90
)
returns jsonb language plpgsql stable security definer as $$
declare
  v_since timestamptz := now() - (p_days || ' days')::interval;
  v_completion_rate numeric;
  v_median_hours numeric;
  v_substitute_count int;
  v_top jsonb;
begin
  select
    case when count(*) = 0 then 0
    else count(*) filter (where fulfillment_status = 'delivered')::numeric / count(*)::numeric
    end,
    percentile_cont(0.5) within group (
      order by extract(epoch from (delivered_at - accepted_at)) / 3600.0
    ) filter (where delivered_at is not null and accepted_at is not null),
    count(*) filter (where fulfillment_status = 'substituted')
  into v_completion_rate, v_median_hours, v_substitute_count
  from public.demand_record_items i
  join public.demand_records dr on dr.id = i.demand_record_id
  where i.cancelled = false
    and dr.created_at >= v_since
    and (p_location_point_id is null or dr.location_point_id = p_location_point_id);

  select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into v_top
  from (
    select coalesce(i.category, '其他') as name, sum(i.quantity)::int as qty
    from public.demand_record_items i
    join public.demand_records dr on dr.id = i.demand_record_id
    where i.cancelled = false and dr.created_at >= v_since
      and (p_location_point_id is null or dr.location_point_id = p_location_point_id)
    group by 1 order by 2 desc limit 10
  ) t;

  return jsonb_build_object(
    'completion_rate', coalesce(v_completion_rate, 0),
    'median_fulfillment_hours', coalesce(v_median_hours, 0),
    'substitute_count', coalesce(v_substitute_count, 0),
    'top_categories', coalesce(v_top, '[]'::jsonb),
    'period_days', p_days
  );
end;
$$;

create or replace function public.register_device_token(
  p_fcm_token text,
  p_platform text default 'unknown'
)
returns void language plpgsql security definer as $$
begin
  insert into public.device_tokens (user_id, fcm_token, platform, updated_at)
  values (auth.uid(), p_fcm_token, p_platform, now())
  on conflict (user_id, fcm_token)
  do update set platform = excluded.platform, updated_at = now();
end;
$$;

-- RLS
alter table public.product_items enable row level security;
alter table public.product_aliases enable row level security;
alter table public.clarification_sessions enable row level security;
alter table public.demand_fulfillment_events enable row level security;
alter table public.daily_shopping_lists enable row level security;
alter table public.device_tokens enable row level security;
alter table public.push_notifications_log enable row level security;

drop policy if exists "product_items_select" on public.product_items;
create policy "product_items_select" on public.product_items
  for select to authenticated using (true);

drop policy if exists "product_aliases_select" on public.product_aliases;
create policy "product_aliases_select" on public.product_aliases
  for select to authenticated using (true);

drop policy if exists "clarification_sessions_own" on public.clarification_sessions;
create policy "clarification_sessions_own" on public.clarification_sessions
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "fulfillment_events_read" on public.demand_fulfillment_events;
create policy "fulfillment_events_read" on public.demand_fulfillment_events
  for select to authenticated using (true);

drop policy if exists "device_tokens_own" on public.device_tokens;
create policy "device_tokens_own" on public.device_tokens
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 推播紀錄：僅 service role（Edge Function）寫入；客戶端僅志工/管理員或本人可讀
drop policy if exists "push_notifications_log_select" on public.push_notifications_log;
create policy "push_notifications_log_select" on public.push_notifications_log
  for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('volunteer', 'admin')
    )
  );

drop policy if exists "daily_shopping_lists_volunteer" on public.daily_shopping_lists;
create policy "daily_shopping_lists_volunteer" on public.daily_shopping_lists
  for select to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('volunteer', 'admin')
    )
  );

grant execute on function public.resolve_product_item to authenticated;
grant execute on function public.upsert_clarification_session to authenticated;
grant execute on function public.get_recommendation_cards to authenticated;
grant execute on function public.get_daily_shopping_list to authenticated;
grant execute on function public.update_item_fulfillment to authenticated;
grant execute on function public.get_community_analytics to authenticated;
grant execute on function public.register_device_token to authenticated;
