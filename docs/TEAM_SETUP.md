# 團隊建置指南（新電腦／換機）

> 個人負責模組：物資代購 + 智慧小幫手。其他組員模組見根目錄 [README.md](../README.md)。

---

## 1. 環境需求

| 項目 | 版本建議 |
|------|----------|
| Flutter | 3.x（`flutter doctor` 全綠） |
| Dart | 隨 Flutter SDK |
| Supabase CLI | Scoop／Homebrew 安裝（見 [supabase/DEPLOY.md](../supabase/DEPLOY.md)） |
| Android Studio / Xcode | 實機 Demo 用 |

```bash
cd smart_bp-main
flutter pub get
```

---

## 2. 機密檔（不在 Git，需私下取得）

| 檔案 | 用途 | 取得方式 |
|------|------|----------|
| `android/app/google-services.json` | Android FCM | [Firebase Console](https://console.firebase.google.com/project/smart-bp-1c925) → 專案設定 → 你的 Android App → 下載 |
| `ios/Runner/GoogleService-Info.plist` | iOS Firebase（選用；FCM 本期僅 Android） | 同上 |

Supabase 連線目前寫在 `lib/main.dart`（`url` + `anonKey`）。**勿將 service role key 寫進 App**。

Edge Function 金鑰在 Supabase Dashboard → Edge Functions → Secrets（見下方 §4）。

---

## 3. Supabase 資料庫（必做）

**完整順序**見 [supabase/DEPLOY.md](../supabase/DEPLOY.md)：

1. **階段 A**：`orders_schema` → `chapter5` → `order_line_items_shopping_snapshot` → `graduation_enhancement` →（選）`assistant_chat`
2. **階段 B**：`20260601` → `202606015` → `20260602` → `20260603` → `20260605` → `20260606` → `20260607`（Realtime）
3. **Demo 種子**：[`supabase/price_references_demo_seed.sql`](../supabase/price_references_demo_seed.sql)（查價頁／小幫手查價）

**自檢**：SQL Editor 執行 [`supabase/verify_shop_backend.sql`](../supabase/verify_shop_backend.sql)。

**Realtime**：若未跑 `20260607`，到 Dashboard → Database → Replication 手動開啟 `orders`、`demand_records`、`demand_record_items`。

---

## 4. Edge Functions

```bash
supabase link --project-ref ntufhwqxaidwnelorcsv
supabase secrets set GEMINI_API_KEY=你的金鑰
supabase functions deploy parse_shop_nlu --no-verify-jwt
supabase functions deploy send_shop_push --no-verify-jwt
supabase functions deploy assistant_casual_chat --no-verify-jwt
```

Android 推播另設 `FCM_SERVICE_ACCOUNT_JSON`（整份服務帳戶 JSON），詳 [FCM_SETUP.md](FCM_SETUP.md)。

---

## 5. 測試帳號建議

在 Supabase Auth 建立帳號後，於 `profiles` 設定 `role`：

| 角色 | `profiles.role` | 登入後導向 |
|------|-----------------|------------|
| 長輩 | `elder` | `/home` |
| 志工 | `volunteer` | `/volunteer-dashboard` |

註冊畫面可勾選「我是社區志工」自動設 `volunteer`。

---

## 6. 本機執行

```bash
# Web（快速 UI）
flutter run -d chrome --web-port=8080

# Android 實機（FCM Demo）
flutter run -d <device_id>
```

**不插線安裝 Release APK**（傳檔或 adb 無線）：見 [WIRELESS_INSTALL.md](WIRELESS_INSTALL.md)。

關閉小幫手雲端閒聊（離線口試）：

```bash
flutter run --dart-define=ASSISTANT_CASUAL_GEMINI=false
```

---

## 7. 測試

```bash
flutter test test/supply_dialogue_test.dart
flutter test test/hybrid_nlu_orchestrator_test.dart
flutter test test/assistant_shop_intent_test.dart
flutter test test/shop_manual_voice_parser_test.dart
```

---

## 8. 口試 Demo 路徑

固定劇本：[DEMO_SCRIPT.md](DEMO_SCRIPT.md)

**請勿**用目錄購物車「送出需求」作主 Demo（不經品牌確認、無完整履行鏈）；主線為柑仔店上方 **語音 → 品牌 → 送出給志工**。

---

## 9. 常見問題

| 症狀 | 處理 |
|------|------|
| `product_categories does not exist` | 未跑 `20260601`，見 DEPLOY B1 |
| 志工看不到草稿 | Realtime 未開 `demand_records` |
| Android 無推播 | 檢查 `google-services.json`、`FCM_SERVICE_ACCOUNT_JSON`、志工 Android 登入後 `device_tokens` |
| 查價空白 | 跑 `price_references_demo_seed.sql` |

---

*相關文件：[SHOP_ASSISTANT_README.md](SHOP_ASSISTANT_README.md) · [FCM_SETUP.md](FCM_SETUP.md) · [專題成果報告書初稿.md](專題成果報告書初稿.md)*
