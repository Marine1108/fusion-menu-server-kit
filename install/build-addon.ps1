# Packages a Fusion add-on (sold separately) as its own zip in dist\addons\:
#   powershell -ExecutionPolicy Bypass -File install\build-addon.ps1 [-Name fusion-builder]
#
#   FusionBuilder-asset.zip          Upload to the Cfx.re portal as its OWN asset (not a version of Fusion Menu).
#                                    The name never changes, so the portal takes each upload as a new version of the
#                                    same asset (the version is in fxmanifest.lua). A copy named with the version
#                                    (FusionBuilder-v<ver>-asset.zip) goes to dist\addons\previous as the backup.
#                                    Buyers get it from their keymaster. Holds the resource folder, HOW-TO-INSTALL.txt
#                                    and the guide (README.md). No PDFs or other archives: the portal refuses them.
#
# The add-on's source lives in resources\[fusion-addons]\<name>, so the Fusion Menu build never includes it.
# Its JavaScript is scrambled (tools\js-protect) because Cfx.re escrow only encrypts Lua; -NoProtect skips that.
# -Product names the zip (Fusion<Product>-asset.zip) when the folder name doesn't give a good one, e.g.
#   build-addon.ps1 -Name fh-firehose -Product FireHose   (an add-on kept in resources\[addons])
param([string]$Name = 'fusion-builder', [string]$Product, [switch]$NoProtect)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot

# Node.js for the JavaScript protection step: the one on PATH, or the pinned portable copy build-release.ps1 uses
function Get-Node {
    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($node) { return $node.Source }
    $ver = 'v22.11.0'
    $dir = Join-Path $env:LOCALAPPDATA 'fusion-build'
    $exe = Join-Path $dir "node-$ver-win-x64\node.exe"
    if (Test-Path -LiteralPath $exe) { return $exe }
    Write-Host "Downloading Node.js $ver (one time, for the build only)..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $zip = Join-Path $dir "node-$ver-win-x64.zip"
    Invoke-WebRequest "https://nodejs.org/dist/$ver/node-$ver-win-x64.zip" -OutFile $zip -UseBasicParsing
    $sums = (Invoke-WebRequest "https://nodejs.org/dist/$ver/SHASUMS256.txt" -UseBasicParsing).Content
    $want = ($sums -split "`n" | Where-Object { $_ -match "node-$ver-win-x64\.zip$" }) -replace '\s.*$', ''
    if ((Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower() -ne $want.Trim().ToLower()) { Remove-Item $zip; throw 'Node.js download is damaged (checksum mismatch).' }
    Expand-Archive -Path $zip -DestinationPath $dir -Force
    Remove-Item $zip
    return $exe
}

# Cfx.re escrow encrypts Lua only, so the add-on's JavaScript (UI, server JS) is scrambled before packaging
function Protect-JavaScript($folder) {
    $tool = Join-Path $Root 'tools\js-protect'
    $node = Get-Node
    if (-not (Test-Path -LiteralPath (Join-Path $tool 'node_modules\javascript-obfuscator'))) {
        Write-Host 'Installing the JavaScript protection tool (one time)...'
        $npm = Join-Path (Split-Path -Parent $node) 'node_modules\npm\bin\npm-cli.js'
        Push-Location $tool
        try { & $node $npm ci --no-audit --no-fund | Out-Host; if ($LASTEXITCODE -ne 0) { throw 'npm ci failed' } } finally { Pop-Location }
    }
    & $node (Join-Path $tool 'protect.js') $folder | Select-Object -Last 1 | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'JavaScript protection failed - not packaging.' }
    Get-ChildItem -LiteralPath $folder -Recurse -Filter *.js | ForEach-Object {
        & $node --check $_.FullName
        if ($LASTEXITCODE -ne 0) { throw "Protected file does not parse: $($_.FullName)" }
    }
}
$src = Join-Path $Root "resources\[fusion-addons]\$Name"
if (-not (Test-Path -LiteralPath (Join-Path $src 'fxmanifest.lua'))) { $src = Join-Path $Root "resources\[addons]\$Name" }
if (-not (Test-Path -LiteralPath (Join-Path $src 'fxmanifest.lua'))) { throw "No add-on named $Name in resources\[fusion-addons] or resources\[addons]" }
# the add-on's own updater (for servers without Fusion Menu): always the master copy, so every add-on ships the same one
$updaterMaster = Join-Path $Root 'tools\addon-updater\fusion-updater.js'
if ((Test-Path -LiteralPath $updaterMaster) -and ((Get-Content -Raw -LiteralPath (Join-Path $src 'fxmanifest.lua')) -match 'server/fusion-updater\.js')) {
    Copy-Item -LiteralPath $updaterMaster -Destination (Join-Path $src 'server\fusion-updater.js') -Force
}
$manifest = Get-Content -Raw -LiteralPath (Join-Path $src 'fxmanifest.lua')
$version = if ($manifest -match "(?m)^version\s+'([^']+)'") { $Matches[1] } else { '1.0.0' }
$product = if ($Product) { $Product } else { (Get-Culture).TextInfo.ToTitleCase(($Name -replace '^fusion-', '')) -replace '[\s-]', '' }
$zipName = "Fusion$product-asset.zip"
$backupName = "Fusion$product-v$version-asset.zip"

$out = Join-Path $Root 'dist\addons'
$work = Join-Path $out '.build'
if (Test-Path -LiteralPath $work) { Remove-Item -Recurse -Force -LiteralPath $work }
New-Item -ItemType Directory -Force -Path (Join-Path $work $Name) | Out-Null
# the resource itself (its guide stays inside it too, so owners always have it)
robocopy $src (Join-Path $work $Name) /E /XD .git node_modules .fusion-update /XF *.log /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Copy failed (robocopy $LASTEXITCODE)" }
# .addonignore: files that stay on the owner's server (e.g. configs for trucks we don't own), one path per line;
# a line with * matches files in that folder (configs/*.json)
$ignore = Join-Path $src '.addonignore'
if (Test-Path -LiteralPath $ignore) {
    Get-Content -LiteralPath $ignore | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') } | ForEach-Object {
        $p = Join-Path (Join-Path $work $Name) $_.Trim()
        if ($p.Contains('*')) {
            Get-ChildItem -Path $p -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
        } elseif (Test-Path -LiteralPath $p) { Remove-Item -Recurse -Force -LiteralPath $p }
    }
    Remove-Item -Force -LiteralPath (Join-Path (Join-Path $work $Name) '.addonignore')
}
if (-not $NoProtect) { Protect-JavaScript (Join-Path $work $Name) }
# every install guide (HOW-TO-INSTALL.txt, and e.g. HOW-TO-INSTALL-STANDALONE.txt) also goes at the top of the zip
Get-ChildItem -LiteralPath $src -Filter 'HOW-TO-INSTALL*.txt' | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $work }
Copy-Item -LiteralPath (Join-Path $src 'README.md') -Destination (Join-Path $work 'GUIDE.md')
# a developer guide (DEVELOPER.md), when the add-on has one, also goes at the top
$dev = Join-Path $src 'DEVELOPER.md'
if (Test-Path -LiteralPath $dev) { Copy-Item -LiteralPath $dev -Destination (Join-Path $work 'DEVELOPER-GUIDE.md') }
Copy-Item -LiteralPath (Join-Path $Root 'LICENSE') -Destination $work

# nothing the portal refuses
$bad = Get-ChildItem -LiteralPath $work -Recurse -File | Where-Object { $_.Extension -match '^\.(pdf|zip|rar|7z|gz|tar)$' }
if ($bad) { throw "The portal refuses these files: $($bad.FullName -join ', ')" }

$zip = Join-Path $out $zipName
# Only the newest copy of each add-on stays in dist\addons: the zip this build replaces, older versions of the same
# add-on and their unpacked folders go to dist\addons\previous as backups (nothing is deleted)
$prevDir = Join-Path $out 'previous'
New-Item -ItemType Directory -Force -Path $prevDir | Out-Null
Get-ChildItem -LiteralPath $out -Force | Where-Object { $_.Name -like "Fusion$product-v*-asset*" -and $_.Name -ne '.build' } | ForEach-Object {
    $dest = Join-Path $prevDir $_.Name
    if (Test-Path -LiteralPath $dest) { Remove-Item -Recurse -Force -LiteralPath $dest }
    Move-Item -Force -LiteralPath $_.FullName -Destination $dest
}
# entries with forward slashes (Windows PowerShell's CreateFromDirectory writes backslashes, which Linux and the
# portal read as part of the file name), and never a license key
$leak = Get-ChildItem -LiteralPath $work -Recurse -File | Select-String -Pattern 'cfxk_[A-Za-z0-9]{6,}' -List
if ($leak) { throw "Refusing to package a license key: $($leak.Path -join ', ')" }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
# the last build's upload zip (its versioned copy is already in previous)
if (Test-Path -LiteralPath $zip) { Remove-Item -Force -LiteralPath $zip }
$archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
try {
    $base = (Resolve-Path -LiteralPath $work).Path.TrimEnd('\') + '\'
    Get-ChildItem -LiteralPath $work -Recurse -File -Force | ForEach-Object {
        $entry = $_.FullName.Substring($base.Length).Replace('\', '/')
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $entry, [IO.Compression.CompressionLevel]::Optimal)
    }
} finally { $archive.Dispose() }
Copy-Item -Force -LiteralPath $zip -Destination (Join-Path $prevDir $backupName)
Remove-Item -Recurse -Force -LiteralPath $work
Write-Host ("Built {0} ({1:N1} KB)" -f $zip, ((Get-Item -LiteralPath $zip).Length / 1KB)) -ForegroundColor Green
Write-Host "Version $version. Upload $zipName to the Cfx.re portal under the same asset as before (same name), so it updates that asset."
Write-Host "Backup with the version in its name: dist\addons\previous\$backupName"
