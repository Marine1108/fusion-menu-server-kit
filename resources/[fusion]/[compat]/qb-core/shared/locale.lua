-- Translations for QBCore scripts. Scripts load this with '@qb-core/shared/locale.lua' and use it as
--   Lang = Locale:new({ phrases = Translations, warnOnMissing = true, fallbackLang = OtherLocale })
--   Lang:t('error.no_money', { amount = 5 })      -- "%{amount}" in a phrase becomes 5
-- Nested phrase tables become dotted keys ('error.no_money'). Fusion's own implementation.

Locale = {}
Locale.__index = Locale

-- every key/value of a nested table as dotted keys
local function flatten(tbl, prefix, out)
    for k, v in pairs(tbl or {}) do
        local key = prefix and (prefix .. '.' .. tostring(k)) or tostring(k)
        if type(v) == 'table' then flatten(v, key, out) else out[key] = v end
    end
    return out
end

local function fill(text, values)
    if not values then return text end
    return (text:gsub('%%{([%w_]+)}', function(name)
        local v = values[name]
        if v == nil then return '%{' .. name .. '}' end
        return tostring(v)
    end))
end

function Locale.new(_, options)
    options = options or {}
    local obj = setmetatable({ phrases = {} }, Locale)
    obj.warnOnMissing = options.warnOnMissing ~= false
    if options.fallbackLang then
        obj.fallback = Locale.new(nil, { phrases = options.fallbackLang.phrases, warnOnMissing = false })
    else
        obj.fallback = false
    end
    obj:extend(options.phrases)
    return obj
end

function Locale:extend(phrases, prefix)
    for k, v in pairs(flatten(phrases, prefix, {})) do self.phrases[k] = v end
end

function Locale:clear() self.phrases = {} end

function Locale:replace(phrases)
    self.phrases = {}
    self:extend(phrases)
end

function Locale:locale(name)
    if name then self.currentLocale = name end
    return self.currentLocale
end

function Locale:has(key) return self.phrases[key] ~= nil end

function Locale:delete(target, prefix)
    if type(target) == 'string' then
        self.phrases[target] = nil
        return
    end
    for k in pairs(flatten(target, prefix, {})) do self.phrases[k] = nil end
end

function Locale:t(key, values)
    local text = self.phrases[key]
    if type(text) == 'string' then
        if type(key) ~= 'string' then error('Locale:t needs a text key') end
        return fill(text, values)
    end
    if self.warnOnMissing then print(('^3[qb-core] No translation for "%s"^0'):format(tostring(key))) end
    if self.fallback then return self.fallback:t(key, values) end
    return key
end
