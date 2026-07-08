-- Frakció-hozzárendelés tárolása/betöltése, exportok, admin parancs.

local playerFactions = {} -- [source] = factionId

CreateThread(function()
    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS nb_player_factions (
                identifier VARCHAR(64) PRIMARY KEY,
                faction_id INT NOT NULL DEFAULT 0,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        ]], {}, function()
            print('^3[nb_factions]^7 nb_player_factions tábla ellenőrizve/létrehozva.')
        end)
    end)
end)

local function pushFactionToHud(source)
    local factionId = playerFactions[source]
    if factionId == nil then return end

    local factionDef = Config.Factions[factionId]
    local name = factionDef and factionDef.name or ('Frakció #' .. factionId)

    pcall(function()
        TriggerClientEvent('nb_hud:setStat', source, 'faction', name)
    end)
end

AddEventHandler('nb_accounts:playerLoggedIn', function(source)
    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return end

    local result = MySQL.query.await('SELECT faction_id FROM nb_player_factions WHERE identifier = ?', { playerData.identifier })
    local row = result and result[1]

    if row then
        playerFactions[source] = row.faction_id
    else
        playerFactions[source] = Config.DefaultFactionId
        MySQL.insert.await('INSERT IGNORE INTO nb_player_factions (identifier, faction_id) VALUES (?, ?)', {
            playerData.identifier, Config.DefaultFactionId
        })
    end

    pushFactionToHud(source)
end)

AddEventHandler('playerDropped', function()
    playerFactions[source] = nil
end)

-- ============================================================
-- Exportok
-- ============================================================

--- Visszaadja a player frakció ID-ját. FONTOS: ha még nincs
--- gyorsítótárazva (pl. mert egy MÁSIK resource - pl. nb_character - a
--- 'nb_accounts:playerLoggedIn' eseményre a mi saját betöltésünk ELŐTT
--- kérdezi le, versenyhelyzet miatt), akkor ITT, AZONNAL lekérdezzük az
--- adatbázisból, ahelyett hogy hibásan az alapértelmezettre esnénk vissza.
local function getFaction(source)
    if playerFactions[source] ~= nil then
        return playerFactions[source]
    end

    local playerData = nil
    pcall(function() playerData = exports['nb_core']:GetPlayerData(source) end)
    if not playerData then return Config.DefaultFactionId end

    local ok, result = pcall(function()
        return MySQL.query.await('SELECT faction_id FROM nb_player_factions WHERE identifier = ?', { playerData.identifier })
    end)

    local row = ok and result and result[1]
    local factionId = row and row.faction_id or Config.DefaultFactionId

    playerFactions[source] = factionId
    return factionId
end

local function getFactionName(source)
    local def = Config.Factions[getFaction(source)]
    return def and def.name or 'Ismeretlen'
end

local function setFaction(source, factionId)
    if not Config.Factions[factionId] then return false, 'Nincs ilyen frakció ID.' end

    playerFactions[source] = factionId

    local playerData = exports['nb_core']:GetPlayerData(source)
    if playerData then
        MySQL.query('INSERT INTO nb_player_factions (identifier, faction_id) VALUES (?, ?) ON DUPLICATE KEY UPDATE faction_id = VALUES(faction_id)', {
            playerData.identifier, factionId
        })
    end

    pushFactionToHud(source)
    return true
end

exports('GetFaction', getFaction)
exports('GetFactionName', getFactionName)
exports('SetFaction', setFaction)
exports('GetFactionConfig', function(factionId) return Config.Factions[factionId] end)

-- A player frakciójához tartozó spawn pontot adja vissza (ha a frakciónak
-- nincs saját spawnCoords-a, visszaesik az nb_core alap spawn pontjára).
exports('GetSpawnPoint', function(source)
    local factionDef = Config.Factions[getFaction(source)]
    if factionDef and factionDef.spawnCoords then
        return factionDef.spawnCoords
    end

    local fallback = nil
    pcall(function() fallback = exports['nb_core']:GetDefaultSpawn() end)
    return fallback
end)

exports('GetShopDef', function(factionId, shopType, shopIndex)
    local def = Config.Factions[factionId]
    if not def then return nil end

    local list = (shopType == 'item' and def.itemShops)
        or (shopType == 'weapon' and def.weaponShops)
        or (shopType == 'vehicle' and def.vehicleShops)
        or nil

    return list and list[shopIndex] or nil
end)

exports('GetGarageDef', function(factionId, garageIndex)
    local def = Config.Factions[factionId]
    return def and def.garages and def.garages[garageIndex] or nil
end)

-- ============================================================
-- /setfaction [player_id] [faction_id]
-- ============================================================
RegisterCommand('setfaction', function(source, args)
    local isConsole = source == 0

    if not isConsole and not exports['nb_group']:HasPermission(source, 'admin') then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    local targetId = tonumber(args[1])
    local factionId = tonumber(args[2])

    if not targetId or not factionId or not GetPlayerName(targetId) then
        local msg = 'Használat: /setfaction [player_id] [faction_id]'
        if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'warning' }) end
        return
    end

    local ok, err = setFaction(targetId, factionId)

    if ok then
        local name = getFactionName(targetId)
        local msg = ('%s frakciója beállítva: %s'):format(GetPlayerName(targetId), name)
        if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'success' }) end
        if not isConsole then
            exports['nb_core']:Notify(targetId, { message = ('A frakciód mostantól: %s'):format(name), type = 'info' })
        end
    else
        if isConsole then print('HIBA: ' .. (err or '')) else exports['nb_core']:Notify(source, { message = err, type = 'error' }) end
    end
end, false)
