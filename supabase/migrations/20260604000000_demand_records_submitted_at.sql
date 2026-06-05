-- 今日採買 RPC 與志工篩選：補 submitted_at、擴充 status
-- 若已執行 20260602（內含相同 ALTER），本檔可安全重跑（idempotent）

alter table public.demand_records
  add column if not exists submitted_at timestamptz;

alter table public.demand_records
  drop constraint if exists demand_records_status_check;

alter table public.demand_records
  add constraint demand_records_status_check
  check (status in ('draft', 'submitted', 'cancelled', 'pending', 'processing'));

comment on column public.demand_records.submitted_at is '草稿轉正式需求時間（今日採買清單用）';
