-- progressbar Progress() API on top of the Fusion progress bar.

local core = exports['fusion-core']
local active = false

local function progress(action, finish)
    if active then
        if finish then finish(true) end
        return
    end
    active = true
    CreateThread(function()
        local cd = action.controlDisables or {}
        local anim
        if action.animation and action.animation.animDict then
            anim = { dict = action.animation.animDict, clip = action.animation.anim, flag = action.animation.flags }
        end
        local prop
        if action.prop and action.prop.model then
            prop = { model = action.prop.model, bone = action.prop.bone, pos = action.prop.coords, rot = action.prop.rotation }
        end
        local ok = core:Progress({
            label = action.label, duration = action.duration, canCancel = action.canCancel,
            anim = anim, scenario = action.animation and action.animation.task or nil, prop = prop,
            disable = { move = cd.disableMovement, car = cd.disableCarMovement, combat = cd.disableCombat, mouse = cd.disableMouse },
        })
        active = false
        if finish then finish(not ok) end
    end)
end

exports('Progress', progress)
exports('isDoingSomething', function() return active or core:IsProgressActive() end)

RegisterNetEvent('progressbar:client:progress', function(action, finish) progress(action, finish) end)
