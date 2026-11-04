-- qb-input ShowInput() on top of the Fusion input dialog.

local core = exports['fusion-core']

local function showInput(data)
    if type(data) ~= 'table' then return nil end
    local fields = {}
    for i, input in ipairs(data.inputs or {}) do
        local t = input.type or 'text'
        local field = {
            name = input.name or ('input' .. i), label = input.text, type = t, required = input.isRequired,
            default = input.default, placeholder = input.text,
        }
        if t == 'select' or t == 'radio' or t == 'checkbox' then
            field.options = {}
            for _, o in ipairs(input.options or {}) do
                field.options[#field.options + 1] = { value = o.value, label = o.text }
            end
        end
        if t == 'checkbox' then
            -- qb-input checkboxes are a list of options; Fusion asks for each one separately
            for _, o in ipairs(input.options or {}) do
                fields[#fields + 1] = { name = (input.name or 'input' .. i) .. '__' .. tostring(o.value), label = o.text, type = 'checkbox', default = o.checked }
            end
        else
            fields[#fields + 1] = field
        end
    end
    local result = core:Input({ title = data.header, submit = data.submitText, fields = fields })
    if not result then return nil end

    -- Rebuild qb-input's checkbox shape: result[name] = { [value] = 'true'/'false' }
    local out = {}
    for key, value in pairs(result) do
        local base, opt = key:match('^(.-)__(.+)$')
        if base then
            out[base] = out[base] or {}
            out[base][opt] = value and 'true' or 'false'
        else
            out[key] = type(value) == 'number' and tostring(value) or value
        end
    end
    return out
end

exports('ShowInput', showInput)
