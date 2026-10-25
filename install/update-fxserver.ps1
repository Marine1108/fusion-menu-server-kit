# Updates the FiveM server program (FXServer), and with it txAdmin, which is built into it. Windows.
#   update-fxserver.bat              the "recommended" build (the safe choice)
#   update-fxserver.bat latest       the newest build (the newest txAdmin patch, e.g. 8.1.2)
#   update-fxserver.bat rollback     back to the build you had before the last update
#
# Only FXServer's own files are replaced (the ones in FiveM's download: FXServer.exe, its DLLs, citizen\ ...).
# Everything else in that folder stays, including txData (txAdmin's settings) if it is kept there, and your
# server folder, Fusion Menu, the database and server.cfg are never touched. The replaced files are kept in
# a "previous" folder next to FXServer until the next update, so "rollback" can put them back.
param([ValidateSet('recommended', 'latest', 'rollback')][string]$Choice = 'recommended')
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot

function Fail($msg) { Write-Host $msg -ForegroundColor Red; exit 1 }

# where FXServer is: from the start shortcuts the installer made, else C:\FXServer
$fxDir = $null
foreach ($bat in 'Start txAdmin.bat', 'Start Fusion Server.bat') {
    $p = Join-Path $Root $bat
    if (Test-Path -LiteralPath $p) {
        $m = [regex]::Match((Get-Content -Raw -LiteralPath $p), '"([^"]+\\FXServer\.exe)"')
        if ($m.Success) { $fxDir = Split-Path -Parent $m.Groups[1].Value; break }
    }
}
if (-not $fxDir) { $fxDir = 'C:\FXServer' }
if ($env:FX_DIR) { $fxDir = $env:FX_DIR }
if (-not (Test-Path -LiteralPath (Join-Path $fxDir 'FXServer.exe'))) {
    Fail "FXServer.exe was not found in $fxDir. Run it with the folder: set FX_DIR=D:\path\to\FXServer then update-fxserver.bat"
}
$prevDir = "$fxDir.previous"
$marker = Join-Path $fxDir '.fusion-build'

$running = Get-Process -Name FXServer -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($fxDir, [StringComparison]::OrdinalIgnoreCase) }
if ($running) { Fail 'The server is running. Stop it (txAdmin > Stop server, or close its window) and run this again.' }

if ($Choice -eq 'rollback') {
    if (-not (Test-Path -LiteralPath $prevDir)) { Fail "There is no earlier build to go back to ($prevDir is missing)." }
    foreach ($item in Get-ChildItem -LiteralPath $prevDir -Force) {
        $dst = Join-Path $fxDir $item.Name
        if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
        Move-Item -LiteralPath $item.FullName -Destination $dst
    }
    Remove-Item -LiteralPath $prevDir -Recurse -Force
    Write-Host 'Back on the build you had before. Start the server again.' -ForegroundColor Green
    exit 0
}

Write-Host "Asking FiveM for the $Choice build..."
try { $v = Invoke-RestMethod 'https://changelogs-live.fivem.net/api/changelog/versions/win32/server' } catch { Fail "Could not reach FiveM's download server. Try again in a minute." }
$build = $v.$Choice
$url = $v."$($Choice)_download"
$txa = $v."$($Choice)_txadmin"
if (-not $build -or -not $url) { Fail 'FiveM did not say which build that is. Try again in a minute.' }
$now = if (Test-Path -LiteralPath $marker) { (Get-Content -Raw -LiteralPath $marker).Trim() } else { 'unknown' }
Write-Host "Installed: build $now.  $Choice : build $build with txAdmin $txa." -ForegroundColor Cyan
if ($now -eq "$build") { Write-Host "You already have build $build. Nothing to do." -ForegroundColor Green; exit 0 }

$tmp = Join-Path $env:TEMP ('fxserver-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    Write-Host "Downloading build $build..."
    $zip = Join-Path $tmp 'server.zip'
    try { Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing } catch { Fail 'The download failed. Nothing was changed.' }
    $new = Join-Path $tmp 'new'
    try { Expand-Archive -LiteralPath $zip -DestinationPath $new -Force } catch { Fail 'The download is damaged. Nothing was changed.' }
    if (-not (Test-Path -LiteralPath (Join-Path $new 'FXServer.exe'))) { Fail 'The download does not look like FXServer. Nothing was changed.' }

    # set aside exactly what the new build replaces, then move the new files in
    if (Test-Path -LiteralPath $prevDir) { Remove-Item -LiteralPath $prevDir -Recurse -Force }
    New-Item -ItemType Directory -Path $prevDir | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $new -Force) {
        $dst = Join-Path $fxDir $item.Name
        if (Test-Path -LiteralPath $dst) { Move-Item -LiteralPath $dst -Destination (Join-Path $prevDir $item.Name) }
        Move-Item -LiteralPath $item.FullName -Destination $dst
    }
    Set-Content -LiteralPath $marker -Value $build -Encoding ASCII
    Write-Host "FXServer updated to build $build (txAdmin $txa). The previous build is kept: update-fxserver.bat rollback" -ForegroundColor Green
    Write-Host 'Start the server again (the "Fusion txAdmin" or "Start Fusion Server" shortcut).' -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
