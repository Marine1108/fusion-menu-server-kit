# Posts the newest changelog entry of one or more products to Discord through a webhook.
#
#   install\post-changelog.ps1 -Product FireHose
#   install\post-changelog.ps1 -Product Menu, Builder, PursuitEquipment
#   install\post-changelog.ps1 -Product Fires -DryRun      (shows what would be posted, sends nothing)
#
# Changelogs: dist\changelogs\Fusion<Product>.md, newest "## <Product> <version> (<date>)" entry at the top.
# Webhook URL: %USERPROFILE%\.fusion-signing\discord-changelog-webhook.txt (outside the project, never committed).

param(
    [Parameter(Mandatory = $true)][string[]]$Product,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$folder = Join-Path $root 'dist\changelogs'
$hookFile = Join-Path $env:USERPROFILE '.fusion-signing\discord-changelog-webhook.txt'

$webhook = $null
if (-not $DryRun) {
    if (-not (Test-Path -LiteralPath $hookFile)) { throw "No webhook yet: put the Discord webhook URL in $hookFile" }
    $webhook = (Get-Content -LiteralPath $hookFile -Raw).Trim()
    if ($webhook -notmatch '^https://(canary\.|ptb\.)?discord(app)?\.com/api/webhooks/\d+/[\w-]+$') { throw "$hookFile does not hold a Discord webhook URL" }
}

foreach ($p in $Product) {
    $name = if ($p -like 'Fusion*') { $p } elseif ($p -eq 'Menu') { 'FusionMenu' } else { "Fusion$p" }
    $file = Join-Path $folder "$name.md"
    if (-not (Test-Path -LiteralPath $file)) { throw "No changelog: $file" }

    # the newest entry: its "## " heading and every line up to the next "## "
    $title = $null; $body = @()
    foreach ($line in [IO.File]::ReadAllLines($file, [Text.Encoding]::UTF8)) {
        if ($line -match '^## (.+)$') {
            if ($title) { break }
            $title = $Matches[1].Trim()
        } elseif ($title) {
            $body += $line
        }
    }
    if (-not $title) { throw "No '## ' entry in $file" }
    $text = ($body -join "`n").Trim()
    if ($text.Length -gt 4000) { throw "$title is longer than a Discord post allows (4000 characters)" }

    if ($DryRun) {
        Write-Host "== $title" -ForegroundColor Cyan
        Write-Host $text
        continue
    }

    $payload = @{
        username         = 'Fusion Platform Technologies'
        allowed_mentions = @{ parse = @() }   # never pings anyone
        embeds           = @(@{
            title       = $title
            description = $text
            color       = 0xE8590C
            footer      = @{ text = 'Fusion Platform Technologies LLC  ·  fusion-platform-technologies.tebex.store' }
        })
    } | ConvertTo-Json -Depth 6
    Invoke-RestMethod -Method Post -Uri $webhook -ContentType 'application/json; charset=utf-8' `
        -Body ([Text.Encoding]::UTF8.GetBytes($payload)) | Out-Null
    Write-Host "Posted: $title" -ForegroundColor Green
}
