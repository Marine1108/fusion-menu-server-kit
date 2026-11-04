-- exports['qb-core']:* on the server, forwarded to fusion-core.

local core = exports['fusion-core']

exports('GetCoreObject', function(filters) return core:GetCoreObject(filters) end)

local forwarded = {
    'GetCoreVersion', 'AddItem', 'AddItems', 'UpdateItem', 'RemoveItem', 'AddJob', 'AddJobs', 'UpdateJob', 'RemoveJob',
    'AddGang', 'AddGangs', 'UpdateGang', 'RemoveGang', 'SetMethod', 'SetField', 'AddPlayerMethod', 'AddPlayerField', 'ExploitBan',
}

for _, name in ipairs(forwarded) do
    exports(name, function(...) return core['QB_' .. name](core, ...) end)
end
