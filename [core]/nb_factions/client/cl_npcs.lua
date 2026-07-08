-- Minden frakció összes shop/garázs NPC-jét spawnoljuk (mindenki látja őket
-- a világban, függetlenül attól kinek melyik a saját frakciója - a
-- hozzáférést a szerver ellenőrzi majd megnyitáskor).

local npcs = {} -- lista: { entity, coords, tag, pointId }

local function spawnNpc(model, coords)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 3000 do
        Wait(50)
        timeout = timeout + 50
    end
    if not HasModelLoaded(hash) then return nil end

    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanRagdoll(ped, false)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    SetModelAsNoLongerNeeded(hash)

    return ped
end

local function registerNpc(npcName, tagSuffix, model, coords, eventName, eventArgs)
    local ped = spawnNpc(model, coords)

    local pointId = ('nb_factions_%s_%d'):format(eventName, #npcs + 1)
    exports['nb_interact']:AddPoint(pointId, {
        coords = { x = coords.x, y = coords.y, z = coords.z },
        label = npcName,
        eventName = eventName,
        eventArgs = eventArgs,
        distance = Config.NpcTagDistance,
        interactDistance = Config.NpcInteractDistance
    })

    npcs[#npcs + 1] = {
        entity = ped,
        coords = coords,
        tag = ('%s %s - %s'):format(Config.NpcTagPrefix, npcName, tagSuffix)
    }
end

CreateThread(function()
    for factionId, faction in pairs(Config.Factions) do
        for i, shop in ipairs(faction.itemShops or {}) do
            registerNpc(shop.npcName, 'Item Shop', shop.model, shop.coords, 'nb_factions:openItemShop', { factionId, i })
        end
        for i, shop in ipairs(faction.weaponShops or {}) do
            registerNpc(shop.npcName, 'Weapon Shop', shop.model, shop.coords, 'nb_factions:openWeaponShop', { factionId, i })
        end
        for i, shop in ipairs(faction.vehicleShops or {}) do
            registerNpc(shop.npcName, 'Vehicle Shop', shop.model, shop.coords, 'nb_factions:openVehicleShop', { factionId, i })
        end
        for i, garage in ipairs(faction.garages or {}) do
            registerNpc(garage.npcName, 'Garázs', garage.model, garage.coords, 'nb_factions:openGarage', { factionId, i })
        end
    end
end)

-- ============================================================
-- Névtáblák kirajzolása ("[NPC] Név - Típus") a közeli NPC-k felett
-- ============================================================
local function draw3DText(coords, text)
    local onScreen, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    if not onScreen then return end

    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(220, 235, 210, 215)
    SetTextOutline()
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(x, y)
end

CreateThread(function()
    while true do
        Wait(0)
        local pedCoords = GetEntityCoords(PlayerPedId())

        for _, npc in ipairs(npcs) do
            local dist = #(pedCoords - vector3(npc.coords.x, npc.coords.y, npc.coords.z))
            if dist <= Config.NpcTagDistance then
                draw3DText(vector3(npc.coords.x, npc.coords.y, npc.coords.z + 1.0), npc.tag)
            end
        end
    end
end)

-- ============================================================
-- Interakciók továbbítása a megfelelő resource-oknak
-- ============================================================
AddEventHandler('nb_factions:openItemShop', function(factionId, shopIndex)
    TriggerServerEvent('nb_shops:requestOpen', 'item', factionId, shopIndex)
end)

AddEventHandler('nb_factions:openWeaponShop', function(factionId, shopIndex)
    TriggerServerEvent('nb_shops:requestOpen', 'weapon', factionId, shopIndex)
end)

AddEventHandler('nb_factions:openVehicleShop', function(factionId, shopIndex)
    TriggerServerEvent('nb_shops:requestOpen', 'vehicle', factionId, shopIndex)
end)

AddEventHandler('nb_factions:openGarage', function(factionId, garageIndex)
    TriggerServerEvent('nb_ownvehicles:requestOpenGarage', factionId, garageIndex)
end)
