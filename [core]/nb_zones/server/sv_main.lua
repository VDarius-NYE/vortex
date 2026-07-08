-- Zónák betöltése, folyamatos tagság-ellenőrzés (ki melyik zónában van),
-- a megfelelő üzenet + ghost mode jelzése a kliens felé.

NBZoneServer = NBZoneServer or {}

local zones = {} -- [id] = { id, type, faction_id, points = {{x,y},...} }
local playerZone = {} -- [source] = zoneId vagy nil

CreateThread(function()
    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS nb_zones (
                id INT AUTO_INCREMENT PRIMARY KEY,
                type VARCHAR(20) NOT NULL,
                faction_id INT NULL,
                points LONGTEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ]], {}, function()
            local rows = MySQL.query.await('SELECT * FROM nb_zones', {}) or {}
            for _, row in ipairs(rows) do
                row.points = json.decode(row.points)
                zones[row.id] = row
            end
            print(('^3[nb_zones]^7 nb_zones tábla ellenőrizve, %d zóna betöltve.'):format(#rows))
            NBZoneServer.Broadcast()
        end)
    end)
end)

NBZoneServer.zones = zones

local function broadcastZones()
    local list = {}
    for _, z in pairs(zones) do
        list[#list + 1] = { id = z.id, type = z.type, faction_id = z.faction_id, points = z.points }
    end
    TriggerClientEvent('nb_zones:syncZones', -1, list)
end

NBZoneServer.Broadcast = broadcastZones

-- Amint egy player betölt, megkapja a teljes zóna listát (blip rajzoláshoz)
AddEventHandler('nb_core:playerLoaded', function(source)
    local list = {}
    for _, z in pairs(zones) do
        list[#list + 1] = { id = z.id, type = z.type, faction_id = z.faction_id, points = z.points }
    end
    TriggerClientEvent('nb_zones:syncZones', source, list)
end)

function NBZoneServer.AddZone(zoneType, factionId, points)
    local pointsJson = json.encode(points)

    local id = MySQL.insert.await('INSERT INTO nb_zones (type, faction_id, points) VALUES (?, ?, ?)', {
        zoneType, factionId, pointsJson
    })

    zones[id] = { id = id, type = zoneType, faction_id = factionId, points = points }
    broadcastZones()
    return id
end

function NBZoneServer.RemoveZone(zoneId)
    if not zones[zoneId] then return false end
    MySQL.query('DELETE FROM nb_zones WHERE id = ?', { zoneId })
    zones[zoneId] = nil
    broadcastZones()
    return true
end

local function buildZoneMessage(source, zone)
    if zone.type == 'safe' then
        return Config.Messages.safe
    elseif zone.type == 'danger' then
        return Config.Messages.danger
    elseif zone.type == 'admin' then
        return Config.Messages.admin
    elseif zone.type == 'faction' then
        local factionDef = nil
        pcall(function() factionDef = exports['nb_factions']:GetFactionConfig(zone.faction_id) end)
        local name = factionDef and factionDef.name or ('Frakció #' .. tostring(zone.faction_id))

        local isMember = false
        pcall(function() isMember = exports['nb_factions']:GetFaction(source) == zone.faction_id end)

        return (isMember and Config.Messages.faction_member or Config.Messages.faction_nonmember):format(name)
    end
    return ''
end

local function findZoneAt(x, y)
    for id, zone in pairs(zones) do
        if NBZone.PointInPolygon(x, y, zone.points) then
            return zone
        end
    end
    return nil
end

CreateThread(function()
    while true do
        Wait(Config.CheckIntervalMs)

        for _, playerId in ipairs(GetPlayers()) do
            local source = tonumber(playerId)
            local ped = GetPlayerPed(source)
            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)
                local zone = findZoneAt(coords.x, coords.y)
                local zoneId = zone and zone.id or nil

                if zoneId ~= playerZone[source] then
                    playerZone[source] = zoneId

                    if zone then
                        TriggerClientEvent('nb_zones:enterZone', source, {
                            type = zone.type,
                            message = buildZoneMessage(source, zone),
                            ghost = Config.GhostModeTypes[zone.type] or false
                        })
                    else
                        TriggerClientEvent('nb_zones:exitZone', source)
                    end
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    playerZone[source] = nil
end)
