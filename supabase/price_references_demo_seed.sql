-- 常用品項參考價種子（可重複執行）
-- 執行時機：chapter5 建表後、查價功能驗收前
-- 說明：價格為社區志工依全聯門市常見品項人工整理，非即時爬蟲。

insert into public.price_references (product_name, unit_price, unit_label, category, source_note)
select v.product_name, v.unit_price, v.unit_label, v.category, v.source_note
from (values
  ('衛生紙', 129, '串', '日用品', '社區常用品參考價'),
  ('鮮奶', 89, '瓶', '乳品', '社區常用品參考價'),
  ('雞蛋', 95, '盒', '生鮮', '社區常用品參考價'),
  ('白米', 199, '包', '米糧', '社區常用品參考價'),
  ('洗衣精', 159, '瓶', '清潔', '社區常用品參考價'),
  ('成人尿布', 320, '包', '照護', '社區常用品參考價')
) as v(product_name, unit_price, unit_label, category, source_note)
where not exists (
  select 1 from public.price_references p
  where p.product_name = v.product_name
);
