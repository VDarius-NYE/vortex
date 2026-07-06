-- Admin duty (szolgálat) rendszer - szolgálatba lépéskor/kilépéskor mindenki értesítést kap.

local onDuty = {} -- [source] = true/false

local function isOnDuty(source)
    return onDuty[source] == true
end

local function broadcastNotify(message, notifyType)
    for _, playerId in ipairs(GetPlayers()) do
        exports['nb_core']:Notify(tonumber(playerId), {
            message = message,
            type = notifyType or 'info',
            duration = 6000
        })
    end
end

local function toggleDuty(source)
    if not exports['nb_group']:HasPermission(source, Config.Permissions.duty) then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    local newState = not isOnDuty(source)
    onDuty[source] = newState

    local name = GetPlayerName(source)

    if newState then
        broadcastNotify(('%s adminszolgálatba lépett.'):format(name), 'info')
    else
        broadcastNotify(('%s kilépett adminszolgálatból.'):format(name), 'info')
    end

    TriggerClientEvent('nb_administration:dutyState', source, newState)
end

AddEventHandler('playerDropped', function()
    local source = source
    onDuty[source] = nil
end)

RegisterCommand('duty', function(source)
    if source == 0 then return end
    toggleDuty(source)
end, false)

RegisterNetEvent('nb_administration:toggleDuty', function()
    toggleDuty(source)
end)

exports('IsOnDuty', isOnDuty)
