local panelOpen = false
local uiAck = false

RegisterCommand('nbadminpanel', function()
    TriggerServerEvent('nb_administration:requestPanel')
end, false)

RegisterKeyMapping('nbadminpanel', 'Admin panel megnyitása', 'keyboard', Config.PanelKeyMapping)

RegisterNUICallback('panelReady', function(data, cb)
    uiAck = true
    cb('ok')
end)

local function openPanelUI(payload)
    SetNuiFocus(true, true)
    panelOpen = true
    uiAck = false

    CreateThread(function()
        local attempts = 0
        while not uiAck and attempts < 20 do
            SendNUIMessage(payload)
            attempts = attempts + 1
            Wait(150)
        end
    end)
end

RegisterNetEvent('nb_administration:openPanel', function(data)
    openPanelUI({
        action = 'open',
        players = data.players,
        groups = data.groups,
        myGroup = data.myGroup
    })
end)

RegisterNetEvent('nb_administration:updatePlayerList', function(players)
    SendNUIMessage({ action = 'updatePlayers', players = players })
end)

RegisterNUICallback('closePanel', function(data, cb)
    panelOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    cb('ok')
end)

RegisterNUICallback('panelAction', function(data, cb)
    TriggerServerEvent('nb_administration:panelAction', data)
    cb('ok')
end)

RegisterNUICallback('refreshPanel', function(data, cb)
    TriggerServerEvent('nb_administration:refreshPanel')
    cb('ok')
end)

RegisterNUICallback('toggleDuty', function(data, cb)
    TriggerServerEvent('nb_administration:toggleDuty')
    cb('ok')
end)

RegisterNetEvent('nb_administration:dutyState', function(state)
    SendNUIMessage({ action = 'dutyState', onDuty = state })
end)

RegisterNUICallback('requestDetails', function(data, cb)
    TriggerServerEvent('nb_administration:requestDetails', data.targetId)
    cb('ok')
end)

RegisterNetEvent('nb_administration:showDetails', function(details)
    SendNUIMessage({ action = 'showDetails', details = details })
end)

RegisterNUICallback('addWarn', function(data, cb)
    TriggerServerEvent('nb_administration:addWarn', data)
    cb('ok')
end)

RegisterNUICallback('deleteWarn', function(data, cb)
    TriggerServerEvent('nb_administration:deleteWarn', data)
    cb('ok')
end)

-- ESC-cel is bezárható
CreateThread(function()
    while true do
        Wait(0)
        if panelOpen then
            if IsControlJustPressed(0, 322) then -- ESC
                panelOpen = false
                SetNuiFocus(false, false)
                SendNUIMessage({ action = 'close' })
            end
        else
            Wait(300)
        end
    end
end)
