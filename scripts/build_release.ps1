param(
  [Parameter(Mandatory = $true)]
  [string]$SupabaseUrl,

  [Parameter(Mandatory = $true)]
  [string]$SupabasePublishableKey,

  [string]$Flutter = 'C:\Users\jun10\flutter\bin\flutter.bat'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Flutter)) {
  $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
  if ($null -eq $flutterCommand) {
    throw 'Flutter SDK is not available. Pass -Flutter or add flutter to PATH.'
  }
  $Flutter = $flutterCommand.Source
}

if ([string]::IsNullOrWhiteSpace($SupabaseUrl)) {
  throw 'SupabaseUrl is required.'
}

if ([string]::IsNullOrWhiteSpace($SupabasePublishableKey)) {
  throw 'SupabasePublishableKey is required.'
}

& $Flutter pub get
& $Flutter analyze
& $Flutter test
& $Flutter build apk --release `
  --dart-define="SUPABASE_URL=$SupabaseUrl" `
  --dart-define="SUPABASE_PUBLISHABLE_KEY=$SupabasePublishableKey"

Write-Host 'Release APK: build\app\outputs\flutter-apk\app-release.apk'
