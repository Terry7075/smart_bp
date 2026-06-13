-- 若畫面上仍顯示「全聯參考價（Demo）」，在 Supabase SQL Editor 執行本檔一次即可。
update public.price_references
set source_note = '社區常用品參考價'
where source_note ilike '%demo%'
   or source_note = '全聯參考價（Demo）';
