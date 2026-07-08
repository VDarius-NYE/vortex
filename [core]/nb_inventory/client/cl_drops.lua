-- Eldobott itemek megjelenítése a világban (generikus táska modell) +
-- felszedés nb_interact-on keresztül.

local dropObjects = {} -- [dropId] = entity handle

local DROP_MODEL = 'prop_paper_bag01' -- egyelőre egységes modell minden itemhez

local function spawnDropObject(drop)
    local hash = GetHashKey(DROP_MODEL)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 2000 do
        Wait(50)
        timeout = timeout + 50
    end
    if not HasModelLoaded(hash) then return nil end

    local obj = CreateObject(hash, drop.x, drop.y, drop.z - 0.9, false, false, false)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

RegisterNetEvent('nb_inventory:spawnDrop', function(drop)
    local def = Config.Items[drop.item]
    local label = def and def.label or drop.item

    dropObjects[drop.id] = spawnDropObject(drop)

    exports['nb_interact']:AddPoint('nb_drop_' .. drop.id, {
        coords = { x = drop.x, y = drop.y, z = drop.z },
        label = ('Felszedés: %s'):format(label),
        eventName = 'nb_inventory:pickupDropInteract',
        eventArgs = { drop.id },
        distance = 6.0,
        interactDistance = 1.5
    })
end)

RegisterNetEvent('nb_inventory:removeDrop', function(dropId)
    if dropObjects[dropId] and DoesEntityExist(dropObjects[dropId]) then
        DeleteEntity(dropObjects[dropId])
    end
    dropObjects[dropId] = nil
    exports['nb_interact']:RemovePoint('nb_drop_' .. dropId)
end)

AddEventHandler('nb_inventory:pickupDropInteract', function(dropId)
    TriggerServerEvent('nb_inventory:requestPickup', dropId)
end)
