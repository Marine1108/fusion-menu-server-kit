# Fusion Menu: Developer Guide

Everything you need to build FiveM scripts that work with **Fusion Menu**: player data, identifiers, jobs and gangs, the economy, items and inventory, permissions, in-game settings, UI, events, vehicles and the world, and QBCore compatibility.

Fusion Menu is a FiveM framework that is configured entirely in game (an admin panel on **F10**, a player menu on **M**) and runs **unmodified QBCore scripts**. You can integrate in two ways, and you can mix them:

| Way | Use it when | You get |
|---|---|---|
| **Fusion API** (`@fusion-core/lib/init.lua`) | You write for Fusion, or want the extras | In-game settings pages, permission nodes, Fusion menus and UI, callbacks, logs, key bindings |
| **QBCore API** (`exports['qb-core']:GetCoreObject()`) | You already have a QBCore script, or want one script for both | The usual `QBCore.Functions.*`, player object, events, shared data. Works on Fusion unchanged |

## Contents

| # | Chapter | What's in it |
|---|---|---|
| 1 | [Getting started](01-getting-started.md) | Manifest, the `Fusion` library, startup order, a first script |
| 2 | [Players and identifiers](02-players-and-identifiers.md) | Player object, `PlayerData` fields, citizen ID, license and other identifiers, metadata, character info |
| 3 | [Jobs and gangs](03-jobs-and-gangs.md) | Job and gang data, grades, bosses, duty, job types, adding jobs, society accounts |
| 4 | [Economy](04-economy.md) | Money types, adding and removing money, reasons, "economy off" mode, paychecks, society funds, transactions |
| 5 | [Items and inventory](05-items-and-inventory.md) | Item definitions, usable and consumable items, item metadata, stashes, shops, item pictures |
| 6 | [Permissions and roles](06-permissions-and-roles.md) | Permission nodes, roles, wildcards, ACE groups, QBCore permission levels |
| 7 | [In-game settings](07-settings.md) | Give your script its own page in F10 › Settings: every field type; how F10 › Script Configs reads your config.lua |
| 8 | [UI](08-ui.md) | Notifications, menus and the main menu, input dialogs, confirm, progress bars, text UI, radial, context menu, HUD, streamer / video mode and recording, key bindings, third eye |
| 9 | [Callbacks and events](09-callbacks-and-events.md) | Client↔server callbacks, every event Fusion fires, state bags, logs, key/value storage |
| 10 | [Modules and world](10-modules-and-world.md) | Vehicles, keys and fuel, garages, voice and radio, phone and alerts, emergency (radar, BOLOs, PIT rules), hospital, jail, weather and time, postal codes, appearance, weapons, housing, Vinewood sign, anticheat |
| 11 | [QBCore compatibility](11-qbcore-compatibility.md) | What works, what is replaced, mapped exports and events, scripts not to install |
| 12 | [Database](12-database.md) | Tables and their columns |
| 13 | [Best practices and checklist](13-best-practices.md) | Security, performance, naming, Linux, escrow, release checklist |
| — | [Example resource](examples/example-courier) | A complete courier job using settings, permissions, a job, money, items, target, menus and callbacks |

## The 30-second version

```lua
-- fxmanifest.lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'
dependency 'fusion-core'
shared_script '@fusion-core/lib/init.lua'
server_script 'server.lua'
client_script 'client.lua'
```

```lua
-- server.lua
Fusion.Perms.Register('myscript.use', 'Use my script', 'My Script', nil, { 'user' })

Fusion.Callback.Register('myscript:buy', function(src, amount)
    if not Fusion.Perms.Has(src, 'myscript.use') then return false, 'Not allowed' end
    if not Fusion.RemoveMoney(src, 'cash', 250 * amount, 'myscript purchase') then return false, 'Not enough cash' end
    Fusion.AddItem(src, 'water_bottle', amount)
    return true
end)
```

```lua
-- client.lua
RegisterCommand('buywater', function()
    local ok, err = Fusion.Callback.Await('myscript:buy', 1)
    Fusion.Notify(ok and 'Bought a water' or err, ok and 'success' or 'error')
end)
```

## Conventions in this guide

* `src` is a player's server ID. "Server" and "client" say where a function can be called.
* Function signatures use Lua: `Fusion.AddMoney(src, account, amount, reason) -> boolean`.
* Everything in this guide is public, supported API. Anything else inside Fusion's resources is internal and may change between versions.
* Fusion's own resources are named `fusion-*`. Don't use that prefix for your scripts (see [chapter 13](13-best-practices.md)).
