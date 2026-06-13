-- 物資後端自檢（Supabase SQL Editor 執行，逐段檢視 Results）

-- 1) 商品目錄 seed
select 'product_categories' as check_name, count(*)::int as row_count
from public.product_categories;

select 'product_items' as check_name, count(*)::int as row_count
from public.product_items;

-- 2) 查價種子
select 'price_references' as check_name, count(*)::int as row_count
from public.price_references;

select product_name, unit_price, unit_label
from public.price_references
order by product_name
limit 10;

-- 3) demand_records 欄位
select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'demand_records'
  and column_name in ('submitted_at', 'status');

-- 4) 離線冪等鍵
select indexname
from pg_indexes
where schemaname = 'public'
  and tablename = 'demand_record_items'
  and indexname = 'demand_record_items_client_request_id_key';

-- 5) 家屬綁定表
select 'family_elder_links' as check_name, count(*)::int as row_count
from public.family_elder_links;

-- 6) FCM device_tokens（Android 推播）
select 'device_tokens' as check_name, count(*)::int as row_count
from public.device_tokens;

select platform, count(*)::int as cnt
from public.device_tokens
group by platform
order by platform;

-- 7) Realtime publication
select tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
  and schemaname = 'public'
  and tablename in ('orders', 'demand_records', 'demand_record_items')
order by tablename;

-- 8) RPC 是否存在
select proname
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and proname in (
    'get_daily_shopping_list',
    'get_recommendation_cards',
    'get_community_analytics',
    'update_item_fulfillment',
    'resolve_product_item',
    'recommend_brands',
    'register_device_token'
  )
order by proname;

-- 9) 今日採買（需至少一筆 location_points）
select public.get_daily_shopping_list(
  (select id from public.location_points limit 1),
  (timezone('Asia/Taipei', now()))::date
) as daily_list_sample;

-- 10) 社區成效 RPC（需有 demand 資料時才有意義）
select public.get_community_analytics(
  (select id from public.location_points limit 1),
  90
) as analytics_sample;
