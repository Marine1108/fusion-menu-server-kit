# 4. Economy

## Money types

Every character has one balance per **money type**. Owners define them in **F10 › Settings › Economy › Money types**:

| Name | Default label | Starting amount | Can go below 0 |
|---|---|---|---|
| `cash` | Cash | 500 | no |
| `bank` | Bank | 5000 | yes |
| `crypto` | Crypto | 0 | no |

Owners can add more (e.g. `blackmoney`, `chips`). Read the list from `PlayerData.money` instead of assuming three:

```lua
for account, balance in pairs(Fusion.GetPlayerData(src).money) do print(account, balance) end
```

Use `cash` and `bank` for normal purchases. If your script needs its own currency, ask owners to add a money type and let them pick it with a setting (`type = 'select', source = 'moneyTypes'`, see [chapter 7](07-settings.md)).

## Adding and removing money (server)

| Call | Returns |
|---|---|
| `Fusion.AddMoney(src, account, amount, reason)` | `true`, or `false` (unknown account, negative amount, no character) |
| `Fusion.RemoveMoney(src, account, amount, reason)` | `true`, or `false` (not enough, unknown account) |
| `Fusion.GetMoney(src, account)` | balance (0 if unknown) |
| `Player.Functions.SetMoney(account, amount, reason)` | sets an exact balance |

Same as `Player.Functions.AddMoney(account, amount, reason)` and friends, and as the `exports['fusion-core']:AddMoney/RemoveMoney/GetMoney` exports.

**Always give a `reason`.** It is saved in the character's transaction history and shown to staff, e.g. `'car wash'`, `'fine: speeding'`, `'myscript reward'`. Amounts of 10,000 or more are also written to F10 › Logs.

### Charging a player

```lua
local price = 1500
if not Fusion.RemoveMoney(src, 'cash', price, 'tattoo') then
    if not Fusion.RemoveMoney(src, 'bank', price, 'tattoo (card)') then
        return Fusion.Notify(src, 'You can\'t afford this', 'error')
    end
end
-- give the thing
```

Check the result: **take the money first, then hand out the item or service**, and refund if handing it out fails.

### "Economy off" servers

Owners can turn the economy off (**Settings › Economy › Enable economy**) for a vMenu-style freeroam server. Then:

* `RemoveMoney` returns **`true` without taking anything**, so purchases, fines and fees just work and are free,
* money is hidden from the HUD, and paychecks, banks and giving cash are off.

Your script needs no special code for this. If you want to hide prices in your UI, check `Fusion.Settings.Get('economy', 'enabled') == false`.

## Events

| Event | Side | Arguments |
|---|---|---|
| `QBCore:Server:OnMoneyChange` | server | `src, account, amount, 'add' or 'remove', reason` |
| `QBCore:Client:OnMoneyChange` | client | `account, amount, 'add' or 'remove', reason` |
| `fusion:client:moneyChanged` | client | `account, amount, 'add' or 'remove', newBalance` |
| `hud:client:OnMoneyChange` | client | `account, amount, isRemove` (qb-hud style) |

## Paychecks

Every **Settings › Economy › Paycheck interval** minutes (default 15), each online player with a paying job receives their grade's `payment` into the **Pay into** account (default `bank`), if they are on duty or the job has `offDutyPay`. With **Pay from society funds** on, the money comes out of the job's society account and is skipped when it's empty. The reason is `paycheck`.

## Society accounts

Shared money for jobs and gangs; see [chapter 3](03-jobs-and-gangs.md#society-job-and-gang-money).

## Transaction history

When **Keep transaction history** is on, every change is stored in `fusion_transactions` (`citizenid, account, amount, balance, reason, created_at`; amounts are negative for removals). Read it directly if you build a banking app:

```lua
local rows = MySQL.query.await('SELECT account, amount, balance, reason, UNIX_TIMESTAMP(created_at) AS time FROM fusion_transactions WHERE citizenid = ? ORDER BY id DESC LIMIT 50', { citizenid })
```

## Banking

Banks and ATMs are built in (permission `economy.bank`). Giving cash to nearby players uses `economy.givecash`. A banking script of your own can sit alongside; use the money functions above rather than writing to the `players` table.
