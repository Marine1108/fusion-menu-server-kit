# 3. Jobs and gangs

Jobs and gangs live in a **registry** stored in the database. Owners edit them in **F10 › Jobs** and **F10 › Gangs**. The data has the same shape as `QBCore.Shared.Jobs` / `Gangs`.

## Job definition

```lua
police = {
    label = 'Law Enforcement',
    type = 'leo',            -- 'leo' | 'ems' | 'mechanic' | 'none' | any text your script checks
    defaultDuty = true,      -- on duty when the character loads
    offDutyPay = false,      -- paycheck while off duty
    whitelisted = false,
    color = '#3b82f6',       -- optional, used in the UI
    grades = {
        ['0'] = { name = 'Recruit', payment = 50 },
        ['1'] = { name = 'Officer', payment = 75 },
        ['4'] = { name = 'Chief', payment = 150, isboss = true, bankAuth = true },
    },
}
```

* Grade keys are **strings** (`'0'`, `'1'`…), like QBCore.
* `isboss` grades get the boss menu (hire, fire, promote, society money).
* `payment` is paid every paycheck (see [chapter 4](04-economy.md)).

Gangs have `label`, `color` and `grades` (with `name` and `isboss`, no `payment`).

### Default jobs

Jobs: `unemployed` (required, label "Civilian"), `police`, `sheriff`, `ambulance`, `fire`, `mechanic`, `tow`, `taxi`, `bus`, `trucker`, `garbage`, `realestate`, `cardealer`, `judge`, `lawyer`, `reporter`, `hotdog`. Gangs: `none` (required), `lostmc`, `ballas`, `vagos`, `cartel`, `families`, `triads`. Owners can rename or delete anything except `unemployed` and `none`, so **don't hard-code labels**, and let owners choose which jobs your script uses (a `multiselect` setting with `source = 'jobs'`, see [chapter 7](07-settings.md)).

### Job types

`type` groups jobs: several police departments are all `leo`, so check the type instead of a name when you mean "any police":

| Type | Default jobs | Used by Fusion for |
|---|---|---|
| `leo` | police, sheriff | Radar, BOLOs, 911 dispatch, restricted radio channels, AMBER Alerts |
| `ems` | ambulance, fire | Revives, 911 dispatch, restricted radio channels |
| `mechanic` | mechanic | — |
| `none` | everything else | — |

```lua
local pd = Fusion.GetPlayerData(src)
if pd.job.type == 'leo' and pd.job.onduty then … end
```

## The player's job

`PlayerData.job`:

```lua
{ name = 'police', label = 'Law Enforcement', type = 'leo', onduty = true,
  isboss = false, bankAuth = false, payment = 75, grade = { name = 'Officer', level = 1 } }
```

| Do this | Server call |
|---|---|
| Set a job | `exports['fusion-core']:SetJob(src, 'police', 1)` or `Player.Functions.SetJob('police', 1)` → `false` if the job or grade doesn't exist |
| Set a gang | `Player.Functions.SetGang('ballas', 0)` |
| Duty on/off | `Player.Functions.SetJobDuty(true)` |

| Event | Side | Arguments |
|---|---|---|
| `QBCore:Server:OnJobUpdate` | server | `src, job` |
| `QBCore:Client:OnJobUpdate` | client | `job` |
| `QBCore:Server:OnGangUpdate` / `QBCore:Client:OnGangUpdate` | both | (`src`,) `gang` |
| `QBCore:Server:SetDuty` / `QBCore:Client:SetDuty` | both | (`src`,) `onduty` |

## Reading and adding jobs

```lua
local jobs = exports['fusion-core']:GetRegistry('jobs')   -- server or client: { police = {…}, … }
local gangs = exports['fusion-core']:GetRegistry('gangs')
```

To ship a job with your script, add it **only if it doesn't exist yet**, so you never overwrite the owner's edits:

```lua
CreateThread(function()
    Fusion.Ready()
    local jobs = exports['fusion-core']:GetRegistry('jobs')
    if not jobs.courier then
        exports['fusion-core']:SaveRegistry('jobs', 'courier', {
            label = 'Courier', type = 'none', defaultDuty = true,
            grades = { ['0'] = { name = 'Driver', payment = 40 }, ['1'] = { name = 'Dispatcher', payment = 70, isboss = true } },
        })
    end
end)
```

`SaveRegistry(kind, name, data)` returns `true, savedData` or `false, error`. Names may only contain letters, numbers and `_`. Saved jobs appear in F10 › Jobs, and every client gets the update (`fusion:registry:updated` / `fusion:client:registryUpdated` with `kind, name, data`; QBCore scripts get `QBCore:Client:UpdateObject`).

QBCore's `exports['qb-core']:AddJob(name, data)` / `AddGang` also work and are saved the same way.

## Society (job and gang) money

Every job and gang has a shared account, stored in `management_funds` like qb-management.

| Server call | Returns |
|---|---|
| `exports['fusion-core']:GetSocietyMoney(name)` | balance |
| `exports['fusion-core']:AddSocietyMoney(name, amount)` | `true` (`false` for amounts of 0 or less) |
| `exports['fusion-core']:RemoveSocietyMoney(name, amount)` | `true`, or `false` if the account doesn't have enough |

Amounts are whole dollars (decimals are dropped).

`exports['qb-management']:GetAccount / AddMoney / RemoveMoney / AddGangMoney / …` and `exports['qb-banking']:GetAccountBalance / AddMoney / RemoveMoney` answer with the same accounts, so QBCore job scripts work unchanged.

## Counting on-duty staff

```lua
local QBCore = exports['qb-core']:GetCoreObject()
local players, count = QBCore.Functions.GetPlayersOnDuty('police')   -- or GetDutyCount('police')
```
