# 物資代購 — 固定 Demo 路徑（約 5 分鐘）

> 單一主入口：**柑仔店 `/shop`**。請勿走目錄購物車直送。

## 帳號說明

| 角色 | `profiles.role` | 說明 |
|------|-----------------|------|
| 長輩 | `elder` | Demo 主操作帳號 |
| 志工 | `volunteer` | 接單、今日採買、數據總覽 |

進度查詢由**長輩本人**開啟「我的需求單」`/shop/orders`。

## 流程

### 1. 長輩：語音 → 品牌 → 送出

1. 登入長輩 → 底部 **柑仔店**
2. 按住麥克風：「**我要衛生紙兩包**」
3. 點選品牌（例：**五月花**）或「無指定品牌」
4. 確認「目前採買清單」有品項
5. 按 **送出給志工**
6. （Android 志工機）應收到推播：`○○ 長輩 已送出代購需求：…`

### 2. 志工：接單

1. 登入志工 → 主控台 **物資代購 → 代購管理**，或從推播進入 `/volunteer/shop-orders`
2. 「已送出需求單」區 → **接單（代購）**（勿走「代長輩送出」除非 Demo 小幫手未送出情境）
3. 長輩（Android）收到：「志工已接單，正在為您採買」

### 3. 長輩：查看進度

1. 長輩帳號 → 柑仔店選單 → **我的需求單** `/shop/orders`
2. 點入需求單可見配送進度（志工已接單 → 採買中 → 已送達活動中心）

### 4. 志工：後台統計

1. 志工主控台 → **物資代購 → 數據總覽**（或 `?tab=3`）
2. 口試說明：總需求單／待處理來自 `orders`；「待送出清單」來自尚未送出的 `demand_records`

## 延伸：小幫手記需求 → 柑仔店送出

1. 首頁「小幫手」→ 說「我要衛生紙兩包」
2. 對話中選品牌；或按 **「前往柑仔店送出」**／底部 **「柑仔店送出」**
3. 柑仔店會捲動並標示綠色 **「送出給志工」** 按鈕（`?focus=submit`）
4. 之後同主線：志工接單 → 統計

## 延伸：離線暫存（可選，約 1 分鐘）

1. 長輩開飛航模式 → 小幫手或柑仔店說「我要雞蛋一盒」
2. 顯示「已暫存本機」→ 關閉飛航
3. 連線恢復後自動寫入採買清單，並跳出 **「立即送出」** 對話框（可選稍後再送）
4. 按 **送出給志工** 後，志工端「已送出需求單」才會出現

## 口試前檢查

執行 [`supabase/verify_shop_backend.sql`](../supabase/verify_shop_backend.sql) 或手動確認：

- [ ] `graduation_enhancement_schema.sql` 已跑（配送時間軸）
- [ ] `price_references_demo_seed.sql` 已跑（查價 Demo）
- [ ] `20260607` 或 Dashboard Realtime 已開 `orders`、`demand_records`、`demand_record_items`
- [ ] 志工 Android 已登入且 `device_tokens` 有 `platform=android`
- [ ] Edge `send_shop_push` 已 deploy，`FCM_SERVICE_ACCOUNT_JSON` 已設
- [ ] `android/app/google-services.json` 本機已放置（見 [TEAM_SETUP.md](TEAM_SETUP.md)）
