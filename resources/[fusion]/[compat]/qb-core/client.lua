-- exports['qb-core']:* on the client, forwarded to fusion-core.

local core = exports['fusion-core']

exports('GetCoreObject', function() return core:GetCoreObject() end)
exports('DrawText', function(text, position) core:QB_DrawText(text, position) end)
exports('ChangeText', function(text, position) core:QB_ChangeText(text, position) end)
exports('HideText', function() core:QB_HideText() end)
exports('KeyPressed', function() core:QB_KeyPressed() end)

-- Legacy event some old resources use
RegisterNetEvent('qb-core:client:DrawText', function(text, position) core:QB_DrawText(text, position) end)
RegisterNetEvent('qb-core:client:ChangeText', function(text, position) core:QB_ChangeText(text, position) end)
RegisterNetEvent('qb-core:client:HideText', function() core:QB_HideText() end)
RegisterNetEvent('qb-core:client:KeyPressed', function() core:QB_KeyPressed() end)
