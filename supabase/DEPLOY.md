# Supabase 部署說明（Windows 友善）

## 為什麼 `npx supabase init` 會失敗？

在 Windows 上透過 **npm 套件 `supabase`** 安裝時，常出現：

```text
Error: No matching Supabase CLI binary package found for win32-x64
```

這代表 **npm 包裡沒有對應的 Windows 執行檔**，不是專案程式寫錯。  
請改用下方「方式 A」安裝真正的 CLI，或「方式 B」完全不用 CLI。

---

## 方式 A：安裝 Supabase CLI（建議 Scoop）

### 1. 安裝 Scoop（若尚未安裝）

PowerShell（一般使用者即可）：

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex
```

### 2. 安裝 Supabase CLI

```powershell
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
supabase --version
```

### 3. 登入 CLI（瀏覽器失敗時用 Token）

瀏覽器出現 **「Unable to create CLI sign-in / Unknown error」** 時，不要用網頁授權，改用手動 Token：

1. 打開 [Account → Access Tokens](https://supabase.com/dashboard/account/tokens)
2. **Generate new token**（名稱例如 `smart-bp-cli`）→ 複製（格式像 `sbp_...`，只顯示一次）
3. 在 **Windows Terminal** 或 **PowerShell**（不要用有時會卡住的 VS Code 內建終端）執行：

```powershell
cd C:\Users\ASUS\smart_bp
supabase login --token
```

出現提示時 **貼上整段 `sbp_...` token**（貼上時畫面可能不顯示字元，屬正常），按 Enter。

或一行設定（本視窗有效）：

```powershell
$env:SUPABASE_ACCESS_TOKEN="貼上你的_sbp_token"
supabase projects list
```

若 `projects list` 有列出專案，代表登入成功。

**仍失敗可試：**

- 關閉 VPN／換網路（公司防火牆常擋 CLI 回呼）
- 用系統 Chrome／Edge 登入 Supabase 帳號後再試
- 更新 CLI：`scoop update supabase`

### 4. 在專案目錄連結並部署

```powershell
cd C:\Users\ASUS\smart_bp
supabase link --project-ref ntufhwqxaidwnelorcsv
supabase secrets set GEMINI_API_KEY=你的_Gemini_API金鑰
supabase functions deploy process_prescription_vision
```

> `project-ref` 請到 Supabase Dashboard → Project Settings → General 查看。

---

## 方式 B：不用 CLI（Dashboard 手動完成）

### 1. 資料庫 Migration

打開 [Supabase SQL Editor](https://supabase.com/dashboard/project/ntufhwqxaidwnelorcsv/sql/new)，**依序執行** `supabase/migrations/` 內尚未跑過的 `.sql` 檔（含 `20260508190000_prescription_vision.sql`）。

### 2. Edge Function 金鑰

Dashboard → **Project Settings** → **Edge Functions** → **Secrets**：

| Name | Value |
|------|--------|
| `GEMINI_API_KEY` | 你的 [Google AI Studio](https://aistudio.google.com/apikey) API Key |
| `GEMINI_MODEL`（選填） | 預設 `gemini-2.5-flash` |

（`SUPABASE_URL`、`SUPABASE_SERVICE_ROLE_KEY` 通常已自動注入，無需手動加。）

### 3. 部署 Edge Function

Dashboard → **Edge Functions** → **Deploy a new function**：

- 名稱：`process_prescription_vision`
- 將 `supabase/functions/process_prescription_vision/index.ts` 內容貼上部署  
  或使用 CLI 成功後再 `supabase functions deploy process_prescription_vision`

### 4. Storage（選做：目前 OCR + LLM 流程已不再上傳藥單圖到 Storage）

> 自 v2026.05 起，藥單辨識改成「本地 ML Kit OCR → 把文字傳給 Edge Function」的雙階段流程；
> 不再上傳整張藥單到 `prescription-photos`，Edge Function 也不再走 Storage 下載。  
> 既存的 `prescription-photos` bucket 與 `photo_storage_path` 欄位仍然存在（為了歷史資料相容），
> 但全新 install 可以略過此步。如果你要支援志工幫忙審單的圖檔備份，請改用各自的功能 bucket。

如需建 bucket 給其他流程使用，可在 **SQL Editor** 執行：
`supabase/migrations/20260508191000_prescription_photos_bucket_fix.sql`

---

## 請勿在錯誤位置安裝 npm 套件

- `npm install supabase` 在 `C:\Users\ASUS\` **不會**讓 Flutter 專案自動能用 CLI。
- 若要在專案用 npm 腳本，應在 `smart_bp` 目錄並用 **Scoop 版 CLI**，不要依賴 npm 的 `supabase` 包。

---

## 物資子系統 — 完整 SQL 執行順序（新環境必讀）

在 [Supabase SQL Editor](https://supabase.com/dashboard/project/ntufhwqxaidwnelorcsv/sql/new) **整檔貼上並 Run，一次一支、不可跳過**。

### 階段 A：基礎 schema（`supabase/` 根目錄，不在 `migrations/`）

| 順序 | 檔案 | 說明 |
|------|------|------|
| A1 | [`orders_schema.sql`](orders_schema.sql) | `orders`／`order_items` 本體與 RLS（柑仔店正式單） |
| A2 | [`chapter5_shop_assistant_schema.sql`](chapter5_shop_assistant_schema.sql) | `demand_records`、`price_references`、`location_points` 等 |
| A3 | [`order_line_items_shopping_snapshot.sql`](order_line_items_shopping_snapshot.sql) | 採買快照欄位（今日清單 RPC 依賴） |
| A4 | [`graduation_enhancement_schema.sql`](graduation_enhancement_schema.sql) | 配送時間軸、`order_delivery_events`、訂單擴充欄位 |
| A5 | [`assistant_chat_schema.sql`](assistant_chat_schema.sql) | 小幫手對話歷史（選做，未跑則歷史功能不可用） |

> 若專案已跑過用藥等 migration，**勿重跑** `supabase/migrations/` 內既有檔；僅補跑上方 A 段缺漏與下方 B 段物資遷移。

### 階段 B：`migrations/` 物資遷移（v2／v3）

| 順序 | 檔案 |
|------|------|
| B1 | `20260601000000_product_catalog_and_intelligence.sql` — 建立 `product_categories` 等表 |
| B2 | `20260601500000_product_catalog_seed.sql` — 種子分類／品牌（`20260602` 的 `product_items` 依賴此資料） |
| B3 | `20260602000000_group_buy_collaboration.sql` — SKU、澄清、今日清單、履行 RPC |
| B4 | `20260603000000_volunteer_hub_unified_role.sql` — 志工端 RLS |
| B5 | `20260604000000_demand_records_submitted_at.sql` — 與 B3 開頭相同，可省略或重跑（idempotent） |
| B6 | `20260605000000_shop_backend_gaps.sql` — `client_request_id` 冪等鍵、`recommend_brands` GRANT |
| B7 | `20260606000000_android_fcm_tokens.sql` — `device_tokens` 複合索引（Android FCM 查詢） |
| B8 | `20260607000000_shop_realtime_publication.sql` — 冪等加入 `orders`／`demand_records`／`demand_record_items` Realtime |

### 階段 C：Demo 種子（選做但口試建議）

| 順序 | 檔案 | 說明 |
|------|------|------|
| C1 | [`price_references_demo_seed.sql`](price_references_demo_seed.sql) | 查價頁／小幫手「衛生紙多少錢」Demo 用 |

**自檢**：執行 [`verify_shop_backend.sql`](verify_shop_backend.sql) 確認 catalog seed、查價種子、Realtime publication、RPC、今日清採買可呼叫。

**易漏（舊檔，內容已併入 B6）**：`demand_record_items_add_client_request_id.sql` 可不再跑。

**常見錯誤**：若直接執行 B3 會出現  
`ERROR: 42P01: relation "public.product_categories" does not exist`  
→ 代表尚未執行 **B1**（或執行失敗中斷）。請先跑完 B1，在 Table Editor 確認有 `product_categories` 表，再跑 B2 與 B3。

說明見 `docs/shop_subsystem_architecture_v3.md`（v2 文件已標示為舊版）。

部署 Edge Functions（物資 NLU／推播）：

```bash
supabase secrets set GEMINI_API_KEY=你的_Gemini_API金鑰
supabase functions deploy parse_shop_nlu --no-verify-jwt
supabase functions deploy send_shop_push --no-verify-jwt
supabase functions deploy assistant_casual_chat --no-verify-jwt
```

| Function | Secret | 說明 |
|----------|--------|------|
| `parse_shop_nlu` | `GEMINI_API_KEY`（必填） | Hybrid NLU 低信心時補強；未部署則僅規則路徑 |
| `assistant_casual_chat` | `GEMINI_API_KEY`（必填） | 小幫手閒聊；失敗時 App 降級為本地模板 |
| `send_shop_push` | `FCM_SERVICE_ACCOUNT_JSON`（推薦，FCM v1）或 `FCM_SERVER_KEY`（Legacy，多已停用） | 長輩送單／志工更新訂單後 App invoke；僅 `platform=android` token |

**驗證 Edge**：Dashboard → Edge Functions → `parse_shop_nlu` → Invoke body `{"utterance":"我要買衛生紙"}` 應回 200。

**Realtime**：優先執行 **B8**（`20260607`）自動加入 publication。若仍無即時更新，到 Dashboard → **Database → Replication** 手動確認以下表已啟用：

| 表 | 用途 |
|----|------|
| `demand_records` | 志工草稿區、送單狀態 |
| `demand_record_items` | 品項履行 |
| `orders` | 長輩／志工訂單列表即時更新 |

未啟用時 App 仍可手動刷新，但 Demo 即時性會失效。

## 志工端權限

執行 `supabase/migrations/20260603000000_volunteer_hub_unified_role.sql` 後，志工可存取物資訂單與數據總覽。App 僅區分 **長輩** 與 **志工** 兩種登入角色。

---

## 驗證 Function 是否可用

部署後，在 App 掃描藥單；若失敗，到 Dashboard → **Edge Functions** → `process_prescription_vision` → **Logs** 查看錯誤。

常見錯誤：

| 訊息 | 處理 |
|------|------|
| `GEMINI_API_KEY not configured` | 設定 Secret 後重新部署 |
| `Gemini API 失敗 (404)` | 重新部署 Function；確認 API Key 來自 [AI Studio](https://aistudio.google.com/apikey) |
| `Gemini API 失敗 (429)` | 免費額度／每分鐘請求過多：等 1 分鐘再試；或升級配額；Function 會自動重試並換模型 |
| `raw_text 為必填` | 客戶端沒先做 ML Kit OCR；確認 App 已升到含 `PrescriptionVisionService` 雙階段流程的版本 |
| `PGRST204` / `medications_detail` 欄位找不到 | 執行 `20260508192000_prescription_vision_columns_fix.sql` |
| `pill_appearance` 欄位找不到 | 執行 `20260508193000_prescriptions_missing_columns_fix.sql` |
| `PGRST205` | 執行 vision 相關 migration |
