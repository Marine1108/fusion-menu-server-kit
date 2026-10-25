# Packages a Fusion add-on (sold separately) as its own zip in dist\addons\:
#   powershell -ExecutionPolicy Bypass -File install\build-addon.ps1 [-Name fusion-builder]
#
#   FusionBuilder-v<ver>-asset.zip   Upload to the Cfx.re portal as its OWN asset (not a version of Fusion Menu).
#                                    Buyers get it from their keymaster. Holds the resource folder, HOW-TO-INSTALL.txt
#                                    and the guide (README.md). No PDFs or other archives: the portal refuses them.
#
# The add-on's source lives in resources\[fusion-addons]\<name>, so the Fusion Menu build never includes it.
param([string]$Name = 'fusion-builder')
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $Root "resources\[fusion-addons]\$Name"
if (-not (Test-Path -LiteralPath (Join-Path $src 'fxmanifest.lua'))) { throw "No add-on at $src" }
$manifest = Get-Content -Raw -LiteralPath (Join-Path $src 'fxmanifest.lua')
$version = if ($manifest -match "(?m)^version\s+'([^']+)'") { $Matches[1] } else { '1.0.0' }
$product = (Get-Culture).TextInfo.ToTitleCase(($Name -replace '^fusion-', '')) -replace '\s', ''
$zipName = "Fusion$product-v$version-asset.zip"

$out = Join-Path $Root 'dist\addons'
$work = Join-Path $out '.build'
if (Test-Path -LiteralPath $work) { Remove-Item -Recurse -Force -LiteralPath $work }
New-Item -ItemType Directory -Force -Path (Join-Path $work $Name) | Out-Null
# the resource itself (its guide stays inside it too, so owners always have it)
robocopy $src (Join-Path $work $Name) /E /XD .git node_modules /XF *.log /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Copy failed (robocopy $LASTEXITCODE)" }
Copy-Item -LiteralPath (Join-Path $src 'HOW-TO-INSTALL.txt') -Destination $work
Copy-Item -LiteralPath (Join-Path $src 'README.md') -Destination (Join-Path $work 'GUIDE.md')
Copy-Item -LiteralPath (Join-Path $Root 'LICENSE') -Destination $work

# nothing the portal refuses
$bad = Get-ChildItem -LiteralPath $work -Recurse -File | Where-Object { $_.Extension -match '^\.(pdf|zip|rar|7z|gz|tar)$' }
if ($bad) { throw "The portal refuses these files: $($bad.FullName -join ', ')" }

$zip = Join-Path $out $zipName
if (Test-Path -LiteralPath $zip) {
    New-Item -ItemType Directory -Force -Path (Join-Path $out 'previous') | Out-Null
    Move-Item -Force -LiteralPath $zip -Destination (Join-Path $out "previous\$zipName")
}
# entries with forward slashes (Windows PowerShell's CreateFromDirectory writes backslashes, which Linux and the
# portal read as part of the file name), and never a license key
$leak = Get-ChildItem -LiteralPath $work -Recurse -File | Select-String -Pattern 'cfxk_[A-Za-z0-9]{6,}' -List
if ($leak) { throw "Refusing to package a license key: $($leak.Path -join ', ')" }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
try {
    $base = (Resolve-Path -LiteralPath $work).Path.TrimEnd('\') + '\'
    Get-ChildItem -LiteralPath $work -Recurse -File -Force | ForEach-Object {
        $entry = $_.FullName.Substring($base.Length).Replace('\', '/')
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $entry, [IO.Compression.CompressionLevel]::Optimal)
    }
} finally { $archive.Dispose() }
Remove-Item -Recurse -Force -LiteralPath $work
Write-Host ("Built {0} ({1:N1} KB)" -f $zip, ((Get-Item -LiteralPath $zip).Length / 1KB)) -ForegroundColor Green
Write-Host 'Upload it to the Cfx.re portal as a NEW asset (e.g. "Fusion Interior Builder"), not as a version of Fusion Menu.'
