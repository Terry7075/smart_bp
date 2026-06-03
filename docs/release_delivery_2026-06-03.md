# 2026-06-03 APK Delivery

## Changes

- Fixed scroll and safe-area layout issues across admin, elder, driver, auth, and profile screens.
- Added bottom padding to scrollable pages so actions are not blocked by Android system navigation.
- Built a release APK for handoff.

## APK

- Path: `artifacts/elder-system-release.apk`
- Size: 54.75 MB
- SHA-256: `F97D6AEC3D2E15BB3B6581F22FD95B31683970C63236E3D9DE240396D0300B19`

## Validation

- `flutter analyze`
- `flutter test`
- `flutter build apk --release`

## Signing Note

The current project has no `android/key.properties`, so the release build used the project's debug-signing fallback. This APK is suitable for installation testing. A production store release should be rebuilt with a proper release keystore.
