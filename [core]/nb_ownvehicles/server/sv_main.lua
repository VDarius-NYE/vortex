-- Megvett járművek tárolása, garázs UI adat, lehívás/eltárolás - a
-- "spawned" flag akadályozza meg, hogy ugyanaz a jármű kétszer kint legyen.

CreateThread(function()
    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS nb_owned_vehicles (
                id INT AUTO_INCREMENT PRIMARY KEY,
                identifier VARCHAR(64) NOT NULL,
                model VARCHAR(50) NOT NULL,
                label VARCHAR(100) NOT NULL,
                faction_id INT NOT NULL DEFAULT 0,
                plate VARCHAR(12) NOT NULL,
                spawned TINYINT(1) NOT NULL DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ]], {}, function()
            MySQL.query([[
                ALTER TABLE nb_owned_vehicles
                ADD COLUMN IF NOT EXISTS spawn_coords TEXT NULL DEFAULT NULL
            ]], {}, function()
                print('^3[nb_ownvehicles]^7 nb_owned_vehicles tábla ellenőrizve/létrehozva.')
            end)
        end)
    end)
end)

math.randomseed(os.time() + GetGameTimer())

local function generatePlate()
    local chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local plate = 'VM'
    for _ = 1, 6 do
        local i = math.random(1, #chars)
        plate = plate .. chars:sub(i, i)
    end
    return plate
end

-- ============================================================
-- Exportok
-- ============================================================
exports('AddOwnedVehicle', function(source, model, label, factionId, customSpawnCoords)
    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return false end

    local plate = generatePlate()
    local spawnCoordsJson = customSpawnCoords and json.encode(customSpawnCoords) or nil

    MySQL.insert.await('INSERT INTO nb_owned_vehicles (identifier, model, label, faction_id, plate, spawn_coords) VALUES (?, ?, ?, ?, ?, ?)', {
        playerData.identifier, model, label, factionId, plate, spawnCoordsJson
    })

    return true
end)

exports('GetOwnedVehicles', function(source)
    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return {} end
    return MySQL.query.await('SELECT * FROM nb_owned_vehicles WHERE identifier = ?', { playerData.identifier }) or {}
end)

-- ============================================================
-- Garázs megnyitás
-- ============================================================
RegisterNetEvent('nb_ownvehicles:requestOpenGarage', function(factionId, garageIndex)
    local source = source
    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return end

    local garageDef = exports['nb_factions']:GetGarageDef(factionId, garageIndex)
    if not garageDef then return end

    local vehicles = MySQL.query.await('SELECT id, model, label, plate, spawned FROM nb_owned_vehicles WHERE identifier = ?', {
        playerData.identifier
    }) or {}

    TriggerClientEvent('nb_ownvehicles:openUI', source, {
        factionId = factionId,
        garageIndex = garageIndex,
        garageName = garageDef.npcName,
        vehicles = vehicles
    })
end)

-- ============================================================
-- Lehívás (duplikáció-védelemmel)
-- ============================================================
RegisterNetEvent('nb_ownvehicles:requestSpawn', function(vehicleRowId, factionId, garageIndex)
    local source = source
    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return end

    local rows = MySQL.query.await('SELECT * FROM nb_owned_vehicles WHERE id = ? AND identifier = ?', {
        vehicleRowId, playerData.identifier
    })
    local row = rows and rows[1]
    if not row then return end

    if row.spawned == 1 then
        exports['nb_core']:Notify(source, { message = 'Ez a jármű már kint van a világban.', type = 'error' })
        return
    end

    local garageDef = exports['nb_factions']:GetGarageDef(factionId, garageIndex)
    if not garageDef then return end

    MySQL.query('UPDATE nb_owned_vehicles SET spawned = 1 WHERE id = ?', { vehicleRowId })

    -- Ha a járműnek (pl. helikopter/repülő) van saját, vásárláskor eltárolt
    -- spawn pontja, azt használjuk a garázs alap spawnCoords-a helyett.
    local spawnCoords = garageDef.spawnCoords
    if row.spawn_coords and row.spawn_coords ~= '' then
        local ok, decoded = pcall(json.decode, row.spawn_coords)
        if ok and decoded then spawnCoords = decoded end
    end

    TriggerClientEvent('nb_ownvehicles:spawnVehicle', source, {
        vehicleRowId = row.id,
        model = row.model,
        plate = row.plate,
        coords = spawnCoords
    })
end)

-- ============================================================
-- Eltárolás (a kliens jelenti, amikor a player kiadja a parancsot a jármű mellett)
-- ============================================================
RegisterNetEvent('nb_ownvehicles:reportStored', function(vehicleRowId)
    local source = source
    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return end

    MySQL.query('UPDATE nb_owned_vehicles SET spawned = 0 WHERE id = ? AND identifier = ?', {
        vehicleRowId, playerData.identifier
    })

    exports['nb_core']:Notify(source, { message = 'Jármű eltárolva.', type = 'success' })
end)

-- Ha lecsatlakozik anélkül hogy eltárolta volna, a jármű a világban marad,
-- de a DB-ben "spawned" marad - legközelebb bejelentkezéskor a kliens úgyis
-- csak akkor spawnol újat, ha explicit lehívja; a szellem-entitás a szerver
-- resource restart-jáig a világban marad (ez egy jövőbeli finomítási pont
-- lehet, pl. időzített despawn üres/tulajdonos nélküli járművekre).
