-- F5 - Kill Log panel megnyitása/bezárása (admin jogosultságot a szerver
-- ellenőrzi, itt csak a billentyű + NUI életciklus van).

local panelOpen = false

RegisterCommand('killlog', function()
    if panelOpen then
        panelOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
        return
    end

    SendNUIMessage({ action = 'loading' })
    SetNuiFocus(true, true)
    panelOpen = true

    TriggerServerEvent('nb_killlog:requestOpen')
end, false)

RegisterKeyMapping('killlog', 'Kill Log megnyitása/bezárása', 'keyboard', 'F5')

RegisterNetEvent('nb_killlog:openUI', function(rows)
    if not panelOpen then return end -- időközben bezárta
    SendNUIMessage({ action = 'show', rows = rows })
end)

RegisterNetEvent('nb_killlog:closeUI', function()
    panelOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end)

RegisterNUICallback('closeKillLog', function(data, cb)
    panelOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    cb('ok')
end)

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
