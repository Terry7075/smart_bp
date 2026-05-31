-- 修復：Vision 成功後「資料庫更新失敗」— 缺少 pill_appearance 等欄位
-- 在 Supabase Dashboard → SQL Editor 執行本檔即可。

alter table public.prescriptions
  add column if not exists pill_appearance text;

alter table public.prescriptions
  add column if not exists medication_days integer;

alter table public.prescriptions
  add column if not exists hospital_name text;

alter table public.prescriptions
  add column if not exists notes text;

alter table public.prescriptions
  add column if not exists source text default 'ocr';

comment on column public.prescriptions.pill_appearance is
  '藥丸外觀文字，例如「粉紅/圓形」';

comment on column public.prescriptions.medication_days is
  '給藥天數（OCR / Vision 推算領藥週期用）';

-- 讓 PostgREST 立刻認到新欄位（避免 schema cache 仍顯示舊結構）
notify pgrst, 'reload schema';
