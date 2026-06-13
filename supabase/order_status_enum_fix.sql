-- =============================================================================
-- 除錯：查 enum order_status 允許值；若 App 用錯字串會報
-- invalid input value for enum order_status: "..."
-- =============================================================================
-- 明德 e 達人專案常見結果：pending, processing, completed, cancelled
-- → App 已預設新單為 **pending**，通常不必再 ADD VALUE 'submitted'。
-- =============================================================================

SELECT e.enumlabel AS allowed_value
FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'public'
  AND t.typname = 'order_status'
ORDER BY e.enumsortorder;

-- 若你的型別名稱不是 order_status，可先找：
-- SELECT typname FROM pg_type WHERE typname ILIKE '%order%status%';

-- =============================================================================
-- （選用）若未來要新增自訂狀態字串，例如 submitted：
-- ALTER TYPE public.order_status ADD VALUE IF NOT EXISTS 'submitted';
-- =============================================================================
-- 若 App 與 DB 不一致，跑 App 時可覆寫：
-- flutter run --dart-define=SHOP_ORDER_STATUS=pending
-- =============================================================================
