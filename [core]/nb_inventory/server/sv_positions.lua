-- A saját inventory és stash panel képernyőn elfoglalt pozíciójának mentése,
-- ugyanúgy accounthoz kötve, mint az nb_hud beállításai.

local positionsCache = {} -- [source] = { player = {x,y} vagy nil, stash = {x,y} vagy nil }

CreateThread(function()
    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS nb_inventory_positions (
                identifier VARCHAR(64) PRIMARY KEY,
                positions LONGTEXT,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        ]], {}, function()
            print('^3[nb_inventory]^7 nb_inventory_positions tábla ellenőrizve/létrehozva.')
        end)
    end)
end)

AddEventHandler('nb_accounts:playerLoggedIn', function(source)
    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return end

    local result = MySQL.query.await('SELECT positions FROM nb_inventory_positions WHERE identifier = ?', { playerData.identifier })
    local row = result and result[1]

    positionsCache[source] = row and row.positions and json.decode(row.positions) or {}
end)

AddEventHandler('playerDropped', function()
    positionsCache[source] = nil
end)

function NBInv.GetPositions(source)
    return positionsCache[source] or {}
end

RegisterNetEvent('nb_inventory:savePosition', function(data)
    local source = source
    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return end

    positionsCache[source] = positionsCache[source] or {}
    positionsCache[source][data.panel] = { x = data.x, y = data.y }

    MySQL.query([[
        INSERT INTO nb_inventory_positions (identifier, positions)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE positions = VALUES(positions), updated_at = CURRENT_TIMESTAMP
    ]], { playerData.identifier, json.encode(positionsCache[source]) })
end)
