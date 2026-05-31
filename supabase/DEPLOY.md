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
| `GEMINI_MODEL`（選填） | 預設 `gemini-2.0-flash`；勿再用已下架的 `gemini-1.5-flash` |

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
