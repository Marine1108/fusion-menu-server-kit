-- example-courier (client): third-eye at the depot, a menu, an entry in the main menu (M),
-- route blips and an [E] prompt at each drop-off.

local MODULE = 'example_courier'
local stops = {}       -- drop-off indexes still to deliver
local blips = {}

local function S() return Fusion.Settings.Get(MODULE) or {} end
local function vec(c) return vector3(tonumber(c.x) or 0.0, tonumber(c.y) or 0.0, tonumber(c.z) or 0.0) end

local function clearBlips()
    for _, b in pairs(blips) do RemoveBlip(b) end
    blips = {}
end

local function drawRoute()
    clearBlips()
    local drops = S().dropoffs or {}
    for _, index in ipairs(stops) do
        local d = drops[index]
        if d and not blips[index] then
            local c = vec(d.coords or {})
            local b = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(b, 501)
            SetBlipColour(b, 5)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName('Parcel: ' .. (d.label or 'Drop-off'))
            EndTextCommandSetBlipName(b)
            blips[index] = b
        end
    end
    local first = drops[stops[1] or 0]
    if first then
        local c = vec(first.coords or {})
        SetNewWaypoint(c.x, c.y)
    end
end

local function startRoute()
    local ok, result = Fusion.Callback.Await('example_courier:start')
    if not ok then return Fusion.Notify(result or 'Could not start a route', 'error') end
    stops = result
    drawRoute()
    Fusion.Notify(('Route started: %d parcel(s). Follow the yellow blips.'):format(#stops), 'success', 6000, 'Courier')
end

local function deliver(index)
    local done = Fusion.Progress({
        label = 'Handing over the parcel', duration = 3000, canCancel = true,
        anim = { dict = 'mp_common', clip = 'givetake1_a', flag = 49 },
        disable = { move = true, car = true, combat = true },
    })
    if not done then return end
    local ok, paid, finished = Fusion.Callback.Await('example_courier:deliver', index)
    if not ok then return Fusion.Notify(paid or 'Delivery failed', 'error') end
    for i, s in ipairs(stops) do if s == index then table.remove(stops, i) break end end
    if blips[index] then RemoveBlip(blips[index]) blips[index] = nil end
    Fusion.Notify(('Delivered. You earned $%d'):format(paid), 'success')
    if finished then
        stops = {}
        Fusion.Notify('Route complete. Head back to the depot for another one.', 'info', 6000, 'Courier')
    else
        drawRoute()
    end
end

---------------------------------------------------------------------------
-- Menus
---------------------------------------------------------------------------
Fusion.Menu.Register('example_courier:main', {
    build = function(ctx)
        local items = {
            { id = 'start', type = 'button', label = 'Start a route', icon = 'package', description = 'Only at the depot', disabled = #stops > 0 },
            { id = 'stats', type = 'button', label = 'My stats', icon = 'star' },
        }
        if #stops > 0 then
            items[#items + 1] = { type = 'separator', label = 'Current route' }
            local drops = S().dropoffs or {}
            for _, index in ipairs(stops) do
                items[#items + 1] = { type = 'info', label = (drops[index] or {}).label or ('Stop ' .. index), right = 'to deliver' }
            end
        end
        return { title = 'Courier', subtitle = #stops > 0 and (#stops .. ' parcel(s) left') or 'No active route', items = items }
    end,
    onSelect = function(item)
        if item.id == 'start' then
            Fusion.Menu.Close()
            startRoute()
        elseif item.id == 'stats' then
            local stats = Fusion.Callback.Await('example_courier:stats') or {}
            Fusion.Notify(('Parcels delivered: %d · Earned: $%d'):format(stats.parcels or 0, stats.earned or 0), 'info', 6000, 'Courier')
        end
    end,
})

Fusion.Menu.AddRootEntry({
    id = 'example_courier', label = 'Courier', icon = 'package', description = 'Deliveries',
    menu = 'example_courier:main', perm = 'example_courier.work', module = MODULE, order = 60,
    condition = function()
        local pd = Fusion.GetPlayerData() or {}
        for _, j in ipairs(S().jobs or {}) do if pd.job and j == pd.job.name then return true end end
        return false
    end,
})

---------------------------------------------------------------------------
-- Third eye at the depot (qb-target API, answered by fusion-target)
---------------------------------------------------------------------------
local function addDepotTarget()
    exports['qb-target']:RemoveZone('example_courier_depot')
    local depot = vec(S().depot or {})
    exports['qb-target']:AddCircleZone('example_courier_depot', depot, 1.5, { name = 'example_courier_depot', useZ = true }, {
        options = {
            { icon = 'fas fa-box', label = 'Start a courier route', action = function() startRoute() end,
              canInteract = function() return #stops == 0 and Fusion.Perms.Has('example_courier.work') end },
            { icon = 'fas fa-clipboard', label = 'Courier menu', action = function() Fusion.Menu.Open('example_courier:main') end },
        },
        distance = 2.0,
    })
end

---------------------------------------------------------------------------
-- [E] prompt at drop-offs. Sleeps when no route is active or the player is far away.
---------------------------------------------------------------------------
CreateThread(function()
    local shown = false
    while true do
        local sleep = 1000
        if #stops > 0 then
            local pos = GetEntityCoords(PlayerPedId())
            local drops = S().dropoffs or {}
            local here
            for _, index in ipairs(stops) do
                local d = drops[index]
                if d then
                    local dist = #(pos - vec(d.coords or {}))
                    if dist < 50.0 then sleep = 0 end
                    if dist < 3.0 then here = index end
                end
            end
            if here then
                if not shown then
                    Fusion.TextUI.Show(('[%s] Deliver parcel'):format(Fusion.Key.Label('interact')))
                    shown = true
                end
                if Fusion.Key.Pressed('interact') then
                    Fusion.TextUI.Hide()
                    shown = false
                    deliver(here)
                end
            elseif shown then
                Fusion.TextUI.Hide()
                shown = false
            end
        elseif shown then
            Fusion.TextUI.Hide()
            shown = false
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- Start-up, settings changes, character switch and resource stop
---------------------------------------------------------------------------
CreateThread(function()
    while not Fusion.Settings.Get(MODULE) do Wait(500) end
    addDepotTarget()
end)

Fusion.Settings.OnChange(MODULE, function(key)
    if key == nil or key == 'depot' then addDepotTarget() end
    if key == nil or key == 'dropoffs' then drawRoute() end
end)

AddEventHandler('fusion:client:playerUnloaded', function()
    stops = {}
    clearBlips()
    Fusion.TextUI.Hide()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearBlips()
    Fusion.TextUI.Hide()
    exports['qb-target']:RemoveZone('example_courier_depot')
end)
