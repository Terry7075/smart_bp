# Android 不插線安裝（Release APK）

同事測試、口試 Demo 若不想接 USB，可用本機建好的 **Release APK** 安裝到手機。

## 1. 建置 APK（維護者執行一次）

```bash
cd smart_bp-main
flutter pub get
flutter build apk --release
```

產物路徑：

```text
build/app/outputs/flutter-apk/app-release.apk
```

（亦可複製到 `releases/smart_bp-release.apk` 方便傳檔。）

## 2. 傳到手機（擇一）

| 方式 | 步驟 |
|------|------|
| **AirDrop / LINE / Google Drive** | 把 `app-release.apk` 傳到手機，點檔安裝 |
| **同一 Wi‑Fi + adb 無線** | 見下方 §3 |
| **USB 僅第一次配對** | `adb tcpip 5555` 後即可拔線，之後用 Wi‑Fi adb |

安裝前請在手機開啟：**設定 → 安全性 → 允許安裝未知來源 App**（各廠牌名稱略有不同）。

## 3. adb 無線安裝（可選）

```bash
# 手機與電腦同一 Wi‑Fi；手機先開「開發人員選項 → 無線偵錯」
adb pair <手機顯示的 IP:配對埠>   # 輸入配對碼
adb connect <手機 IP:連線埠>
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## 4. 與 `flutter run` 差異

- APK 為 **release** 建置，效能較佳、不需插線。
- `google-services.json` 須在本機 `android/app/` 放好再建置，才有 FCM 推播。
- 若只改 Dart UI，同事可 `git pull` 後自行 `flutter run -d <device>` 熱更新開發。

## 5. 常見問題

| 症狀 | 處理 |
|------|------|
| 無法安裝 | 確認允許未知來源；先解除安裝舊版同名 App |
| 開啟閃退 | 確認 `minSdk 26`（Android 8+） |
| 無推播 | 建置前需有 `google-services.json`，見 [TEAM_SETUP.md](TEAM_SETUP.md) |
