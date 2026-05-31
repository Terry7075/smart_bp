-- 藥典：登入使用者可讀（打卡頁看圖認藥）
-- 若表已存在僅缺 RLS，執行本檔即可。

alter table public.drug_dictionary enable row level security;

drop policy if exists drug_dictionary_select_authenticated on public.drug_dictionary;
create policy drug_dictionary_select_authenticated
  on public.drug_dictionary
  for select
  to authenticated
  using (true);

grant select on table public.drug_dictionary to authenticated;

notify pgrst, 'reload schema';
