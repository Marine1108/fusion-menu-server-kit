# 6. Permissions and roles

Fusion has its own role and permission system, edited in **F10 › Roles & Permissions**. Use it instead of a config list of admin identifiers: owners then control your script like every other feature.

## Roles

| Role | Priority | Inherits | Has by default |
|---|---|---|---|
| `user` (Player) | 0 | — | everyday features. **Every player has this role** |
| `moderator` | 50 | user | admin panel, kick, warn, freeze, spectate… |
| `admin` | 100 | moderator | `admin.*` |
| `superadmin` (Owner) | 1000 | admin | `*` (everything) |

Owners can rename, re-prioritise and add roles (e.g. *LSPD Command*, *Donator*). A player can have several roles. **Priority** decides who outranks whom (`exports['fusion-core']:CanTarget(src, target)`).

## Permission nodes

A node is a dotted name such as `myscript.use`. Register yours so it appears in the editor with a label and description:

```lua
-- server, top level
Fusion.Perms.Register('mechanic.repair', 'Repair vehicles anywhere', 'Mechanic Tools',
    'Repair a vehicle without being at a shop.', { 'admin' })
--                    node              label                       category (editor group)
--                    description                                    roles that get it the first time it's registered
```

`defaultRoles` is applied **once**, the first time the node is seen. After that the owner's choices stick.

| Check | Where |
|---|---|
| `Fusion.Perms.Has(src, 'mechanic.repair')` | server: **the real check, always do it here** |
| `Fusion.Perms.Has('mechanic.repair')` | client: for showing or hiding UI only |
| `exports['fusion-core']:HasPermission(src, node)` | server, without the library |

The client copy updates live when an owner changes permissions (`fusion:client:permissionsUpdated`; server: `fusion:permissions:changed`).

### How a check is decided

* Each role says **Allow**, **Deny** or **Inherit** (from the role it inherits) for each node.
* **Wildcards:** `mechanic.*` covers every node starting with `mechanic.`; `*` covers everything.
* **The most specific rule wins.** `mechanic.repair = Deny` beats `mechanic.* = Allow`. With equally specific rules, Deny beats Allow.
* A player with several roles gets the combination.

So name nodes in a hierarchy (`myscript.use`, `myscript.admin`, `myscript.spawn.boat`) and owners can grant `myscript.*` in one click.

## ACE (for scripts that use `IsPlayerAceAllowed`)

Fusion mirrors every role to FiveM ACE as `group.fusion_<role>`, with role inheritance as ACE inheritance and role members as principals. Every rule on a role (Allow or Deny, including wildcards: `myscript.*` becomes the ACE object `myscript`) is applied as an ACE, so:

* `IsPlayerAceAllowed(src, 'myscript.use')` follows the in-game roles. If your script doesn't register the node, owners add it under *Custom nodes* and allow it,
* restricted commands (`RegisterCommand(name, fn, true)`) follow the node `command.<name>`.

This needs fusion-core to be allowed to run `add_ace` (the default `server.cfg` grants it; Fusion warns in the console if not). Prefer `Fusion.Perms.Has`: it doesn't depend on ACE at all.

## QBCore permission levels

`QBCore.Functions.HasPermission(src, 'admin')` checks the node `qbcore.admin` (likewise `qbcore.mod`, `qbcore.god`; any dotted name is checked as-is). Commands added with `QBCore.Commands.Add(..., 'admin')` use the same mapping. `'user'` always passes.

## Useful built-in nodes

| Node | Meaning |
|---|---|
| `admin.panel` | Can open F10 (treat as "is staff") |
| `menu.open` | Can open the M menu |
| `anticheat.bypass` | Never flagged by the anticheat; give it to your own trusted staff tools' users, not to players |
| `inventory.search`, `hospital.revive`, `jail.use` | Search players, revive, jail |
| `emergency.siren`, `emergency.radar`, `emergency.bolo` | Emergency vehicle tools |
| `vehicles.class.<class>`, `vehicles.keys.all` | Vehicle spawning by class, keys to every vehicle |
| `weapons.category.<category>` | Which weapon categories a role may carry |

Every node, with its description, is listed in F10 › Roles & Permissions.
