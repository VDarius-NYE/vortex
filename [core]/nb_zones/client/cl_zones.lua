-- Zóna belépés/kilépés kezelése: Zóna Infó panel megjelenítése + ghost mode
-- (safe/admin zónákban sebezhetetlenség és ütközés-mentesség más playerekkel).

local ghostActive = false
local currentGhostVehicle = nil

RegisterNetEvent('nb_zones:enterZone', function(data)
    SendNUIMessage({ action = 'show', type = data.type, message = data.message })

    ghostActive = data.ghost
    local ped = PlayerPedId()
    SetEntityInvincible(ped, ghostActive)

    if not ghostActive then
        currentGhostVehicle = nil
    end
end)

RegisterNetEvent('nb_zones:exitZone', function()
    SendNUIMessage({ action = 'hide' })

    ghostActive = false
    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)

    if currentGhostVehicle and DoesEntityExist(currentGhostVehicle) then
        SetEntityInvincible(currentGhostVehicle, false)
    end
    currentGhostVehicle = nil
end)

-- ============================================================
-- Ghost mode: amíg aktív, minden tick-ben letiltjuk az ütközést a saját
-- ped/jármű és az ÖSSZES többi online player ped/járműve között, plusz
-- sebezhetetlenné tesszük az aktuális járművet is.
-- ============================================================
CreateThread(function()
    while true do
        if ghostActive then
            Wait(0)

            local myPed = PlayerPedId()
            local myVeh = GetVehiclePedIsIn(myPed, false)

            if myVeh ~= 0 and myVeh ~= currentGhostVehicle then
                SetEntityInvincible(myVeh, true)
                currentGhostVehicle = myVeh
            end

            for _, playerId in ipairs(GetActivePlayers()) do
                if playerId ~= PlayerId() then
                    local theirPed = GetPlayerPed(playerId)
                    if theirPed and theirPed ~= 0 and DoesEntityExist(theirPed) then
                        SetEntityNoCollisionEntity(myPed, theirPed, true)
                        if myVeh ~= 0 then SetEntityNoCollisionEntity(myVeh, theirPed, true) end

                        local theirVeh = GetVehiclePedIsIn(theirPed, false)
                        if theirVeh ~= 0 then
                            SetEntityNoCollisionEntity(myPed, theirVeh, true)
                            if myVeh ~= 0 then SetEntityNoCollisionEntity(myVeh, theirVeh, true) end
                        end
                    end
                end
            end
        else
            Wait(500)
        end
    end
end)
