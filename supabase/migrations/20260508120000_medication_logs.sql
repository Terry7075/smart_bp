-- 吃藥打卡紀錄（對應 App insertMedicationLog）
-- 在 Supabase Dashboard → SQL Editor 貼上執行，或使用 CLI：supabase db push

create table if not exists public.medication_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  prescription_id uuid not null references public.prescriptions (id) on delete cascade,
  slot_time text,
  created_at timestamptz not null default now()
);

comment on table public.medication_logs is '長輩每日／各時段吃藥打卡紀錄';

create index if not exists medication_logs_user_created_idx
  on public.medication_logs (user_id, created_at desc);

create index if not exists medication_logs_prescription_idx
  on public.medication_logs (prescription_id);

alter table public.medication_logs enable row level security;

drop policy if exists "medication_logs_insert_own" on public.medication_logs;
create policy "medication_logs_insert_own"
  on public.medication_logs
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "medication_logs_select_own" on public.medication_logs;
create policy "medication_logs_select_own"
  on public.medication_logs
  for select
  to authenticated
  using (auth.uid() = user_id);
