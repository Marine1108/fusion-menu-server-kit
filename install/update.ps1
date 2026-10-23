# Fusion Menu updater / script installer (Windows). Used by update-fusion.bat and install-script.bat.
#
#   -Mode fusion  [-Source <zip|folder>]   Update the framework in resources\[fusion]
#   -Mode script  -Source <zip|folder>     Install or upgrade QBCore scripts, vehicles, EUP, maps
#
# Nothing you changed is lost. Every install writes .fusion-install.sha256 into the resource folder
# (a fingerprint of each file it installed). On the next update:
#   - files still matching their fingerprint are replaced with the new version
#   - files you edited (configs, pictures, media...) are kept; the new version is saved next to them as <file>.new
#   - files the new version no longer has are removed, unless you edited them
#   - files you added yourself are never touched
# The whole resource folder is backed up to backups\<date>\ first (and the database, for Fusion updates).

param(
    [ValidateSet('fusion', 'script')][string]$Mode = 'script',
    [string]$Source,
    [string]$Target = 'auto',  # auto | qb | addons | a sub-folder such as "[addons]/[cars]"
    [switch]$Force,          # allow downgrades and scripts Fusion replaces
    [switch]$IgnoreRunning,  # skip the 'server is running' check
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Resources = Join-Path $Root 'resources'
$FusionDir = Join-Path $Resources '[fusion]'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupDir = Join-Path $Root "backups\$Stamp"
$RecordName = '.fusion-install.sha256'
$Log = New-Object System.Collections.Generic.List[string]

$TextExt = @('.lua', '.js', '.json', '.cfg', '.html', '.htm', '.css', '.txt', '.md', '.yaml', '.yml', '.xml', '.meta', '.sql', '.ts', '.ini')
# Resources Fusion replaces: installing them breaks things (see README section 9)
$Replaced = @('qb-core', 'qb-inventory', 'qb-target', 'qb-menu', 'qb-input', 'progressbar', 'qb-multicharacter', 'qb-spawn',
    'qb-garages', 'qb-shops', 'qb-clothing', 'illenium-appearance', 'qb-vehiclekeys', 'qb-weathersync', 'qb-ambulancejob',
    'qb-prison', 'qb-management', 'qb-banking', 'LegacyFuel', 'qb-hud')

function Say($msg, $color = 'Gray') { Write-Host $msg -ForegroundColor $color; $Log.Add($msg) }
function Fail($msg) { Write-Host ''; Write-Host $msg -ForegroundColor Red; exit 1 }
function Confirm($question) {
    if ($Yes) { return $true }
    $a = Read-Host "$question [Y/n]"
    return ($a -eq '' -or $a -match '^[Yy]')
}

$sha = [Security.Cryptography.SHA256]::Create()
function Get-Sha($path) {
    $s = [IO.File]::OpenRead($path)
    try { return ([BitConverter]::ToString($sha.ComputeHash($s)) -replace '-', '').ToLower() } finally { $s.Dispose() }
}

function Get-Files($dir) {
    $base = $dir.TrimEnd('\') + '\'
    $map = @{}
    foreach ($f in [IO.Directory]::EnumerateFiles($dir, '*', 'AllDirectories')) {
        $rel = $f.Substring($base.Length).Replace('\', '/')
        if ($rel -ne $RecordName) { $map[$rel] = $f }
    }
    return $map
}

function Read-Record($dir) {
    $file = Join-Path $dir $RecordName
    if (-not [IO.File]::Exists($file)) { return $null }
    $map = @{}
    foreach ($line in [IO.File]::ReadAllLines($file)) {
        if ($line -match '^([0-9a-f]{64})  (.+)$') { $map[$Matches[2]] = $Matches[1] }
    }
    return $map
}

function Write-Record($dir, $map) {
    $lines = $map.Keys | Sort-Object | ForEach-Object { "$($map[$_])  $_" }
    [IO.File]::WriteAllLines((Join-Path $dir $RecordName), [string[]]$lines)
}

# Files kept as yours on the first update (before any fingerprint exists)
function Test-Protected($rel) {
    if ($Mode -eq 'fusion') { return $rel -match '^html/(img|images|media|sounds)/' -or $rel -match '^tiles/' -or $rel -match '^data/(labels|edited-postals)\.json$' }
    return ($rel -match '(^|/)config[^/]*\.lua$' -or $rel -match '(^|/)(config|configs|locales|locale|lang)/' -or
            $rel -match '\.cfg$' -or $rel -match '(^|/)settings\.lua$')
}

function Copy-File($from, $to) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($to))
    [IO.File]::Copy($from, $to, $true)
}

function Backup-Folder($dir, $name) {
    $dest = Join-Path $BackupDir $name
    robocopy $dir $dest /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { Fail "Backup of $name failed (robocopy code $LASTEXITCODE). Nothing was changed." }
}

# Three-way merge of one resource. Returns $true if anything needs your attention.
function Merge-Resource($pkgDir, $destDir, $name) {
    $new = Get-Files $pkgDir
    $exists = [IO.Directory]::Exists($destDir)
    $recorded = if ($exists) { Read-Record $destDir } else { $null }
    if ($exists) { Backup-Folder $destDir $name } else { [void][IO.Directory]::CreateDirectory($destDir) }

    $s = @{ added = 0; updated = 0; same = 0; removed = 0 }
    $kept = @(); $leftover = @()
    $record = @{}
    foreach ($rel in $new.Keys) {
        $src = $new[$rel]
        $dst = Join-Path $destDir ($rel.Replace('/', '\'))
        $newHash = Get-Sha $src
        $record[$rel] = $newHash
        if (-not [IO.File]::Exists($dst)) { Copy-File $src $dst; $s.added++; continue }
        $cur = Get-Sha $dst
        if ($cur -eq $newHash) { $s.same++; continue }
        # the update doesn't change this file: whatever is there (yours or ours) stays, nothing to compare
        if ($recorded -and $recorded.ContainsKey($rel) -and $recorded[$rel] -eq $newHash) { $s.same++; continue }
        $untouched = $recorded -and $recorded.ContainsKey($rel) -and $recorded[$rel] -eq $cur
        $yours = ($recorded -and -not $untouched) -or (-not $recorded -and (Test-Protected $rel))
        if (-not $yours) { Copy-File $src $dst; $s.updated++; continue }
        # yours: keep it, put the new version next to it (text files only)
        if ($TextExt -contains [IO.Path]::GetExtension($rel).ToLower()) { Copy-File $src ($dst + '.new'); $kept += "$rel  (new version saved as $([IO.Path]::GetFileName($rel)).new)" }
        else { $kept += $rel }
    }
    if ($recorded) {
        foreach ($rel in $recorded.Keys) {
            if ($new.ContainsKey($rel)) { continue }
            $dst = Join-Path $destDir ($rel.Replace('/', '\'))
            if (-not [IO.File]::Exists($dst)) { continue }
            if ((Get-Sha $dst) -eq $recorded[$rel]) { [IO.File]::Delete($dst); $s.removed++ } else { $leftover += $rel }
        }
    }
    Write-Record $destDir $record

    $verb = if ($exists) { 'Updated' } else { 'Installed' }
    Say ("  {0,-26} {1}: {2} new, {3} changed, {4} unchanged, {5} removed" -f $name, $verb, $s.added, $s.updated, $s.same, $s.removed) 'Green'
    foreach ($k in $kept) { Say "      kept your version: $k" 'Yellow' }
    foreach ($k in $leftover) { Say "      no longer used, kept because you edited it: $k" 'Yellow' }
    return ($kept.Count + $leftover.Count) -gt 0
}

# ------------------------------------------------------------------ Source
function Find-Package {
    if ($Source) { return $Source.Trim().Trim('"') }
    if ($Mode -eq 'fusion') {
        $updates = Join-Path $Root 'updates'
        [void][IO.Directory]::CreateDirectory($updates)
        $zip = Get-ChildItem -LiteralPath $updates -Filter *.zip -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($zip) { return $zip.FullName }
        Fail "Put the Fusion Menu zip you downloaded from your Cfx.re keymaster into:`n  $updates`nthen run update-fusion.bat again."
    }
    $p = Read-Host 'Drag the script zip or folder into this window and press Enter'
    return $p.Trim().Trim('"')
}

function Expand-Package($path) {
    if ([IO.Directory]::Exists($path)) { return $path }
    if (-not [IO.File]::Exists($path)) { Fail "Not found: $path" }
    if ([IO.Path]::GetExtension($path).ToLower() -ne '.zip') { Fail 'Only .zip files or folders are supported. Extract .rar / .7z files first, then drag in the folder.' }
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "fusion-update-$Stamp"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($path, $tmp)
    $script:Temp = $tmp
    return $tmp
}

# Resource roots = folders with an fxmanifest.lua / __resource.lua (not nested in another resource)
function Find-Resources($dir) {
    $roots = @()
    $manifests = [IO.Directory]::EnumerateFiles($dir, '*.lua', 'AllDirectories') | Where-Object { [IO.Path]::GetFileName($_) -in 'fxmanifest.lua', '__resource.lua' }
    foreach ($m in ($manifests | ForEach-Object { [IO.Path]::GetDirectoryName($_) } | Sort-Object -Unique | Sort-Object Length)) {
        if (-not ($roots | Where-Object { $m.StartsWith($_ + '\') })) { $roots += $m }
    }
    return $roots
}

function Get-Version($dir) {
    $m = Join-Path $dir 'fxmanifest.lua'
    if (-not [IO.File]::Exists($m)) { return $null }
    if ([IO.File]::ReadAllText($m) -match "(?m)^version\s+'([^']+)'") { return $Matches[1] }
    return $null
}

function Find-Existing($name, $under) {
    foreach ($d in [IO.Directory]::EnumerateDirectories($under, '*', 'AllDirectories')) {
        if ([IO.Path]::GetFileName($d) -eq $name -and ([IO.File]::Exists((Join-Path $d 'fxmanifest.lua')) -or [IO.File]::Exists((Join-Path $d '__resource.lua')))) { return $d }
    }
    return $null
}

# ------------------------------------------------------------------ Server must be stopped
if ((Get-Process -Name 'FXServer' -ErrorAction SilentlyContinue) -and -not $IgnoreRunning) {
    Fail 'The server is running. Stop it first (txAdmin > Stop server), then run this again.'
}

$pkgPath = Find-Package
$pkg = Expand-Package $pkgPath
$Temp = if ($script:Temp) { $script:Temp } else { $null }
try {
    $found = @(Find-Resources $pkg)
    if (-not $found.Count) { Fail "No resources found in $pkgPath (no fxmanifest.lua inside)." }
    $attention = $false

    if ($Mode -eq 'fusion') {
        # ---------------------------------------------------------- Fusion update
        $core = $found | Where-Object { [IO.Path]::GetFileName($_) -eq 'fusion-core' } | Select-Object -First 1
        if (-not $core) { Fail 'This is not a Fusion Menu package (fusion-core is missing).' }
        $newVer = Get-Version $core
        $installedCore = Find-Existing 'fusion-core' $FusionDir
        $oldVer = if ($installedCore) { Get-Version $installedCore } else { $null }
        Say ''
        Say "Fusion Menu update: $(if ($oldVer) { "v$oldVer" } else { 'not installed' }) -> v$newVer" 'Cyan'
        if ($oldVer -and $newVer -and ([version]$newVer -lt [version]$oldVer) -and -not $Force) {
            Fail "This package (v$newVer) is older than what you have (v$oldVer). Run with -Force to downgrade anyway."
        }
        Say "Backups go to backups\$Stamp"
        if (-not (Confirm 'Continue?')) { exit 0 }
        [void][IO.Directory]::CreateDirectory($BackupDir)

        # database backup
        $cfgPath = Join-Path $Root 'server.cfg'
        $cfg = if ([IO.File]::Exists($cfgPath)) { [IO.File]::ReadAllText($cfgPath) } else { '' }
        if ($cfg -match '(?m)^\s*set\s+mysql_connection_string\s+"([^"]+)"') {
            $cs = $Matches[1]; $db = @{}
            if ($cs -match '^mysql://(?<u>[^:@/]+)(:(?<p>[^@]*))?@(?<h>[^:/]+)(:(?<port>\d+))?/(?<d>[^?]+)') {
                $db = @{ user = $Matches.u; pass = $Matches.p; host = $Matches.h; port = $Matches.port; name = $Matches.d }
            } else {
                foreach ($part in $cs.Split(';')) {
                    $kv = $part.Split('=', 2)
                    if ($kv.Count -eq 2) {
                        switch -regex ($kv[0].Trim().ToLower()) {
                            '^(user|user id|uid|username)$' { $db.user = $kv[1] } '^(password|pwd)$' { $db.pass = $kv[1] }
                            '^(host|server)$' { $db.host = $kv[1] } '^port$' { $db.port = $kv[1] } '^(database|db)$' { $db.name = $kv[1] }
                        }
                    }
                }
            }
            $dump = (Get-Command mysqldump -ErrorAction SilentlyContinue).Source
            if (-not $dump -and [IO.File]::Exists('C:\xampp\mysql\bin\mysqldump.exe')) { $dump = 'C:\xampp\mysql\bin\mysqldump.exe' }
            if ($dump -and $db.name) {
                $dumpArgs = @("--user=$($db.user)", "--host=$(if ($db.host) { $db.host } else { 'localhost' })", "--port=$(if ($db.port) { $db.port } else { '3306' })", '--single-transaction', '--routines', "--result-file=$(Join-Path $BackupDir 'database.sql')")
                if ($db.pass) { $dumpArgs += "--password=$($db.pass)" }
                $dumpArgs += $db.name
                & $dump @args 2>$null
                if ($LASTEXITCODE -eq 0) { Say "  Database '$($db.name)' backed up to backups\$Stamp\database.sql" 'Green' }
                elseif (-not (Confirm '  Database backup failed (is MySQL running?). Continue without it?')) { exit 1 }
            } elseif (-not (Confirm '  mysqldump not found, so the database cannot be backed up. Continue without it?')) { exit 1 }
        }

        $newResources = @()
        foreach ($r in $found) {
            $name = [IO.Path]::GetFileName($r)
            $dest = Find-Existing $name $FusionDir
            if (-not $dest) {
                $dest = if ($name -like 'fusion-*') { Join-Path $FusionDir $name } else { Join-Path $FusionDir "[compat]\$name" }
                if ($name -like 'fusion-*') { $newResources += $name }
            }
            if (Merge-Resource $r $dest $name) { $attention = $true }
        }

        # every Fusion module needs an ensure line (new ones, and any an earlier install missed),
        # added in order after the last "ensure fusion-..." line
        $modules = @($found | ForEach-Object { [IO.Path]::GetFileName($_) } | Where-Object { $_ -like 'fusion-*' })
        if ($cfg -and $modules.Count -and $cfg -notmatch '(?m)^\s*ensure\s+\[fusion\]\s*$') {
            $nl = if ($cfg.Contains("`r`n")) { "`r`n" } else { "`n" }
            $added = @()
            foreach ($n in $modules) {
                if ($cfg -match "(?m)^\s*(ensure|start)\s+$([regex]::Escape($n))\s*$") { continue }
                $last = [regex]::Matches($cfg, '(?m)^[ \t]*ensure[ \t]+fusion-[\w-]+[ \t]*\r?$')
                $coreLine = [regex]::Match($cfg, '(?m)^[ \t]*ensure[ \t]+fusion-core[ \t]*\r?$')
                if ($n -eq 'fusion-updater' -and $coreLine.Success) {
                    # before fusion-core, so it can repair an interrupted update before Fusion loads
                    $cfg = $cfg.Substring(0, $coreLine.Index) + "ensure $n" + $nl + $cfg.Substring($coreLine.Index)
                } elseif ($last.Count) {
                    $m = $last[$last.Count - 1]
                    $at = $m.Index + $m.Value.TrimEnd("`r").Length
                    $cfg = $cfg.Substring(0, $at) + $nl + "ensure $n" + $cfg.Substring($at)
                } else {
                    $cfg = $cfg.TrimEnd() + $nl + "ensure $n" + $nl
                }
                $added += $n
                Say "  Added 'ensure $n' to server.cfg" 'Green'
            }
            # F10 > Script Configs "Start with the server": server.cfg runs Fusion's start list at its very end
            $execLine = 'exec resources/[fusion]/fusion-core/permissions/startup.cfg'
            if ($cfg -notmatch '(?m)^\s*exec\s+resources/\[fusion\]/fusion-core/permissions/startup\.cfg\s*$') {
                $cfg = $cfg.TrimEnd() + $nl + $nl + '# Scripts set to "Start with the server" in F10 > Script Configs. Keep this line LAST.' + $nl + $execLine + $nl
                $added += 'startup.cfg'
                Say "  Added '$execLine' to the end of server.cfg" 'Green'
            }
            # the updater runs 'refresh' after it installs a module that did not exist before
            if ($cfg -notmatch '(?m)^\s*add_ace\s+resource\.fusion-updater\s+command\s+allow') {
                $cfg = $cfg.TrimEnd() + $nl + $nl + '# Lets the updater refresh the resource list after it installs a new module' + $nl + 'add_ace resource.fusion-updater command allow' + $nl
                $added += 'ace'
                Say "  Added 'add_ace resource.fusion-updater command allow' to server.cfg" 'Green'
            }
            if ($added.Count) {
                Copy-Item -LiteralPath $cfgPath -Destination (Join-Path $BackupDir 'server.cfg')
                [IO.File]::WriteAllText($cfgPath, $cfg)
            }
        }
    } else {
        # ---------------------------------------------------------- Scripts
        Say ''
        Say "Installing from $pkgPath" 'Cyan'
        $plan = @()
        foreach ($r in $found) {
            $name = [IO.Path]::GetFileName($r)
            if ($Replaced -contains $name -and -not $Force) { Say "  $name skipped: Fusion Menu already does this job. To use it instead, turn Fusion's version off in Settings > Modules, then run this again with -Force." 'Yellow'; continue }
            if (Find-Existing $name $FusionDir) { Say "  $name skipped: that name belongs to Fusion Menu. Use update-fusion.bat for Fusion updates." 'Yellow'; continue }
            $dest = $null
            foreach ($top in [IO.Directory]::GetDirectories($Resources)) {
                if ([IO.Path]::GetFileName($top) -in '[fusion]', '[cfx-default]') { continue }
                if ([IO.Path]::GetFileName($top) -eq $name) { $dest = $top; break }
                $dest = Find-Existing $name $top
                if ($dest) { break }
            }
            if (-not $dest) {
                $folder = $Target
                if ($folder -eq 'auto') {
                    $manifest = Get-ChildItem -LiteralPath $r -File | Where-Object { $_.Name -in 'fxmanifest.lua', '__resource.lua' } | Select-Object -First 1
                    $text = [IO.File]::ReadAllText($manifest.FullName)
                    $folder = if ($text -match '(?m)^\s*(client|server|shared)_scripts?\b') { 'qb' } else { 'addons' }
                }
                $sub = if ($folder -in 'qb', 'addons') { "[$folder]" } else { $folder.Trim('/', '\').Replace('/', '\') }
                if ($sub -notmatch '^\[(qb|addons)\]') { Fail "Target must be qb, addons, or a folder inside [qb] / [addons] (e.g. `"[addons]/[cars]`")." }
                $dest = Join-Path $Resources "$sub\$name"
            }
            $plan += , @($r, $dest, $name)
            $what = if ([IO.Directory]::Exists($dest)) { 'upgrade' } else { 'install' }
            Say ("  {0,-26} {1} -> {2}" -f $name, $what, $dest.Substring($Root.Length + 1))
        }
        if (-not $plan.Count) { exit 0 }
        if (-not (Confirm 'Continue?')) { exit 0 }
        [void][IO.Directory]::CreateDirectory($BackupDir)
        foreach ($p in $plan) { if (Merge-Resource $p[0] $p[1] $p[2]) { $attention = $true } }
    }

    $Log | Set-Content -LiteralPath (Join-Path $BackupDir 'report.txt') -Encoding UTF8
    Say ''
    if ($attention) {
        Say 'Some files were kept because you had changed them (yellow above). Compare each with its .new file' 'Yellow'
        Say 'and copy over anything new you want, then delete the .new file.' 'Yellow'
    }
    Say "Done. Backup and report: backups\$Stamp" 'Cyan'
    Say 'Start the server again from txAdmin.' 'Cyan'
} finally {
    if ($Temp -and [IO.Directory]::Exists($Temp)) { Remove-Item -Recurse -Force -LiteralPath $Temp }
}
