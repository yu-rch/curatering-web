# Build Flutter web with compile-time --dart-define.
# Run this from the Flutter package directory (the folder that contains pubspec.yaml),
# i.e. ...\curatering-web\curatering — not from the repo root twice.
#
# Examples (from curatering\):
#   $env:API_BASE_URL = "https://your-api.up.railway.app"
#   $env:SUPABASE_URL = "https://xxx.supabase.co/rest/v1/"
#   $env:SUPABASE_ANON_KEY = "eyJ..."
#   .\tool\build_web.ps1
#
# From repo root (curatering-web\):
#   .\curatering\tool\build_web.ps1
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptDir
Set-Location $root

$flutterArgs = @("build", "web", "--release")
if ($env:API_BASE_URL) {
    $flutterArgs += "--dart-define=API_BASE_URL=$($env:API_BASE_URL)"
}
if ($env:SUPABASE_URL) {
    $flutterArgs += "--dart-define=SUPABASE_URL=$($env:SUPABASE_URL)"
}
if ($env:SUPABASE_ANON_KEY) {
    $flutterArgs += "--dart-define=SUPABASE_ANON_KEY=$($env:SUPABASE_ANON_KEY)"
}

Write-Host "flutter $($flutterArgs -join ' ')"
& flutter @flutterArgs
exit $LASTEXITCODE
