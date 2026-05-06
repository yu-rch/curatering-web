param(
    [string]$OutputZip = "deploy_package.zip"
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

Write-Host "Preparing deploy package..."

$outDir = Join-Path $root "deploy_package"
if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
New-Item -ItemType Directory -Path $outDir | Out-Null

function Copy-IfExists($src, $dst) {
    if (Test-Path $src) {
        Write-Host "Copying $src -> $dst"
        Copy-Item $src -Recurse -Force -Destination $dst
    } else {
        Write-Host "Warning: $src not found, skipping"
    }
}

# Flutter web build output
Copy-IfExists "curatering/build/web" (Join-Path $outDir "web")

# Node server: include package.json, package-lock.json, src, and .env.example
Copy-IfExists "server/package.json" (Join-Path $outDir "server")
Copy-IfExists "server/package-lock.json" (Join-Path $outDir "server")
Copy-IfExists "server/src" (Join-Path $outDir "server/src")
Copy-IfExists "server/.env.example" (Join-Path $outDir "server")

# AI service: include Dockerfile, requirements, app and models
Copy-IfExists "ai-service/Dockerfile" (Join-Path $outDir "ai-service")
Copy-IfExists "ai-service/requirements.txt" (Join-Path $outDir "ai-service")
Copy-IfExists "ai-service/app" (Join-Path $outDir "ai-service/app")
Copy-IfExists "ai-service/models" (Join-Path $outDir "ai-service/models")

Write-Host "Creating zip $OutputZip"
if (Test-Path $OutputZip) { Remove-Item $OutputZip -Force }
Compress-Archive -Path (Join-Path $outDir "*") -DestinationPath $OutputZip

Write-Host "Package created: $OutputZip"
