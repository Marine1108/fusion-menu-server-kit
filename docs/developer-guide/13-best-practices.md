# 13. Best practices and release checklist

## Security

* **The server decides.** Clients can be modified and can trigger any event with any arguments. Every reward, payment, item, job change or permission check happens on the server, inside a callback or server event, after checking:
  * the player has a character (`Fusion.GetPlayerData(src)` isn't `nil`),
  * the permission (`Fusion.Perms.Has(src, node)`) or job (`pd.job.name`, `pd.job.onduty`),
  * the player is where they should be (`#(GetEntityCoords(GetPlayerPed(src)) - expected) < 10.0`),
  * amounts and item names are ones **you** chose (look them up from your settings; never take a price or reward from the client),
  * cooldowns (a client can call your event 100 times a second).
* Report impossible requests with `exports['fusion-anticheat']:Flag(src, 'yourscript_reason', details)` instead of silently ignoring them, so staff see who is probing your events.
* Never trigger Fusion's internal events (`fusion:*:client:*`, `fusion:internal:*`) and never write Fusion's state bags or `fusion_*` tables.
* Keep secrets (API keys, webhooks) in `private = true` settings fields: they never reach clients.

## Integration

* Use **permissions and settings** instead of config files and admin identifier lists. Owners expect to configure everything in F10.
* Let owners choose jobs, items, accounts and places through settings (`source = 'jobs'`, `'items'`, `'moneyTypes'`; `vector3` fields with "Use my position").
* Don't hard-code job names or labels: owners rename and delete jobs. Use job **types** (`leo`, `ems`) where you mean a group.
* Add your items and jobs **only if they're missing**, so owners' edits survive.
* Give every money change a clear `reason`.
* Use Fusion's UI (notifications, menus, progress, input, third eye) so your script matches the server's theme and the player's key bindings.
* Build prompts with `Fusion.Key.Label('interact')`, never a hard-coded "E".
* Check `IsModuleEnabled` before relying on an optional module (phone, voice, target…).
* Clean up on `fusion:client:playerUnloaded` (character switch) as well as `onResourceStop`.

## Performance

* No `while true do Wait(0)` loops that run all the time. Wait longer when the player is far away (`Wait(1000)` beyond 50 m, `Wait(0)` only when close), or use the third eye / zones.
* Read settings when you need them; they're cached locally, so `Fusion.Settings.Get` is cheap.
* Cache `Fusion.KV` and database reads; don't query per frame or per player per second.
* Use state bags for data every client needs instead of broadcasting events in a loop.

## Naming

* Don't name your resource `fusion-*`. That prefix is Fusion's, and Fusion's installers and update tools treat `fusion-*` folders as part of the framework.
* Prefix everything global: events (`courier:server:start`), callbacks (`courier:getRoute`), permission nodes (`courier.use`), settings modules (`courier`), metadata keys (`courier_level`), KV owners (`courier`).

## Linux servers

Many servers run Linux, where file names are **case-sensitive**: `Parcel.png` and `parcel.png` are different files, and so are `Client.lua` and `client.lua`. Match the case in `fxmanifest.lua`, `LoadResourceFile`, NUI paths and item `image` names exactly. Use lowercase file names to be safe.

## Paid scripts and Cfx.re escrow

Fusion itself is escrowed. If you sell your script with Asset Escrow too:

* `lua54 'yes'` is required.
* Files other resources load with `@yourscript/...`, and anything owners must read, go in `escrow_ignore`.
* Fusion's settings pages replace config files, so you usually don't need an editable `config.lua` at all.

## Where owners put your script

Owners install third-party scripts in `resources/[addons]` (or `[qb]` for QBCore scripts), optionally in sub-folders, and Fusion starts them automatically. Their `install-script` tool installs a zipped script and keeps their configs across updates. In your readme, list:

1. requirements (`fusion-core`, or QBCore, plus anything else),
2. item pictures to copy to `fusion-inventory/html/images/`,
3. what to configure in **F10 › Settings › Your Script** and which permissions to grant in **F10 › Roles & Permissions**.

## Release checklist

- [ ] Works on a fresh Fusion server with no extra config, using the defaults of your settings page
- [ ] Every server event and callback checks the player, permission or job, distance, amounts and cooldowns
- [ ] Permission nodes registered with labels, descriptions and sensible default roles
- [ ] Settings page has descriptions; private fields marked `private`
- [ ] Items and jobs added only when missing; pictures included and lowercase
- [ ] Money changes have reasons; purchases take money before handing out goods
- [ ] Works with the economy turned off
- [ ] No permanent `Wait(0)` loops; resmon below 0.05 ms idle
- [ ] Cleans up on resource stop and character switch
- [ ] Tested on Linux (or at least: all file names lowercase and matching)
- [ ] No resource name or global names starting with `fusion`
