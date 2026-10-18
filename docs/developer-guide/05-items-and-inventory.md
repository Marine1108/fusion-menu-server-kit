# 5. Items and inventory

## Item definitions

Items live in the item **registry** (database), edited in **F10 › Items**. Same shape as `QBCore.Shared.Items`; default item names match QBCore, so QBCore scripts find the items they expect.

```lua
water_bottle = {
    name = 'water_bottle',      -- internal name: letters, numbers, _ and -
    label = 'Bottle of Water',
    weight = 500,               -- grams
    type = 'item',              -- 'item' or 'weapon'
    image = 'water_bottle.png', -- file in fusion-inventory/html/images, or a web link
    unique = false,             -- true: never stacks (each has its own info)
    useable = true,
    shouldClose = true,         -- close the inventory when used
    description = 'For all the thirsty out there',
    category = 'food',          -- picks the fallback picture and the admin filter
    price = 5,                  -- default store price
    ammotype = nil,             -- weapons and ammo: 'AMMO_PISTOL', …
    effects = { thirst = 35, anim = 'drink', remove = 1 },   -- optional, see "Consumables"
}
```

Read them with `Fusion.GetItem(name)` (server), `exports['fusion-core']:GetItemDefinition(name)`, or the whole registry with `exports['fusion-core']:GetRegistry('items')` (server and client).

### Adding your script's items

Add them only if they don't exist yet, so owners' edits survive restarts:

```lua
CreateThread(function()
    Fusion.Ready()
    if not Fusion.GetItem('courier_parcel') then
        exports['fusion-core']:SaveRegistry('items', 'courier_parcel', {
            label = 'Parcel', weight = 1500, unique = true, useable = false,
            description = 'Deliver it to the address on the label', category = 'misc', image = 'courier_parcel.png',
        })
    end
end)
```

`exports['qb-core']:AddItem(name, data)` (QBCore style) works too and is saved the same way.

### Item pictures

Pictures are in `resources/[fusion]/fusion-inventory/html/images/`, matched by the item's `image` (default `<name>.png`). Ship yours with your script and tell owners to copy them there (or set `image` to a web link). PNG with a transparent background, about 100×100. **Lowercase file names**: Linux servers are case-sensitive. Items without a picture fall back to `category_<category>.png`, then an icon.

## A player's items

`PlayerData.items` is a table keyed by slot:

```lua
[3] = {
    name = 'courier_parcel', label = 'Parcel', amount = 1, slot = 3,
    info = { address = '1337 Vinewood Blvd', serial = 'P-10442' },   -- per-item metadata
    weight = 1500, type = 'item', unique = true, useable = false,
    image = 'courier_parcel.png', description = '…', category = 'misc',
}
```

`info` is free-form metadata you control (serial numbers, quality, owner…). Unique items each keep their own `info`; stackable items with different `info` don't stack.

| Server call | Returns |
|---|---|
| `Fusion.AddItem(src, name, amount, info, slot)` | `true`, or `false` (unknown item, no space, too heavy) |
| `Fusion.RemoveItem(src, name, amount, slot)` | `true`, or `false` (not enough) |
| `Fusion.HasItem(src, items, amount)` | `items` is a name, a list of names (all needed) or `{ name = amount, … }` |
| `exports['fusion-core']:GetPlayerItems(src)` | the items table |
| `Player.Functions.GetItemByName(name)` / `GetItemsByName(name)` / `GetItemBySlot(slot)` | item(s) |
| `Player.Functions.SetItemInfo(slot, info)` | updates one item's metadata |
| `Player.Functions.GetTotalWeight()` | grams |
| `exports['fusion-core']:GetInventoryLimits()` | `maxSlots, maxWeight` (owner settings, default 41 and 120000) |

Client: `exports['fusion-core']:HasItem(items, amount)`.

When the inventory changes: `fusion:server:inventoryUpdated` (server, `src`) and `fusion:client:inventoryUpdated` (client).

Show the "item added/removed" pop-up like QBCore: `TriggerClientEvent('inventory:client:ItemBox', src, Fusion.GetItem(name), 'add', amount)` (`'remove'` / `'use'`).

## Usable items

```lua
exports['fusion-core']:CreateUseableItem('courier_scanner', function(src, item)
    -- item is the slot's item table (name, slot, info, …)
    TriggerClientEvent('myscript:client:scan', src, item.info)
end)
```

The QBCore way, `QBCore.Functions.CreateUseableItem(name, cb)`, is identical. The item must have `useable = true` to show the Use option. `exports['fusion-inventory']:UseItem(src, item)` uses an item for a player from code.

## Consumables (no code needed)

Items with `effects` are used up by the inventory itself, with an animation and progress bar:

| Field | Effect |
|---|---|
| `hunger`, `thirst` | added (to a max of 100) |
| `stress` | removed |
| `health`, `armor` | added on the client |
| `anim` | `eat`, `drink`, `smoke`, `bandage` or `pills` |
| `remove` | how many are used up (usually 1; 0 for reusable items) |

A registered usable-item callback takes priority over `effects`.

## Stashes, shops and other containers

| Server export (`fusion-inventory`) | What it does |
|---|---|
| `OpenStash(src, id, label, slots, maxWeight)` | Opens a saved stash. `id` is yours to choose: `'myscript_locker_' .. citizenid` makes a personal one, `'myscript_evidence'` a shared one |
| `OpenShop(src, id, label, products, account)` | Opens a store. `products = { { name = 'water_bottle', price = 5, amount = 50, info = {} }, … }`, `account` defaults to `cash` (falls back to bank) |
| `GetContainer(id)` | Snapshot of an open or loaded container (`items`, `slots`, `weight`, …) |
| `UseItem(src, item)` | Uses an item as if the player clicked it |

Client (`fusion-inventory`): `OpenInventory()` (own inventory), `CloseInventory()`, `IsOpen()`.

Purchases fire `fusion:inventory:server:purchased` (server: `src, itemName, amount, cost, shopLabel`).

QBCore flows also work: `TriggerServerEvent('inventory:server:OpenInventory', 'stash', id, { maxweight = 100000, slots = 50 })`, `'shop'`, `'trunk'`, `'glovebox'`, `'otherplayer'`, and every `exports['qb-inventory']:*` function (`AddItem`, `RemoveItem`, `HasItem`, `GetItemByName`, `GetItemCount`, `CanAddItem`, `GetFreeWeight`, `SetItemData`, `OpenInventory`, `AddToStash`, `RemoveFromStash`, `ClearStash`, `CreateUsableItem`, …).

## Weapons

Weapons are items with `type = 'weapon'` and names like `weapon_pistol`; ammo items have an `ammotype`. Give a weapon with `Fusion.AddItem(src, 'weapon_pistol', 1, { serie = 'ABC123', quality = 100, ammo = 0 })` (the same `info` keys Fusion's weapon spawner uses: serial number, condition 0–100, loaded ammo). Owners control who may carry which category (**Settings › Weapons**, `weapons.category.<category>` permissions).
