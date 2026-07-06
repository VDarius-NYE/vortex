-- Stash rendszer: admin parancsok létrehozásra/listázásra/mozgatásra,
-- plusz a kliensek felé szinkronizált stash-lista (prop spawnoláshoz).

local stashes = {} -- [id] = { id, faction_id, weight_capacity, slot_count, x, y, z, heading, model }

CreateThread(function()
    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS nb_stashes (
                id INT AUTO_INCREMENT PRIMARY KEY,
                faction_id VARCHAR(50) NOT NULL,
                weight_capacity FLOAT NOT NULL DEFAULT 100,
                slot_count INT NOT NULL DEFAULT 50,
                x FLOAT NOT NULL,
                y FLOAT NOT NULL,
                z FLOAT NOT NULL,
                heading FLOAT NOT NULL DEFAULT 0,
                model VARCHAR(50) NOT NULL DEFAULT 'prop_box_wood01a',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ]], {}, function()
            local rows = MySQL.query.await('SELECT * FROM nb_stashes', {}) or {}
            for _, row in ipairs(rows) do
                stashes[row.id] = row
            end
            print(('^3[nb_inventory]^7 nb_stashes tábla ellenőrizve, %d stash betöltve.'):format(#rows))
        end)
    end)
end)

function NBInv.GetStashInfo(stashId)
    return stashes[stashId]
end

local function broadcastStashList()
    local list = {}
    for _, s in pairs(stashes) do
        list[#list + 1] = s
    end
    TriggerClientEvent('nb_inventory:syncStashes', -1, list)
end

-- Amint egy player betölt, megkapja a teljes stash listát (prop spawnoláshoz)
AddEventHandler('nb_core:playerLoaded', function(source)
    local list = {}
    for _, s in pairs(stashes) do
        list[#list + 1] = s
    end
    TriggerClientEvent('nb_inventory:syncStashes', source, list)
end)

-- ============================================================
-- /createstash {frakcio_id} {sulykapacitas} {slotszam}
-- ============================================================
RegisterCommand('createstash', function(source, args)
    if source == 0 then
        print('Ez a parancs csak játékban használható.')
        return
    end

    if not exports['nb_group']:HasPermission(source, 'admin') then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    local factionId = args[1]
    local weightCapacity = tonumber(args[2])
    local slotCount = tonumber(args[3])

    if not factionId or not weightCapacity or not slotCount then
        exports['nb_core']:Notify(source, {
            message = 'Használat: /createstash [frakcio_id] [sulykapacitas] [slotszam]',
            type = 'warning'
        })
        return
    end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    local insertId = MySQL.insert.await([[
        INSERT INTO nb_stashes (faction_id, weight_capacity, slot_count, x, y, z, heading, model)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { factionId, weightCapacity, slotCount, coords.x, coords.y, coords.z, heading, Config.DefaultStashModel })

    stashes[insertId] = {
        id = insertId, faction_id = factionId, weight_capacity = weightCapacity, slot_count = slotCount,
        x = coords.x, y = coords.y, z = coords.z, heading = heading, model = Config.DefaultStashModel
    }

    broadcastStashList()

    exports['nb_core']:Notify(source, {
        message = ('Stash létrehozva! ID: %d (%s, %dkg, %d slot)'):format(insertId, factionId, weightCapacity, slotCount),
        type = 'success'
    })
end, false)

-- ============================================================
-- /nearbystash - közeli stash-ek listázása
-- ============================================================
RegisterCommand('nearbystash', function(source)
    if source == 0 then return end

    if not exports['nb_group']:HasPermission(source, 'admin') then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    local coords = GetEntityCoords(GetPlayerPed(source))
    local nearby = {}

    for id, s in pairs(stashes) do
        local dist = #(vector3(coords.x, coords.y, coords.z) - vector3(s.x, s.y, s.z))
        if dist <= 30.0 then
            nearby[#nearby + 1] = { id = id, faction = s.faction_id, capacity = s.weight_capacity, dist = dist }
        end
    end

    if #nearby == 0 then
        exports['nb_core']:Notify(source, { message = 'Nincs közeli stash (30m-en belül).', type = 'info' })
        return
    end

    table.sort(nearby, function(a, b) return a.dist < b.dist end)

    TriggerClientEvent('chat:addMessage', source, {
        color = { 106, 154, 58 },
        args = { '[nb_inventory]', '--- Közeli stash-ek ---' }
    })
    for _, s in ipairs(nearby) do
        TriggerClientEvent('chat:addMessage', source, {
            args = { '[nb_inventory]', ('#%d — %s — %dkg (%.0fm)'):format(s.id, s.faction, s.capacity, s.dist) }
        })
    end
end, false)

-- ============================================================
-- /movestash {stashid} - a player pozíciójára mozgatja
-- ============================================================
RegisterCommand('movestash', function(source, args)
    if source == 0 then return end

    if not exports['nb_group']:HasPermission(source, 'admin') then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    local stashId = tonumber(args[1])
    if not stashId or not stashes[stashId] then
        exports['nb_core']:Notify(source, { message = 'Használat: /movestash [stash_id]', type = 'warning' })
        return
    end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    MySQL.query('UPDATE nb_stashes SET x = ?, y = ?, z = ?, heading = ? WHERE id = ?', {
        coords.x, coords.y, coords.z, heading, stashId
    })

    stashes[stashId].x = coords.x
    stashes[stashId].y = coords.y
    stashes[stashId].z = coords.z
    stashes[stashId].heading = heading

    broadcastStashList()

    exports['nb_core']:Notify(source, { message = ('#%d stash idehelyezve.'):format(stashId), type = 'success' })
end, false)
