# 11. QBCore compatibility

Fusion ships its own `qb-core` resource: a compatibility layer that answers QBCore's API with Fusion's data. **Unmodified QBCore scripts run on Fusion.** Owners put them in `resources/[qb]` and start them.

## What works

```lua
local QBCore = exports['qb-core']:GetCoreObject()
```

### Server: `QBCore.Functions`

`GetPlayer`, `GetPlayerByCitizenId`, `GetOfflinePlayerByCitizenId`, `GetPlayerByLicense`, `GetPlayerByPhone`, `GetPlayerByAccount`, `GetPlayerByCharInfo`, `GetPlayers`, `GetQBPlayers`, `GetSource`, `GetIdentifier`, `GetCoords`, `GetClosestPlayer`, `GetPlayersOnDuty`, `GetDutyCount`, `CreateCallback`, `TriggerCallback`, `TriggerClientCallback`, `CreateUseableItem`, `CanUseItem`, `UseItem`, `HasItem`, `HasPermission`, `GetPermission`, `AddPermission`, `RemovePermission`, `IsWhitelisted`, `IsOptin`, `ToggleOptin`, `IsPlayerBanned`, `IsLicenseInUse`, `Kick`, `Notify`, `SpawnVehicle`, `CreateVehicle`, `SetPlayerBucket`, `SetEntityBucket`, `GetPlayersInBucket`, `GetEntitiesInBucket`, `GetBucketObjects`, `SetDefaultVehicleExtras`, `ChangeVehicleExtra`, `PrepForSQL`, `GetDatabaseInfo`, plus the shared helpers (`RandomStr`, `RandomInt`, `SplitStr`, `Trim`, `FirstToUpper`, `Round`).

`QBCore.Commands.Add(name, help, args, argsRequired, cb, permission)`, `QBCore.Player.CreatePlayer`, `CheckPlayerData`, `DeleteCharacter`, `GetTotalWeight`, `CreateCitizenId`.

### Client: `QBCore.Functions`

`GetPlayerData`, `TriggerCallback`, `CreateClientCallback`, `TriggerClientCallback`, `HasItem`, `Notify`, `Progressbar`, `DrawText`, `DrawTextUI`, `GetCoords`, `GetClosestPlayer`, `GetPlayersFromCoords`, `GetClosestVehicle`, `GetClosestVehicleInDirection`, `GetClosestPed`, `GetClosestObject`, `GetClosestBone`, `GetBoneDistance`, `GetPlayers`, `GetPeds`, `GetVehicles`, `GetObjects`, `GetVehicleLabel`, `GetStreetNametAtCoords`, `GetZoneAtCoords`, `GetCardinalDirection`, `GetCurrentTime`, `GetGroundZCoord`, `IsWearingGloves`, `LoadModel`, `LoadAnimSet`, `RequestAnimDict`, `PlayAnim`, `LookAtEntity`, `AttachProp`, `SpawnClear`, `LoadParticleDictionary`, `StartParticleAtCoord`, `StartParticleOnEntity`.

### The player object

`Player.PlayerData` ([chapter 2](02-players-and-identifiers.md)) and `Player.Functions`:

`UpdatePlayerData`, `SetJob`, `SetGang`, `SetJobDuty`, `SetPlayerData`, `SetMetaData`, `GetMetaData`, `AddJobReputation`, `AddRep`, `RemoveRep`, `GetRep`, `AddMoney`, `RemoveMoney`, `SetMoney`, `GetMoney`, `SetCreditCard`, `AddItem`, `RemoveItem`, `SetInventory`, `ClearInventory`, `GetItemByName`, `GetItemsByName`, `GetItemBySlot`, `SetItemInfo`, `GetTotalWeight`, `HasItem`, `GetCardSlot`, `Save`, `Logout`, `AddMethod`, `AddField`.

### Shared data

`QBCore.Shared.Items`, `Jobs`, `Gangs`, `Vehicles`, `Weapons` come from Fusion's registries (editable in F10) and refresh live (`QBCore:Client:UpdateObject`).

### qb-core exports (server)

`GetCoreObject`, `GetCoreVersion`, `AddItem`, `AddItems`, `UpdateItem`, `RemoveItem`, `AddJob`, `AddJobs`, `UpdateJob`, `RemoveJob`, `AddGang`, `AddGangs`, `UpdateGang`, `RemoveGang`, `SetMethod`, `SetField`, `AddPlayerMethod`, `AddPlayerField`, `ExploitBan`. Items, jobs and gangs added this way are **saved** in Fusion's registry and become editable in F10.

### Events

Server: `QBCore:Server:PlayerLoaded`, `QBCore:Server:OnPlayerUnload`, `QBCore:Server:OnJobUpdate`, `QBCore:Server:OnGangUpdate`, `QBCore:Server:SetDuty`, `QBCore:Server:OnMoneyChange`, `QBCore:Server:UpdateObject`, `QBCore:Server:SetMetaData`, `QBCore:Server:UseItem`, `QBCore:CallCommand`, `QBCore:UpdatePlayer`, `QBCore:Server:TriggerCallback`, `QBCore:Server:TriggerClientCallback`.

Client: `QBCore:Client:OnPlayerLoaded`, `QBCore:Client:OnPlayerUnload`, `QBCore:Client:OnJobUpdate`, `QBCore:Client:OnGangUpdate`, `QBCore:Client:SetDuty`, `QBCore:Client:OnMoneyChange`, `QBCore:Player:SetPlayerData`, `QBCore:Client:UpdateObject`, `QBCore:Client:OnSharedUpdate`, `QBCore:Client:OnSharedUpdateMultiple`, `QBCore:Notify`, `QBCore:Client:EnteringVehicle`, `QBCore:Client:EnteredVehicle`, `QBCore:Client:LeftVehicle`, `QBCore:Command:SpawnVehicle`, `DeleteVehicle`, `TeleportToPlayer`, `TeleportToCoords`, `GoToMarker`, `QBCore:Client:UseItem`, `hud:client:UpdateNeeds`, `hud:client:OnMoneyChange`.

### Other resources Fusion answers for

| Resource | Answered by |
|---|---|
| `qb-inventory` | fusion-inventory (exports, `inventory:server:OpenInventory`, `inventory:client:ItemBox`, `inventory:client:requiredItems`, stashes, shops) |
| `qb-target` | fusion-target (full API, [chapter 8](08-ui.md#third-eye-targeting)) |
| `qb-menu`, `qb-input`, `progressbar` | fusion-core UI |
| `qb-vehiclekeys` | fusion-vehicles |
| `qb-management`, `qb-banking` | fusion-core society accounts |
| `qb-weathersync` | fusion-weather |
| `qb-clothing`, `illenium-appearance` (main events) | fusion-appearance |
| `qb-ambulancejob` (`hospital:*` events), `qb-prison` (`prison:*`, `police:server:JailPlayer`) | fusion-hospital, fusion-jail |
| `pma-voice` | fusion-voice |
| `LegacyFuel`, `cdn-fuel`, `ps-fuel`, `lj-fuel`, `qb-fuel` | fusion-fuel |
| `nearest-postal` | fusion-core postals |

### Database

QBCore's tables keep QBCore's columns: `players`, `player_vehicles`, `playerskins`, `player_outfits`, `bans`, `management_funds`, `inventories` ([chapter 12](12-database.md)). Scripts that query them directly keep working.

## Don't depend on these (they're replaced)

Owners don't install these on Fusion, because Fusion does their job: `qb-core` (the real one), `qb-inventory`, `qb-target`, `qb-menu`, `qb-input`, `progressbar`, `qb-multicharacter`, `qb-spawn`, `qb-apartments` (spawn), `qb-garages`, `qb-shops`, `qb-clothing`, `illenium-appearance`, `qb-vehiclekeys`, `qb-weathersync`, `qb-ambulancejob`, `qb-prison`, `qb-management`, `qb-banking`, `LegacyFuel`, `qb-hud`. Calling their **exports and events** is fine (Fusion answers); requiring their **files** (`@qb-inventory/...`) or their resource being started is not.

`@qb-core/shared/locale.lua` is provided, so `Locale:new{ … }` translations work.

## Known differences

* `PlayerData.money` contains every money type the owner configured, not just `cash`, `bank`, `crypto`.
* With the economy off, `RemoveMoney` succeeds without charging ([chapter 4](04-economy.md#economy-off-servers)).
* `QBCore.Config` reflects Fusion's settings; editing it at runtime has no effect. Use settings instead.
* Scripts that read files or internal state of a specific QB resource may need small changes.
* PolyZone isn't bundled: scripts that use PolyZone directly need it installed.
