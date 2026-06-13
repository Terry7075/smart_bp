# Android APK release deployment

## Required build values

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

The app uses `flutter_map` with OpenStreetMap tiles for in-app maps, so it does not require a Google Maps Android API key.

## Release signing

Create a keystore outside source control:

```powershell
keytool -genkey -v -keystore android/app/mingde-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mingde
```

Create `android/key.properties`:

```properties
storeFile=app/mingde-release.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=mingde
keyPassword=YOUR_KEY_PASSWORD
```

Both `android/key.properties` and keystore files are ignored by git.

## Map provider

The in-app map uses:

```text
https://tile.openstreetmap.org/{z}/{x}/{y}.png
```

Requirements:

- Keep OpenStreetMap attribution visible.
- Do not bulk download or prefetch tiles.
- For heavy production usage, use a dedicated tile provider or self-host tiles.

## Build

```powershell
./scripts/build_release.ps1 `
  -SupabaseUrl "https://YOUR_PROJECT.supabase.co" `
  -SupabasePublishableKey "YOUR_PUBLISHABLE_KEY"
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Manual acceptance checklist

- Install release APK on Android.
- Google OAuth returns to `tw.mingde.transport://login-callback/`.
- Driver grants location permission and GPS appears on elder/admin ride detail.
- Driver can call passenger and open external navigation.
- Driver completes the trip with only `接到人` and `已送達`.
- Elder account can cancel pending/matched rides, report issues, and rate completed rides.
- Admin can cancel, reschedule, reassign, see delayed rides, stale GPS, and unresolved reports.
