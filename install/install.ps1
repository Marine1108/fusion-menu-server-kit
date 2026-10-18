# Fusion Menu - Windows installer
# Run through install-windows.bat (double-click). It sets up everything a server needs on this PC:
#   * a database that runs in the background and starts with Windows (installs MariaDB for you, or
#     turns XAMPP's MySQL into a Windows service, or uses one you already have)
#   * server.cfg (license key, name, players, port, owner)
#   * the FiveM server program (FXServer), a firewall rule, and start shortcuts

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # downloads are much faster without the progress bar
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Root = Split-Path -Parent $PSScriptRoot
$Template = Join-Path $PSScriptRoot 'server.cfg.template'
$ConfigPath = Join-Path $Root 'server.cfg'
$LoginFile = Join-Path $Root 'database-login.txt'

function Title($text) {
    Write-Host ''
    Write-Host "== $text ==" -ForegroundColor Cyan
}

function Ask($question, $default) {
    if ($default -ne $null -and $default -ne '') { $q = "$question [$default]" } else { $q = $question }
    $answer = Read-Host $q
    if ([string]::IsNullOrWhiteSpace($answer)) { return $default }
    return $answer.Trim()
}

function AskYesNo($question, $defaultYes) {
    $hint = if ($defaultYes) { 'Y/n' } else { 'y/N' }
    $answer = Read-Host "$question ($hint)"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $defaultYes }
    return $answer.Trim().ToLower().StartsWith('y')
}

function AskSecret($question) {
    $secure = Read-Host $question -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function AskChoice($question, $options, $default) {
    for ($i = 0; $i -lt $options.Count; $i++) { Write-Host ("  {0}) {1}" -f ($i + 1), $options[$i]) }
    while ($true) {
        $a = Ask $question "$default"
        $n = 0
        if ([int]::TryParse($a, [ref]$n) -and $n -ge 1 -and $n -le $options.Count) { return $n }
        Write-Host "Type a number from 1 to $($options.Count)." -ForegroundColor Yellow
    }
}

function New-Password($length) {
    $chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    $bytes = New-Object byte[] $length
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

function Test-Admin {
    $id = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $id.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-PortListening($port) {
    try { return [bool](Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction Stop) } catch { return $false }
}

function Find-MySqlClient {
    $candidates = @()
    foreach ($drive in (Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root })) { $candidates += Join-Path $drive 'xampp\mysql\bin\mysql.exe' }
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ($base -and (Test-Path -LiteralPath $base)) {
            Get-ChildItem -Path $base -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like 'MySQL*' -or $_.Name -like 'MariaDB*' } |
                ForEach-Object {
                    Get-ChildItem -Path $_.FullName -Recurse -Filter 'mysql.exe' -ErrorAction SilentlyContinue |
                        ForEach-Object { $candidates = @($_.FullName) + $candidates }
                }
        }
    }
    foreach ($cmd in @('mysql', 'mariadb')) {
        $found = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($found) { $candidates += $found.Source }
    }
    foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
    return $null
}

function Find-Xampp {
    foreach ($drive in (Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root })) {
        $dir = Join-Path $drive 'xampp'
        if (Test-Path -LiteralPath (Join-Path $dir 'mysql\bin\mysqld.exe')) { return $dir }
    }
    return $null
}

function Invoke-MySql($client, $dbHost, $port, $user, $password, $sql) {
    $env:MYSQL_PWD = $password
    try {
        $output = & $client "--host=$dbHost" "--port=$port" "--user=$user" '-e' $sql 2>&1
        return @{ ok = ($LASTEXITCODE -eq 0); output = ($output | Out-String) }
    } finally {
        Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue
    }
}

# Creates the database and a "fusion" login that can only use it. Falls back to the admin login.
function New-FusionDatabase($client, $dbHost, $port, $adminUser, $adminPass, $dbName) {
    $create = Invoke-MySql $client $dbHost $port $adminUser $adminPass "CREATE DATABASE IF NOT EXISTS ``$dbName`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    if (-not $create.ok) { throw "Could not create the database: $($create.output)" }
    $pass = New-Password 20
    $sql = "CREATE USER IF NOT EXISTS 'fusion'@'localhost' IDENTIFIED BY '$pass'; ALTER USER 'fusion'@'localhost' IDENTIFIED BY '$pass'; " +
           "CREATE USER IF NOT EXISTS 'fusion'@'127.0.0.1' IDENTIFIED BY '$pass'; ALTER USER 'fusion'@'127.0.0.1' IDENTIFIED BY '$pass'; " +
           "GRANT ALL PRIVILEGES ON ``$dbName``.* TO 'fusion'@'localhost'; GRANT ALL PRIVILEGES ON ``$dbName``.* TO 'fusion'@'127.0.0.1'; FLUSH PRIVILEGES;"
    $user = Invoke-MySql $client $dbHost $port $adminUser $adminPass $sql
    Write-Host "Database '$dbName' is ready. Fusion creates its tables on the first start." -ForegroundColor Green
    if ($user.ok) { return @{ user = 'fusion'; pass = $pass } }
    Write-Host 'Could not create a separate database login, so the admin login is used.' -ForegroundColor Yellow
    return @{ user = $adminUser; pass = $adminPass }
}

function Install-MariaDB($port) {
    Write-Host 'Looking up the newest MariaDB 11.4 (long-term support)...'
    $api = Invoke-RestMethod 'https://downloads.mariadb.org/rest-api/mariadb/11.4/'
    $release = $api.releases.PSObject.Properties | Select-Object -First 1
    $msi = $release.Value.files | Where-Object { $_.file_name -like '*winx64.msi' } | Select-Object -First 1
    if (-not $msi) { throw 'MariaDB did not list a Windows installer.' }
    $url = $msi.file_download_url -replace '^http://', 'https://'
    $file = Join-Path $env:TEMP $msi.file_name
    Write-Host "Downloading $($msi.file_name) (about 70 MB)..."
    Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
    $hash = (Get-FileHash -Algorithm SHA256 -Path $file).Hash.ToLower()
    if ($msi.checksum.sha256sum -and $hash -ne $msi.checksum.sha256sum.ToLower()) {
        Remove-Item $file -Force
        throw 'The MariaDB download is damaged (checksum does not match). Run the installer again.'
    }
    $rootPass = New-Password 20
    Write-Host 'Installing MariaDB (this takes a minute)...'
    $log = Join-Path $env:TEMP 'fusion-mariadb-install.log'
    $msiArgs = @('/i', "`"$file`"", 'SERVICENAME=FusionMariaDB', "PORT=$port", "PASSWORD=$rootPass", 'UTF8=1', '/qn', '/norestart', '/l*v', "`"$log`"")
    $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru
    if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) { throw "MariaDB setup failed (code $($p.ExitCode)). Details: $log" }
    Remove-Item $file -Force -ErrorAction SilentlyContinue
    Set-Service -Name 'FusionMariaDB' -StartupType Automatic
    Start-Service -Name 'FusionMariaDB' -ErrorAction SilentlyContinue
    $client = Get-ChildItem -Path $env:ProgramFiles -Directory -Filter 'MariaDB*' | Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName 'bin\mysql.exe' } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $client) { throw 'MariaDB was installed but its mysql.exe was not found.' }
    Write-Host 'MariaDB is installed as the Windows service "FusionMariaDB" and starts with Windows.' -ForegroundColor Green
    return @{ client = $client; rootPass = $rootPass }
}

function Set-XamppService($xampp) {
    $mysqld = Join-Path $xampp 'mysql\bin\mysqld.exe'
    $ini = Join-Path $xampp 'mysql\bin\my.ini'
    $existing = Get-CimInstance Win32_Service | Where-Object { $_.PathName -and $_.PathName -like "*$mysqld*" } | Select-Object -First 1
    if ($existing) {
        $name = $existing.Name
        Write-Host "XAMPP's MySQL is already the Windows service '$name'." -ForegroundColor Green
    } else {
        $running = Get-Process -Name 'mysqld' -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $mysqld }
        if ($running) {
            Write-Host "Stopping XAMPP's MySQL so Windows can run it instead..."
            $running | Stop-Process -Force
            Start-Sleep -Seconds 3
        }
        $name = 'FusionMySQL'
        & $mysqld --install $name "--defaults-file=$ini" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not register XAMPP's MySQL as a Windows service." }
    }
    Set-Service -Name $name -StartupType Automatic
    Start-Service -Name $name -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Write-Host "XAMPP's MySQL now runs as the Windows service '$name' and starts with Windows - no need to open XAMPP." -ForegroundColor Green
    Write-Host '(In the XAMPP Control Panel it shows as a service; leave it running.)'
    return (Join-Path $xampp 'mysql\bin\mysql.exe')
}

function Get-FXServer($dir) {
    Write-Host 'Looking up the recommended FiveM server build...'
    $v = Invoke-RestMethod 'https://changelogs-live.fivem.net/api/changelog/versions/win32/server'
    $zip = Join-Path $env:TEMP "fxserver-$($v.recommended).zip"
    Write-Host "Downloading FXServer build $($v.recommended)..."
    Invoke-WebRequest -Uri $v.recommended_download -OutFile $zip -UseBasicParsing
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Expand-Archive -Path $zip -DestinationPath $dir -Force
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Write-Host "FXServer $($v.recommended) is in $dir" -ForegroundColor Green
    return (Join-Path $dir 'FXServer.exe')
}

function New-Shortcut($path, $target, $arguments, $workdir) {
    $ws = New-Object -ComObject WScript.Shell
    $s = $ws.CreateShortcut($path)
    $s.TargetPath = $target
    if ($arguments) { $s.Arguments = $arguments }
    $s.WorkingDirectory = $workdir
    $s.Save()
}

# ================================================================= Start
Clear-Host
Write-Host '  ______         _               __  __                 ' -ForegroundColor Magenta
Write-Host ' |  ____|       (_)             |  \/  |                ' -ForegroundColor Magenta
Write-Host ' | |__ _   _ ___ _  ___  _ __   | \  / | ___ _ __  _   _ ' -ForegroundColor Magenta
Write-Host ' |  __| | | / __| |/ _ \| ''_ \  | |\/| |/ _ \ ''_ \| | | |' -ForegroundColor Magenta
Write-Host ' | |  | |_| \__ \ | (_) | | | | | |  | |  __/ | | | |_| |' -ForegroundColor Magenta
Write-Host ' |_|   \__,_|___/_|\___/|_| |_| |_|  |_|\___|_| |_|\__,_|' -ForegroundColor Magenta
Write-Host ''
Write-Host 'This sets up everything your server needs. Press Enter to accept the [default] answer.'

if (-not (Test-Path -LiteralPath $Template)) {
    Write-Host "Missing $Template - is the download complete?" -ForegroundColor Red
    exit 1
}
$admin = Test-Admin
if (-not $admin) {
    Write-Host 'Not running as administrator: the database service, firewall and auto-start steps are skipped.' -ForegroundColor Yellow
    Write-Host 'Close this window and double-click install-windows.bat again (click Yes when Windows asks) for the full setup.' -ForegroundColor Yellow
}

# ---------------------------------------------------------------- Fusion files
& (Join-Path $PSScriptRoot 'add-fusion.ps1') -Root $Root

# ---------------------------------------------------------------- Database
Title 'Database'
$xampp = Find-Xampp
$dbService = Get-Service -ErrorAction SilentlyContinue | Where-Object { ($_.Name -match 'mysql|mariadb') -and $_.Status -eq 'Running' } | Select-Object -First 1
$options = @('Install a database for me (recommended - runs in the background and starts with Windows)')
$map = @('install')
if ($xampp) { $options += "Use XAMPP's MySQL ($xampp) and make it start with Windows"; $map += 'xampp' }
$options += 'I already have a MySQL / MariaDB server (I know its login)'; $map += 'existing'
$default = 1
if ($dbService) { $default = $map.IndexOf('existing') + 1; Write-Host "A database service is already running: $($dbService.DisplayName)" -ForegroundColor Green }
elseif ($xampp) { $default = 2 }
if (-not $admin) { Write-Host 'Options 1 and 2 need administrator rights.' -ForegroundColor Yellow }
$choice = $map[(AskChoice 'Choose' $options $default) - 1]
if (-not $admin -and $choice -ne 'existing') { Write-Host 'That needs administrator rights - using an existing database instead.' -ForegroundColor Yellow; $choice = 'existing' }

$dbName = 'fusion'
$dbHost = '127.0.0.1'
$dbPort = 3306
$login = $null
$loginNote = @()

if ($choice -eq 'install') {
    try {
        if (Test-PortListening 3306) {
            $dbPort = 3307
            Write-Host 'Something already uses port 3306 (another database?), so MariaDB will use port 3307.' -ForegroundColor Yellow
        }
        $mdb = Install-MariaDB $dbPort
        $login = New-FusionDatabase $mdb.client $dbHost $dbPort 'root' $mdb.rootPass $dbName
        $loginNote += "MariaDB (Windows service FusionMariaDB, port $dbPort)"
        $loginNote += "  admin login: root / $($mdb.rootPass)"
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host 'Falling back to an existing database.' -ForegroundColor Yellow
        $choice = 'existing'
    }
}
if ($choice -eq 'xampp') {
    try {
        $client = Set-XamppService $xampp
        $dbPort = 3306
        $login = New-FusionDatabase $client $dbHost $dbPort 'root' '' $dbName
        $loginNote += "XAMPP MySQL (Windows service, port $dbPort)"
        $loginNote += '  admin login: root / (no password - XAMPP default)'
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host 'Falling back to an existing database.' -ForegroundColor Yellow
        $choice = 'existing'
    }
}
if ($choice -eq 'existing') {
    $client = Find-MySqlClient
    if ($client) { Write-Host "Found MySQL client: $client" -ForegroundColor Green }
    else { Write-Host 'No MySQL client found. The database must already exist (create it in phpMyAdmin or HeidiSQL).' -ForegroundColor Yellow }
    while ($true) {
        $dbHost = Ask 'Database host' '127.0.0.1'
        $dbPort = Ask 'Database port' '3306'
        $dbUser = Ask 'Database user' 'root'
        $dbPass = AskSecret 'Database password (XAMPP default: leave empty)'
        $dbName = Ask 'Database name' 'fusion'
        if ($dbName -notmatch '^[A-Za-z0-9_]+$') { Write-Host 'Use letters, numbers and _ only.' -ForegroundColor Red; continue }
        $login = @{ user = $dbUser; pass = $dbPass }
        if (-not $client) { break }
        $test = Invoke-MySql $client $dbHost $dbPort $dbUser $dbPass 'SELECT 1;'
        if (-not $test.ok) {
            Write-Host 'Could not connect:' -ForegroundColor Red
            Write-Host $test.output
            Write-Host 'Check that the database is running and the user/password are right.' -ForegroundColor Yellow
            if (AskYesNo 'Try again?' $true) { continue }
            break
        }
        try { $login = New-FusionDatabase $client $dbHost $dbPort $dbUser $dbPass $dbName } catch { Write-Host $_.Exception.Message -ForegroundColor Red }
        break
    }
}

$userPart = [uri]::EscapeDataString($login.user)
if ($login.pass) { $userPart += ':' + [uri]::EscapeDataString($login.pass) }
$connection = "mysql://$userPart@${dbHost}:$dbPort/$($dbName)?charset=utf8mb4"
if ($loginNote.Count -gt 0) {
    $text = @('FUSION MENU - DATABASE LOGINS (keep this file private)', '', $loginNote, '', "Fusion's login: $($login.user) / $($login.pass)  (database '$dbName')",
              '', 'You only need these for tools like HeidiSQL. The server already has them in server.cfg.') | ForEach-Object { $_ }
    [IO.File]::WriteAllLines($LoginFile, [string[]]$text)
    Write-Host "Database logins saved to $LoginFile" -ForegroundColor Green
}

# ---------------------------------------------------------------- Server
Title 'Server'
Write-Host 'Get a free license key at https://portal.cfx.re (Server Registration Keys).'
while ($true) {
    $license = Ask 'License key (cfxk_...)' ''
    if ($license -and $license.StartsWith('cfxk_')) { break }
    if (AskYesNo 'That does not look like a license key (cfxk_...). Use it anyway?' $false) { break }
}
$serverName = Ask 'Server name' 'Fusion Menu Server'
$serverName = $serverName -replace '"', "'"
$maxPlayers = Ask 'Max players' '48'
$port = Ask 'Port' '30120'

# ---------------------------------------------------------------- Owner
Title 'Owner'
Write-Host 'Your identifier makes you Owner right away, e.g. fivem:1234567 or license:abc123...'
Write-Host 'Leave empty to claim ownership in game instead (the console shows a /claimowner code).'
$owner = Ask 'Owner identifier' ''
$principals = ''
if ($owner) {
    if ($owner -notmatch '^\w+:') { Write-Host 'That is not a valid identifier - skipping. Use /claimowner in game instead.' -ForegroundColor Yellow }
    else { $principals = "add_principal identifier.$owner group.admin" }
}

# ---------------------------------------------------------------- Write server.cfg
$cfg = Get-Content -Raw -LiteralPath $Template
$endpoints = "endpoint_add_tcp `"0.0.0.0:$port`"`r`nendpoint_add_udp `"0.0.0.0:$port`""
$cfg = $cfg.Replace('{{serverEndpoints}}', $endpoints)
$cfg = $cfg.Replace('{{maxClients}}', $maxPlayers)
$cfg = $cfg.Replace('{{svLicense}}', $license)
$cfg = $cfg.Replace('{{serverName}}', $serverName)
$cfg = $cfg.Replace('{{dbConnectionString}}', $connection)
$cfg = $cfg.Replace('{{addPrincipalsMaster}}', $principals)
if (Test-Path -LiteralPath $ConfigPath) {
    $backup = "$ConfigPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $ConfigPath -Destination $backup
    Write-Host "Existing server.cfg backed up to $backup" -ForegroundColor Yellow
}
[IO.File]::WriteAllText($ConfigPath, $cfg, (New-Object Text.UTF8Encoding $false))
Write-Host 'server.cfg written.' -ForegroundColor Green

# ---------------------------------------------------------------- FXServer
Title 'FiveM server program (FXServer)'
$fxDir = 'C:\FXServer'
$fx = Join-Path $fxDir 'FXServer.exe'
if (Test-Path -LiteralPath $fx) {
    Write-Host "Found $fx" -ForegroundColor Green
    if (AskYesNo 'Update it to the recommended build?' $false) { try { $fx = Get-FXServer $fxDir } catch { Write-Host $_.Exception.Message -ForegroundColor Red } }
} elseif (AskYesNo "Download FXServer to $fxDir for you?" $true) {
    try { $fx = Get-FXServer $fxDir } catch { Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red }
} else {
    $fx = Ask 'Full path to your FXServer.exe' $fx
}

# ---------------------------------------------------------------- Start shortcuts
Title 'Starting the server'
$startBat = Join-Path $Root 'Start Fusion Server.bat'
$bat = "@echo off`r`ntitle Fusion Menu server`r`ncd /d `"%~dp0`"`r`n`"$fx`" +set onesync on +exec server.cfg`r`necho.`r`necho The server stopped. Press any key to close.`r`npause >nul`r`n"
[IO.File]::WriteAllText($startBat, $bat, (New-Object Text.ASCIIEncoding))
$txBat = Join-Path $Root 'Start txAdmin.bat'
$tx = "@echo off`r`ntitle txAdmin`r`ncd /d `"%~dp0`"`r`nstart `"`" http://localhost:40120`r`n`"$fx`" +set txDataPath `"%~dp0txData`"`r`npause`r`n"
[IO.File]::WriteAllText($txBat, $tx, (New-Object Text.ASCIIEncoding))
$desktop = [Environment]::GetFolderPath('Desktop')
try {
    New-Shortcut (Join-Path $desktop 'Start Fusion Server.lnk') $startBat '' $Root
    New-Shortcut (Join-Path $desktop 'Fusion txAdmin.lnk') $txBat '' $Root
    Write-Host 'Desktop shortcuts: "Start Fusion Server" and "Fusion txAdmin".' -ForegroundColor Green
} catch { Write-Host "Could not create desktop shortcuts: $($_.Exception.Message)" -ForegroundColor Yellow }

if ($admin) {
    if (AskYesNo "Open port $port in the Windows firewall so players can join?" $true) {
        foreach ($proto in 'TCP', 'UDP') {
            $name = "Fusion Menu $proto $port"
            Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue | Remove-NetFirewallRule
            New-NetFirewallRule -DisplayName $name -Direction Inbound -Protocol $proto -LocalPort $port -Action Allow | Out-Null
        }
        Write-Host "Firewall: port $port (TCP and UDP) is open. If players outside your home can't join, forward port $port on your router too." -ForegroundColor Green
    }
    if (AskYesNo 'Start the server automatically when you log in to Windows?' $false) {
        $action = New-ScheduledTaskAction -Execute $startBat -WorkingDirectory $Root
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
        Register-ScheduledTask -TaskName 'Fusion Menu server' -Action $action -Trigger $trigger -RunLevel Highest -Force | Out-Null
        Write-Host 'The server starts when you log in (Task Scheduler: "Fusion Menu server").' -ForegroundColor Green
    }
}

# ---------------------------------------------------------------- Done
Title 'Done'
Write-Host 'Your server is set up.' -ForegroundColor Green
Write-Host '  * "Start Fusion Server" (desktop) starts it straight away in a console window.'
Write-Host '  * "Fusion txAdmin" opens the txAdmin web panel instead. The first time: enter the PIN from the window,'
Write-Host '    sign in with Cfx.re, choose "Existing Server Data", pick this folder and server.cfg, turn OneSync on.'
Write-Host "    Folder: $Root" -ForegroundColor White
Write-Host 'Join with F8 > connect localhost, then press F10 for the admin panel.'
if (-not $principals) { Write-Host 'Watch the server console for your /claimowner code.' -ForegroundColor Yellow }
Write-Host 'Full guide: README.md'
if (AskYesNo 'Start the server now?' $true) { Start-Process -FilePath $startBat -WorkingDirectory $Root }
