-- Demo 用全聯參考價種子（可重複執行）
-- 執行時機：chapter5 建表後、口試查價 Demo 前

insert into public.price_references (product_name, unit_price, unit_label, category, source_note)
select v.product_name, v.unit_price, v.unit_label, v.category, v.source_note
from (values
  ('衛生紙', 129, '串', '日用品', '全聯參考價（Demo）'),
  ('鮮奶', 89, '瓶', '乳品', '全聯參考價（Demo）'),
  ('雞蛋', 95, '盒', '生鮮', '全聯參考價（Demo）'),
  ('白米', 199, '包', '米糧', '全聯參考價（Demo）'),
  ('洗衣精', 159, '瓶', '清潔', '全聯參考價（Demo）'),
  ('成人尿布', 320, '包', '照護', '全聯參考價（Demo）')
) as v(product_name, unit_price, unit_label, category, source_note)
where not exists (
  select 1 from public.price_references p
  where p.product_name = v.product_name
);
