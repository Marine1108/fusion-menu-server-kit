# 7. In-game settings

Fusion servers have **no config files**. Instead, a script declares a **settings schema** and Fusion builds a page for it in **F10 › Settings**, stores the values in the database, and syncs them to every client. Owners change your script without touching files, and changes apply live.

## Registering a page (server)

```lua
Fusion.Settings.Register('courier', {
    label = 'Courier Job',          -- page title
    icon = 'package',               -- icon name (see below)
    description = 'Parcel deliveries for the courier job.',
    order = 60,                     -- position in the list (lower = higher)
    fields = {
        { key = 'enabled', type = 'toggle', label = 'Enable deliveries', default = true },
        { key = 'pay', type = 'number', label = 'Pay per parcel', default = 120, min = 0, max = 10000, section = 'Pay' },
        { key = 'bonusChance', type = 'slider', label = 'Bonus chance (%)', default = 10, min = 0, max = 100, step = 5, section = 'Pay' },
        { key = 'account', type = 'select', label = 'Pay into', default = 'bank', source = 'moneyTypes', section = 'Pay' },
        { key = 'depot', type = 'vector4', label = 'Depot', default = { x = 78.7, y = 111.9, z = 81.2, w = 160.0 }, section = 'Places' },
        { key = 'apiKey', type = 'text', label = 'Tracking API key', default = '', private = true, section = 'Advanced' },
    },
})
```

The **module name** (`'courier'`) is how you read values. Pick something unique to your script.

Register at the top level of a server file. Changing `fields` in an update is fine: new fields get their defaults, removed ones are ignored.

## Reading values (server and client)

```lua
local s = Fusion.Settings.Get('courier')            -- whole page: { enabled = true, pay = 120, … }
local pay = Fusion.Settings.Get('courier', 'pay')   -- one value
if Fusion.Settings.Enabled('courier') then … end    -- shortcut for the 'enabled' toggle

Fusion.Settings.OnChange('courier', function(key, value)
    -- called when an owner saves (key/value), or with nil, nil when the page was reset
end)
```

Read values when you use them (they can change any time) rather than copying them once at start. `private = true` fields (API keys, webhooks) are **never sent to clients**: `Get` on the client returns `nil` for them.

On the client, settings arrive just after the player connects; `Get` returns `nil` before that. Wait with `while not Fusion.Settings.Get('courier') do Wait(250) end` if you read them at resource start.

Without the library: `exports['fusion-core']:GetSettings(module)`, `GetSetting(module, key)`, `SetSetting(module, key, value)` (server). Server event on every change: `fusion:settings:changed` (`module, key, value`).

## Field reference

Every field has `key`, `type`, `label`, and optionally `description` (help text), `default`, `section` (groups fields under a heading) and `private`.

| Type | Value | Extra options |
|---|---|---|
| `toggle` | `true` / `false` | |
| `number` | number | `min`, `max` |
| `slider` | number | `min`, `max`, `step` |
| `text` | string | `multiline = true` for a text box |
| `select` | one value | `options = { { value = 'a', label = 'A' }, … }` **or** `source` |
| `multiselect` | list of values | `options` or `source` |
| `color` | `'#rrggbb'` | |
| `list` | list of strings | (owners add and remove entries) |
| `vector3` | `{ x, y, z }` | the editor has a **Use my position** button |
| `vector4` | `{ x, y, z, w }` | position plus heading |
| `collection` | list of objects | `fields = { … }` (sub-fields, any type above), `labelField = 'name'` (which sub-field titles each entry) |
| `image` | URL or file name | |
| `json` | any table | raw JSON editor, for advanced data |

`source` fills a `select` / `multiselect` from live data: `'jobs'`, `'gangs'`, `'items'`, `'roles'`, `'weapons'`, `'vehicles'` or `'moneyTypes'`.

### Collections

Lists of things owners can add to: locations, shops, rewards.

```lua
{ key = 'dropoffs', type = 'collection', label = 'Drop-off points', labelField = 'label', section = 'Places',
  default = {
      { label = 'Vinewood Hills', coords = { x = -174.5, y = 502.9, z = 137.4 }, tip = 25 },
  },
  fields = {
      { key = 'label', type = 'text', label = 'Name', default = 'Drop-off' },
      { key = 'coords', type = 'vector3', label = 'Location', default = { x = 0, y = 0, z = 0 } },
      { key = 'tip', type = 'number', label = 'Tip', default = 0, min = 0 },
  } },
```

Coordinates come back as plain tables; turn them into vectors when you use them: `vector3(c.x, c.y, c.z)`.

## Icons

Use one of Fusion's icon names for `icon`: `package`, `car`, `user`, `users`, `wallet`, `map`, `map-pin`, `shield`, `star`, `briefcase`, `cog`, `alert`, `flag`, `key`, `layers`, `crosshair`, `fuel`, `store`, `shirt`, `phone`, `cloud`, `wrench`, `scroll`, `info`, `home`, `zap`, `search`, `trash`, `plus`, `save`, `refresh`. Unknown names show a default icon.

## Letting owners replace your script

If your script replaces a Fusion module (your own phone, inventory…), tell owners to turn Fusion's version off in **F10 › Settings › Modules**. Check from code with `exports['fusion-core']:IsModuleEnabled('fusion-phone')`.
