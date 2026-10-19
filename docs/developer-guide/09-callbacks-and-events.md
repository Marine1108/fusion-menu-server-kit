# 9. Callbacks, events, state bags, logs and storage

## Callbacks (client asks, server answers)

```lua
-- server
Fusion.Callback.Register('courier:getRoute', function(src, routeId)
    local pd = Fusion.GetPlayerData(src)
    if not pd or pd.job.name ~= 'courier' then return nil, 'Not a courier' end
    return { id = routeId, stops = 5 }, nil          -- any number of return values
end)

-- client
local route, err = Fusion.Callback.Await('courier:getRoute', 3)        -- blocks this thread
Fusion.Callback.Trigger('courier:getRoute', function(route, err) end, 3)   -- callback style
```

* The first argument on the server is always the caller's `src`. Everything else is **sent by the client and must be validated**: never trust amounts, item names, coordinates or IDs from it.
* If the server function errors, the client receives no values (and the error is printed on the server).
* Calls time out after 20 seconds and return nothing.
* Callback names are global; prefix them with your script name.

QBCore callbacks (`QBCore.Functions.CreateCallback` / `TriggerCallback`, and client callbacks) also work.

## Events Fusion fires

### Server

| Event | Arguments |
|---|---|
| `fusion:server:ready` | — fusion-core finished starting |
| `fusion:server:playerLoaded` | `src, PlayerData, isNew` |
| `fusion:server:playerSpawned` | `src, PlayerData` |
| `fusion:server:playerUnloaded` | `src, citizenid` |
| `fusion:server:characterDeleted` | `citizenid` |
| `fusion:server:inventoryUpdated` | `src` |
| `fusion:settings:changed` | `module, key, value` |
| `fusion:settings:reset` | `module` |
| `fusion:permissions:changed` | — roles or permissions were edited |
| `fusion:registry:updated` | `kind ('items'/'jobs'/'gangs'/'vehicles'), name, data` (`data` is `nil` when deleted) |
| `fusion:inventory:server:purchased` | `src, itemName, amount, cost, shopLabel` |
| `fusion:vehicles:server:ownerChanged` | `plate` |
| `fusion:weather:alertIssued` | `kind, label, alertText` (severe weather started) |
| QBCore | `QBCore:Server:PlayerLoaded` (player object), `QBCore:Server:OnPlayerUnload` (`src`), `QBCore:Server:OnJobUpdate`, `OnGangUpdate`, `SetDuty`, `OnMoneyChange`, `QBCore:Server:UpdateObject` |

### Client

| Event | Arguments |
|---|---|
| `fusion:client:ready` | — the UI and settings are ready |
| `fusion:client:playerLoaded` | `PlayerData, isNew` |
| `fusion:client:spawned` | `isNew, home` (`home` = the housing id when they chose to spawn at home, else `nil`) |
| `fusion:client:privacyChanged` | `hidden, videoMode`: streamer / video mode changed (see chapter 8) |
| `fusion:client:playerDataUpdated` | `PlayerData` |
| `fusion:client:playerUnloaded` | — |
| `fusion:client:moneyChanged` | `account, amount, 'add'/'remove', newBalance` |
| `fusion:client:inventoryUpdated` | — |
| `fusion:client:permissionsUpdated` | — |
| `fusion:client:registryUpdated` | `kind, name, data` |
| `fusion:settings:changed` | `module, key, value` |
| QBCore | `QBCore:Client:OnPlayerLoaded`, `OnPlayerUnload`, `OnJobUpdate`, `OnGangUpdate`, `SetDuty`, `OnMoneyChange`, `QBCore:Player:SetPlayerData`, `QBCore:Client:UpdateObject`, `QBCore:Client:EnteringVehicle` / `EnteredVehicle` / `LeftVehicle` |

### Events you can trigger

| Event | Side | Arguments | Does |
|---|---|---|---|
| `fusion:client:notify` | client (or `TriggerClientEvent` from server) | `message, type, duration, title` | Shows a notification |
| `inventory:client:ItemBox` | client | `itemDefinition, 'add'/'remove'/'use', amount` | Item pop-up |
| `QBCore:Notify` | client | `message, type, duration` | Notification |
| `hospital:client:Revive` | client | — | Revives the player (QBCore event, handled by the hospital module) |

Fusion's other events (`fusion:*:client:*`, `fusion:internal:*`, `fusion:cb:*`…) are internal and protected; don't trigger them.

## State bags

| State bag | Value |
|---|---|
| `Player(src).state.citizenid` | citizen ID of the loaded character |
| `Player(src).state.isLoggedIn` | `true` while a character is loaded |
| `Player(src).state.isDown` | downed or dead (hospital module) |
| `Player(src).state.radioChannel`, `.callChannel` | voice: radio channel and phone call (0 = none) |
| `LocalPlayer.state.proximity` | voice range `{ index, distance, mode }` |
| `Entity(vehicle).state.fuel` | fuel 0–100 (read it; set it with the fuel exports) |
| `Entity(vehicle).state.fusionLocked` | doors locked |
| `GlobalState.fusionWeather` | `{ weather = 'CLEAR', blackout, snow, enabled }` |
| `GlobalState.fusionClock` | `{ hour, minute, base, scale, frozen }`: the in-game time at real time `base` (`os.time()`) and how fast it runs. On the client just use `GetClockHours()` / `GetClockMinutes()` |
| `GlobalState.fusionWeatherEvent` | the active severe weather event, or `nil` |

Read state bags, don't write Fusion's: changing them directly skips Fusion's checks.

## Logs (server)

```lua
Fusion.Log('admin', 'Courier route 3 completed by ' .. GetPlayerName(src), src, { route = 3, pay = 120 })
--          category  message                                             src  extra data (optional)
```

Logs appear in **F10 › Logs**, filterable by category, player and text, and go to the owner's Discord webhooks. Built-in categories: `admin`, `money`, `items`, `connect`, `jobs`, `settings`, `permissions`, `reports`, `anticheat`, `emergency`, `phone`. You may use your own category name (e.g. `courier`); owners can still filter on it.

## Key/value storage (server)

A small persistent store for your script's data (saved in `fusion_kv`), so you don't need your own table for simple things:

```lua
local kv = Fusion.KV('courier')                        -- 'owner' namespace: use your script name
kv.Set('stats:' .. citizenid, { routes = 12, best = 340 })
local stats = kv.Get('stats:' .. citizenid, { routes = 0 })   -- second argument: default
kv.Set('stats:' .. citizenid, nil)                     -- delete
```

Values are stored as JSON. Owner names can be up to 100 characters and keys up to 64. Calls go to the database, so cache what you read often. For large or queryable data, create your own table.

## Answering another script's exports

If your script replaces a well-known resource, you can answer calls made to it without that resource being installed:

```lua
-- calls to exports['legacy-thing']:GetLevel(...) now run this function
Fusion.ProvideExport('legacy-thing', 'GetLevel', function(src) return 3 end)
```

Fusion uses this to answer `qb-target`, `qb-inventory`, `pma-voice`, `LegacyFuel` and others.
