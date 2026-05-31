-- 藥丸外觀描述（OCR 擷取「外觀／形狀／顏色」等，供打卡頁視覺化）
alter table public.prescriptions
  add column if not exists pill_appearance text;

comment on column public.prescriptions.pill_appearance is
  '藥丸外觀文字，例如「粉紅/圓形」';
