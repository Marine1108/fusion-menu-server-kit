-- Part of the free Fusion Menu server kit. When Fusion Menu itself is missing (only the kit was
-- installed) or failed to start, this explains why in the console and to anyone trying to join,
-- instead of a list of "Couldn't find resource" errors. Once Fusion runs, it does nothing.

local PORTAL = 'https://portal.cfx.re  >  Granted Assets  >  Fusion Menu'

local function problem()
    local state = GetResourceState('fusion-core')
    if state == 'started' or state == 'starting' then return nil end
    if state == 'missing' then return 'missing' end
    return 'stopped'
end

local function banner(kind)
    local lines
    if kind == 'missing' then
        lines = {
            'Fusion Menu is not installed yet - this server is only the free server kit.',
            '  1. Buy Fusion Menu, then download it from ' .. PORTAL,
            '  2. Unzip it into resources/[fusion]  (next to oxmysql)',
            '     or run install-windows.bat / install-linux.sh again: they find the zip in Downloads.',
            '  3. Restart the server.',
        }
    else
        lines = {
            'Fusion Menu is installed but did not start. Look for the red error above. Usually:',
            '  * "lack the required entitlement": the license key in server.cfg must belong to the',
            '    Cfx.re account that bought Fusion Menu (portal.cfx.re > Server Registration Keys).',
            '  * the database is not running, or mysql_connection_string in server.cfg is wrong.',
        }
    end
    print('^3' .. ('='):rep(78) .. '^0')
    for _, l in ipairs(lines) do print('^3  ' .. l .. '^0') end
    print('^3' .. ('='):rep(78) .. '^0')
end

CreateThread(function()
    Wait(20000) -- let everything start first
    local kind = problem()
    if kind then banner(kind) end
end)

-- players get the same explanation instead of joining an empty world
AddEventHandler('playerConnecting', function(_, _, deferrals)
    local kind = problem()
    if not kind then return end
    deferrals.defer()
    Wait(0)
    if kind == 'missing' then
        deferrals.done('This server is not finished yet: Fusion Menu is not installed. Server owner: download it from portal.cfx.re > Granted Assets and put it in resources/[fusion].')
    else
        deferrals.done('This server is not finished yet: Fusion Menu did not start. Server owner: check the server console for the error (license key or database).')
    end
end)
