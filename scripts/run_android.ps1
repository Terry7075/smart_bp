param(
  [string]$SupabaseUrl,

  [string]$SupabasePublishableKey,

  [string]$Device = 'emulator-5554',

  [string]$Flutter = 'C:\Users\jun10\flutter\bin\flutter.bat'
)

$ErrorActionPreference = 'Stop'

$envFile = Join-Path (Get-Location) '.env'
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line.Length -eq 0 -or $line.StartsWith('#') -or -not $line.Contains('=')) {
      return
    }

    $name, $value = $line.Split('=', 2)
    if ($name -eq 'SUPABASE_URL' -and [string]::IsNullOrWhiteSpace($SupabaseUrl)) {
      $SupabaseUrl = $value.Trim()
    }
    if ($name -eq 'SUPABASE_PUBLISHABLE_KEY' -and [string]::IsNullOrWhiteSpace($SupabasePublishableKey)) {
      $SupabasePublishableKey = $value.Trim()
    }
  }
}

if ([string]::IsNullOrWhiteSpace($SupabaseUrl)) {
  throw 'SupabaseUrl is required. Pass -SupabaseUrl or set SUPABASE_URL in .env.'
}

if ([string]::IsNullOrWhiteSpace($SupabasePublishableKey)) {
  throw 'SupabasePublishableKey is required. Pass -SupabasePublishableKey or set SUPABASE_PUBLISHABLE_KEY in .env.'
}

if (-not (Test-Path $Flutter)) {
  $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
  if ($null -eq $flutterCommand) {
    throw 'Flutter SDK is not available. Pass -Flutter or add flutter to PATH.'
  }
  $Flutter = $flutterCommand.Source
}

& $Flutter run `
  -d $Device `
  --dart-define="SUPABASE_URL=$SupabaseUrl" `
  --dart-define="SUPABASE_PUBLISHABLE_KEY=$SupabasePublishableKey"
