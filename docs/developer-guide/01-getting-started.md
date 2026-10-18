# 1. Getting started

## The manifest

```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

dependency 'fusion-core'

shared_script '@fusion-core/lib/init.lua'   -- gives you the global `Fusion` table
server_script 'server.lua'
client_script 'client.lua'
```

`@fusion-core/lib/init.lua` is a small library that runs inside **your** resource. It talks to `fusion-core` through exports and adds helpers that would be tedious with raw exports (menus, callbacks, settings change listeners).

Writing a QBCore script instead? Nothing changes: `local QBCore = exports['qb-core']:GetCoreObject()` works on Fusion. See [chapter 11](11-qbcore-compatibility.md).

## Detecting Fusion

```lua
local isFusion = GetResourceState('fusion-core') == 'started'
```

If you also support plain QBCore, use the QBCore API for the shared parts and add Fusion extras (settings pages, permission nodes) behind this check. Load the library only when Fusion is present by keeping the Fusion-specific code in a separate resource or guarding calls.

## Startup order

| Side | Wait for | How |
|---|---|---|
| Server | fusion-core finished loading settings, permissions and data | `Fusion.Ready()` (blocks until ready) or the `fusion:server:ready` event |
| Client | the player picked a character and spawned | `Fusion.IsLoaded()`, or the `fusion:client:playerLoaded` / `QBCore:Client:OnPlayerLoaded` event |

```lua
-- server
CreateThread(function()
    Fusion.Ready()
    local jobs = 0
    for _ in pairs(exports['fusion-core']:GetRegistry('jobs') or {}) do jobs = jobs + 1 end
    print(('Fusion is ready, %d jobs loaded'):format(jobs))
end)

-- client
AddEventHandler('fusion:client:playerLoaded', function(playerData, isNewCharacter)
    print('Hi ' .. playerData.charinfo.firstname)
end)
```

Register permission nodes and settings pages at the top of your server file (not inside a thread). Fusion queues them if it isn't ready yet.

## What the `Fusion` table contains

| Area | Server | Client |
|---|---|---|
| Startup | `Fusion.Ready()` | `Fusion.Ready()`, `Fusion.IsLoaded()` |
| Players | `Fusion.GetPlayer(src)`, `Fusion.GetPlayerData(src)`, `Fusion.GetPlayers()` | `Fusion.GetPlayerData()` |
| Money | `Fusion.AddMoney`, `Fusion.RemoveMoney`, `Fusion.GetMoney` | — |
| Items | `Fusion.AddItem`, `Fusion.RemoveItem`, `Fusion.HasItem`, `Fusion.GetItem` | — (use `exports['fusion-core']:HasItem`) |
| Callbacks | `Fusion.Callback.Register` | `Fusion.Callback.Await`, `Fusion.Callback.Trigger` |
| Settings | `Fusion.Settings.Register`, `Get`, `Enabled`, `OnChange` | `Fusion.Settings.Get`, `Enabled`, `OnChange` |
| Permissions | `Fusion.Perms.Register`, `Fusion.Perms.Has(src, node)` | `Fusion.Perms.Has(node)` |
| UI | `Fusion.Notify(src, ...)` | `Fusion.Notify`, `Fusion.Menu.*`, `Fusion.Input`, `Fusion.Confirm`, `Fusion.Progress`, `Fusion.TextUI`, `Fusion.Radial`, `Fusion.SetHud`, `Fusion.Key.*` |
| Other | `Fusion.Log`, `Fusion.KV(owner)`, `Fusion.ProvideExport` | `Fusion.ProvideExport` |
| Info | `Fusion.Resource` (your resource name), `Fusion.IsServer` | same |

Every function is documented in the chapter for its area. Anything also has a plain export on `fusion-core` (`exports['fusion-core']:AddMoney(...)`), so you can call Fusion from scripts that don't load the library, or from JavaScript or C#.

## Your first script

A `/paycheck` command that pays on-duty police a bonus, with an in-game setting for the amount and a permission:

```lua
-- server.lua
Fusion.Perms.Register('bonus.claim', 'Claim the duty bonus', 'Duty Bonus', 'Lets a role use /bonus.', { 'user' })

Fusion.Settings.Register('dutybonus', {
    label = 'Duty Bonus', icon = 'wallet',
    description = 'A bonus on-duty officers can claim once per restart.',
    fields = {
        { key = 'enabled', type = 'toggle', label = 'Enable the bonus', default = true },
        { key = 'amount', type = 'number', label = 'Bonus amount', default = 250, min = 0, max = 100000 },
        { key = 'jobs', type = 'multiselect', label = 'Jobs that can claim it', default = { 'police' }, source = 'jobs' },
    },
})

local claimed = {}

RegisterCommand('bonus', function(src)
    local s = Fusion.Settings.Get('dutybonus')
    if not Fusion.Settings.Enabled('dutybonus') or not Fusion.Perms.Has(src, 'bonus.claim') then return end
    local pd = Fusion.GetPlayerData(src)
    if not pd then return end
    local jobOk = false
    for _, j in ipairs(s.jobs or {}) do if j == pd.job.name then jobOk = true end end
    if not jobOk or not pd.job.onduty then return Fusion.Notify(src, 'Only on-duty staff can claim this', 'error') end
    if claimed[pd.citizenid] then return Fusion.Notify(src, 'Already claimed', 'error') end
    claimed[pd.citizenid] = true
    Fusion.AddMoney(src, 'bank', s.amount, 'duty bonus')
    Fusion.Notify(src, ('$%d added to your bank'):format(s.amount), 'success')
end, false)
```

The settings page appears in **F10 › Settings › Duty Bonus**, the permission in **F10 › Roles & Permissions**, and owners never edit a config file.
