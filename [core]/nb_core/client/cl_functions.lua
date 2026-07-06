NB = NB or {}
NB.ClientCallbacks = {}

--- Szerver callback meghívása kliens oldalról
function NB.TriggerCallback(name, cb, ...)
    local callId = ('%s_%s'):format(name, tostring(GetGameTimer()))
    NB.ClientCallbacks[callId] = cb
    TriggerServerEvent('nb_core:triggerServerCallback', name, callId, ...)
end

RegisterNetEvent('nb_core:serverCallbackResult', function(callId, ...)
    if NB.ClientCallbacks[callId] then
        NB.ClientCallbacks[callId](...)
        NB.ClientCallbacks[callId] = nil
    end
end)

RegisterNetEvent('nb_core:triggerClientCallback', function(name, callId, ...)
    if NB.ClientCallbackHandlers and NB.ClientCallbackHandlers[name] then
        NB.ClientCallbackHandlers[name](function(...)
            TriggerServerEvent('nb_core:clientCallbackResult', name, callId, ...)
        end, ...)
    end
end)

NB.ClientCallbackHandlers = {}
function NB.CreateClientCallback(name, cb)
    NB.ClientCallbackHandlers[name] = cb
end
