# 2. Players and identifiers

## Accounts, characters and IDs

One Rockstar account (identified by its **license**) can own several **characters**. Each character has its own **citizen ID**, money, job, gang, items, appearance and position. A player picks a character after joining and can switch through the character menu.

| ID | Looks like | Unique per | Use it for |
|---|---|---|---|
| **Server ID** (`src`, `source`) | `7` | connection | Talking to the player right now. Changes every time they join. |
| **Citizen ID** | `ABC12345` (3 letters + 5 digits) | character | **Saving anything that belongs to a character.** It never changes. |
| **License** | `license:1a2b3c…` | Rockstar account | Account-wide data (bans, preferences shared by all characters) |
| Other identifiers | `fivem:123456`, `discord:930…`, `steam:110000…`, `license2:…`, `xbl:…`, `live:…` | account | Linking accounts (Discord roles, etc.). Not every player has every kind. |
| **Phone number** | `5551234567` (10 digits) | character | Phones, contacts (`charinfo.phone`) |
| **Bank account** | `US03FUSION12345678` | character | Banking scripts (`charinfo.account`) |
| Wallet ID / fingerprint | `FUS-aB3dE5fG` / `aB3dE5fG7hJk` | character | Evidence and RP scripts (`metadata.walletid`, `metadata.fingerprint`) |

```lua
-- server: every identifier kind -> its first value
local ids = exports['fusion-core']:GetIdentifiers(src)
-- { license = 'license:…', license2 = 'license2:…', fivem = 'fivem:…', discord = 'discord:…', steam = 'steam:…', ip = 'ip:…' }
```

Never store personal data you don't need, and never show `ip` identifiers to other players.

## Getting a player (server)

| Call | Returns |
|---|---|
| `Fusion.GetPlayer(src)` | The **player object** (`{ PlayerData = {…}, Functions = {…} }`) or `nil` if they haven't picked a character |
| `Fusion.GetPlayerData(src)` | Just the `PlayerData` table, or `nil` |
| `Fusion.GetPlayers()` | List of server IDs with a loaded character |
| `exports['fusion-core']:GetPlayerByCitizenId(citizenid)` | Player object of an **online** character, or `nil` |
| `exports['fusion-core']:GetOfflinePlayer(citizenid)` | Player object loaded from the database (works when they're offline; call `.Functions.Save()` after changes) |
| `exports['fusion-core']:SavePlayer(src)` | Saves now (Fusion also saves regularly and on disconnect) |
| `exports['fusion-core']:SetPlayerMetadata(src, key, value)` | `true` if set |

The player object is the same shape as QBCore's, so `Player.Functions.AddMoney(...)` and friends work. See [chapter 11](11-qbcore-compatibility.md) for the full list of `Functions`.

On the client, `Fusion.GetPlayerData()` returns the local player's data. It is kept up to date automatically; listen for `fusion:client:playerDataUpdated` to react to changes.

## `PlayerData`

```lua
{
    source = 7,                    -- server ID
    citizenid = 'ABC12345',
    license = 'license:…',
    name = 'RockstarName',         -- FiveM player name
    cid = 1,                       -- character slot
    money = { cash = 500, bank = 5000, crypto = 0 },   -- one entry per money type (chapter 4)
    charinfo = {
        firstname = 'John', lastname = 'Doe', birthdate = '1990-01-31',
        gender = 0,                -- 0 male, 1 female
        nationality = 'USA', backstory = '',
        phone = '5551234567', account = 'US03FUSION12345678', cid = 1,
    },
    job = {                        -- chapter 3
        name = 'police', label = 'Law Enforcement', type = 'leo',
        onduty = true, isboss = false, bankAuth = false, payment = 75,
        grade = { name = 'Officer', level = 1 },
    },
    gang = { name = 'none', label = 'No Gang', isboss = false, grade = { name = 'Unaffiliated', level = 0 } },
    metadata = { … },              -- below
    items = { [1] = { name = 'water_bottle', amount = 2, slot = 1, info = {}, … }, … },  -- chapter 5
    position = vector4(…),         -- last saved position
}
```

## Metadata

`metadata` holds per-character state. Read it with `PlayerData.metadata.<key>`; change it with `Player.Functions.SetMetaData(key, value)` (server) so every script and the client are updated.

| Key | Type | Default | Notes |
|---|---|---|---|
| `hunger`, `thirst` | number | 100 | 0–100, clamped. Changing them updates the HUD. |
| `stress` | number | 0 | 0–100 |
| `armor` | number | 0 | Saved armor |
| `isdead`, `inlaststand` | boolean | false | Set by the hospital module |
| `ishandcuffed` | boolean | false | |
| `injail` | number | 0 | Minutes left in jail |
| `jailitems` | table | `{}` | Items taken at the jail door |
| `callsign` | string | `NO CALLSIGN` | Emergency services |
| `bloodtype` | string | random | `A+`, `O-`, … |
| `licences` | table | `{ driver = true, business = false, weapon = false }` | |
| `criminalrecord` | table | `{ hasRecord = false }` | |
| `rep` | table | `{}` | Generic reputation: `Functions.AddRep(name, n)` / `GetRep(name)` |
| `jobrep` | table | `{ tow = 0, trucker = 0, taxi = 0, hotdog = 0 }` | `Functions.AddJobReputation(n)` adds to the current job |
| `dealerrep`, `craftingrep`, `attachmentcraftingrep` | number | 0 | |
| `walletid`, `fingerprint` | string | generated | |
| `phonedata` | table | `{ SerialNumber = …, InstalledApps = {} }` | |
| `inside` | table | `{ house = nil, apartment = {…} }` | Housing scripts |
| `commandbinds`, `status`, `phone` | table | `{}` | |

You may add your own keys: `Player.Functions.SetMetaData('myscript_level', 3)`. Use a prefix so you don't collide with other scripts.

## Events about players

| Event | Side | Arguments | When |
|---|---|---|---|
| `fusion:server:playerLoaded` | server | `src, PlayerData, isNew` | A character was loaded (also `QBCore:Server:PlayerLoaded` with the player object) |
| `fusion:server:playerSpawned` | server | `src, PlayerData` | The character spawned in the world |
| `fusion:server:playerUnloaded` | server | `src, citizenid` | Character logged out or the player left (also `QBCore:Server:OnPlayerUnload`) |
| `fusion:server:characterDeleted` | server | `citizenid` | A character was deleted: clean up your own data for it |
| `fusion:client:playerLoaded` | client | `PlayerData, isNew` | Also `QBCore:Client:OnPlayerLoaded` |
| `fusion:client:spawned` | client | `isNew` | In the world, control given |
| `fusion:client:playerDataUpdated` | client | `PlayerData` | Anything changed. Also `QBCore:Player:SetPlayerData` |
| `fusion:client:playerUnloaded` | client | — | Also `QBCore:Client:OnPlayerUnload` |

State bags you can read anywhere: `Player(src).state.citizenid` and `Player(src).state.isLoggedIn`.

## Who outranks whom

Staff actions should respect the role hierarchy (a moderator can't kick an admin):

```lua
if not exports['fusion-core']:CanTarget(src, target) then return end   -- true if src's highest role outranks target's
local roles = exports['fusion-core']:GetPlayerRoles(src)               -- { 'admin', 'moderator', 'user' } (inherited roles included)
```
