-- A szerver által kiváltott admin akciók kliens oldali végrehajtása.

RegisterNetEvent('nb_administration:teleport', function(coords)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z + 1.0, false, false, false, false)
end)

RegisterNetEvent('nb_administration:revive', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('nb_administration:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('nb_administration:setArmor', function(amount)
    SetPedArmour(PlayerPedId(), amount)
end)

-- ============================================================
-- Noclip
-- ============================================================
local noclipActive = false

RegisterNetEvent('nb_administration:toggleNoclip', function()
    noclipActive = not noclipActive
    local ped = PlayerPedId()

    SetEntityVisible(ped, not noclipActive, false)
    SetEntityCollision(ped, not noclipActive, not noclipActive)
    SetEntityInvincible(ped, noclipActive)
    FreezeEntityPosition(ped, false)

    exports['nb_core']:Notify({
        message = noclipActive and 'Noclip bekapcsolva.' or 'Noclip kikapcsolva.',
        type = 'info'
    })
end)

CreateThread(function()
    while true do
        Wait(0)
        if noclipActive then
            local ped = PlayerPedId()
            local speed = IsControlPressed(0, 21) and 4.0 or 1.5 -- Shift = gyorsabb

            local coords = GetEntityCoords(ped)
            local forward, right = 0.0, 0.0
            if IsControlPressed(0, 32) then forward = 1.0 end   -- W
            if IsControlPressed(0, 33) then forward = -1.0 end  -- S
            if IsControlPressed(0, 34) then right = -1.0 end    -- A
            if IsControlPressed(0, 35) then right = 1.0 end     -- D
            local up = 0.0
            if IsControlPressed(0, 44) then up = 1.0 end   -- Q
            if IsControlPressed(0, 38) then up = -1.0 end  -- E

            if forward ~= 0.0 or right ~= 0.0 or up ~= 0.0 then
                local heading = math.rad(GetEntityHeading(ped))
                local rot = GetGameplayCamRot(2)
                local pitch = math.rad(rot.x)
                local camHeading = math.rad(rot.z)

                local dx = (math.sin(-camHeading) * forward + math.cos(-camHeading) * right) * speed * 0.15
                local dy = (math.cos(-camHeading) * forward - math.sin(-camHeading) * right) * speed * 0.15
                local dz = (up * speed * 0.15) + (forward * math.sin(pitch) * speed * 0.15)

                SetEntityCoordsNoOffset(ped, coords.x + dx, coords.y + dy, coords.z + dz, true, true, true)
            end
        else
            Wait(400)
        end
    end
end)

-- ============================================================
-- Godmode
-- ============================================================
local godmodeActive = false

RegisterNetEvent('nb_administration:toggleGodmode', function()
    godmodeActive = not godmodeActive
    SetEntityInvincible(PlayerPedId(), godmodeActive)

    exports['nb_core']:Notify({
        message = godmodeActive and 'Godmode bekapcsolva.' or 'Godmode kikapcsolva.',
        type = 'info'
    })
end)

-- ============================================================
-- Jármű spawnolás
-- ============================================================
RegisterNetEvent('nb_administration:spawnVehicle', function(model)
    local hash = GetHashKey(model)

    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 5000 do
        Wait(50)
        timeout = timeout + 50
    end

    if not HasModelLoaded(hash) then
        exports['nb_core']:Notify({ message = 'Érvénytelen jármű modell: ' .. model, type = 'error' })
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
    SetPedIntoVehicle(ped, vehicle, -1)
    SetModelAsNoLongerNeeded(hash)

    exports['nb_core']:Notify({ message = 'Jármű lespawnolva.', type = 'success' })
end)
