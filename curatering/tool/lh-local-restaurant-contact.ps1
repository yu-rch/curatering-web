$ErrorActionPreference = 'Stop'
Set-Location 'C:\Users\gette\Downloads\curatering\curatering-web\curatering'

Write-Host '=== STEP 1: Copy boot.js before build ==='
New-Item -ItemType Directory -Force -Path 'build\web' | Out-Null
Copy-Item -Force 'web\boot.js' 'build\web\boot.js'
Write-Host 'Copied boot.js (pre-build)'

Write-Host '=== STEP 2: flutter build web --release ==='
& flutter build web --release
if ($LASTEXITCODE -ne 0) {
  Write-Host "FLUTTER_BUILD_FAILED exit=$LASTEXITCODE"
  exit $LASTEXITCODE
}
Write-Host 'FLUTTER_BUILD_OK'

Write-Host '=== STEP 3: Copy boot.js after build ==='
Copy-Item -Force 'web\boot.js' 'build\web\boot.js'
Write-Host 'Copied boot.js (post-build)'

Write-Host '=== STEP 4: SPA route dirs ==='
foreach ($route in @('restaurant','contact-us')) {
  $dir = "build\web\$route"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  Copy-Item -Force 'build\web\index.html' "$dir\index.html"
  $html = Get-Content "$dir\index.html" -Raw
  $html = $html -replace '<base href="[^"]*">','<base href="/">'
  Set-Content -Path "$dir\index.html" -Value $html -NoNewline
  Write-Host "Prepared $dir"
}

Write-Host '=== STEP 5: Ensure static server on 8765 ==='
$needServer = $true
try {
  $tcp = New-Object System.Net.Sockets.TcpClient
  $tcp.Connect('127.0.0.1', 8765)
  if ($tcp.Connected) { $needServer = $false }
  $tcp.Close()
} catch {
  $needServer = $true
}
if ($needServer) {
  Write-Host 'Starting python http.server 8765'
  Start-Process -FilePath 'python' -ArgumentList '-m','http.server','8765' -WorkingDirectory 'C:\Users\gette\Downloads\curatering\curatering-web\curatering\build\web' -WindowStyle Hidden
  Start-Sleep -Seconds 2
} else {
  Write-Host 'Server already listening on 8765'
}

New-Item -ItemType Directory -Force -Path 'tool\lh-out' | Out-Null

Write-Host '=== STEP 6: Lighthouse restaurant ==='
& npx --yes lighthouse 'http://127.0.0.1:8765/restaurant/' --throttling-method=simulate --chrome-flags='--headless --no-sandbox --disable-gpu' --output=json --output=html --output-path='tool\lh-out\local-restaurant' --quiet
Write-Host "LH_RESTAURANT_EXIT=$LASTEXITCODE"

Write-Host '=== STEP 6b: Lighthouse contact-us ==='
& npx --yes lighthouse 'http://127.0.0.1:8765/contact-us/' --throttling-method=simulate --chrome-flags='--headless --no-sandbox --disable-gpu' --output=json --output=html --output-path='tool\lh-out\local-contact-us' --quiet
Write-Host "LH_CONTACT_EXIT=$LASTEXITCODE"

Write-Host '=== ALL STEPS DONE ==='
