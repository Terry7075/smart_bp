-- =============================================================================
-- Migration: order_items 新增 category + unit_label 兩個快照欄位
-- 目的：讓後台可以依「分類」統計熱門品項；讓志工端清楚看到「包/瓶/罐」單位
-- 執行方式：Supabase Dashboard → SQL Editor → 貼上後執行
-- 安全性：兩欄均為 nullable，舊資料不受影響
-- =============================================================================

-- 1. 新增分類快照欄位
ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS category TEXT;

-- 2. 新增計價單位快照欄位
ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS unit_label TEXT;

-- 3. 說明
COMMENT ON COLUMN public.order_items.category   IS '下單當下商品分類快照（清潔用品/米糧/雞蛋相關…）';
COMMENT ON COLUMN public.order_items.unit_label IS '下單當下計價單位快照（包/瓶/罐/每組…）';
