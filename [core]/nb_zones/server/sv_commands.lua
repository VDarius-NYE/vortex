-- Zóna létrehozás/törlés parancsok. A safe/faction/danger zónákat owner
-- hozhatja létre (sarok-jelöléssel, /zonepoint + /finishzone), az admin
-- zónákat pedig 'admin' jogosultsággal, egy gyors /adminzone paranccsal.

local creationSessions = {} -- [source] = { type=, factionId=, points={} }

local VALID_TYPES = { safe = true, faction = true, danger = true }

-- ============================================================
-- /createzone {safe|faction|danger} {factionId - csak faction típusnál kell}
-- ============================================================
RegisterCommand('createzone', function(source, args)
    if source == 0 then print('Ez a parancs csak játékban használható.') return end

    if not exports['nb_group']:HasPermission(source, 'owner') then
        exports['nb_core']:Notify(source, { message = 'Csak owner hozhat létre zónát.', type = 'error' })
        return
    end

    local zoneType = args[1]
    if not VALID_TYPES[zoneType] then
        exports['nb_core']:Notify(source, { message = 'Használat: /createzone [safe|faction|danger] [factionId]', type = 'warning' })
        return
    end

    local factionId = tonumber(args[2])
    if zoneType == 'faction' and not factionId then
        exports['nb_core']:Notify(source, { message = 'Faction zónánál kötelező megadni a factionId-t.', type = 'warning' })
        return
    end

    creationSessions[source] = { type = zoneType, factionId = factionId, points = {} }

    exports['nb_core']:Notify(source, {
        message = 'Zóna létrehozás elindítva. Menj a sarkokhoz és add ki a /zonepoint parancsot mindegyiknél, a végén /finishzone. Megszakítás: /cancelzone.',
        type = 'info',
        duration = 8000
    })

    TriggerClientEvent('nb_zones:startCreation', source, zoneType)
end, false)

-- ============================================================
-- /zonepoint - hozzáadja a jelenlegi pozíciót mint sarokpont
-- ============================================================
RegisterCommand('zonepoint', function(source)
    local session = creationSessions[source]
    if not session then
        exports['nb_core']:Notify(source, { message = 'Nincs folyamatban lévő zóna létrehozás. Kezdd a /createzone-nal.', type = 'error' })
        return
    end

    local coords = GetEntityCoords(GetPlayerPed(source))
    table.insert(session.points, { x = coords.x, y = coords.y })

    exports['nb_core']:Notify(source, { message = ('Sarokpont hozzáadva (#%d).'):format(#session.points), type = 'success' })
    TriggerClientEvent('nb_zones:pointAdded', source, session.points)
end, false)

-- ============================================================
-- /finishzone - lezárja és elmenti a zónát
-- ============================================================
RegisterCommand('finishzone', function(source)
    local session = creationSessions[source]
    if not session then
        exports['nb_core']:Notify(source, { message = 'Nincs folyamatban lévő zóna létrehozás.', type = 'error' })
        return
    end

    if #session.points < Config.MinZonePoints then
        exports['nb_core']:Notify(source, {
            message = ('Legalább %d sarokpont kell (jelenleg: %d).'):format(Config.MinZonePoints, #session.points),
            type = 'warning'
        })
        return
    end

    local id = NBZoneServer.AddZone(session.type, session.factionId, session.points)
    creationSessions[source] = nil

    exports['nb_core']:Notify(source, { message = ('Zóna létrehozva! ID: %d'):format(id), type = 'success' })
    TriggerClientEvent('nb_zones:endCreation', source)
end, false)

-- ============================================================
-- /cancelzone - megszakítja a folyamatban lévő létrehozást
-- ============================================================
RegisterCommand('cancelzone', function(source)
    if not creationSessions[source] then
        exports['nb_core']:Notify(source, { message = 'Nincs folyamatban lévő zóna létrehozás.', type = 'warning' })
        return
    end

    creationSessions[source] = nil
    exports['nb_core']:Notify(source, { message = 'Zóna létrehozás megszakítva.', type = 'info' })
    TriggerClientEvent('nb_zones:endCreation', source)
end, false)

-- ============================================================
-- /nearbyzones - közeli zónák listázása (középpont alapján)
-- ============================================================
RegisterCommand('nearbyzones', function(source)
    if not exports['nb_group']:HasPermission(source, 'admin') then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    local coords = GetEntityCoords(GetPlayerPed(source))
    local nearby = {}

    for id, zone in pairs(NBZoneServer.zones) do
        local cx, cy = NBZone.Centroid(zone.points)
        local dist = #(vector2(coords.x, coords.y) - vector2(cx, cy))
        if dist <= Config.NearbyRadius then
            nearby[#nearby + 1] = { id = id, type = zone.type, factionId = zone.faction_id, dist = dist }
        end
    end

    if #nearby == 0 then
        exports['nb_core']:Notify(source, { message = ('Nincs közeli zóna (%dm-en belül).'):format(Config.NearbyRadius), type = 'info' })
        return
    end

    table.sort(nearby, function(a, b) return a.dist < b.dist end)

    TriggerClientEvent('chat:addMessage', source, { color = { 106, 154, 58 }, args = { '[nb_zones]', '--- Közeli zónák ---' } })
    for _, z in ipairs(nearby) do
        local label = z.type
        if z.type == 'faction' then
            local name = 'Frakció #' .. tostring(z.factionId)
            pcall(function()
                local def = exports['nb_factions']:GetFactionConfig(z.factionId)
                if def then name = def.name end
            end)
            label = ('faction (%s)'):format(name)
        end
        TriggerClientEvent('chat:addMessage', source, {
            args = { '[nb_zones]', ('#%d — %s (%.0fm)'):format(z.id, label, z.dist) }
        })
    end
end, false)

-- ============================================================
-- /deletezone {zoneid}
-- ============================================================
RegisterCommand('deletezone', function(source, args)
    if not exports['nb_group']:HasPermission(source, 'owner') then
        exports['nb_core']:Notify(source, { message = 'Csak owner törölhet zónát.', type = 'error' })
        return
    end

    local zoneId = tonumber(args[1])
    if not zoneId or not NBZoneServer.zones[zoneId] then
        exports['nb_core']:Notify(source, { message = 'Használat: /deletezone [zone_id]', type = 'warning' })
        return
    end

    NBZoneServer.RemoveZone(zoneId)
    exports['nb_core']:Notify(source, { message = ('#%d zóna törölve.'):format(zoneId), type = 'success' })
end, false)

-- ============================================================
-- /adminzone {méret} - gyors, négyzet alakú admin zóna a jelenlegi pozícióra
-- ============================================================
RegisterCommand('adminzone', function(source, args)
    if not exports['nb_group']:HasPermission(source, 'admin') then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    local size = tonumber(args[1]) or 20.0
    local half = size / 2

    local coords = GetEntityCoords(GetPlayerPed(source))
    local points = {
        { x = coords.x - half, y = coords.y - half },
        { x = coords.x + half, y = coords.y - half },
        { x = coords.x + half, y = coords.y + half },
        { x = coords.x - half, y = coords.y + half },
    }

    local id = NBZoneServer.AddZone('admin', nil, points)
    exports['nb_core']:Notify(source, { message = ('Admin zóna létrehozva (ID: %d, %dm x %dm).'):format(id, size, size), type = 'success' })
end, false)

-- ============================================================
-- /removezone - törli azt az admin zónát, amiben az admin éppen áll
-- ============================================================
RegisterCommand('removezone', function(source)
    if not exports['nb_group']:HasPermission(source, 'admin') then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    local coords = GetEntityCoords(GetPlayerPed(source))

    for id, zone in pairs(NBZoneServer.zones) do
        if zone.type == 'admin' and NBZone.PointInPolygon(coords.x, coords.y, zone.points) then
            NBZoneServer.RemoveZone(id)
            exports['nb_core']:Notify(source, { message = ('#%d admin zóna törölve.'):format(id), type = 'success' })
            return
        end
    end

    exports['nb_core']:Notify(source, { message = 'Nem állsz jelenleg admin zónában.', type = 'warning' })
end, false)
