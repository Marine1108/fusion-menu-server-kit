# Fusion Menu - one-click Windows setup.
# FusionMenu-Setup.bat runs this straight from GitHub. It downloads the free server kit into a folder,
# finds the Fusion Menu zip you downloaded from portal.cfx.re and unpacks it, then starts the installer.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$KitZip = 'https://github.com/Marine1108/fusion-menu-server-kit/archive/refs/heads/main.zip'

function Ask($question, $default) {
    $q = if ($default) { "$question [$default]" } else { $question }
    $a = Read-Host $q
    if ([string]::IsNullOrWhiteSpace($a)) { return $default }
    return $a.Trim().Trim('"')
}

Clear-Host
Write-Host ''
Write-Host '  FUSION MENU - SERVER SETUP' -ForegroundColor Magenta
Write-Host '  This downloads everything your server needs and sets it up.' -ForegroundColor Gray
Write-Host ''

$dir = Ask 'Where should the server go?' 'C:\FusionServer'
if ((Test-Path -LiteralPath $dir) -and (Get-ChildItem -LiteralPath $dir -Force | Select-Object -First 1)) {
    if (Test-Path -LiteralPath (Join-Path $dir 'install\install.ps1')) {
        Write-Host 'Fusion Menu is already here - the kit files are refreshed, your server.cfg and resources are kept.' -ForegroundColor Yellow
    } else {
        Write-Host "$dir is not empty. Files with the same names are replaced." -ForegroundColor Yellow
    }
}
New-Item -ItemType Directory -Force -Path $dir | Out-Null

# ---------------------------------------------------------------- Server kit
Write-Host 'Downloading the Fusion Menu server kit...'
$zip = Join-Path $env:TEMP 'fusion-menu-server-kit.zip'
$tmp = Join-Path $env:TEMP 'fusion-menu-server-kit'
Invoke-WebRequest -Uri $KitZip -OutFile $zip -UseBasicParsing
if (Test-Path -LiteralPath $tmp) { Remove-Item -Recurse -Force $tmp }
Expand-Archive -Path $zip -DestinationPath $tmp -Force
$src = Get-ChildItem -LiteralPath $tmp -Directory | Select-Object -First 1
$keep = @('server.cfg')
Get-ChildItem -LiteralPath $src.FullName -Force | ForEach-Object {
    if ($keep -contains $_.Name -and (Test-Path -LiteralPath (Join-Path $dir $_.Name))) { return }
    Copy-Item -LiteralPath $_.FullName -Destination $dir -Recurse -Force
}
Remove-Item -Recurse -Force $tmp, $zip
Write-Host "Server kit is in $dir" -ForegroundColor Green

# ---------------------------------------------------------------- Fusion Menu itself
& (Join-Path $dir 'install\add-fusion.ps1') -Root $dir

# ---------------------------------------------------------------- Installer
& (Join-Path $dir 'install\install.ps1')
