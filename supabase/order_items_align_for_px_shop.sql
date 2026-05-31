-- =============================================================================
-- 將現有 `order_items` 對齊「柑仔店／全聯參考目錄」App（字串 product_id + 品名快照）
-- =============================================================================
-- 適用：Table Editor 裡 order_items 為
--   product_id uuid (FK → products)、quantity、price_at_time 等
-- 而 App 種子商品的 id 是字串（非 products 表的 uuid）。
--
-- 執行前請備份；若 order_items 已有依賴 product 的資料，請先與團隊確認。
-- 在 Supabase → SQL Editor 以 postgres 身分執行。
-- =============================================================================

-- 1) 移除外鍵（名稱若不同，請到 Database → Tables → order_items → 查看 Constraints 複製正確名稱）
ALTER TABLE public.order_items
  DROP CONSTRAINT IF EXISTS order_items_product_id_fkey;

-- 2) product_id 改為 text，承接種子商品的字串 id（既有 uuid 列會變成字串形式）
ALTER TABLE public.order_items
  ALTER COLUMN product_id TYPE text USING product_id::text;

-- 3) 品名快照（志工列表與對帳用，不必依賴 products 表）
ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS product_name text NOT NULL DEFAULT '';

-- 4) （選用）若希望保留數值參考價與 App 一致，可再加；否則只用 price_at_time 即可
ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS unit_price numeric;

COMMENT ON COLUMN public.order_items.product_name IS '下單當下品名快照（柑仔店種子／外部目錄）';
COMMENT ON COLUMN public.order_items.unit_price IS '下單當下參考單價（可空；與 price_at_time 擇一或並存）';

-- 若 product_name 有 DEFAULT ''，可視需要改為不含 DEFAULT（需先回填資料）
-- ALTER TABLE public.order_items ALTER COLUMN product_name DROP DEFAULT;
