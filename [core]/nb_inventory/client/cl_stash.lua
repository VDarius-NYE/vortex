-- Stash propok megjelenítése a világban, és E-vel megnyitás közelről.

local stashes = {}   -- [id] = { ..., object = handle vagy nil }
local nearestStashId = nil
local promptShown = false

local function spawnStashObject(stash)
    local hash = GetHashKey(stash.model)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 3000 do
        Wait(50)
        timeout = timeout + 50
    end

    if not HasModelLoaded(hash) then return nil end

    local obj = CreateObject(hash, stash.x, stash.y, stash.z, false, false, false)
    SetEntityHeading(obj, stash.heading or 0.0)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

RegisterNetEvent('nb_inventory:syncStashes', function(list)
    -- Régi objektumok törlése (egyszerű megoldás: mindig újraépítjük)
    for _, s in pairs(stashes) do
        if s.object and DoesEntityExist(s.object) then
            DeleteEntity(s.object)
        end
    end

    stashes = {}
    for _, s in ipairs(list) do
        stashes[s.id] = s
    end

    CreateThread(function()
        for id, s in pairs(stashes) do
            s.object = spawnStashObject(s)
        end
    end)
end)

-- Közelség figyelés + E prompt
CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        local closestId, closestDist = nil, 4.0
        for id, s in pairs(stashes) do
            local dist = #(vector3(coords.x, coords.y, coords.z) - vector3(s.x, s.y, s.z))
            if dist <= closestDist then
                closestId = id
                closestDist = dist
            end
        end

        nearestStashId = closestId
    end
end)

-- Prompt megjelenítés + E kezelés (natív text draw, egyszerű megoldás)
CreateThread(function()
    while true do
        Wait(0)
        if nearestStashId then
            SetTextComponentFormat('STRING')
            AddTextComponentString('Nyomj [E]-t a stash megnyitásához')
            DisplayHelpTextFromStringLabel(0, 0, 1, -1)

            if IsControlJustPressed(0, 38) then -- E
                TriggerServerEvent('nb_inventory:requestOpenStash', nearestStashId)
            end
        else
            Wait(400)
        end
    end
end)
