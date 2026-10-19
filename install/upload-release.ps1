# Uploads the zips in dist\ to GitHub as a release of this build, so there's a copy online as well as on this PC.
#   powershell -ExecutionPolicy Bypass -File install\upload-release.ps1
# Everything goes to the PRIVATE repo Marine1108/fusion-menu (release "v<version>-build.<n>"); the Pterodactyl
# zips and deployment guide also go to the PRIVATE repo Marine1108/fusion-menu-pterodactyl. Nothing goes public
# (the public server kit is published separately by publish-kit.ps1). Run build-release.ps1 first.
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $Root 'dist'
$stampFile = Join-Path $dist 'BUILD.txt'
if (-not (Test-Path -LiteralPath $stampFile)) { throw 'No dist\BUILD.txt - run install\build-release.ps1 first.' }
$stamp = (Get-Content -LiteralPath $stampFile -Raw).Trim()
if ($stamp -notmatch 'v(\S+) build (\d+)') { throw "Can't read the build number from dist\BUILD.txt: $stamp" }
$tag = "v$($Matches[1])-build.$($Matches[2])"
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'The GitHub CLI (gh) was not found - install it from cli.github.com.' }

function Publish($repo, $files, $title) {
    $visibility = (& gh repo view $repo --json visibility -q .visibility).Trim()
    if ($visibility -ne 'PRIVATE') { throw "$repo is not private ($visibility) - refusing to upload." }
    $ErrorActionPreference = 'Continue'   # gh writes "release not found" to stderr
    $null = & gh release view $tag --repo $repo 2>&1
    $exists = $LASTEXITCODE -eq 0
    if ($exists) {
        & gh release upload $tag @files --repo $repo --clobber
    } else {
        & gh release create $tag @files --repo $repo --title $title --notes "$stamp. Built from the private source; for staff use only."
    }
    $ok = $LASTEXITCODE -eq 0
    $ErrorActionPreference = 'Stop'
    if (-not $ok) { throw "Upload to $repo failed." }
    Write-Host "Uploaded $($files.Count) file(s) to $repo, release $tag" -ForegroundColor Green
}

$zips = @(Get-ChildItem -LiteralPath $dist -Filter *.zip -File | ForEach-Object { $_.FullName })
$guide = Join-Path $dist 'PTERODACTYL-DEPLOYMENT-GUIDE.md'
$all = $zips + @($stampFile)
if (Test-Path -LiteralPath $guide) { $all += $guide }
Publish 'Marine1108/fusion-menu' $all "Fusion Menu $stamp"

$ptero = @($zips | Where-Object { $_ -match 'pterodactyl' })
if (Test-Path -LiteralPath $guide) { $ptero += $guide }
if ($ptero.Count) { Publish 'Marine1108/fusion-menu-pterodactyl' $ptero "Pterodactyl packages - $stamp" }
