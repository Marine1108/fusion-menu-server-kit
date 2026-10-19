# Fusion Menu — Server Owner's Guide

Fusion Menu is a complete FiveM server: a framework that **plays like vMenu**, **runs QBCore scripts without modification**, and is **configured entirely in game**. Settings, permissions, locations, jobs, items, vehicles, prices and every feature toggle live in the admin panel. The only files you ever add are pictures, music and new resources.

---

## Contents

1. [Folder layout](#1-folder-layout)
2. [Installing and first start](#2-installing-and-first-start)
3. [Becoming the owner and adding staff](#3-becoming-the-owner-and-adding-staff)
4. [The admin panel](#4-the-admin-panel)
5. [Roles and permissions](#5-roles-and-permissions)
6. [Turning features on and off](#6-turning-features-on-and-off)
7. [Feature guides](#7-feature-guides)
8. [Adding content](#8-adding-content)
9. [Running QBCore scripts](#9-running-qbcore-scripts)
10. [Keys and commands](#10-keys-and-commands)
11. [Backups and updates](#11-backups-and-updates)
12. [License](#12-license)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. Folder layout

```
FusionMenu/                          ← your server data folder
├─ install-windows.bat               ← Windows installer (double-click)
├─ install-linux.sh                  ← Linux / VPS installer
├─ update-fusion.bat / .sh           ← update Fusion Menu without losing your changes
├─ install-script.bat / .sh          ← install or upgrade QBCore scripts, vehicles, EUP, maps
├─ updates/                          ← put Fusion update zips here
├─ backups/                          ← automatic backups made by the two tools above
├─ recipe.yaml                       ← txAdmin one-click recipe
├─ install/                          ← installer files and the server.cfg template
├─ server.cfg                        ← written by the installer
└─ resources/
   ├─ [cfx-default]                  ← standard FiveM resources (chat, spawnmanager…)
   ├─ [fusion]                       ← the framework, do not remove anything here
   │  ├─ oxmysql                     database driver
   │  ├─ fusion-core                 settings, permissions, characters, economy, jobs, admin panel, UI
   │  ├─ fusion-anticheat            anticheat: detections, honeypots, entity & explosion protection
   │  ├─ fusion-loadscreen           loading screen
   │  ├─ fusion-target               third-eye targeting (hold Left Alt)
   │  ├─ fusion-inventory            inventory, stashes, trunks, drops
   │  ├─ fusion-vehicles             spawner, vehicle options, garages, keys
   │  ├─ fusion-emergency            siren controller, police radar and plate reader
   │  ├─ fusion-phone                phone: calls, texts, contacts, 911, bank, weather, web, emergency / AMBER alerts
   │  ├─ fusion-voice                proximity voice, radio and phone call audio (pma-voice compatible)
   │  ├─ fusion-postalmap            the illustrated pause map with postal codes and place names (F10 › Postal Map)
   │  ├─ fusion-vinewood             the hillside sign: your own text, colours and night glow (F10 › Vinewood Sign)
   │  ├─ fusion-weapons              weapon spawner, loadouts, weapon wheel
   │  ├─ fusion-appearance           character creator, clothing, EUP uniforms
   │  ├─ fusion-stores               shops
   │  ├─ fusion-fuel                 fuel and gas stations
   │  ├─ fusion-hospital             death, respawning, EMS
   │  ├─ fusion-jail                 prison
   │  ├─ fusion-weather              weather and time sync
   │  └─ [compat]                    qb-core, qb-menu, qb-input, progressbar (QBCore compatibility)
   ├─ [standalone]
   │  └─ screenshot-basic            screenshots for other scripts (CCTV, evidence, MDTs, phone cameras)
   ├─ [qb]                           ← put QBCore scripts here
   └─ [addons]                       ← put vehicles, EUP, peds, maps here
```

Everything in `[qb]` and `[addons]` starts automatically, so you normally never edit `server.cfg` to add content. The only exception is scripts that must start in a particular order ([section 8](#scripts-that-must-start-in-a-certain-order)).

---

## 2. Installing and first start

**You need:** a FiveM server license key (free at [portal.cfx.re](https://portal.cfx.re) › Server Registration Keys). The installers download and set up everything else: the database (MariaDB), FXServer and txAdmin. If you set things up by hand: MySQL or MariaDB, and FXServer build 12913 or newer.

**Getting Fusion Menu:** after buying, sign in at [portal.cfx.re](https://portal.cfx.re) with the same Cfx.re account and open **Granted Assets**. Fusion Menu is protected by Cfx.re, so only you can download it, and it only runs on servers whose license key belongs to that account. Download the zip there; the installers below find it and put it in the right place for you. Everything else (the free server kit, database, FXServer) is downloaded by the installer.

Pick the one that matches where your server runs.

### Option A: Your own Windows PC (one click)

1. Download Fusion Menu from portal.cfx.re › Granted Assets (leave it in your **Downloads** folder).
2. Download **[FusionMenu-Setup.bat](https://github.com/Marine1108/fusion-menu-server-kit/releases/latest/download/FusionMenu-Setup.bat)** and double-click it. Click **Yes** when Windows asks for permission. (If Windows says *"Windows protected your PC"*, click **More info › Run anyway**.)
3. Answer the questions (press Enter for the suggested answer). The setup:
   * downloads the server kit into `C:\FusionServer` (or a folder you choose) and unpacks your Fusion Menu zip into it,
   * **sets up the database so it starts by itself with Windows.** You never have to open XAMPP:
     * no database yet → it installs **MariaDB** as a background Windows service,
     * XAMPP installed → it turns XAMPP's MySQL into a Windows service,
     * your own MySQL → it just asks for the login,
   * creates the database and a login just for Fusion (saved in `database-login.txt`, keep it private),
   * asks for your license key, server name, players, port and (optionally) your identifier, and writes `server.cfg`,
   * downloads the recommended **FXServer** build to `C:\FXServer`,
   * opens the port in the Windows firewall and, if you like, starts the server when you log in to Windows,
   * puts **Start Fusion Server** and **Fusion txAdmin** shortcuts on your desktop.
4. Double-click **Start Fusion Server**. That's it.

Already have the kit folder? Double-click `install-windows.bat` inside it instead; it does the same from step 3.

### Option B: Your own Linux VPS (one command, Ubuntu / Debian)

1. Upload the Fusion Menu zip from portal.cfx.re to the VPS (WinSCP or FileZilla, e.g. into `/root`).
2. Run:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/Marine1108/fusion-menu-server-kit/main/setup/get-fusion.sh | sudo bash
   ```
3. Answer the questions. It downloads the server kit to `/home/fivem/fusion`, finds and unpacks your Fusion Menu zip, installs **MariaDB** with a random password, writes `server.cfg`, downloads **FXServer** to `/opt/fxserver`, creates a **`fusion` systemd service** (starts on boot, with or without the txAdmin web panel) and opens the firewall ports.
4. **txAdmin mode:** open `http://YOUR_SERVER_IP:40120`, enter the PIN from `journalctl -u fusion -f`, choose **Existing server data** with the Fusion folder and `server.cfg`, turn OneSync on and start. **Direct mode:** the server is already running (`systemctl start|stop|restart fusion`, logs: `journalctl -u fusion -f`).

### Option C: A game server host (ZAP-Hosting and others with txAdmin)

1. In the host's panel, open **txAdmin** and start the setup. Choose **Popular Template › Remote URL Template** and paste:
   ```
   https://raw.githubusercontent.com/Marine1108/fusion-menu-server-kit/main/recipe.yaml
   ```
2. Enter your license key. For the database, use the details from your host's panel (most hosts fill them in for you). txAdmin downloads the server kit, creates the database, writes `server.cfg` and makes your txAdmin account the owner. OneSync is turned on for you.
3. Upload Fusion Menu: unzip the file from portal.cfx.re on your PC, then upload its folders into **`resources/[fusion]`** with the host's **File Manager** or FTP (next to `oxmysql`).
4. Start the server in txAdmin.

### Option D: Your own server with txAdmin's recipe

Prefer txAdmin's recipe on your own PC or VPS instead of Option A or B? txAdmin's database step needs a database login it can sign in to with a password, which a fresh machine doesn't have. Set one up first:

* **Linux VPS (Ubuntu / Debian):** run
  ```bash
  curl -fsSL https://raw.githubusercontent.com/Marine1108/fusion-menu-server-kit/main/setup/prepare-database.sh | sudo bash
  ```
  It installs MariaDB if needed, creates the login `txadmin` with a random password, and prints what to type in txAdmin's database step (also saved in `~/fusion-database-login.txt`).
* **Windows:** install a database that starts with Windows, e.g. run **FusionMenu-Setup.bat** once (it installs MariaDB and saves the login in `database-login.txt`), or use XAMPP's MySQL (user `root`, no password). Using the setup? Then you don't need the recipe at all, see below.

Then follow Option C, steps 1–4, using that login on the database step.

> **Already ran the Windows setup or the Linux installer?** Don't use the recipe: everything is set up. In txAdmin choose **Existing Server Data** and point it at the server folder (the installer prints the exact paths; on Linux with txAdmin it's `/opt/fxserver/txData/fusion`). Running the recipe as well would create a second, separate server.

Players connect on port **30120** (TCP and UDP) unless you chose another. txAdmin uses **40120**. If friends outside your home can't join a server on your own PC, forward port 30120 on your router.

### First start

The console ends with:
```
[Fusion] Ready - open the admin panel in game with /admin (or F10)
```
Join the server, and press **F10** once you are the owner (see below).

### What players see when joining

Loading screen → **player guide** (first visit only) → character selection → **spawn selector** → in the city. New characters get the appearance editor right after spawning.

---

## 3. Becoming the owner and adding staff

**Owners** always have every permission. You become one in any of these ways:

* **Claim code (easiest):** if no owner is set, the server console shows
  `Join the server and type: /claimowner ABC123`. Type that in the in-game chat. The code works once and changes every restart until it's used.
* **Installer / txAdmin:** the identifier you enter (or your txAdmin account) is added to `group.admin`, and everyone in `group.admin` is an owner.
* **Server console:** `fusion_role <server id or identifier> superadmin`.

Everyone else is managed in game.

**To add staff:** F10 › **Roles & Permissions** › pick a role › **Members** › **Add online player** (or **Add by identifier** for someone offline: `license:…`, `discord:…`, `fivem:…`, `steam:…`).

**From the server console:**
```
fusion_role <server id or identifier> <role>
fusion_role license:abc123… admin
```

---

## 4. The admin panel

Open with **F10** or `/admin`. Each tab only appears for staff with the matching permission.

| Tab | What you can do |
|---|---|
| **Dashboard** | Players online, staff online, characters, bans, uptime, recent activity, quick actions (noclip, teleport to waypoint, announcement, delete empty vehicles) |
| **Players** | Search online players. Open one to: go to / bring, spectate, revive, heal, freeze, open inventory, message, send to character select, kill, warn, kick, ban, give/take/set money, set job and gang, give/remove items, clear inventory, add/remove roles, see identifiers and warnings |
| **Characters** | Search every character (online or offline). Edit names, money and job, or delete a character |
| **Reports** | Player reports and admin requests: claim, go to, bring, message, close with a note. A red badge shows how many are open |
| **Bans** | Search bans, unban, ban an identifier of someone who is offline |
| **Roles & Permissions** | Create roles, set allow/deny rules, manage members, add permission nodes for other scripts ([section 5](#5-roles-and-permissions)) |
| **Settings** | One page per module, plus every location in the server. Export / Import backs up all settings |
| **Jobs / Gangs** | Create and edit jobs and gangs: grades, paychecks, boss grades, duty behaviour, whitelisting |
| **Items** | Create and edit items: label, weight, picture, description, usable, unique, and what happens when used (hunger, thirst, health, armour, stress, animation) |
| **Vehicles** | The vehicle catalogue (every vanilla and addon vehicle): names, brands, prices, class, picture, hidden, permission or job restrictions |
| **Handling** | In-game handling editor for addon vehicles. Saves straight into the vehicle's `handling.meta` |
| **Anticheat** | Every detection with player, details and the action taken. Filter by detection, search, open the player, ban them, delete false positives, clear old detections |
| **Logs** | Searchable history of admin actions, money, items, connections, jobs, settings and permission changes |
| **Server** | Announcements, clean-up tools (empty vehicles, NPCs, props), the **vehicle meta (carcols) fixer**, and start / stop / restart for any resource |

### Using your position in settings

Every location setting (garages, stores, stashes, hospitals, banks, spawns, teleports…) has a **Here** button that fills in your current position and heading. When you add a new entry to a list, it starts at your position automatically. Stand where you want the thing, click **Add**, give it a name, done.

### Staff hierarchy

Each role has a **priority**. Staff can only kick, ban, warn, freeze, kill or log out players whose priority is lower than their own, and can only hand out roles below their own. Owners are exempt.

---

## 5. Roles and permissions

### Default roles

| Role | Priority | Inherits | Has |
|---|---|---|---|
| **Player** (`user`) | 0 | — | Everyday features. **Every player has this role.** |
| **Moderator** | 50 | Player | Admin panel, kick, warn, freeze, revive, heal, teleport, spectate, noclip, logs… |
| **Admin** | 100 | Moderator | `admin.*` (everything admin) |
| **Owner** (`superadmin`) | 1000 | Admin | `*` (everything). Cannot be deleted |

You can rename, recolour, re-prioritise and re-wire all of these, and create as many new roles as you like (e.g. *LSPD Command*, *Trusted*, *Donator*).

### How a permission is decided

On the **Permissions** tab, every permission has three buttons: **Allow**, **Inherit** and **Deny**.

* **Inherit** means the role doesn't decide it; the role it inherits from does. The grey/green text shows the current result and which role it came from.
* **Wildcards:** `admin.*` covers every node starting with `admin.`, and `*` covers everything. Add them under *Wildcard & custom rules*.
* **The most specific rule wins.** `vehicles.godmode = Deny` beats `vehicles.* = Allow`. A deny beats an allow when they are equally specific.
* A player with several roles gets the combination of all of them.

### Permissions for other scripts (ACE)

Fusion mirrors every role to FiveM's ACE system as `group.fusion_<role>`, so standalone scripts that use `IsPlayerAceAllowed` or restricted commands follow your in-game roles.

| The script checks… | Do this |
|---|---|
| An ACE permission such as `cctv.view` | Open the role › **Wildcard & custom rules** › type `cctv.view` › **Allow** › **Add rule**. Several at once: `cctv.view, cctv.record, cctv.playback`; all of a script's permissions: `cctv.*` |
| A restricted command such as `/carwash` | Add the rule `command.carwash` and allow it |
| QBCore permission levels (`admin`, `god`, `mod`) | Allow `qbcore.admin`, `qbcore.god` or `qbcore.mod` on a role |
| A job ("police only") | Nothing; jobs are edited in **Jobs** |

> Scripts that keep their own admin list inside their `config.lua` (identifiers, Discord roles) cannot be controlled from Fusion. That list still lives in the script.

### Useful permission nodes

| Area | Nodes |
|---|---|
| General | `menu.open`, `server.whitelisted`, `server.maintenance`, `characters.extraslots`, `guide.open`, `reports.create` |
| Player menu | `player.menu`, `player.godmode`, `player.invisible`, `player.heal`, `player.stamina`, `player.fastrun`, `player.superjump`, `player.noragdoll`, `player.walkstyle`, `player.scenarios` |
| Misc | `misc.tpwaypoint`, `misc.teleports`, `misc.coords`, `misc.nightvision`, `misc.thermal` |
| Admin | `admin.panel`, `admin.players`, `admin.kick`, `admin.ban`, `admin.unban`, `admin.warn`, `admin.money`, `admin.items`, `admin.setjob`, `admin.roles`, `admin.permissions`, `admin.settings`, `admin.jobs`, `admin.registry`, `admin.logs`, `admin.resources`, `admin.noclip`, `admin.spectate`, `admin.blips`, `admin.names`, `admin.reports`, `admin.handling`, `admin.carcols`, `admin.anticheat` |
| Vehicles | `vehicles.spawn`, `vehicles.spawn.byname`, `vehicles.spawn.free`, `vehicles.class.<class>` (e.g. `vehicles.class.emergency`), `vehicles.addons`, `vehicles.extras`, `vehicles.livery`, `vehicles.mods`, `vehicles.godmode`, `vehicles.performance`, `vehicles.garage`, `vehicles.keys.all` |
| Weapons | `weapons.spawn`, `weapons.category.<category>` (e.g. `weapons.category.heavy`), `weapons.all`, `weapons.attachments`, `weapons.unlimitedammo`, `weapons.loadouts` |
| Appearance | `appearance.anywhere`, `appearance.face`, `appearance.peds`, `appearance.uniforms`, `appearance.uniforms.manage`, `appearance.free` |
| Anticheat | `anticheat.bypass` (never flagged; admins by default), `anticheat.manage` (delete detections), `admin.anticheat` (Anticheat tab and staff alerts) |
| Emergency | `emergency.siren`, `emergency.radar`, `emergency.bolo` |
| Phone | `phone.use`, `phone.amber`, `admin.alerts` |
| Other | `inventory.search`, `stores.free`, `fuel.free`, `hospital.revive`, `jail.use`, `weather.change`, `weather.events`, `time.change` |

The **Permissions** tab lists every node with a description, so you don't need to memorise these.

---

## 6. Turning features on and off

### Replacing a Fusion module with another script

Every Fusion module can be swapped for a script you prefer. In **Settings › Modules**, turn off *Use Fusion's phone* (or inventory, voice, targeting, fuel, garages, hospital, jail, stores, weapons, appearance, sirens/radar, weather, loading screen or anticheat), then install the replacement in `resources/[qb]`. Fusion stops its own module straight away and after every restart, and the rest of Fusion keeps working without it. Turn the switch back on to return to Fusion's version. `install-script` refuses scripts Fusion already replaces until you turn Fusion's version off and run it with `-Force` (`--force` on Linux).

Every module has a page in **F10 › Settings**, and the first switch on it turns the whole module on or off. Changes apply instantly for everyone.

| Settings page | Main switch | Notes |
|---|---|---|
| Economy | **Enable economy** | Off = everything free, money hidden, no paychecks / banks / giving cash |
| Jobs & Gangs | Enable job features | |
| Vehicles | Enable vehicle module | Spawner, saved vehicles, keys and seatbelt also have their own switches |
| Garages & Impound | Enable garages | |
| Emergency Vehicles | Enable emergency vehicle features | Siren controller and radar each have their own switch |
| Weapons | Enable weapon module | **Mode:** free (vMenu) or inventory items (RP) |
| Appearance & EUP | Enable appearance module | *Editor available anywhere* vs stores only |
| Inventory | Enable inventory | Hotbar, giving and dropping have their own switches |
| Stores | Enable stores | |
| Fuel & Gas Stations | Enable fuel | Off = vehicles never run out |
| Hospital & Death | Enable hospital module | **Death mode:** respawn (vMenu) or downed/bleed-out (RP) |
| Jail | Enable jail | |
| Weather & Time | Sync weather & time | |
| Targeting | Enable targeting | |
| Player Guide | Show the guide to new players | |
| Map Blips | Show these blips | Police and fire stations and custom map icons |
| Anticheat | Enable anticheat | Each detection can also be set to off / log / alert / kick / ban |
| Reports & Help | Enable reports | Player reports, admin requests and questions can each be turned off |
| Gameplay | — | Hunger & thirst, PvP, wanted level, NPC/traffic density, HUD parts, player blips and names |

**To hide a feature from some players only,** take away its permission instead (e.g. remove `player.godmode` from Player).

> Stopping a resource on the **Server** tab only lasts until the next restart. Use the switches above for permanent changes.

---

## 7. Feature guides

### Server, branding and interface

* **Settings › Server:** server name, server-list description and tags (update live), Discord link, autosave interval, **whitelist** (only `server.whitelisted` can join), **maintenance mode** (only `server.maintenance` can join), join/leave messages.
* **Settings › Interface:** menu title, subtitle and logo, accent colours, panel colour and opacity, menu position (left/right/center) and size, notification position, money pop-ups, HUD, menu sounds, and whether players can walk/drive with the menu open.
* **Logo:** the menu shows the Fusion logo until you set your own: put a PNG in `resources/[fusion]/fusion-core/html/img/`, run `ensure fusion-core`, and type the file name in *Logo*. To show no logo at all, leave *Logo* empty and turn off *Show the Fusion logo when no logo is set*.

### HUD and vehicle HUD

* Players see their server ID, cash, bank, job and status (noclip, jail…). In a vehicle they get the **vehicle HUD**: speed, gear, RPM, fuel (or battery), engine warning, seatbelt, lock status, street and compass.
* **Every player can move their own HUD:** *Menu › Misc Settings › Edit HUD Layout* or `/hud`. Drag anything (cash, bank, job, status, vehicle HUD, notifications, progress bar, prompts) where you want it, and right-click to hide or show it. **Reset** restores the defaults. Layouts are saved per player.
* **Settings › Interface › HUD:** turn the HUD, vehicle HUD and street/compass on or off, and decide whether players may move the HUD. Speed units (MPH / KM/H) are in **Settings › Vehicles**.

### Reports and admin requests

* Players open **Menu › Help & Reports** to request an admin to their location, report a player, or send a question / bug report. Chat shortcuts: `/calladmin <reason>` and `/report <message>`.
* Staff with `admin.reports` get an alert with a sound. **F10 › Reports** (or `/reports`) lists open reports, with a red badge showing how many. Staff can **Claim** (the player is told who is helping), **Go to** the player or the report location, **Bring** them, **Message** them, open their player page, and **Close** with a note the player sees. Reports are kept in the database and in **Logs**.
* **Settings › Reports & Help:** turn each report type on or off, set the cooldown and the maximum open reports per player, and choose whether staff hear a sound.

### Map blips (police stations, fire stations, anything else)

**Settings › Map Blips** comes with every vanilla police and fire station already on the map.

* **Add a location** (e.g. a new Paleto Bay police MLO): stand at it, click **Add**, give it a name and pick a **Type** (police, sheriff, fire, hospital, courthouse, city hall, mechanic, or custom). The icon appears on everyone's map **immediately**, with no restart.
* **Moved or removed a station?** Click **Here** to move it, untick **Shown** to hide it, or delete the entry.
* **Custom** blips take any icon and colour number from the [FiveM blip list](https://docs.fivem.net/docs/game-references/blips/).
* A blip can be limited to one job (e.g. a private police garage only police see).
* *Only show on the minimap when nearby* keeps the minimap tidy. Blips always show on the full map.

Banks, garages, stores, gas stations and hospitals put their own blips on the map from their own location lists, and those update live too.

### Loading screen

**Settings › Loading Screen:** title, subtitle, logo, accent colour, layout (left / centered / minimal), background images (slideshow), background video, darkness, music playlist and volume, rotating tips, rules, staff list and links.

Media goes in `resources/[fusion]/fusion-loadscreen/html/media/`. After adding files, run `ensure fusion-loadscreen`, then type the file names (e.g. `city.jpg`, `theme.mp3`). URLs work too. Reconnect to see it.

### Player guide

A short slideshow shown **once per player** (per Rockstar account) before they pick a character.

* **Settings › Player Guide:** title, pages (title, text, picture), whether it can be skipped, and whether it appears in the main menu as *Server Guide*.
* **Formatting in page text:** `**bold**`, lines starting with `- ` become bullet points, `[M]` shows a key cap, a blank line starts a new paragraph. `{server}` and `{player}` are replaced with the server and player name.
* **Changed the guide?** Raise **Guide version** by 1 and everyone sees it once more on their next join.
* Players reopen it any time with `/guide`.

### Characters and spawning

* **Settings › Characters:** multiple characters on/off, number of slots (plus extra slots for `characters.extraslots`), deleting and switching characters, nationalities list, **starter items** for new characters, and whether new characters open the appearance editor.
* **Settings › Spawning:** spawn mode (**spawn selector**, last location, or always the default spawn), whether new characters use the selector, the default spawn point, *Last Location* in the selector, camera height, and the **selector locations**. Each location can be limited to a job or a permission.
* **Settings › Teleport Locations:** the staff teleport list in *Menu › Misc Settings*.

### Economy and banking

* **Settings › Economy:** the master switch, money types and starting amounts (cash, bank, crypto, or add your own), whether a type may go negative, paycheck interval and account, paying from society funds, bank and ATM locations, ATM prop models, transfers, and giving cash.
* Paychecks come from each job grade's pay (set in **Jobs**) and are paid on duty, or off duty if the job allows it.
* Bosses manage society funds at any bank (*deposit / withdraw*).

### Jobs, gangs and boss menus

* **Jobs / Gangs tabs:** create jobs, add grades with pay, and mark boss grades. Job *type* (`leo`, `ems`, `mechanic`…) is what QBCore scripts look at.
* **Settings › Jobs & Gangs:** default job, remembering duty, toggling duty and opening the boss menu from the menu anywhere, the **job center** list (jobs players can take themselves), and **duty / boss locations**.
* Players use **Menu › Job**: duty toggle, job center, and the boss menu (hire the nearest player, promote, demote, fire, society balance).

### Inventory and items

* **Settings › Inventory:** carry weight and slots, hotbar, giving and dropping items, drop despawn time, trunk and glovebox sizes, which jobs may search players, robbing downed players, and **stashes**. A stash can be shared or **personal** (every character gets their own), and limited to a job or permission.
* **Items tab:** create any item. To make it consumable, fill in *When used*: hunger/thirst/health/armour/stress amounts, *Consume* = 1 to use it up, and an animation (eat, drink, smoke, bandage, pills).
* **Item pictures:** they live in `resources/[fusion]/fusion-inventory/html/images/`.
  1. Create the item in **F10 › Items › New item**. Its *Internal name* (the small grey text on each tile) is what the picture is matched to, e.g. `energy_drink`.
  2. Put a PNG named after it in that folder: `energy_drink.png`. A transparent background around 100×100 pixels looks best.
  3. Type `ensure fusion-inventory` in the txAdmin console. New files are only picked up when the resource restarts.

  Every default item and weapon already comes with its own picture, made for Fusion Menu, so you only need to add pictures for items you create. Putting a file with the same name in the folder replaces the built-in one.

  Weapons share one picture per type (handguns, SMGs, rifles, shotguns, snipers, machine guns, heavy, melee, throwables, misc), saved as `weapon_<name>.png` so you can replace any single weapon's picture. Addon weapons added in game use `weapontype_<type>.png` until you give them their own. An item with no picture shows its category's picture (`category_<category>.png`), and if that is missing too, an icon.

  The picture then shows everywhere: inventory, item pop-ups, stores and the admin panel. To use a different file name, or a web link (no restart needed), open the item in **F10 › Items** and set **Image**. Names must match exactly, including lowercase: on a Linux VPS `Energy_Drink.png` and `energy_drink.png` are different files. Until an item has a picture it shows its category icon. Items added by QBCore scripts use the same folder (copy in the images that come with the script), and qb-inventory's pictures work as-is because Fusion uses the same item names.
* Players: **I** opens the inventory. Drag to move, right-click to use, drop items on *Use / Give / Drop*, set an amount to split a stack. At a vehicle's boot it opens the trunk; inside a vehicle, the glovebox.

### Vehicles, garages and keys

* **Spawner:** every vanilla and **addon** vehicle appears automatically, sorted by class. Addon packs (anything in `resources/[addons]` with a `vehicles.meta`) also get their own **Addon Vehicles** section. Packs started while the server is running (`ensure mypack`) show up within a few seconds, without players reconnecting. **Settings › Vehicles** controls spawning inside, replacing the previous vehicle, spawn cost (flat or catalogue price), cooldown, plate format (`#` digit, `@` letter), list or picture-grid layout, saved vehicles, keys, locking NPC cars, the seatbelt and ejection speed.
* **Vehicles tab:** rename vehicles, set brand, price and class, hide a vehicle from the spawner, or restrict it to a permission or job (e.g. police cars for `police` only).
* **Vehicle Options** (in a vehicle): repair, wash, flip, god mode, engine, doors, windows, seats, **extras**, **liveries**, mod menu, wheels, colours, neon and headlights, plate text and style, torque/power, speed limiter, give keys, delete.
* **Settings › Garages & Impound:** garage and impound locations (car, air or boat; optional job), shared garages, **storing spawned vehicles** (they become owned, mods and all), max owned per character, impound fee, and sending vehicles left out to the impound on restart.
* **Vehicle pictures:** `resources/[fusion]/fusion-vehicles/html/images/<model>.png`, then `ensure fusion-vehicles`.

### Siren controller and police radar

**Siren controller** (any vehicle in GTA's emergency class, plus models you add):

| Key | Action |
|---|---|
| Q | Emergency lights on / off |
| R | Siren on / off (turns the lights on too) |
| Y | Next siren tone |
| E (hold) | Air horn |

An on-screen **siren controller** (a control head with lit LIGHTS, SIREN and HORN buttons and a button for every tone) sits next to the speedometer. Press **F6** to use it with the mouse while you keep driving; F6 again gives the mouse back. Hide it from **Menu › Emergency** (or with `/hud`). Each vehicle only gets the tones of its service, like real US units:

| Service | Tones (Y cycles) | Air horn |
|---|---|---|
| Police / sheriff | Wail, Yelp, Priority, Wail 2, Yelp 2 | Air horn |
| EMS / ambulance | Wail, Yelp, Hi-Lo, Phaser | Air horn |
| Fire | Mech Wail, Mech Yelp (mechanical fire siren), Wail, Yelp | Fire truck horn |

The vanilla ambulance and lifeguard are EMS and the fire truck is fire; addon vehicles are sorted by name (*amb*, *ems*, *medic*, *rescue* → EMS; *fire*, *ladder*, *pumper*, *tanker*, *brush* → fire), and everything else in the emergency class uses police tones. Change any of this in **Settings › Emergency Vehicles › Siren** (EMS models, fire models, always-police models). **Your own siren sounds:** put an `.ogg` or `.mp3` recording in `resources/[fusion]/fusion-core/html/sounds`, run `ensure fusion-core`, and add a tone in **Settings › Emergency Vehicles › Siren tones** with that file name as its *Recording* (a web link works too). Every nearby player hears it from the vehicle, louder as it gets closer. Air horns can use recordings too, and *Recorded sirens are heard up to* / *Recorded siren volume* tune them. Server-side siren packs (audio banks) still work by entering their sound name, sound set and audio bank instead. Everyone nearby hears the same siren, synced through the server. The same controls are in **Menu › Emergency**.

**Police radar and plate reader:**

| Key | Action |
|---|---|
| F5 | Radar power on / off |
| Numpad 8 / Numpad 5 | Lock / unlock the **front** / **rear** speed |
| Numpad 9 / Numpad 6 | Lock / unlock the **front** / **rear** plate |
| F6 | Radar remote (and the siren controller) with the mouse |

Front and rear lock separately, like a real unit: locking the front never locks the rear. The on-screen **radar unit** shows your patrol speed and, for each antenna, the nearest target's speed, the fastest vehicle in the beam, lock lamps and the plate. The **radar remote** (F6) has every button: power, front / rear antenna on-off, the four locks, auto-lock and the speed alarm. Hide the radar display from **Menu › Emergency** or with `/hud`. The plate reader shows the nearest front and rear plates. **Menu › Emergency** adds a speed alarm (with optional auto-lock), **Run plate** (registered owner and model from the database), and the **BOLO list**: when the reader sees a BOLO plate it locks, beeps and shows the reason.

**Settings › Emergency Vehicles:** turn the siren controller and radar on or off; which jobs may use each (empty = anyone for sirens; police by default for the radar) and whether they must be on duty; extra models for unmarked cars and addon packs outside the emergency class; whether the front passenger can work the siren; what happens when the driver gets out; the **siren tones** (name, sound, and optional sound set / audio bank for server-side siren packs, limited to certain models if you like); the air horn sound; radar range and beam width; plate reader range; and the BOLO list.

Permissions: `emergency.siren` (everyone by default), `emergency.radar` and `emergency.bolo` (radar and BOLOs regardless of job; admins by default). Everyone can rebind the keys in *GTA Settings › Key Bindings › FiveM*, and move both panels with `/hud`.

### Phone

Players open the phone with **F1** (rebindable) or by using the **phone** item from the inventory. Every character has their own number (the same one QBCore scripts see).

| App | What it does |
|---|---|
| **Phone** | Keypad, recent calls and contacts. Calling rings the other player; the call connects with voice through **Fusion Voice** (or pma-voice / mumble-voip if you use those instead) |
| **Messages** | Text conversations with other players, with unread counts and a new-message alert |
| **Contacts** | Add, edit and delete contacts; call or text them in one tap |
| **911** | Dial or text the emergency number to describe what's happening. On-duty police / EMS get the call with your name, number, **postal** and a flashing map marker |
| **Bank** | Bank and cash balance, and sending money to another player's number |
| **Alerts** | Every emergency alert received. Police (and staff) can issue an **AMBER Alert** from here |
| **Weather** | The current conditions and temperature, what is coming next (the server plans its weather ahead, so the forecast is real), and any severe weather warning |
| **Web** | A browser with the bookmarks you set (Discord, rules, wiki, store…). Optionally players can type any address. Some websites refuse to be shown inside apps and stay blank |
| **Settings** | Your number, wallpaper, and turning AMBER Alerts on or off (other emergency alerts cannot be turned off, like a real phone) |

**Emergency alerts** appear as a banner at the top of the screen with the real two-tone alert sound (853 + 960 Hz), on every phone at once. Severe weather events send a warning automatically; an AMBER Alert lists the child, suspect, vehicle and plate, and the plate goes straight onto the police radar's **BOLO** list. Staff can send any alert from **F10 › Alerts**, which also shows the history.

**Settings › Phone:** turn the phone on or off, whether players need the phone item (and which item), which apps are available, wallpapers (built-in or your own pictures), how long calls ring, how long texts are kept, the emergency number, which jobs receive 911 calls and whether they must be on duty, how long 911 calls stay on the map, automatic weather alerts, the alert sound and volume, whether players without a phone still see alerts, which jobs may issue AMBER Alerts, and whether AMBER plates become BOLOs. Permissions: `phone.use`, `phone.amber`, `admin.alerts`.

### Voice and radio (Fusion Voice)

Fusion has its own voice system built on FiveM's voice chat, so no pma-voice is needed. Players talk with their normal push-to-talk key (GTA Settings › Voice Chat).

* **Ranges:** **F11** cycles Whisper / Normal / Shout (a circle shows the range). The HUD shows your range, radio channel, call and a green glow while you talk.
* **Radio:** **Menu › Radio** or `/radio 12` to join a channel (`/radio 0` to turn it off), then hold **Caps Lock** to talk. Everyone on the channel hears you anywhere on the map, with a radio effect and mic clicks. Restricted channels (e.g. 1–10 for police and EMS) and needing a radio item are settings.
* **Calls:** phone calls are heard clearly from anywhere.
* QBCore scripts written for pma-voice (radios, phones, MDTs) work with Fusion Voice automatically.

**Settings › Voice & Radio:** turn Fusion Voice on or off, the ranges and distances, the starting range, the HUD, radios on or off, the radio item, the highest channel, restricted channels and their jobs, radio and call volume, the radio effect, mic clicks and the radio animation. If pma-voice is running, Fusion Voice switches itself off.

### Postal codes

The nearest **postal code** shows next to the street name on the vehicle HUD and on the on-foot location line (*Menu › Misc › Show Location*), and on reports and 911 calls. Type `/postal 1234` to set a waypoint to a postal, or `/postal` to clear it.

**Settings › Postal Codes:** turn it on or off, choose the postal set (*New postals*, *OCRP postals*, *Old postals*, or your own file in `fusion-core/data/postals`), show the distance, the `/postal` command, and postals on reports. **Fusion's postal map** (`fusion-postalmap`) draws the same postal set on the pause-menu map, so the map always matches the HUD and `/postal`. Turn off *Draw the postal codes on the pause map* if you prefer another postal map pack in `resources/[addons]`. For your own postal file, make its map with `tools/postal-map` (see the README there). Scripts written for *nearest-postal* (CAD/MDT systems and others) get their postal from Fusion automatically.

### Postal map (F10 › Postal Map)

The pause map is Fusion's own illustrated map, with the postal codes and place names drawn on by the server. In **F10 › Postal Map** you can drag postals and names around, add a postal by clicking the map or **where you stand**, rename or delete them, and start from the New, OCRP or Old set. **Save & redraw map** redraws it (a few seconds) and reloads it for every player; the HUD, `/postal`, reports and 911 calls use the same postals. **Settings › Postal Map** turns the place names on or off and sets the postal badge size and colour.

### Vinewood sign (F10 › Vinewood Sign)

The sign on the hill is Fusion's own: two rows of up to **12 characters** (letters, numbers and `! ? . - ' &`), the back row higher up the hill behind the front row. Pick a colour per row (or a fade from one colour to another), the night effect (steady glow, slow pulse, chasing lights, sparkle, rainbow or none), whether it lights up the hillside at night, the hand-built look (slightly uneven letters like the real sign) and the daytime brightness. The editor shows a live day and night preview; **Save to the sign** changes it for everyone straight away. The letters stand on legs that run into the hill, so nothing floats, and GTA's own sign is gone at every distance while the Vinewood module runs (turn the module off to get GTA's VINEWOOD back).

**Settings › Vinewood Sign › Letters** picks how they're made:
* **3D models** (default): solid letters in a real sign typeface (Oswald Bold), lit by the sun by day and glowing by themselves at night, with every colour, fade and night effect.
* **Drawn letters**: simple flat-shaded letters, with adjustable letter sizes.

Colours: click a colour box to open the colour picker (any colour, plus quick swatches). The same picker is used for every colour in F10.

Slurs and hate words are always refused (also when spelled with numbers or symbols, spaced out or split over both rows), and online staff get a warning naming who tried. **Settings › Vinewood Sign** sets letter sizes and positions, also blocking swear words, your own blocked and always-allowed words, and the staff warning. Permission: `admin.vinewood`.

### Handling editor

**F10 › Handling** edits an addon vehicle's handling and saves it into the pack's own `handling.meta` on the server.

1. Get in the vehicle and click **Load my vehicle** (or type its model name). Fusion finds its handling entry through the pack's `vehicles.meta`, even when the handling has a different name than the model.
2. Change any line: mass, drag, centre of mass, gears, power, top speed, brakes, steering lock, grip, suspension, anti-roll bars, damage multipliers, flags and more. Each line shows what it does and its original value. Use **Filter fields** to find one quickly. Each line also shows its **safe range**; values outside it turn red and are refused, because they break the vehicle in game (for example a centre of mass far below the car makes it hover).
3. Click **Save to server files**. Only the lines you changed are rewritten, and the original file is backed up first.
   * With **Apply now** ticked (the default), the pack is reloaded straight away and you are respawned in the vehicle with the new handling. Vehicles of that model on the server are removed first, because reloading a pack while its vehicles exist can crash players.
   * Without it, the change applies at the next restart.
4. **Backups / undo** restores any earlier save with one click.

Vanilla GTA vehicles keep their handling inside the game files, so only addon vehicles can be edited. Protected (escrowed) packs are shown read-only. Needs the `admin.handling` permission (admins have it). Like the carcols fixer, a newly added pack can be edited after the next server restart.

### Vehicle meta (carcols) fixer

When two vehicle packs use the same **siren**, **light settings** or **modkit** ID, cars get the wrong sirens or lightbar patterns, or lose liveries and mods. **F10 › Server › Vehicle meta (carcols) fixer** solves this:

1. **Scan vehicle packs:** reads every resource's `carcols.meta` and `carvariations.meta` and lists each clashing ID, which pack keeps it, and which packs need a new one.
2. **Fix:** gives the clashing packs unused IDs and updates their `carcols.meta` and `carvariations.meta` together, so vehicles keep their own sirens, lights and mods. IDs keep their style: small siren/light IDs stay within 100-255 for older game builds, large ones stay large.
3. **Restart the server** so players download the fixed packs.

* Every changed file is backed up first (`fusion-core/carcols-backups`). **Backups / undo** restores any fix with one click.
* **Protected (escrowed)** packs can't be edited. The tool keeps their IDs and changes the other pack instead; a clash between two protected packs is reported for their authors to fix.
* Needs the `admin.carcols` permission (admins have it). FiveM only lets Fusion edit a pack that is listed in `resources/[fusion]/fusion-core/permissions/filesystem.cfg`; Fusion rebuilds that file at every start and `server.cfg` runs it. A pack you add is editable **after the next restart**.

### Weapons

* **Settings › Weapons:** free mode (vMenu style) or inventory items, ammo given, weapons hidden from the spawner, keeping weapons after death and relog, replacing GTA's TAB wheel with the Fusion wheel, and **job loadouts** (pick weapons, jobs, optional permission, on-duty only, auto-attachments).
* Players get **Menu › Weapons**: spawner by category, attachments, tints, ammo, unlimited ammo / no reload (staff), personal loadouts with *equip on spawn*, and the weapon wheel (`/wheel`).
* Weapon categories are permissions (`weapons.category.heavy`…), so you can, for example, allow handguns to everyone and rifles only to police.
* **Addon weapons:**
  1. Put the weapon pack in `resources/[addons]` and restart.
  2. Add it under **Settings › Weapons › Custom / addon weapons** with its spawn name (e.g. `weapon_glock19`), display name, category and ammo type.
  3. It appears in the spawner, becomes an inventory item, and is included in `QBCore.Shared.Weapons`. Add a picture as `fusion-weapons/html/images/<spawn name>.png`.

### Appearance and EUP

* **Settings › Appearance & EUP:** editor anywhere vs stores only, clothing / barber / surgeon prices, **store locations** (a store with a job becomes a free locker room), **uniform presets**, and the ped model list.
* **Creating EUP uniforms:**
  1. Dress your character (Menu › Appearance › Clothing; **Set By Number** jumps straight to an EUP drawable).
  2. Go to **Appearance › Uniforms › Save Current Outfit As Uniform**, and give it a name, department, jobs and a minimum grade.
  3. Fine-tune or add a picture later in **Settings › Appearance & EUP › Uniform presets**.
* **Uniform pictures:** `resources/[fusion]/fusion-appearance/html/images/`, then `ensure fusion-appearance`.
* **Adding EUP or other clothing packs:** put the pack in `resources/[addons]` and restart. Its clothing shows up in the editor automatically, after the vanilla items in each slot. Use **Set By Number** to jump straight to a drawable.

### Stores

**Settings › Stores:** **catalogues** (what is sold, prices, and an optional licence such as `weapon`) and **store locations** (catalogue, blip, optional shopkeeper ped, optional job). Choose between a menu list and the inventory shop screen (drag to buy). Paying by card when cash is short is optional.

### Fuel

**Settings › Fuel & Gas Stations:** consumption overall and per vehicle class, price per litre, jerry can price, refuel speed, pump and EV-charger props, electric vehicles, low-fuel warning, NPC vehicle fuel, and station blips. Pumps work at every gas station automatically.

### Hospital and death

**Settings › Hospital & Death:**

* **Respawn mode (vMenu):** short timer, then respawn at the nearest hospital or where you died.
* **Downed mode (RP):** players go down, then die after a timer. EMS revive them with the revive item (first aid kit), or they respawn after bleeding out, paying a bill and optionally losing items (with a keep list).
* EMS jobs, alerts to on-duty EMS, check-in desks (cost, treatment time, disabled when enough EMS are on duty), and hospital locations.

### Jail

**Settings › Jail:** jobs allowed to jail, the longest sentence, confiscating items (returned on release, with a keep list), time counting offline, cell, release point, escape radius, and what happens on escape. Police use **Menu › Jail** or `/jail <id> <minutes> <charges>`.

### Weather and time

**Settings › Weather & Time:** dynamic weather and cycle length, allowed weather types, weather after restart, snow on the ground, blackout, day length, freezing time, and real-world time with an offset. Staff also get **Menu › Weather & Time** for instant changes.

**Road conditions.** Weather changes how vehicles handle: rain makes the roads wet (grip and braking drop, and roads take a few minutes to dry once it stops), snow cuts grip further, a blizzard leaves the roads icy, and driving fast through standing or flood water makes a car aquaplane. Off-road vehicles and SUVs cope better in snow. The HUD shows *Wet roads*, *Snow on roads* or *Icy roads* while you drive. Adjust or turn it off in **Settings › Weather & Time › Road conditions**: grip on wet, snowy and icy roads, drying time, the off-road bonus, aquaplaning and the HUD label. Only grip and braking change, scaled from each vehicle's own handling, and they return to normal when conditions clear or you get out.

**Outdoor warning sirens.** Civil-defence sirens on poles around the map sound for tornadoes and hurricanes (choose which events in settings). You hear the nearest one, from its direction, quieter indoors. Fusion makes the siren sound itself (*wail*, *steady*, *hi-lo* or *whoop*), or plays a recording you add to `fusion-core/html/sounds` (or a web link). **Settings › Weather & Time › Outdoor sirens:** the events, the signal for tornadoes and for other events, recordings, how long they sound and how often they repeat, volume, the siren poles (name, position, range) and showing them on the map.

**Severe weather events.** Staff start them from **Menu › Weather & Time › Severe Weather** (or `/weatherevent <type>` / `/weatherevent stop`), or let them happen at random. Everyone gets an alert banner with a countdown first, the HUD shows the time left, and every player sees the same event:

| Event | What happens |
|---|---|
| **Thunderstorm** | Heavy rain, strong wind, rough sea and lightning strikes around players (they can hurt people on foot and stall cars) |
| **Flood** | Torrential rain while the sea, rivers and lakes rise (3 m by default): the docks, low coastal roads and riverbanks go under, then the water drains away |
| **Hurricane** | Winds build to maximum, huge waves, a storm surge, a power cut across the city, lightning, and gusts that shove vehicles sideways |
| **Tornado** | A spinning funnel travels across the map towards players, shown on the map with a danger zone. It pulls in and lifts vehicles, people and loose objects, and hurts anyone caught inside |
| **Blizzard** | Heavy snow, snow covering the ground and roads, strong wind and low visibility, with optional icy roads |

**Settings › Weather & Time › Severe weather:** turn events on or off, the warning time, random events (chance per hour, which types, minimum players), each event's length, lightning strikes and damage, flood height and how fast it rises, hurricane surge, gusts and power cut, tornado size, speed, strength and damage, and icy roads. Permission: `weather.events` (admins by default).

> The tornado funnel is built from GTA's own smoke effects. If you prefer another look, change the particle asset and effect under *Severe weather* (advanced).

### Targeting (third eye)

Hold **Left Alt** and look at something. Options appear, and clicking selects one. QBCore scripts add their options automatically. **Settings › Targeting** sets ray length, default distance, outlines and a zone debug view.

### Anticheat

Fusion's anticheat runs mostly on the server, reading what the game reports about each player, so a cheat menu can't hide from it by blocking a script on the player's PC. **Settings › Anticheat** controls everything, and **F10 › Anticheat** lists what it has caught.

**What it detects**

| Detection | Default action | How |
|---|---|---|
| God mode | Kick | Player is invincible without `player.godmode` (downed/dead players are ignored) |
| Health / armour above maximum | Kick | More health or armour than the game allows |
| Invisible | Alert | Invisible without `player.invisible`, noclip or spectate permission |
| Teleport / speed hack on foot | Log | Moved further than possible. Logs only by default, because some QBCore housing and apartment scripts teleport players |
| Impossible vehicle speed | Alert | Cars and bikes faster than the limit (aircraft and boats are ignored) |
| Blacklisted weapon | Alert | Holding a blacklisted weapon without the spawn permission for its category. The weapon is removed |
| Entity spam | Kick | Spawning vehicles, peds or props faster than the limit. Extra spawns are blocked |
| Blacklisted model | Alert | Spawning a blacklisted vehicle, ped or prop. The spawn is blocked. Vehicles taken from the spawner or a garage are allowed |
| Explosion spam | Kick | More explosions than the limit. Extra explosions are blocked |
| Modded explosion | Ban | Invisible or boosted explosions, or blacklisted types (orbital cannon, railgun…) |
| Honeypot event | Ban | Triggered a fake event that only cheat menus use |
| Injected resource | Ban | A resource started on the player's PC that doesn't exist on the server |
| Anticheat client stopped | Kick | The anticheat stopped answering on the player's PC, or they stopped a Fusion resource |
| Cheat menu command | Ban | A known cheat menu's command exists on the player's PC |
| Weapon damage modifier | Kick | Weapon or melee damage boosted |
| Spectating without permission | Kick | Spectator mode without `admin.spectate` |
| Night / thermal vision | Alert | Without `misc.nightvision` / `misc.thermal` |

**Actions:** *Off*, *Log only* (saved in F10 › Anticheat and Logs), *Log + alert staff* (staff with `admin.anticheat` get a notification with a sound), *Kick* or *Ban*. Bans go into the normal **Bans** list; set the length with *Ban length in hours* (0 = permanent).

**Settings › Anticheat** also has:

* **Thresholds:** god mode checks before acting, teleport speed, max vehicle speed, entity spawn limits and explosion limit.
* **Blacklists:** weapons, models, explosion types, honeypot event names and cheat-menu commands. Thresholds and blacklists are private and never sent to players' PCs.

**Avoiding false positives**

* Admins have `anticheat.bypass` and are never flagged. Give it to anyone else you trust (testers, developers) in **Roles & Permissions**.
* Start new detections on *Log only* or *Alert*, check **F10 › Anticheat** for a few days, then switch to kick or ban.
* If a QBCore script of yours uses one of the honeypot event names, remove that name from the list.
* If a job or script hands out a blacklisted weapon (for example a SWAT armory giving out grenade launchers), give that job's role the `weapons.category.<category>` permission or remove the weapon from the blacklist.
* Delete a false positive with the bin icon on its row (`anticheat.manage`).

> No anticheat catches everything. This one stops the common menus and abuse; pair it with active staff and the Reports system.

### Logging and Discord

**Settings › Logging:** turn logging on or off, mirror to the console, retention days, skip categories, and **Discord webhooks** (one for everything, or one per category). Webhook URLs are private and never sent to players.

---

## 8. Adding content

**The easy way (recommended):** stop the server, then drag the script's or pack's `.zip` (or folder) onto **`install-script.bat`** (Windows) or run `bash install-script.sh /path/to/pack.zip` (Linux). It works out where it belongs (scripts go to `[qb]`; vehicles, EUP, maps and peds to `[addons]`), refuses scripts Fusion already replaces, and upgrades a script you already have **without losing your config changes** ([section 11](#11-backups-and-updates)).

**By hand:**

| You want to add… | Put it in | Then |
|---|---|---|
| A QBCore script | `resources/[qb]/<script>` | Restart the server (or `ensure <script>`) |
| Addon vehicles | `resources/[addons]/<pack>` | Restart. They appear in the spawner and **Vehicles** tab by themselves |
| EUP / clothing packs | `resources/[addons]/<pack>` | Restart, then build uniforms in game |
| Maps / MLOs / peds | `resources/[addons]/<pack>` | Restart |
| Item / vehicle / weapon / uniform pictures | the module's `html/images` folder | `ensure` that module |
| Loading screen media | `fusion-loadscreen/html/media` | `ensure fusion-loadscreen` |

New files inside a resource are only picked up when that resource restarts. That's why you run `ensure`.

**On a Linux VPS:** files you upload with WinSCP or FileZilla logged in as `root`, or unzip with `sudo`, belong to root instead of the user the server runs as, and Fusion can't save into them (carcols fixer, handling editor, postal map). The Linux installer handles this for you: every minute it gives anything in the server folder back to the server user, so you never need to fix ownership yourself. To avoid it entirely, log WinSCP in as the server user (e.g. `ubuntu`) instead of `root`. Installed before this was added? Run `sudo chown -R ubuntu:ubuntu /home/fivem/fusion` after adding content (with your own user and folder).

### Scripts that must start in a certain order

`server.cfg` starts each of `[qb]` and `[addons]` with one line (`ensure [qb]`), and FiveM doesn't promise any order **inside** a folder. On Linux it often isn't even alphabetical. Most scripts don't care. For scripts that need another one running first (their readme usually says so):

1. Put them in `resources/[standalone]`, **not** in `[qb]` or `[addons]`. `ensure [qb]` would start, or restart, everything in `[qb]` in its own order.
2. Start them by name in `server.cfg`, in the right order, **above** `ensure [qb]`:

```
ensure screenshot-basic
ensure eyewitness
ensure overwatch
ensure [qb]
ensure [addons]
```

If a script's `fxmanifest.lua` already lists the other one as a `dependency`, FiveM handles the order itself and it can stay in `[qb]`.

### screenshot-basic is included

Many scripts take screenshots of the game view: CCTV and evidence scripts (e.g. Eyewitness), MDTs, phone cameras. They need **screenshot-basic**. Fusion's server kit includes it, already built, in `resources/[standalone]/screenshot-basic`, and `server.cfg` starts it before `[qb]` and `[addons]`, so it's always running first.

* **Don't install a second copy** in `[qb]` or `[addons]`. Two resources with the same name conflict. If a script's instructions tell you to install screenshot-basic, it's already done.
* **Servers set up before it was included:** copy `resources/[standalone]/screenshot-basic` from the latest server kit into your server, and add `ensure screenshot-basic` just above `ensure [qb]` in `server.cfg`.

### Organising [qb] and [addons] into sub-folders

You can group content into sub-folders, as deep as you like, as long as **every grouping folder has square brackets**:

```
resources/[addons]/
├─ [cars]/
│  ├─ [police]/lspd-pack/      ✓ starts
│  └─ [civilian]/supercars/    ✓ starts
├─ [eup]/my-eup-pack/          ✓ starts
├─ cars/mypack/                ✗ "cars" has no brackets: the server ignores everything inside
└─ mypack/mypack/              ✗ zip extracted one folder too deep: move the inner folder up
```

A folder **with** brackets is a category (just for organising). A folder **without** brackets is a resource and must contain `fxmanifest.lua` directly. Resource names must be unique across the whole server, wherever they sit.

Fusion backs this up in two ways (**Settings › Server › Resources**):

* 15 seconds after boot it starts anything in sub-folders of `[qb]` / `[addons]` that didn't start (switch this off, or list resources to leave stopped);
* folders the server can't see, like the two ✗ examples above, are listed in the server console when it starts, as *"&lt;folder&gt; does not have a resource manifest"*.

Vehicles, EUP, weapons, the carcols fixer and the handling editor all find packs in sub-folders automatically. **New vehicle packs and the carcols fixer / handling editor:** after adding a pack, restart the whole server once before fixing or editing it. FiveM only lets Fusion save into packs it knew about when the server started. Then fix, and restart again so players download the fixed pack. To install straight into a sub-folder: `install/update.ps1 -Mode script -Source pack.zip -Target "[addons]/[cars]"` (Linux: `bash install-script.sh pack.zip --target "[addons]/[cars]"`), or install normally and move the folder afterwards: upgrades find it wherever it is.

Your own pictures and media stay yours: Fusion updates never overwrite them, and they are never part of a Fusion release.

---

## 9. Running QBCore scripts

Fusion provides the full QBCore API:

* `exports['qb-core']:GetCoreObject()`, `QBCore.Functions.*`, the player object (`Player.Functions.AddMoney`, `SetJob`, `AddItem`…), callbacks, commands, usable items, and `QBCore.Shared` items, jobs, gangs, vehicles and weapons.
* The standard `QBCore:*` events (player loaded/unloaded, job and duty updates, notifications…).
* QBCore's database tables: `players`, `player_vehicles`, `playerskins`, `player_outfits`, `bans`, `management_funds`, `inventories`.
* Exports from `qb-inventory`, `qb-target`, `qb-menu`, `qb-input`, `progressbar`, `qb-weathersync`, `qb-vehiclekeys`, `qb-management`, `qb-banking`, `LegacyFuel` / `cdn-fuel` / `ps-fuel`, and the common `hospital:*` and `prison:*` events.

**Do not install these. Fusion already does their job, and installing them causes conflicts:**
`qb-core`, `qb-inventory`, `qb-target`, `qb-menu`, `qb-input`, `progressbar`, `qb-multicharacter`, `qb-spawn`, `qb-apartments` (spawn part), `qb-garages`, `qb-shops`, `qb-clothing`, `illenium-appearance`, `qb-vehiclekeys`, `qb-weathersync`, `qb-ambulancejob`, `qb-prison`, `qb-management`, `qb-banking`, `LegacyFuel`, `qb-hud` (money/fuel shown by Fusion).

**Good to know:**

* Scripts that use **PolyZone** directly need the PolyZone resource in `[qb]`.
* Items and jobs a QBCore script registers through `exports['qb-core']:AddItem` / `AddJob` are saved and then editable in the admin panel.
* QBCore permission levels map to the nodes `qbcore.mod`, `qbcore.admin` and `qbcore.god`.
* Most QBCore scripts work as-is, but a script that relies on the internals of a specific QB resource may need small fixes.

---

## 10. Keys and commands

### Default keys

Every key below is a FiveM key binding: each player can change it in *GTA Settings › Key Bindings › FiveM* (look for names starting with **Fusion**). Prompts on screen always show the key the player chose.

| Key | Action | Who |
|---|---|---|
| **M** | Main menu | Everyone |
| **I** | Inventory | Everyone |
| **1 – 5** | Use hotbar slot 1–5 | Everyone |
| **E** | Interact: stores, garages, impounds, pumps, stashes, banks / ATMs, duty points, clothing stores, hospital check-in, respawn | Everyone |
| **G** | Second interaction: boss menu at a duty point, buy a jerry can | Everyone |
| **X** | Cancel the current action / progress bar | Everyone |
| **L** | Lock / unlock vehicle | Everyone |
| **B** | Seatbelt | Everyone |
| **Left Alt** (hold) | Third eye / target | Everyone |
| **Left mouse** | Pick the third-eye option you are looking at | Everyone |
| **Caps Lock** | Mouse cursor in the menu | Everyone |
| **F1** | Phone | Everyone |
| **↑ ↓ ← →**, **Enter**, **Backspace** | Menu: move, change value, select, back | Everyone |
| **TAB** | Fusion weapon wheel (when *Replace GTA's weapon wheel* is on) | Everyone |
| **Q / R / Y**, hold **E** | Emergency lights / siren / next tone / air horn (in emergency vehicles) | Per job / permission |
| **F5** | Police radar power | Per job / permission |
| **Numpad 8 / 5** | Lock front / rear radar speed | Per job / permission |
| **Numpad 9 / 6** | Lock front / rear radar plate | Per job / permission |
| **F6** | Siren controller / radar remote with the mouse | Per job / permission |
| **F11** | Voice range (whisper / normal / shout) | Everyone |
| **Caps Lock** (hold) | Talk on the radio | Everyone with a radio |
| **F10** | Admin panel | Staff |
| **Home** | Noclip on / off | Staff |
| **Q / E**, **Left Shift / Left Ctrl** | Noclip up / down, faster / slower | Staff |
| **Backspace** | Stop spectating | Staff |
| **Delete** | Delete the entity under the entity laser | Staff |

Three things follow GTA's own controls instead (change them in GTA's normal key bindings): walking in noclip and turning your character in the appearance editor (your walking keys), **Esc** to close the menu, and the controller D-pad in menus.

In the menu: **↑↓** move, **←→** change values, **Enter** select, **Backspace** back, **Esc** close. Players can keep walking and driving while it's open.

### Commands

| Command | Who | What |
|---|---|---|
| `/admin` | Staff | Admin panel |
| `/guide` | Everyone | Reopen the player guide |
| `/hud` | Everyone | Move or hide HUD elements |
| `/calladmin [reason]`, `/report <message>` | Everyone | Ask staff for help |
| `/reports` | Staff | Open the Reports tab |
| `/noclip` | Staff | Toggle noclip |
| `/car <model>`, `/dv`, `/fix` | Per permission | Spawn, delete or repair a vehicle |
| `/wheel` | Everyone | Weapon wheel |
| `/duty`, `/job`, `/cash`, `/bank` | Everyone | Duty and info |
| `/logout` | Everyone | Back to character selection |
| `/kick`, `/ban <id> <hours> <reason>`, `/warn` | Staff | Moderation (0 hours = permanent) |
| `/revive [id]`, `/heal [id]`, `/goto`, `/bring`, `/freeze`, `/kill` | Staff | Player actions |
| `/setjob <id> <job> <grade>`, `/setgang` | Staff | Jobs |
| `/givemoney <id> <account> <amount>`, `/setmoney`, `/giveitem <id> <item> <amount>` | Staff | Money and items |
| `/setrole <id> <role>`, `/removerole` | Staff | Roles |
| `/announce <message>` | Staff | Server announcement |
| `/jail <id> <minutes> <charges>`, `/unjail <id>` | Police / staff | Jail |
| `/weather <type>`, `/time <h> <m>`, `/blackout` | Staff | Weather and time |
| `/weatherevent thunderstorm\|flood\|hurricane\|tornado\|blizzard\|stop` | Staff | Severe weather events |
| `/setfuel <0-100>` | Staff | Set your vehicle's fuel |
| `/postal [code]` | Everyone | Waypoint to a postal code (empty clears it) |
| `/claimowner <code>` | Anyone (once) | Become owner of a server that has none (code is in the server console) |
| `fusion_role <id|identifier> <role>` | Server console | Grant a role without being in game |

---

## 11. Backups and updates

* **Settings backup:** F10 › Settings › **Export** copies every setting as text. **Import** restores it.
* **Full backup:** back up the `fusion` database (phpMyAdmin › Export, or `mysqldump fusion > fusion.sql` on Linux) and the server folder. Everything Fusion knows lives in those two places.
### Updating Fusion Menu

1. Download the new version from your **Cfx.re keymaster** (Granted Assets) and put the zip in the `updates` folder.
2. Stop the server (txAdmin › Stop server, or `sudo systemctl stop fusion`).
3. Run **`update-fusion.bat`** (Windows) or `bash update-fusion.sh` (Linux).
4. Start the server.

The updater:

* backs up every Fusion resource, your `server.cfg` and the **database** to `backups/<date>/` first (the database backup needs `mysqldump`, which XAMPP and MariaDB include);
* replaces the framework files, removes files the new version no longer uses, and installs new modules (adding their `ensure` line to `server.cfg`);
* **keeps everything you changed or added**: logos, loading screen media, item / vehicle / weapon / uniform pictures, and any file you edited;
* refuses to install an older version over a newer one (add `-Force` / `--force` if you really mean to).

Your settings, roles, jobs, items, characters and vehicles live in the database and are untouched; new settings simply appear with their defaults. Never replace the `[fusion]` folders by hand. That throws away your pictures and media.

### Upgrading QBCore scripts and packs

Drag the new version onto **`install-script.bat`** (or `bash install-script.sh new-version.zip`). Files you changed (`config.lua`, locales, anything else) are kept, and the script's new version of each one is saved next to it as **`config.lua.new`**. Open both, copy over any new options you want, then delete the `.new` file.

The very first upgrade of a script you installed by hand keeps its config and locale files (`config*.lua`, `config/`, `locales/`, `.cfg`); every install after that tracks exactly which files you edited.

### How it knows what you changed

Each install writes a `.fusion-install.sha256` file into the resource folder: a fingerprint of every file it put there. On the next update, a file that still matches its fingerprint is replaced; a file that doesn't (you edited it) is kept. Leave this file in place. Every run also writes `report.txt` into its backup folder.

To roll back, stop the server and copy the resource folders from `backups/<date>/` back into `resources` (restore `database.sql` with phpMyAdmin › Import if needed).

---

## 12. License

Fusion Menu is licensed, not sold (see `LICENSE`). You may use and modify it on servers you own or operate. You may **not** resell, share or redistribute it, original or modified, and the *Fusion Menu by Fusion Menu Studios* credit must stay. oxmysql (LGPL-3.0) and the default Cfx.re resources (MIT) keep their own licenses.

---

## 13. Troubleshooting

**Asking for help:** open a ticket on our Discord (https://discord.gg/kVRqwDPsnJ) and attach a support file:
1. **F10 › Support › Create support file**, or type `fusionsupport` in the server console if F10 won't open.
2. It's saved as `resources/[fusion]/fusion-core/support/fusion-support-<date>.txt`. F10 also has **Copy everything**.

It holds your Fusion build number (also shown at the bottom right of the loading screen), the FXServer and txAdmin
versions, every resource and whether it started, the latest Fusion log and the latest 2500 lines of the server
console. Passwords, license keys, database logins, webhooks and players' IP addresses are blanked out.

| Problem | Fix |
|---|---|
| Console: *You lack the required entitlement* for a fusion resource | The server's license key belongs to a different Cfx.re account than the one that bought Fusion Menu. Use a key from the buying account |
| Console: *Still waiting for the database* | MySQL isn't running, or the database doesn't exist. Start MySQL (XAMPP) or `systemctl start mariadb` (Linux) and run the installer again |
| Console runs old resources (vMenu, missing cars…) | txAdmin's *CFG File* still points at another server's `server.cfg` |
| Stuck on a camera view or blank screen | Press F8 and type `nui_devtools` to see interface errors; send them to whoever maintains your server |
| A picture doesn't show | Check the file name matches exactly (including `.png`) and `ensure` the resource |
| A third-party script ignores your roles | Find the permission name it uses and add it under **Custom nodes** ([section 5](#5-roles-and-permissions)) |
| A QBCore script can't find `qb-xxx` | Check it isn't on the *do not install* list. If it needs PolyZone, add PolyZone to `[qb]` |
| Locked out of the admin panel | Run `fusion_role <your server id> superadmin` in the server console |
| Linux: resources or pictures not found | File names are case-sensitive on Linux. `Car.png` and `car.png` are different files |
| VPS: players can't connect | Open port 30120 TCP and UDP in your provider's firewall as well as `ufw` |
| An updated script misbehaves | Look for `.new` files in its folder: the new version may need options your kept `config.lua` doesn't have. Or roll back from `backups/<date>/` |
| The updater says the server is running | Stop it in txAdmin (or `sudo systemctl stop fusion`) and run it again |
| Carcols fixer or handling editor says FiveM refused to edit a pack | Restart the server once (new packs need one restart). If it repeats, check `server.cfg` contains `exec resources/[fusion]/fusion-core/permissions/filesystem.cfg` |
| Players spawn in the wrong place | Check **Settings › Spawning** (spawn mode and locations) |
| A legit player was kicked or banned by the anticheat | Look at their row in **F10 › Anticheat** to see why. Unban them in **Bans**, then set that detection to *Log only*, raise its threshold, or give them `anticheat.bypass` |
