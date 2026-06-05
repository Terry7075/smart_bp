-- 商品目錄最小種子（與 App ElderSupplyTemplates 對齊）
-- 依賴：20260601000000_product_catalog_and_intelligence.sql
-- 須在 20260602000000_group_buy_collaboration.sql 之前執行

insert into public.product_categories (key, label, default_unit_label, keywords, sort_order)
values
  ('tissue', '衛生紙', '提', array['衛生紙', '面紙', '紙巾', '抽取式'], 1),
  ('egg', '雞蛋', '盒', array['雞蛋', '蛋'], 2),
  ('milk', '鮮奶', '瓶', array['鮮奶', '牛奶', '牛乳'], 3),
  ('rice', '白米', '包', array['白米', '米', '米飯'], 4),
  ('instant_noodle', '泡麵', '包', array['泡麵', '麵', '速食麵'], 5)
on conflict (key) do nothing;

insert into public.product_brands (
  category_id, brand_name, display_name, spec, unit_label, ref_price,
  px_search_keyword, template_option_id, is_active
)
select c.id, v.brand_name, v.display_name, v.spec, v.unit_label, v.ref_price,
  v.px_search_keyword, v.template_option_id, true
from (values
  ('tissue', '舒潔', '舒潔抽取式衛生紙', '100抽×10包', '提', 199::numeric, '舒潔抽取式衛生紙', 'tissue:scott'),
  ('tissue', '五月花', '五月花抽取式衛生紙', '100抽×10包', '提', 189, '五月花抽取式衛生紙', 'tissue:mayflower'),
  ('tissue', '得意', '得意抽取式衛生紙', '100抽×10包', '提', 169, '得意抽取式衛生紙', 'tissue:deyi'),
  ('tissue', '春風', '春風抽取式衛生紙', '100抽×10包', '提', 179, '春風抽取式衛生紙', 'tissue:chunfeng'),
  ('tissue', '其他', '其他品牌衛生紙', '請於備註說明', '提', null, null, 'tissue:other'),
  ('egg', '洗選鮮蛋', '洗選鮮蛋', '10入/盒', '盒', 89, '洗選鮮蛋10入', 'egg:fresh'),
  ('egg', '鄉牧', '鄉牧鮮蛋', '10入/盒', '盒', 95, '鄉牧鮮蛋', 'egg:country'),
  ('egg', '其他', '其他雞蛋', '請於備註說明', '盒', null, null, 'egg:other'),
  ('milk', '林鳳營', '林鳳營鮮奶', '936ml', '瓶', 89, '林鳳營鮮奶', 'milk:linfeng'),
  ('milk', '光泉', '光泉鮮奶', '936ml', '瓶', 85, '光泉鮮奶', 'milk:guangming'),
  ('milk', '其他', '其他鮮奶', '請於備註說明', '瓶', null, null, 'milk:other'),
  ('rice', '台東5號', '台東5號米', '3kg', '包', 199, '台東5號米3kg', 'rice:taitung5'),
  ('rice', '福壽', '福壽米', '3kg', '包', 189, '福壽米3kg', 'rice:formosa'),
  ('rice', '其他', '其他白米', '請於備註說明', '包', null, null, 'rice:other'),
  ('instant_noodle', '統一', '統一肉燥麵', '5入/包', '包', 89, '統一肉燥麵', 'noodle:uni'),
  ('instant_noodle', '味全', '味全牛肉麵', '5入/包', '包', 85, '味全牛肉麵', 'noodle:weichuan'),
  ('instant_noodle', '其他', '其他泡麵', '請於備註說明', '包', null, null, 'noodle:other')
) as v(cat_key, brand_name, display_name, spec, unit_label, ref_price, px_search_keyword, template_option_id)
join public.product_categories c on c.key = v.cat_key
on conflict (category_id, template_option_id) do nothing;

insert into public.product_synonyms (term, target_type, target_id, weight)
select s.term, 'category', c.id, 1.0
from (values
  ('衛生紙', 'tissue'), ('面紙', 'tissue'), ('雞蛋', 'egg'), ('鮮奶', 'milk'),
  ('牛奶', 'milk'), ('白米', 'rice'), ('泡麵', 'instant_noodle')
) as s(term, cat_key)
join public.product_categories c on c.key = s.cat_key
where not exists (
  select 1 from public.product_synonyms x
  where x.term = s.term and x.target_type = 'category' and x.target_id = c.id
);
