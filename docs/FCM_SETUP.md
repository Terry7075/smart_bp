# FCM 推播設定（Android-only）

**iOS** 不做 APNs；**Android** 用 Firebase Cloud Messaging。

你的 Firebase 專案若 **Legacy API 已停用**（2023 後新專案常見），請用 **FCM HTTP v1 + 服務帳戶 JSON**，不要用已停用的 Server key。

## 1. 取得服務帳戶 JSON（推薦，對應 V1 已啟用）

1. [Firebase Console](https://console.firebase.google.com/project/smart-bp-1c925/settings/serviceaccounts/adminsdk) → **專案設定** → **服務帳戶**
2. 點 **產生新的私密金鑰** → 下載 `.json`（只下載一次，勿提交 Git）
3. Supabase Dashboard → **Edge Functions → Secrets** → 新增：
   - **Name**：`FCM_SERVICE_ACCOUNT_JSON`
   - **Value**：打開 JSON 檔，**整份內容貼上**（一行或多行皆可）

JSON 內 `project_id` 應為 `smart-bp-1c925`。

## 2.（可選）Legacy Server key

僅在 Firebase **Cloud Messaging API (Legacy)** 仍「已啟用」時可用：

- Secret 名稱：`FCM_SERVER_KEY`
- 值：Legacy **Server key**

若 Legacy 顯示 **已停用**，請只用上一節的 `FCM_SERVICE_ACCOUNT_JSON`。

## 3. 部署 Edge Function

```bash
cd /Users/xuyuchen/Desktop/smart_bp-main
supabase functions deploy send_shop_push --no-verify-jwt
```

## 4. Android App

- `android/app/google-services.json` 已設定
- 志工 **Android** 登入 → `device_tokens.platform = android`
- 長輩可用 **iPhone** 送單測志工 Android 鎖屏推播

## 5. 測試 Invoke

```json
{
  "target_role": "volunteer",
  "event_type": "test_push",
  "title": "測試推播",
  "body_text": "FCM v1 測試",
  "payload": { "route": "/volunteer/shop-orders" },
  "platform": "android"
}
```

成功時：`sent: true`、`token_count > 0`、`fcm_api: "v1"`。  
`degraded: true` → 尚未設定 `FCM_SERVICE_ACCOUNT_JSON`（或 Legacy key）。

## 6. 安全

勿將 JSON 私鑰或 Server key 寫入 Flutter 或公開 repo。
