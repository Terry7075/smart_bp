# 物資代購 — 固定 Demo 路徑（約 5 分鐘）

> 單一主入口：**柑仔店 `/shop`**。請勿走目錄購物車直送。

## 帳號說明

| 角色 | `profiles.role` | 說明 |
|------|-----------------|------|
| 長輩 | `elder` | Demo 主操作帳號 |
| 志工 | `volunteer` | 接單、今日採買、數據總覽 |
| 家屬 | `family` | **獨立帳號**（非與長輩共用）；需在「家屬關懷」綁定長輩 UUID |

若口試未準備家屬帳號：改由**同一長輩帳號**開啟「我的需求單」`/shop/orders` 展示進度。

## 流程

### 1. 長輩：語音 → 品牌 → 送出

1. 登入長輩 → 底部 **柑仔店**
2. 按住麥克風：「**我要衛生紙兩包**」
3. 點選品牌（例：**五月花**）或「無指定品牌」
4. 確認「目前採買清單（草稿）」有品項
5. 按 **送出給志工**
6. （Android 志工機）應收到推播：`○○ 長輩 已送出代購需求：…`

### 2. 志工：接單

1. 登入志工 → AppBar「物資／柑仔店代購」或推播進入
2. 「已送出訂單」區 → **接單**
3. 長輩（Android）收到：「志工已接單，正在為您採買」

### 3. 家屬：查看（可選）

- **方案 A**：家屬帳號 → `/family/home` → 綁定長輩 → 看代購進度
- **方案 B（簡化）**：長輩帳號 → 柑仔店選單 → **我的需求單**

### 4. 志工：後台統計

1. 志工主控台 → **📊 數據總覽**（`?tab=3`）
2. 說明：訂單趨勢來自 `orders`；履行成效來自 `demand_record_items`

## 延伸：小幫手記需求 → 柑仔店送出

1. 首頁「小幫手」→ 說「我要衛生紙兩包」
2. 對話中選品牌；或按 **「前往柑仔店送出」**／底部 **「柑仔店送出」**
3. 柑仔店會捲動並標示綠色 **「送出給志工」** 按鈕（`?focus=submit`）
4. 之後同主線：志工接單 → 統計

## 延伸：離線草稿（可選，約 1 分鐘）

1. 長輩開飛航模式 → 小幫手或柑仔店說「我要雞蛋一盒」
2. 顯示「已離線暫存」→ 關閉飛航
3. 連線恢復後草稿自動寫入（**不會**自動送志工）
4. 柑仔店按 **送出給志工** → 志工端才會看到

## 口試前檢查

執行 [`supabase/verify_shop_backend.sql`](../supabase/verify_shop_backend.sql) 或手動確認：

- [ ] `graduation_enhancement_schema.sql` 已跑（家屬 Demo）
- [ ] `price_references_demo_seed.sql` 已跑（查價 Demo）
- [ ] `20260607` 或 Dashboard Realtime 已開 `orders`、`demand_records`、`demand_record_items`
- [ ] 志工 Android 已登入且 `device_tokens` 有 `platform=android`
- [ ] Edge `send_shop_push` 已 deploy，`FCM_SERVICE_ACCOUNT_JSON` 已設
- [ ] `android/app/google-services.json` 本機已放置（見 [TEAM_SETUP.md](TEAM_SETUP.md)）
