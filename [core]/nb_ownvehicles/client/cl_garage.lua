-- Garázs NUI vezérlés + jármű tényleges spawnolása/eltárolása.

local garageOpen = false
local spawnedVehicles = {} -- [entity] = vehicleRowId (ezen a kliensen lehívott saját járművek)

RegisterNetEvent('nb_ownvehicles:openUI', function(payload)
    garageOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', payload = payload })
end)

local function closeGarage()
    garageOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('closeGarage', function(data, cb)
    closeGarage()
    cb('ok')
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    TriggerServerEvent('nb_ownvehicles:requestSpawn', data.vehicleRowId, data.factionId, data.garageIndex)
    cb('ok')
end)

CreateThread(function()
    while true do
        Wait(0)
        if garageOpen then
            if IsControlJustPressed(0, 322) then closeGarage() end
        else
            Wait(300)
        end
    end
end)

-- ============================================================
-- Tényleges jármű-spawnolás
-- ============================================================
RegisterNetEvent('nb_ownvehicles:spawnVehicle', function(data)
    local hash = GetHashKey(data.model)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 3000 do
        Wait(50)
        timeout = timeout + 50
    end
    if not HasModelLoaded(hash) then return end

    local coords = data.coords
    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, coords.w, true, false)
    SetVehicleNumberPlateText(veh, data.plate)
    SetModelAsNoLongerNeeded(hash)

    SetPedIntoVehicle(PlayerPedId(), veh, -1)

    spawnedVehicles[veh] = data.vehicleRowId

    exports['nb_core']:Notify({ message = 'Nyomj [/storevehicle]-t a jármű eltárolásához, ha kiszálltál mellőle.', type = 'info', duration = 6000 })
end)

-- ============================================================
-- Eltárolás - a járműn belül vagy annak közvetlen közelében kiadva
-- ============================================================
RegisterCommand('storevehicle', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local nearestEntity, nearestDist = nil, 5.0
    for entity, _ in pairs(spawnedVehicles) do
        if DoesEntityExist(entity) then
            local dist = #(coords - GetEntityCoords(entity))
            if dist <= nearestDist then
                nearestEntity = entity
                nearestDist = dist
            end
        end
    end

    if not nearestEntity then
        exports['nb_core']:Notify({ message = 'Nincs a közelben olyan járműved, amit eltárolhatnál.', type = 'error' })
        return
    end

    local vehicleRowId = spawnedVehicles[nearestEntity]
    spawnedVehicles[nearestEntity] = nil

    DeleteEntity(nearestEntity)
    TriggerServerEvent('nb_ownvehicles:reportStored', vehicleRowId)
end, false)
