-- 物資子系統補齊：離線冪等鍵、recommend_brands 權限（可重複執行）

alter table public.demand_record_items
  add column if not exists client_request_id text;

create unique index if not exists demand_record_items_client_request_id_key
  on public.demand_record_items (client_request_id)
  where client_request_id is not null;

grant execute on function public.recommend_brands(uuid, uuid, int) to authenticated;
