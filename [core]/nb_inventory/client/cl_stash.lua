-- Stash propok megjelenítése a világban + nb_interact pont regisztrálása
-- (a régi natív help-text E-prompt helyett).

local stashes = {} -- [id] = { ..., object = handle vagy nil }

local function spawnStashObject(stash)
    local hash = GetHashKey(stash.model)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 3000 do
        Wait(50)
        timeout = timeout + 50
    end

    if not HasModelLoaded(hash) then return nil end

    local obj = CreateObject(hash, stash.x, stash.y, stash.z - 1.0, false, false, false)
    SetEntityHeading(obj, stash.heading or 0.0)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

RegisterNetEvent('nb_inventory:syncStashes', function(list)
    -- Régi objektumok + interact pontok törlése (egyszerű megoldás: újraépítjük)
    for id, s in pairs(stashes) do
        if s.object and DoesEntityExist(s.object) then
            DeleteEntity(s.object)
        end
        exports['nb_interact']:RemovePoint('nb_stash_' .. id)
    end

    stashes = {}
    for _, s in ipairs(list) do
        stashes[s.id] = s
    end

    CreateThread(function()
        for id, s in pairs(stashes) do
            s.object = spawnStashObject(s)

            local isGround = s.is_ground and s.is_ground ~= 0
            local label = isGround and 'Föld megnyitása' or 'Stash megnyitása'

            exports['nb_interact']:AddPoint('nb_stash_' .. id, {
                coords = { x = s.x, y = s.y, z = s.z },
                label = label,
                eventName = 'nb_inventory:stashInteract',
                eventArgs = { id },
                distance = isGround and 6.0 or 8.0,
                interactDistance = isGround and 1.5 or 2.0
            })
        end
    end)
end)

AddEventHandler('nb_inventory:stashInteract', function(stashId)
    TriggerServerEvent('nb_inventory:requestOpenStash', stashId)
end)
