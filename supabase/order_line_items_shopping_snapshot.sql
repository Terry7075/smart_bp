-- 代購明細結構化快照（志工採買、後台統計）
-- 在 chapter5_shop_assistant_schema.sql 之後執行

alter table public.demand_record_items
  add column if not exists brand text,
  add column if not exists spec text,
  add column if not exists unit_label text,
  add column if not exists category text,
  add column if not exists supply_category_key text,
  add column if not exists template_option_id text,
  add column if not exists px_product_id text,
  add column if not exists source_url text,
  add column if not exists px_search_keyword text,
  add column if not exists image_url text,
  add column if not exists reference_note text;

alter table public.order_items
  add column if not exists brand text,
  add column if not exists spec text,
  add column if not exists supply_category_key text,
  add column if not exists template_option_id text,
  add column if not exists px_product_id text,
  add column if not exists source_url text,
  add column if not exists px_search_keyword text,
  add column if not exists image_url text,
  add column if not exists reference_note text;

comment on column public.demand_record_items.supply_category_key is '物資類別 key（tissue/egg/…）';
comment on column public.demand_record_items.template_option_id is '模板品牌選項 id';
