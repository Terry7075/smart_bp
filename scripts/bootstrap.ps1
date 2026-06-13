$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter SDK is not available on PATH. Install Flutter first, then rerun this script.'
}

flutter create . --platforms=android
flutter pub get
Write-Host 'Project shell created. Remember to add the Android OAuth intent-filter from docs/android_manifest_snippet.md.'
