-- =============================================================================
-- Migration: orders 新增 is_urgent 欄位（緊急需求旗標）
-- 目的：讓長輩可標記「緊急」，志工端排序優先顯示、顯示紅色徽章
-- 執行方式：Supabase Dashboard → SQL Editor → 貼上後執行
-- 安全性：預設 FALSE，舊訂單不受影響
-- =============================================================================

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS is_urgent BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.orders.is_urgent IS '長輩標記為緊急需求（TRUE = 志工端優先顯示）';
