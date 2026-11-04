-- qb-menu API on top of the Fusion context menu.

local core = exports['fusion-core']

local function openMenu(data, sort, skipFirst)
    if type(data) ~= 'table' then return end
    local items = {}
    for _, item in ipairs(data) do items[#items + 1] = item end
    if sort then
        local first = (skipFirst and table.remove(items, 1)) or nil
        table.sort(items, function(a, b) return tostring(a.header or '') < tostring(b.header or '') end)
        if first then table.insert(items, 1, first) end
    end
    core:OpenContext(items)
end

local function closeMenu()
    core:CloseContext()
end

local function showHeader(data)
    if type(data) ~= 'table' then return end
    local items = {}
    for _, item in ipairs(data) do
        items[#items + 1] = { header = item.header, txt = item.txt or item.text, icon = item.icon, isMenuHeader = true }
    end
    core:OpenContext(items)
end

exports('openMenu', openMenu)
exports('closeMenu', closeMenu)
exports('showHeader', showHeader)

RegisterNetEvent('qb-menu:client:openMenu', openMenu)
RegisterNetEvent('qb-menu:client:closeMenu', closeMenu)
