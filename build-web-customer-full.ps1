# Build full customer/guest web handoff package.
# Run from repo root:
#   powershell -ExecutionPolicy Bypass -File build-web-customer-full.ps1

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot
if (-not (Test-Path (Join-Path $repoRoot ".git")) -and (Test-Path (Join-Path (Split-Path -Parent $PSScriptRoot) ".git"))) {
  $repoRoot = Split-Path -Parent $PSScriptRoot
}
Set-Location $repoRoot

$outDir = Join-Path $repoRoot "web-customer-full-handoff"
$zipPath = Join-Path $repoRoot "web-customer-full-handoff.zip"
$docsDir = Join-Path $PSScriptRoot "web-customer-full-docs"
$packageBackendSrc = Join-Path $repoRoot "packages\backend\src"
$packageFrontendLib = Join-Path $repoRoot "packages\frontend\lib"

function Ensure-Dir($p) { New-Item -ItemType Directory -Force -Path $p | Out-Null }

if ((Test-Path $packageBackendSrc) -and (Test-Path $packageFrontendLib)) {
  if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }

  # --- Backend (full production API — customer + guest + shared; POS routes documented as out-of-scope) ---
  $beSrc = $packageBackendSrc
  $beOut = Join-Path $outDir "backend\src"
  Ensure-Dir $beOut
  Get-ChildItem $beSrc -Filter "*.ts" | ForEach-Object { Copy-Item $_.FullName $beOut }

  Ensure-Dir (Join-Path $outDir "backend\sql\migrations")
  Copy-Item (Join-Path $repoRoot "packages\backend\sql\migrations\*") (Join-Path $outDir "backend\sql\migrations") -Force
  $sqlManual = Join-Path $repoRoot "packages\backend\sql\manual_renumber_customer_ids.sql"
  if (Test-Path $sqlManual) {
    Ensure-Dir (Join-Path $outDir "backend\sql")
    Copy-Item $sqlManual (Join-Path $outDir "backend\sql\manual_renumber_customer_ids.sql")
  }

  foreach ($f in @("package.json", "package-lock.json", "tsconfig.json", ".env.example")) {
    $src = Join-Path $repoRoot "packages\backend\$f"
    if (Test-Path $src) { Copy-Item $src (Join-Path $outDir "backend\$f") }
  }
  $beReadme = Join-Path $repoRoot "packages\backend\README.md"
  if (Test-Path $beReadme) { Copy-Item $beReadme (Join-Path $outDir "backend\README.md") }

  # --- Frontend ---
  $feLib = Join-Path $outDir "frontend\lib"
  Ensure-Dir $feLib
  Ensure-Dir (Join-Path $feLib "features\event_design")
  Ensure-Dir (Join-Path $feLib "features\seating")
  Ensure-Dir (Join-Path $feLib "utils")

  Copy-Item (Join-Path $packageFrontendLib "main.dart") (Join-Path $feLib "main.dart")
  Copy-Item (Join-Path $packageFrontendLib "main_customer.dart") (Join-Path $feLib "main_customer.dart")
  Copy-Item (Join-Path $packageFrontendLib "customer_local_notifications.dart") (Join-Path $feLib "customer_local_notifications.dart")

  Copy-Item (Join-Path $packageFrontendLib "features\event_design\*") (Join-Path $feLib "features\event_design") -Recurse -Force
  Copy-Item (Join-Path $packageFrontendLib "features\seating\*") (Join-Path $feLib "features\seating") -Recurse -Force
  Copy-Item (Join-Path $packageFrontendLib "utils\*") (Join-Path $feLib "utils") -Recurse -Force

  foreach ($f in @("pubspec.yaml", "analysis_options.yaml")) {
    Copy-Item (Join-Path $repoRoot "packages\frontend\$f") (Join-Path $outDir "frontend\$f")
  }

  # Docs
  if (Test-Path (Join-Path $docsDir "README.md")) { Copy-Item (Join-Path $docsDir "README.md") $outDir }
  if (Test-Path (Join-Path $docsDir "CHANGELOG.md")) { Copy-Item (Join-Path $docsDir "CHANGELOG.md") $outDir }

  Write-Host "Wrote $outDir"
} elseif (-not (Test-Path $outDir)) {
  throw "Cannot build customer handoff: neither packages/ sources nor $outDir exist."
} else {
  Write-Host "Using existing customer handoff at $outDir"
}

if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
Compress-Archive -Path (Join-Path $outDir "*") -DestinationPath $zipPath -Force
Write-Host "Created $zipPath"
