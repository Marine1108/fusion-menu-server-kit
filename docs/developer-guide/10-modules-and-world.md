# 10. Modules and the world

Fusion's features are separate resources ("modules"). Owners can switch any of them off and use another script instead (**F10 › Settings › Modules**), so check before calling a module you depend on:

```lua
if exports['fusion-core']:IsModuleEnabled('fusion-phone') then … end
```

| Module | Does |
|---|---|
| `fusion-inventory` | inventory, stashes, shops, drops, item use |
| `fusion-vehicles` | vehicle menu, garages, impound, keys, seatbelt |
| `fusion-fuel` | fuel and gas stations |
| `fusion-target` | third eye (qb-target API) |
| `fusion-voice` | proximity voice, radio, phone call audio (pma-voice API) |
| `fusion-phone` | phone: calls, texts, contacts, 911, bank, alerts, weather, web |
| `fusion-emergency` | siren controller, police radar, BOLOs |
| `fusion-hospital` | death, last stand, revives, hospital beds |
| `fusion-jail` | jail sentences |
| `fusion-weather` | weather, time, severe weather events, road conditions |
| `fusion-appearance` | character creator, clothing, outfits, uniforms, EUP |
| `fusion-weapons` | weapon spawner, attachments, loadouts |
| `fusion-stores` | stores and their stock |
| `fusion-postalmap` | the pause map with postal codes |
| `fusion-vinewood` | the hillside sign |
| `fusion-anticheat` | server-side anticheat |

**Also on every Fusion server:** `screenshot-basic` (screenshots of the game view, started before `[qb]` / `[addons]`), `oxmysql` (database) and the standard FiveM resources (`chat`, `spawnmanager`, `mapmanager`, …).

## Vehicles

### The vehicle catalogue

`exports['fusion-core']:GetRegistry('vehicles')` lists every vanilla and addon vehicle (discovered automatically), keyed by model:

```lua
adder = {
    model = 'adder', hash = 3078201489, name = 'Adder', brand = 'Truffade',
    price = 600000, category = 'super', categoryLabel = 'Super', shop = 'pdm',
    hidden = false,                  -- hidden from menus and shops
    perm = nil,                      -- extra permission needed to spawn it
    jobs = nil,                      -- { 'police' } = only these jobs
    addon = false, resource = nil,   -- addon vehicles: the resource that streams it
}
```

Same data as `QBCore.Shared.Vehicles`. Categories follow GTA's vehicle classes (`compacts`, `sedans`, `suvs`, …, `emergency`, `military`).

### Owned vehicles and garages

Owned vehicles are rows in `player_vehicles` (QBCore layout, see [chapter 12](12-database.md)). `state`: `0` out in the world, `1` in a garage, `2` impounded. To give a player a car:

```lua
local pd = Fusion.GetPlayerData(src)
local plate = 'FUS' .. math.random(10000, 99999)
MySQL.insert.await('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    { pd.license, pd.citizenid, 'sultan', joaat('sultan'), '{}', plate, 'pillboxgarage', 1 })
```

Server event when a vehicle changes owner: `fusion:vehicles:server:ownerChanged` (`plate`).

### Keys

Keys belong to characters, per plate. Owners of a `player_vehicles` row always have keys.

| Call | Side |
|---|---|
| `exports['fusion-vehicles']:GiveKeys(src, plate)` | server |
| `exports['fusion-vehicles']:RemoveKeys(src, plate)` | server |
| `exports['fusion-vehicles']:HasKeys(src, plate)` | server |
| `exports['fusion-vehicles']:HasKeys(plate)` | client |

`exports['qb-vehiclekeys']:*`, `TriggerEvent('vehiclekeys:client:SetOwner', plate)` and `qb-vehiclekeys:client:AddKeys` / `RemoveKeys` work too. Plates are compared trimmed and upper-case.

### Fuel and seatbelt

| Call | Side |
|---|---|
| `exports['fusion-fuel']:GetFuel(vehicle)` / `SetFuel(vehicle, 0–100)` | client and server |
| `Entity(vehicle).state.fuel` | read anywhere |
| `exports['fusion-vehicles']:IsSeatbeltOn()` | client |

`exports['LegacyFuel']`, `cdn-fuel`, `ps-fuel`, `lj-fuel` and `qb-fuel` `GetFuel` / `SetFuel` are answered by fusion-fuel.

### Spawning and properties

Client helpers on `fusion-core`: `GetVehicleProperties(vehicle)`, `SetVehicleProperties(vehicle, props)` (QBCore format), `LoadModel(model)`, `GetVehicleInFront(distance)`, `GetClosestPlayer(coords, maxDistance)`, `Teleport(coords)`. QBCore's `QBCore.Functions.SpawnVehicle` (client) and `CreateVehicle` (server) work.

**Anticheat and spawning:** entities created **on the server** (`CreateVehicleServerSetter`, `CreateVehicle` server-side) are never checked. Entities created by a player's **client** count towards the owner's spam limit (default 20 of a type per 10 seconds) and are blocked if their model is on the owner's blacklist. To let a player spawn one blacklisted model from your client code, approve it from the server first (valid for 20 seconds):

```lua
TriggerEvent('fusion:anticheat:allowModel', src, 'rhino')   -- server, before the client spawns it
```

## Voice and radio (`fusion-voice`)

Fusion Voice implements the **pma-voice API**; calls to `exports['pma-voice']:*` work. It switches itself off if pma-voice is installed.

| Client export | |
|---|---|
| `setRadioChannel(ch)` / `addPlayerToRadio(ch)` / `removePlayerFromRadio()` | join or leave a radio channel |
| `setCallChannel(ch)` / `addPlayerToCall(ch)` / `removePlayerFromCall()` | phone calls (same number on both phones = connected) |
| `setRadioVolume(v)`, `setCallVolume(v)`, `getRadioVolume()`, `getCallVolume()` | 0–1 (or 0–100) |

| Server export | |
|---|---|
| `setPlayerRadio(src, ch)`, `setPlayerCall(src, ch)` | move a player |
| `getPlayersInRadioChannel(ch)` | `{ [src] = false, … }` |

Restricted radio channels (police/EMS) are configured by owners; `setRadioChannel` respects them.

## Phone (`fusion-phone`)

| Call | Side | |
|---|---|---|
| `exports['fusion-phone']:SendDispatch({ title, message, coords, jobs, types, onDuty, blipSeconds })` | server | **Alert on-duty units** (alarms, robberies, panic buttons): a flashing map blip plus a notification with the postal. `jobs = { 'police' }` or `types = { 'leo', 'ems' }` (default: the owner's 911 jobs), `onDuty` defaults to `true`. Returns how many players were reached |
| `exports['fusion-phone']:SendEmergencyAlert(kind, title, body, by)` | server | Wireless Emergency Alert to **every phone**, with the alert tone. `kind`: `emergency`, `weather`, `amber`, `info` |
| `exports['fusion-phone']:IsOpen()` | client | phone open |

```lua
exports['fusion-phone']:SendDispatch({
    title = 'Store alarm', message = '24/7, Innocence Blvd',
    coords = GetEntityCoords(GetPlayerPed(src)), types = { 'leo' },
})
```

Phone numbers are `PlayerData.charinfo.phone`.

## Emergency services (`fusion-emergency`)

`exports['fusion-emergency']:AddBolo(plate, reason)` (server) adds a plate to the radar BOLO list; police radars flag it. Emergency vehicles are recognised by GTA vehicle class 18 plus owner settings.

## Hospital (`fusion-hospital`)

| Call | Side |
|---|---|
| `exports['fusion-hospital']:IsDead()` / `IsDowned()` | client |
| `exports['fusion-hospital']:RevivePlayer(src)` | server |
| `Player(src).state.isDown` | anywhere |

QBCore events work: `hospital:client:Revive`, `hospital:client:HealInjuries`, `hospital:server:RevivePlayer`, `hospital:server:SetDeathStatus`, `hospital:server:SetLaststandStatus`, `hospital:server:SetArmor`. Metadata `isdead` / `inlaststand` stay in sync.

## Jail (`fusion-jail`)

| Call | Side |
|---|---|
| `exports['fusion-jail']:JailPlayer(src, minutes, reason)` / `ReleasePlayer(src)` | server |
| `exports['fusion-jail']:IsJailed()` / `GetJailTime()` | client (minutes left) |

`police:server:JailPlayer`, `police:client:SendToJail` and `prison:server:SetJailStatus` work. `metadata.injail` holds the minutes left.

## Weather and time (`fusion-weather`)

| Call | Side |
|---|---|
| `exports['fusion-weather']:DisableSync()` / `EnableSync()` | client: pause weather/time sync (e.g. inside an interior or a cutscene) |
| `exports['fusion-weather']:StartWeatherEvent(kind)` / `StopWeatherEvent()` / `GetWeatherEvent()` | server: severe weather (`thunderstorm`, `flood`, `hurricane`, `tornado`, `blizzard`) |
| `GlobalState.fusionWeather`, `GlobalState.fusionClock`, `GlobalState.fusionWeatherEvent` | anywhere ([chapter 9](09-callbacks-and-events.md#state-bags)) |

`qb-weathersync:client:DisableSync` / `EnableSync` work.

## Postal codes

```lua
local code, distance = exports['fusion-core']:GetPostal(coords)   -- client (coords optional: player's position) or server
```

`exports['nearest-postal']:getPostal()` (client) and `getPostalServer(coords)` (server, returns `{ code, dist }`) are answered too, so CAD/MDT scripts work. The set (New, OCRP, Old, or the owner's own edited postals) follows the owner's settings.

## Appearance (`fusion-appearance`)

| Client export | |
|---|---|
| `GetSkin(ped)` | the current appearance table |
| `ApplySkin(skin, ped)` | apply a full appearance |
| `ApplyClothing(components, props)` | apply clothing only (outfits, uniforms), keeping the face |
| `LoadSkin()` | reload the saved appearance |
| `SaveSkin()` | save the current look |
| `OpenEditor(ctx)` | open the editor: `{ store = 'clothing', storeLabel = 'Suburban' }` (paid store), `{ free = true }`, `{ creator = true }` |

Events: `fusion:appearance:client:saved` (`skin`), `fusion:appearance:client:changed`. QBCore: `qb-clothing:client:openMenu`, `qb-clothing:client:openOutfitMenu`, `qb-clothing:client:loadOutfit`, `illenium-appearance:client:openClothingShopMenu`.

## Weapons (`fusion-weapons`)

Client: `SpawnWeapon(name)` (respects the owner's permissions), `OpenWheel()`, `GetWeaponComponents(weapon)`. Weapons as items: see [chapter 5](05-items-and-inventory.md#weapons).

## Stores (`fusion-stores`)

Owners create stores in game. To open a store-like list from your script, use `exports['fusion-inventory']:OpenShop(...)` ([chapter 5](05-items-and-inventory.md)). `exports['qb-inventory']:OpenShop(src, name)` opens a store an owner created with that name.

## Vinewood sign (`fusion-vinewood`)

Server: `GetSign()` (current text and colours), `SetSign(data)` (same shape; passes the word filter, returns `ok, message`), `IsTextAllowed(row1, row2)`.

## Anticheat (`fusion-anticheat`)

Report suspicious behaviour your script detects (e.g. a client asking for a reward it can't have earned):

```lua
exports['fusion-anticheat']:Flag(src, 'courier_exploit', 'Claimed 50 parcels in 10 seconds')
```

It is logged in F10 › Anticheat with the player's position. Custom detection names are logged only; they never kick or ban on their own. Players with `anticheat.bypass` are never flagged.
