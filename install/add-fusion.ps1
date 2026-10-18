# Puts Fusion Menu (the zip from portal.cfx.re > Granted Assets) into resources\[fusion].
# Finds the zip in Downloads / Desktop / the server folder by itself; asks only if it can't.

param([string]$Root = (Split-Path -Parent $PSScriptRoot), [string]$Zip = '')

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$target = Join-Path $Root 'resources\[fusion]'

function Test-FusionZip($path) {
    try {
        $z = [IO.Compression.ZipFile]::OpenRead($path)
        try { return [bool]($z.Entries | Where-Object { $_.FullName.Replace([string][char]92, '/') -match '(^|/)fusion-core/fxmanifest\.lua$' } | Select-Object -First 1) }
        finally { $z.Dispose() }
    } catch { return $false }
}

function Find-FusionZip {
    $places = @((Join-Path $env:USERPROFILE 'Downloads'), [Environment]::GetFolderPath('Desktop'), $Root)
    foreach ($p in $places) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $hit = Get-ChildItem -LiteralPath $p -Filter '*.zip' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Where-Object { Test-FusionZip $_.FullName } | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

function Expand-Fusion($path) {
    $z = [IO.Compression.ZipFile]::OpenRead($path)
    try {
        # some zip tools on Windows store paths with \ instead of /
        $core = $z.Entries | Where-Object { $_.FullName.Replace([string][char]92, '/') -match '(^|/)fusion-core/fxmanifest\.lua$' } | Select-Object -First 1
        $corePath = $core.FullName.Replace([string][char]92, '/')
        $prefix = $corePath.Substring(0, $corePath.Length - 'fusion-core/fxmanifest.lua'.Length)
        New-Item -ItemType Directory -Force -Path $target | Out-Null
        foreach ($e in $z.Entries) {
            $name = $e.FullName.Replace([string][char]92, '/')
            if (-not $name.StartsWith($prefix) -or $name.EndsWith('/')) { continue }
            $rel = $name.Substring($prefix.Length)
            if ($rel -match '(^|/)\.\.(/|$)') { continue }
            # never overwrite the owner's own edits or pictures on an update
            if ($rel -match '/html/(img|images|media|sounds)/' -and (Test-Path -LiteralPath (Join-Path $target $rel))) { continue }
            $out = Join-Path $target ($rel -replace '/', '\')
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $out, $true)
        }
    } finally { $z.Dispose() }
}

if (Get-ChildItem -LiteralPath (Join-Path $Root 'resources') -Recurse -Directory -Filter 'fusion-core' -ErrorAction SilentlyContinue | Select-Object -First 1) {
    if (-not $Zip) { Write-Host 'Fusion Menu is already in resources\[fusion].' -ForegroundColor Green; return }
}

Write-Host ''
Write-Host '== Fusion Menu files ==' -ForegroundColor Cyan
while (-not $Zip) {
    $Zip = Find-FusionZip
    if ($Zip) { break }
    Write-Host 'Fusion Menu itself comes from the Cfx.re portal (it is protected, so it cannot be downloaded for you):' -ForegroundColor Yellow
    Write-Host '  1. Sign in at portal.cfx.re with the account you bought it with (the page opens now)'
    Write-Host '  2. Granted Assets > Fusion Menu > Download  (save it in your Downloads folder)'
    Start-Process 'https://portal.cfx.re/assets/granted-assets' | Out-Null
    $answer = Read-Host 'Press Enter when it is downloaded (or type the path to the zip, or "skip")'
    if ($answer -eq 'skip') { Write-Host 'Skipped - put Fusion Menu into resources\[fusion] before starting the server.' -ForegroundColor Yellow; return }
    if ($answer) { $Zip = $answer.Trim('"') ; if (-not (Test-FusionZip $Zip)) { Write-Host 'That zip does not contain Fusion Menu.' -ForegroundColor Red; $Zip = '' } }
}
Write-Host "Unpacking $Zip ..."
Expand-Fusion $Zip
Write-Host "Fusion Menu is in $target" -ForegroundColor Green
