-- Migration: 為 demand_record_items 加入 client_request_id 冪等鍵
-- 安全可重複執行（IF NOT EXISTS）

-- 1. 加欄位
ALTER TABLE public.demand_record_items
  ADD COLUMN IF NOT EXISTS client_request_id TEXT;

-- 2. Partial unique index：NULL 值排除（舊資料相容），UUID 才保證冪等
--    PostgREST upsert(onConflict: 'client_request_id') 需要此 index
CREATE UNIQUE INDEX IF NOT EXISTS demand_record_items_client_request_id_key
  ON public.demand_record_items (client_request_id)
  WHERE client_request_id IS NOT NULL;
