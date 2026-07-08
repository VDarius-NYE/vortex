-- AdminJail belépés/kilépés kezelése: a betöltőképernyő MASZKOLJA a teljes
-- átmenetet (beleértve azt a pár másodpercet is, amíg pl. bejelentkezéskor
-- az nb_character lefuttatja a normál spawn-folyamatát - így a player
-- SOHA nem látja magát a normál spawn ponton, csak a betöltőképernyőt,
-- majd egyből a jail-koordinátán találja magát).

RegisterNetEvent('nb_adminjail:enterJail', function(data)
    SendNUIMessage({ action = 'showLoading' })

    CreateThread(function()
        -- Hagyunk egy kis időt, hogy az esetleges egyidejűleg futó normál
        -- spawn-folyamat (bejelentkezéskor pl. az nb_character) lezajodjon,
        -- MIELŐTT mi tényleg teleportálnánk - a betöltőképernyő mögött ez
        -- nem látszik.
        local settleDelay = 2000
        Wait(settleDelay)

        local ped = PlayerPedId()
        local c = data.coords
        SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
        SetEntityHeading(ped, c.heading or 0.0)

        local remaining = Config.LoadingScreenDuration - settleDelay
        if remaining > 0 then Wait(remaining) end

        SendNUIMessage({ action = 'hideLoading' })
        SendNUIMessage({
            action = 'showJail',
            reason = data.reason,
            adminName = data.adminName,
            remainingSeconds = data.remainingSeconds
        })
    end)
end)

RegisterNetEvent('nb_adminjail:exitJail', function(spawn)
    SendNUIMessage({ action = 'hideJail' })
    SendNUIMessage({ action = 'hideLoading' })

    local ped = PlayerPedId()
    if spawn then
        SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
        SetEntityHeading(ped, spawn.heading or 0.0)
    end
end)
