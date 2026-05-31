-- 修復：PGRST204 medications_detail 欄位不存在
-- 在 Supabase Dashboard → SQL Editor 執行本檔即可。

alter table public.prescriptions
  add column if not exists photo_storage_path text;

alter table public.prescriptions
  add column if not exists vision_status text not null default 'none';

alter table public.prescriptions
  add column if not exists medications_detail jsonb not null default '[]'::jsonb;

comment on column public.prescriptions.photo_storage_path is
  'Supabase Storage object path（bucket: prescription-photos）';

comment on column public.prescriptions.vision_status is
  'none | processing | completed | failed';

alter table public.prescriptions
  drop constraint if exists prescriptions_vision_status_check;

alter table public.prescriptions
  add constraint prescriptions_vision_status_check
  check (
    vision_status = any (
      array[
        'none'::text,
        'processing'::text,
        'completed'::text,
        'failed'::text
      ]
    )
  );

-- 與 Vision 寫入相關（若尚未執行 20260508140000）
alter table public.prescriptions
  add column if not exists pill_appearance text;

alter table public.prescriptions
  add column if not exists medication_days integer;

notify pgrst, 'reload schema';
