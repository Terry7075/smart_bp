# 明德社區交通系統

Flutter + Supabase 的長者接送 Android APK 專案，第一版目標是簡易版 Uber 式接送流程。

- Google OAuth 登入
- 長者/家屬共用長者帳號建立與追蹤行程
- 司機接案、前景 GPS 位置更新、一鍵撥號與外部導航
- App 內地圖使用 `flutter_map` + OpenStreetMap，不需要 Google Maps API key
- 管理員審核司機、媒合、取消、改期、改派與即時調度
- 緊急聯絡人、SOS 快捷、延誤/GPS 中斷提示
- 行程評分與問題回報

## 本機需求

- Flutter SDK
- Android SDK
- Supabase project
- Google OAuth client

本機可用專案腳本建立 Android shell：

```powershell
./scripts/bootstrap.ps1
```

## 執行 App

```powershell
C:\Users\jun10\flutter\bin\flutter.bat run `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

`SUPABASE_URL` 與 `SUPABASE_PUBLISHABLE_KEY` 必須由 `--dart-define` 傳入。

## Supabase

依序套用 migrations：

1. `supabase/migrations/202605150001_mvp_schema.sql`
2. `supabase/migrations/20260515163710_mvp_hardening.sql`
3. `supabase/migrations/20260516020000_uber_v1.sql`
4. `supabase/migrations/20260516021000_uber_v1_security_indexes.sql`

設定 Google OAuth redirect URL：

```text
tw.mingde.transport://login-callback/
```

建立第一位管理員：

```sql
update public.profiles
set role = 'admin'
where email = 'admin@example.com';
```

## Android APK

詳細簽章與 release build 步驟見：

- `docs/android_release_deployment.md`

快速 build：

```powershell
./scripts/build_release.ps1 `
  -SupabaseUrl "https://YOUR_PROJECT.supabase.co" `
  -SupabasePublishableKey "YOUR_PUBLISHABLE_KEY"
```

## 驗證

```powershell
C:\Users\jun10\flutter\bin\flutter.bat analyze
C:\Users\jun10\flutter\bin\flutter.bat test
```
