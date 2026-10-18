# 12. Database

Fusion uses **oxmysql** (`MySQL.query.await`, `MySQL.insert.await`, …; add `server_script '@oxmysql/lib/MySQL.lua'` to your manifest). Fusion creates every table below on its first start.

**Prefer the API over SQL.** Write money, items, jobs and metadata through the functions in the earlier chapters: they keep online players, the HUD and other scripts in sync, and record transactions. A direct `UPDATE players …` on an online player is overwritten at their next save. Reading is fine.

## QBCore-compatible tables

Same columns as QBCore, so QBCore scripts' SQL keeps working.

| Table | Columns |
|---|---|
| `players` | `id`, `citizenid` (primary key), `cid`, `license`, `name`, `money` (JSON), `charinfo` (JSON), `job` (JSON), `gang` (JSON), `position` (JSON), `metadata` (JSON), `inventory` (JSON), `last_updated` |
| `player_vehicles` | `id`, `license`, `citizenid`, `vehicle` (model), `hash`, `mods` (JSON properties), `plate`, `fakeplate`, `garage`, `fuel`, `engine`, `body`, `state` (0 out, 1 garaged, 2 impounded), `depotprice`, `drivingdistance`, `status`, `balance`, `paymentamount`, `paymentsleft`, `financetime`, `nickname` |
| `playerskins` | `id`, `citizenid`, `model`, `skin` (JSON), `active` |
| `player_outfits` | `id`, `citizenid`, `outfitname`, `model`, `props`, `components`, `outfitId` |
| `bans` | `id`, `name`, `license`, `discord`, `ip`, `fivem`, `reason`, `expire` (unix time), `bannedby` |
| `management_funds` | `id`, `job_name`, `amount`, `type` (`boss` / `gang`) |
| `inventories` | `id`, `identifier` (stash, trunk or glovebox id), `items` (JSON) |

## Fusion tables

| Table | Columns | Holds |
|---|---|---|
| `fusion_registry` | `kind`, `name`, `data` (JSON) | items, jobs, gangs, vehicles |
| `fusion_settings` | `module`, `skey`, `value` (JSON), `updated_by`, `updated_at` | every settings page (only values changed from the default) |
| `fusion_kv` | `owner`, `kkey`, `value` (JSON) | `Fusion.KV` storage |
| `fusion_transactions` | `id`, `citizenid`, `account`, `amount`, `balance`, `reason`, `created_at` | money history |
| `fusion_logs` | `id`, `category`, `message`, `player`, `identifier`, `data`, `created_at` | F10 › Logs |
| `fusion_roles`, `fusion_role_permissions`, `fusion_role_members`, `fusion_custom_permissions` | | roles and permissions |
| `fusion_warnings` | `id`, `identifier`, `name`, `reason`, `issued_by`, `created_at` | staff warnings |
| `fusion_reports` | `id`, `kind`, `reporter`, `reporter_name`, `target`, `target_name`, `message`, `coords`, `status`, `claimed_by`, `note`, `created_at`, `closed_at` | player reports |
| `fusion_phone_contacts`, `fusion_phone_messages`, `fusion_phone_calls`, `fusion_phone_alerts` | | phone |
| `fusion_ac_detections` | | anticheat detections |

Don't write to `fusion_*` tables directly. Their layout may change between versions; the API won't.

## Your own tables

Create them with `CREATE TABLE IF NOT EXISTS` when your resource starts. Key character data by **`citizenid`** (`varchar(50)`), use `utf8mb4`, and delete rows on `fusion:server:characterDeleted`:

```lua
MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `courier_stats` (
        `citizenid` varchar(50) NOT NULL,
        `routes` int NOT NULL DEFAULT 0,
        `earned` int NOT NULL DEFAULT 0,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
end)

AddEventHandler('fusion:server:characterDeleted', function(citizenid)
    MySQL.query('DELETE FROM courier_stats WHERE citizenid = ?', { citizenid })
end)
```
