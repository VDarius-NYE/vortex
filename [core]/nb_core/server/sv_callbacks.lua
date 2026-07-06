-- Egyszerű kliens <-> szerver callback rendszer (mint ESX/QBCore callback)

NB.ServerCallbacks = {}
NB.ClientCallbacks = {}

--- Szerver oldali callback regisztrálása (amit a kliens meghívhat)
function NB.CreateCallback(name, cb)
    NB.ServerCallbacks[name] = cb
end

--- Szerver -> kliens callback hívás (pl. admin megkérdez valamit a klienstől)
function NB.TriggerClientCallback(name, source, cb, ...)
    NB.ClientCallbacks[name] = NB.ClientCallbacks[name] or {}
    local callId = ('%s_%s'):format(name, tostring(os.clock()))
    NB.ClientCallbacks[name][callId] = cb
    TriggerClientEvent('nb_core:triggerClientCallback', source, name, callId, ...)
end

RegisterNetEvent('nb_core:triggerServerCallback', function(name, callId, ...)
    local src = source
    if NB.ServerCallbacks[name] then
        NB.ServerCallbacks[name](src, function(...)
            TriggerClientEvent('nb_core:serverCallbackResult', src, callId, ...)
        end, ...)
    else
        NB.Debug(('Ismeretlen szerver callback: %s'):format(name))
    end
end)

RegisterNetEvent('nb_core:clientCallbackResult', function(name, callId, ...)
    if NB.ClientCallbacks[name] and NB.ClientCallbacks[name][callId] then
        NB.ClientCallbacks[name][callId](...)
        NB.ClientCallbacks[name][callId] = nil
    end
end)

exports('CreateCallback', NB.CreateCallback)
exports('TriggerClientCallback', NB.TriggerClientCallback)
