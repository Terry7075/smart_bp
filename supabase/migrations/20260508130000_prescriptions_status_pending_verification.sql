-- 允許 prescriptions.status = 'pending_verification'（長輩送志工協助時 App 會寫入）
-- 錯誤 23514 prescriptions_status_check：代表既有 CHECK 未含此值。
--
-- 在 Supabase → SQL Editor 執行。

alter table public.prescriptions
  drop constraint if exists prescriptions_status_check;

alter table public.prescriptions
  add constraint prescriptions_status_check
  check (
    status = any (
      array[
        'active'::text,
        'cancelled'::text,
        'pending_verification'::text
      ]
    )
  );
