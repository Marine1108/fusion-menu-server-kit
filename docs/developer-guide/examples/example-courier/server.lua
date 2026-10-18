-- example-courier (server): a small but complete Fusion Menu integration.
-- Couriers start a route at the depot, get parcels addressed to drop-off points, and are paid per delivery.

local MODULE = 'example_courier'

---------------------------------------------------------------------------
-- Permissions and the settings page (F10 > Roles & Permissions, F10 > Settings > Courier)
---------------------------------------------------------------------------
Fusion.Perms.Register('example_courier.work', 'Work as a courier', 'Courier', 'Start routes and deliver parcels (also needs the courier job).', { 'user' })
Fusion.Perms.Register('example_courier.admin', 'Courier staff tools', 'Courier', 'Reset a player\'s courier route with /courierreset.', { 'admin' })

Fusion.Settings.Register(MODULE, {
    label = 'Courier', icon = 'package', order = 60,
    description = 'Parcel deliveries for the courier job (example script).',
    fields = {
        { key = 'enabled', type = 'toggle', label = 'Enable deliveries', default = true },
        { key = 'jobs', type = 'multiselect', label = 'Jobs that can deliver', default = { 'courier' }, source = 'jobs' },
        { key = 'pay', type = 'number', label = 'Pay per parcel', default = 120, min = 0, max = 10000, section = 'Pay' },
        { key = 'account', type = 'select', label = 'Pay into', default = 'bank', source = 'moneyTypes', section = 'Pay' },
        { key = 'societyCut', type = 'slider', label = 'Share for the company account (%)', default = 10, min = 0, max = 50, step = 5, section = 'Pay' },
        { key = 'parcels', type = 'number', label = 'Parcels per route', default = 3, min = 1, max = 10, section = 'Routes' },
        { key = 'depot', type = 'vector3', label = 'Depot', default = { x = 78.7, y = 111.9, z = 81.2 }, section = 'Routes' },
        { key = 'dropoffs', type = 'collection', label = 'Drop-off points', labelField = 'label', section = 'Routes',
          default = {
              { label = 'Vinewood Hills', coords = { x = -174.5, y = 502.9, z = 137.4 } },
              { label = 'Mirror Park', coords = { x = 1060.3, y = -378.2, z = 68.2 } },
              { label = 'Little Seoul', coords = { x = -660.9, y = -853.6, z = 24.5 } },
              { label = 'Del Perro', coords = { x = -1371.3, y = -503.5, z = 33.2 } },
          },
          fields = {
              { key = 'label', type = 'text', label = 'Name', default = 'Drop-off' },
              { key = 'coords', type = 'vector3', label = 'Location', default = { x = 0, y = 0, z = 0 } },
          } },
    },
})

local function S() return Fusion.Settings.Get(MODULE) or {} end
local function vec(c) return vector3(tonumber(c.x) or 0.0, tonumber(c.y) or 0.0, tonumber(c.z) or 0.0) end
local function near(src, coords, radius)
    return #(GetEntityCoords(GetPlayerPed(src)) - coords) <= radius
end

---------------------------------------------------------------------------
-- The job and the parcel item: added only if the owner doesn't have them yet
---------------------------------------------------------------------------
CreateThread(function()
    Fusion.Ready()
    local core = exports['fusion-core']
    if not core:GetRegistry('jobs').courier then
        core:SaveRegistry('jobs', 'courier', {
            label = 'Courier', type = 'none', defaultDuty = true,
            grades = { ['0'] = { name = 'Driver', payment = 30 }, ['1'] = { name = 'Dispatcher', payment = 60, isboss = true } },
        })
    end
    if not Fusion.GetItem('example_parcel') then
        core:SaveRegistry('items', 'example_parcel', {
            label = 'Parcel', weight = 1500, unique = true, useable = false, category = 'misc',
            description = 'Deliver it to the address on the label.',
        })
    end
end)

---------------------------------------------------------------------------
-- Routes
---------------------------------------------------------------------------
local routes = {}      -- citizenid -> { stops = { index, … }, startedAt = os.time() }
local cooldown = {}    -- src -> os.time() of the last request

local function canWork(src)
    local s = S()
    if s.enabled == false then return false, 'Deliveries are closed' end
    local pd = Fusion.GetPlayerData(src)
    if not pd then return false, 'No character loaded' end
    if not Fusion.Perms.Has(src, 'example_courier.work') then return false, 'You are not allowed to deliver' end
    local jobOk = false
    for _, j in ipairs(s.jobs or {}) do if j == pd.job.name then jobOk = true end end
    if not jobOk then return false, 'You don\'t work for the courier company' end
    if not pd.job.onduty then return false, 'Go on duty first' end
    return true, pd
end

local function throttled(src)
    local now = os.time()
    if cooldown[src] and now - cooldown[src] < 2 then return true end
    cooldown[src] = now
    return false
end

Fusion.Callback.Register('example_courier:start', function(src)
    if throttled(src) then return false, 'Slow down' end
    local ok, pd = canWork(src)
    if not ok then return false, pd end
    local s = S()
    if not near(src, vec(s.depot or {}), 10.0) then return false, 'You need to be at the depot' end
    if routes[pd.citizenid] then return false, 'Finish your current route first' end

    local drops = s.dropoffs or {}
    if #drops == 0 then return false, 'No drop-off points are set up' end
    local route = { stops = {}, startedAt = os.time() }
    for i = 1, math.min(tonumber(s.parcels) or 3, 10) do
        local index = math.random(1, #drops)
        if Fusion.AddItem(src, 'example_parcel', 1, { stop = index, address = drops[index].label }) then
            route.stops[#route.stops + 1] = index
        end
    end
    if #route.stops == 0 then return false, 'Make room in your inventory' end
    routes[pd.citizenid] = route
    return true, route.stops
end)

Fusion.Callback.Register('example_courier:deliver', function(src, index)
    if throttled(src) then return false, 'Slow down' end
    local ok, pd = canWork(src)
    if not ok then return false, pd end
    local route = routes[pd.citizenid]
    index = tonumber(index)
    local drop = index and (S().dropoffs or {})[index]
    if not route or not drop then return false, 'Nothing to deliver here' end

    if not near(src, vec(drop.coords or {}), 15.0) then
        -- the client claims a delivery somewhere else: worth telling staff about
        exports['fusion-anticheat']:Flag(src, 'example_courier_far', ('Claimed a delivery at %s from far away'):format(drop.label))
        return false, 'You are not at the address'
    end

    -- find the parcel for this stop and take it
    local player = Fusion.GetPlayer(src)
    local slot
    for _, item in pairs(player.Functions.GetItemsByName('example_parcel') or {}) do
        if item.info and tonumber(item.info.stop) == index then slot = item.slot break end
    end
    if not slot or not Fusion.RemoveItem(src, 'example_parcel', 1, slot) then return false, 'You don\'t have a parcel for this address' end
    for i, stop in ipairs(route.stops) do
        if stop == index then table.remove(route.stops, i) break end
    end

    -- pay the courier, and a share to the company
    local s = S()
    local pay = math.floor(tonumber(s.pay) or 0)
    local cut = math.floor(pay * (tonumber(s.societyCut) or 0) / 100)
    if pay - cut > 0 then Fusion.AddMoney(src, s.account or 'bank', pay - cut, 'courier delivery') end
    if cut > 0 then exports['fusion-core']:AddSocietyMoney(pd.job.name, cut) end

    -- lifetime stats in Fusion's key/value store
    local kv = Fusion.KV('example_courier')
    local stats = kv.Get('stats:' .. pd.citizenid, { parcels = 0, earned = 0 })
    stats.parcels, stats.earned = stats.parcels + 1, stats.earned + pay - cut
    kv.Set('stats:' .. pd.citizenid, stats)

    local done = #route.stops == 0
    if done then
        routes[pd.citizenid] = nil
        Fusion.Log('jobs', ('Courier route finished in %d s'):format(os.time() - route.startedAt), src)
    end
    return true, pay - cut, done, stats
end)

Fusion.Callback.Register('example_courier:stats', function(src)
    local pd = Fusion.GetPlayerData(src)
    if not pd then return nil end
    return Fusion.KV('example_courier').Get('stats:' .. pd.citizenid, { parcels = 0, earned = 0 })
end)

---------------------------------------------------------------------------
-- Staff command and clean-up
---------------------------------------------------------------------------
RegisterCommand('courierreset', function(src, args)
    if src > 0 and not Fusion.Perms.Has(src, 'example_courier.admin') then return end
    local target = tonumber(args[1]) or src
    local pd = Fusion.GetPlayerData(target)
    if not pd then return end
    routes[pd.citizenid] = nil
    Fusion.Notify(target, 'Your courier route was reset', 'info')
end, false)

AddEventHandler('fusion:server:playerUnloaded', function(src, citizenid)
    routes[citizenid] = nil
    cooldown[src] = nil
end)

AddEventHandler('fusion:server:characterDeleted', function(citizenid)
    Fusion.KV('example_courier').Set('stats:' .. citizenid, nil)
end)
