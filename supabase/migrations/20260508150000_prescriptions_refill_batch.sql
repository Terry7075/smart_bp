-- 志工批次代領：代領狀態 + 健保卡收妥標記
alter table public.prescriptions
  add column if not exists refill_status text not null default 'none';

alter table public.prescriptions
  add column if not exists has_health_card boolean not null default false;

comment on column public.prescriptions.refill_status is
  'none | pending_collection | collecting | out_of_stock';

alter table public.prescriptions
  drop constraint if exists prescriptions_refill_status_check;

alter table public.prescriptions
  add constraint prescriptions_refill_status_check
  check (
    refill_status = any (
      array[
        'none'::text,
        'pending_collection'::text,
        'collecting'::text,
        'out_of_stock'::text
      ]
    )
  );

-- 志工需能讀取／更新所有 active 藥單（請依專案 RLS 調整）：
-- create policy "volunteer_select_prescriptions" on public.prescriptions
--   for select to authenticated
--   using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'volunteer'));
-- create policy "volunteer_update_prescriptions_refill" on public.prescriptions
--   for update to authenticated
--   using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'volunteer'));
