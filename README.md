# 明德社區交通系統

明德社區交通系統是一個 Flutter + Supabase 的 Android 接送服務 App，目標是提供長者/家屬叫車、司機接案、管理員審核與即時調度的一套完整流程。

## 專案狀態

- App 類型：Flutter Android APK
- 後端：Supabase Auth、Postgres、Realtime、Row Level Security、Postgres RPC
- 目前版本：`1.0.0+1`
- Package ID：`tw.mingde.transport`
- OAuth callback：`tw.mingde.transport://login-callback/`
- 地圖：`flutter_map` + OpenStreetMap，不需要 Google Maps API key

## 主要功能

### 長者 / 家屬

- Google OAuth 登入
- 完成個人資料與緊急聯絡人設定
- 建立一般接送需求
- 選擇已核准的長期接送方案
- 查看行程、歷史紀錄與行程明細
- 查看司機 GPS 位置
- 取消可取消狀態的行程
- 完成後評分與回報問題
- SOS 快捷電話

### 司機

- 申請司機資格
- 查看審核狀態
- 查看可接行程
- 接受行程
- 行程中更新狀態
- 上傳前景 GPS 位置
- 一鍵撥打乘客電話
- 開啟外部導航
- 建立可服務的長期接送方案

### 管理員

- 儀表板統計
- 審核司機申請
- 手動媒合行程
- 查看即時行程
- 取消、改期、改派行程
- 查看延誤與 GPS 中斷狀態
- 查看未處理問題回報
- 審核司機長期接送方案

## 技術棧

- Flutter SDK `>=3.5.0 <4.0.0`
- Dart
- Riverpod
- GoRouter
- Supabase Flutter
- Supabase Auth
- Supabase Postgres + RLS
- Supabase Realtime
- Geolocator
- url_launcher
- flutter_map
- latlong2
- Android Gradle Kotlin DSL

## 專案結構

```text
lib/
  app.dart
  main.dart
  core/
    constants.dart
    providers.dart
    router.dart
    supabase_client.dart
    theme.dart
    utils/
  features/
    admin/
    auth/
    driver/
    elder/
    notifications/
    profile/
  models/
  services/
  widgets/
supabase/
  migrations/
test/
scripts/
docs/
android/
```

## 環境需求

- Flutter SDK
- Android SDK / Android Emulator
- Supabase project
- Google OAuth client
- PowerShell

## 環境變數

App 必須使用 `--dart-define` 注入 Supabase 設定。

```text
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

本機可建立 `.env`：

```text
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

`.env` 已被 `.gitignore` 排除，不應提交。

## 安裝依賴

```powershell
flutter pub get
```

## 執行 App

使用 `.env`：

```powershell
./scripts/run_android.ps1
```

或手動帶入：

```powershell
flutter run `
  -d emulator-5554 `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## 建置 APK

### Debug APK

```powershell
flutter build apk --debug `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

輸出：

```text
build/app/outputs/flutter-apk/app-debug.apk
```

### Release APK

```powershell
./scripts/build_release.ps1 `
  -SupabaseUrl "https://YOUR_PROJECT.supabase.co" `
  -SupabasePublishableKey "YOUR_PUBLISHABLE_KEY"
```

輸出：

```text
build/app/outputs/flutter-apk/app-release.apk
```

如果尚未建立 `android/key.properties`，目前 Gradle 設定會使用 debug signing fallback 產生 release variant。這個 APK 可用於交付測試與側載安裝，但正式上架前應建立 release keystore。

## Release 簽章

建立 keystore：

```powershell
keytool -genkey -v `
  -keystore android/app/mingde-release.jks `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias mingde
```

建立 `android/key.properties`：

```properties
storeFile=app/mingde-release.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=mingde
keyPassword=YOUR_KEY_PASSWORD
```

`android/key.properties`、`*.jks`、`*.keystore` 已被 `.gitignore` 排除。

## Supabase 設定

### OAuth

Google OAuth redirect URL：

```text
tw.mingde.transport://login-callback/
```

Supabase 專案也需要允許對應的 Android deep link callback。

### Migration

依序套用 `supabase/migrations` 內的 SQL 檔。檔名版本已和目前 production migration history 對齊。

目前 migration 包含：

```text
20260515163629_mvp_schema.sql
20260515163710_mvp_hardening.sql
20260515185752_uber_v1.sql
20260515185902_uber_v1_security_indexes.sql
20260521190023_standing_ride_requests.sql
20260521190138_standing_ride_requests_hardening.sql
20260524234556_driver_standing_ride_offers.sql
20260525005004_fix_create_standing_ride_request_weekdays.sql
20260525005037_tighten_standing_ride_table_grants.sql
20260525010838_tighten_ride_rpc_execute_grants.sql
20260525010957_tighten_core_table_grants.sql
20260525020222_remove_elder_standing_request_flow.sql
```

### 建立管理員

使用者登入並建立 profile 後，可在 Supabase SQL editor 將指定帳號設為 admin：

```sql
update public.profiles
set role = 'admin'
where email = 'admin@example.com';
```

## 權限與安全

- 所有 public app tables 已啟用 RLS。
- `anon` 不保留業務表 table privileges。
- `authenticated` 僅保留 App 所需的 `select / insert / update`。
- 重要 RPC 已移除 `PUBLIC/anon` execute grants。
- App 只使用 publishable key，不應在 client 端放入 service role 或 secret key。
- `.env`、release keystore 與簽章設定不可提交。

## 驗證指令

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
flutter build apk --release `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## 手動驗收清單

- Google OAuth 登入會導向正確 Supabase project。
- OAuth callback 回到 App。
- 長者可建立一般接送需求。
- 長者可選擇已核准的司機長期接送方案。
- 司機可提出申請，管理員可核准。
- 司機可接案並更新行程狀態。
- 司機 GPS 位置會在長者/管理員端顯示。
- 管理員可手動媒合、改期、改派與取消。
- 管理員可審核司機長期接送方案。
- 已完成行程可評分與回報問題。
- release APK 可在實體 Android 或 emulator 安裝啟動。

## 常見問題

### 登入網址跑到 `https://example.supabase.co`

代表 APK 是用範例 `SUPABASE_URL` 建置。請使用正確 `.env` 或 `--dart-define` 重新 build 並重新安裝。

### `supabase db lint --linked` 找不到 project ref

本機尚未執行 `supabase link`。可先用 Supabase dashboard/MCP 檢查 production database，或在本機執行：

```powershell
supabase link --project-ref YOUR_PROJECT_REF
```

### Release APK 不是正式簽章

確認 `android/key.properties` 存在且指向 release keystore。若不存在，Gradle 會 fallback 到 debug signing。
