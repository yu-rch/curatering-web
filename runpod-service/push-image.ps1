# Build and push the RunPod worker image. Always tags the SAME name you push
# so you never push a stale yurichhh/... tag from an old build.
#
# Usage (from this directory):
#   .\push-image.ps1 -Tag v6
#   .\push-image.ps1 -Tag v6 -NoCache

param(
    [Parameter(Mandatory = $true)]
    [string] $Tag,
    [string] $Repo = "yurichhh/curatering-ai",
    [switch] $NoCache
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

$full = "${Repo}:${Tag}"
$buildId = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHHmmssZ")
$args = @("build", "-t", $full, "--build-arg", "IMAGE_BUILD_ID=$buildId", ".")
if ($NoCache) { $args = @("build", "--no-cache") + $args[1..($args.Length - 1)] }

Write-Host "docker $($args -join ' ')"
& docker @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "`nLocal image (verify runpod):"
& docker run --rm $full python -c "import runpod; import pathlib; p=pathlib.Path('/app/.build-stamp'); print('runpod OK', p.read_text() if p.exists() else '')"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "`nPushing $full ..."
& docker push $full
exit $LASTEXITCODE
