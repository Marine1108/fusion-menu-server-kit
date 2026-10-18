# example-courier

A small, complete Fusion Menu integration to copy from. Couriers start a route at the depot, receive parcels addressed to drop-off points, and get paid per delivery.

| Feature | Where in the code | Guide chapter |
|---|---|---|
| Settings page with numbers, a slider, a money-type picker, a job picker, a position and a list of places | `server.lua`, `Fusion.Settings.Register` | [7](../../07-settings.md) |
| Permission nodes with default roles | `server.lua`, `Fusion.Perms.Register` | [6](../../06-permissions-and-roles.md) |
| Adding a job and an item only if missing | `server.lua`, `SaveRegistry` | [3](../../03-jobs-and-gangs.md), [5](../../05-items-and-inventory.md) |
| Server-validated callbacks (job, duty, permission, distance, cooldown) | `server.lua`, `Fusion.Callback.Register` | [9](../../09-callbacks-and-events.md), [13](../../13-best-practices.md) |
| Unique items with metadata (`info`) | `Fusion.AddItem` / `GetItemsByName` / `RemoveItem` by slot | [5](../../05-items-and-inventory.md) |
| Paying with a reason, plus a company share | `Fusion.AddMoney`, `AddSocietyMoney` | [4](../../04-economy.md) |
| Per-character stats in the key/value store | `Fusion.KV` | [9](../../09-callbacks-and-events.md) |
| Flagging a suspicious request | `exports['fusion-anticheat']:Flag` | [10](../../10-modules-and-world.md) |
| A menu and a main-menu (M) entry | `client.lua`, `Fusion.Menu.*` | [8](../../08-ui.md) |
| Third eye at the depot (qb-target API) | `client.lua`, `AddCircleZone` | [8](../../08-ui.md) |
| Progress bar, notifications, an `[E]` prompt using the player's key binding | `client.lua` | [8](../../08-ui.md) |
| Clean-up on character switch and resource stop | both files | [13](../../13-best-practices.md) |

## Try it

1. Copy the `example-courier` folder into `resources/[addons]` and restart (or `ensure example-courier`).
2. In game: **F10 › Players** › yourself › set job **Courier**.
3. Go to the depot: by default on Vinewood Blvd (`78.7, 111.9, 81.2`). Or stand anywhere and set it in **F10 › Settings › Courier › Depot** with *Use my position*.
4. Third eye (left Alt) on the depot spot › **Start a courier route**, or **M › Courier**.
5. Drive to the yellow blips and press **E**.
