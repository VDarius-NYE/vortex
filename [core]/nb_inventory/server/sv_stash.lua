-- Stash rendszer: admin parancsok létrehozásra/listázásra/mozgatásra,
-- plusz a kliensek felé szinkronizált stash-lista (prop spawnoláshoz).
--
-- A "Föld" (eldobott itemek) is ugyanezt a stash mechanizmust használja,
-- csak is_ground=1 jelzéssel és automatikus lejárattal (6 óra).

local stashes = {} -- [id] = { id, faction_id, weight_capacity, slot_count, x, y, z, heading, model, is_ground, expires_at }
local broadcastStashList -- forward deklaráció (lentebb definiáljuk)

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
            MySQL.query([[
                ALTER TABLE nb_stashes
                ADD COLUMN IF NOT EXISTS is_ground TINYINT(1) NOT NULL DEFAULT 0,
                ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP NULL DEFAULT NULL
            ]], {}, function()
                local rows = MySQL.query.await('SELECT * FROM nb_stashes', {}) or {}
                for _, row in ipairs(rows) do
                    stashes[row.id] = row
                end
                print(('^3[nb_inventory]^7 nb_stashes tábla ellenőrizve, %d stash betöltve.'):format(#rows))
            end)
        end)
    end)
end)

function NBInv.GetStashInfo(stashId)
    return stashes[tonumber(stashId) or stashId]
end

-- ============================================================
-- "Föld" (ground) stash-ek: eldobott itemek kupaca. Ha van már közeli
-- (2.5m-en belüli), le nem járt ground stash, abba kerül az item, különben
-- újat hoz létre. 6 óra után automatikusan törlődik (lásd takarító thread).
-- ============================================================
function NBInv.FindOrCreateGroundStash(coords)
    for id, s in pairs(stashes) do
        if s.is_ground and s.is_ground ~= 0 then
            local dist = #(vector3(coords.x, coords.y, coords.z) - vector3(s.x, s.y, s.z))
            if dist <= 2.5 then
                return id
            end
        end
    end

    local expiresAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + 6 * 3600)

    local insertId = MySQL.insert.await([[
        INSERT INTO nb_stashes (faction_id, weight_capacity, slot_count, x, y, z, heading, model, is_ground, expires_at)
        VALUES ('GROUND', 200, 20, ?, ?, ?, 0, ?, 1, ?)
    ]], { coords.x, coords.y, coords.z, Config.GroundStashModel, expiresAt })

    stashes[insertId] = {
        id = insertId, faction_id = 'GROUND', weight_capacity = 200, slot_count = 20,
        x = coords.x, y = coords.y, z = coords.z, heading = 0, model = Config.GroundStashModel,
        is_ground = 1, expires_at = expiresAt
    }

    broadcastStashList()

    return insertId
end

-- Lejárt "Föld" stash-ek takarítása 10 percenként
CreateThread(function()
    while true do
        Wait(10 * 60000)

        local expired = MySQL.query.await('SELECT id FROM nb_stashes WHERE is_ground = 1 AND expires_at IS NOT NULL AND expires_at < NOW()', {}) or {}

        for _, row in ipairs(expired) do
            MySQL.query('DELETE FROM nb_stashes WHERE id = ?', { row.id })
            MySQL.query('DELETE FROM nb_inventory_items WHERE owner_type = ? AND owner_id = ?', { 'stash', tostring(row.id) })
            stashes[row.id] = nil
        end

        if #expired > 0 then
            broadcastStashList()
            print(('^3[nb_inventory]^7 %d lejárt Föld-stash törölve.'):format(#expired))
        end
    end
end)

-- Ha egy Föld-kupac kiürül (valaki kivette az utolsó itemet is), töröljük
-- automatikusan (DB + memória + prop/interact minden kliensen). Visszaadja,
-- hogy törölve lett-e.
function NBInv.CheckGroundStashEmpty(stashId)
    local s = stashes[stashId]
    if not s or not s.is_ground or s.is_ground == 0 then return false end

    local slots = NBInv.GetHandle('stash', stashId)
    if slots and next(slots) then return false end -- még van benne valami

    MySQL.query('DELETE FROM nb_stashes WHERE id = ?', { stashId })
    MySQL.query('DELETE FROM nb_inventory_items WHERE owner_type = ? AND owner_id = ?', { 'stash', tostring(stashId) })
    stashes[stashId] = nil
    broadcastStashList()

    return true
end

function broadcastStashList()
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
    local weightCapacity = tonumber(args[2]) or Config.DefaultStashWeight
    local slotCount = tonumber(args[3]) or Config.DefaultStashSlots

    if not factionId then
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
        if not (s.is_ground and s.is_ground ~= 0) then
            local dist = #(vector3(coords.x, coords.y, coords.z) - vector3(s.x, s.y, s.z))
            if dist <= 30.0 then
                nearby[#nearby + 1] = { id = id, faction = s.faction_id, capacity = s.weight_capacity, dist = dist }
            end
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
-- /deletestash {stashid}
-- ============================================================
RegisterCommand('deletestash', function(source, args)
    if source == 0 then
        print('Ez a parancs csak játékban használható.')
        return
    end

    if not exports['nb_group']:HasPermission(source, 'admin') then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    local stashId = tonumber(args[1])
    if not stashId or not stashes[stashId] then
        exports['nb_core']:Notify(source, { message = 'Használat: /deletestash [stash_id]', type = 'warning' })
        return
    end

    MySQL.query('DELETE FROM nb_stashes WHERE id = ?', { stashId })
    MySQL.query('DELETE FROM nb_inventory_items WHERE owner_type = ? AND owner_id = ?', { 'stash', tostring(stashId) })

    stashes[stashId] = nil
    broadcastStashList()

    exports['nb_core']:Notify(source, { message = ('#%d stash törölve.'):format(stashId), type = 'success' })
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
