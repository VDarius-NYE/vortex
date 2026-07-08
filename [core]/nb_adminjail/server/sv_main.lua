-- AdminJail: dimenzió-alapú (routing bucket) elkülönítés, DB-perzisztens.
--
-- FONTOS: az idő "hátralévő másodpercként" van tárolva, NEM abszolút
-- lejárati időbélyegként - így csak akkor telik, amíg a player TÉNYLEGESEN
-- online van. Kilépéskor lefagyasztjuk (elmentjük a pillanatnyi hátralévő
-- időt), belépéskor onnan folytatódik.

local activeJails = {} -- [source] = { remainingSeconds, reason, adminName, identifier }

CreateThread(function()
    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS nb_adminjail (
                identifier VARCHAR(64) PRIMARY KEY,
                admin_name VARCHAR(50) NOT NULL,
                reason TEXT NOT NULL,
                remaining_seconds INT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ]], {}, function()
            print('^3[nb_adminjail]^7 nb_adminjail tábla ellenőrizve/létrehozva.')
        end)
    end)
end)

local function getSpawnPoint(source)
    local spawn = nil
    pcall(function() spawn = exports['nb_factions']:GetSpawnPoint(source) end)
    if not spawn then
        pcall(function() spawn = exports['nb_core']:GetDefaultSpawn() end)
    end
    return spawn
end

local function saveJailToDb(identifier, adminName, reason, remainingSeconds)
    MySQL.query([[
        INSERT INTO nb_adminjail (identifier, admin_name, reason, remaining_seconds)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE admin_name = VALUES(admin_name), reason = VALUES(reason), remaining_seconds = VALUES(remaining_seconds)
    ]], { identifier, adminName, reason, math.floor(remainingSeconds) })
end

-- ============================================================
-- /adminjail [player_id] [perc] [indok...]
-- ============================================================
RegisterCommand('adminjail', function(source, args)
    local isConsole = source == 0
    if isConsole then print('Ez a parancs csak játékban használható.') return end

    if not exports['nb_group']:HasPermission(source, 'admin') then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    local targetId = tonumber(args[1])
    local minutes = tonumber(args[2])

    if not targetId or not GetPlayerName(targetId) or not minutes or minutes <= 0 then
        exports['nb_core']:Notify(source, { message = 'Használat: /adminjail [player_id] [perc] [indok]', type = 'warning' })
        return
    end

    local reasonParts = {}
    for i = 3, #args do reasonParts[#reasonParts + 1] = args[i] end
    local reason = table.concat(reasonParts, ' ')
    if reason == '' then reason = 'Nincs megadva indok.' end

    local playerData = exports['nb_core']:GetPlayerData(targetId)
    if not playerData then return end

    local adminName = GetPlayerName(source)
    local targetName = GetPlayerName(targetId)
    local remainingSeconds = minutes * 60

    saveJailToDb(playerData.identifier, adminName, reason, remainingSeconds)

    activeJails[targetId] = {
        remainingSeconds = remainingSeconds,
        reason = reason,
        adminName = adminName,
        identifier = playerData.identifier
    }

    SetPlayerRoutingBucket(targetId, targetId)

    TriggerClientEvent('nb_adminjail:enterJail', targetId, {
        coords = Config.JailCoords,
        reason = reason,
        adminName = adminName,
        remainingSeconds = remainingSeconds
    })

    exports['nb_core']:Notify(source, { message = ('%s adminjailbe rakva (%d perc).'):format(targetName, minutes), type = 'success' })

    TriggerClientEvent('chat:addMessage', -1, {
        color = { 200, 60, 60 },
        args = { '[AdminJail]: ', ('%s adminjailbe rakta %s játékost %d percre.'):format(adminName, targetName, minutes) }
    })
    TriggerClientEvent('chat:addMessage', -1, {
        color = { 200, 60, 60 },
        args = { '[AdminJail]: ', ('Indok: %s'):format(reason) }
    })
end, false)

-- ============================================================
-- /endadminjail [player_id]
-- ============================================================
local function releaseFromJail(targetId)
    local jail = activeJails[targetId]
    local identifier = jail and jail.identifier

    if not identifier then
        local playerData = exports['nb_core']:GetPlayerData(targetId)
        identifier = playerData and playerData.identifier
    end

    if identifier then
        MySQL.query('DELETE FROM nb_adminjail WHERE identifier = ?', { identifier })
    end

    activeJails[targetId] = nil
    SetPlayerRoutingBucket(targetId, 0)

    local spawn = getSpawnPoint(targetId)
    TriggerClientEvent('nb_adminjail:exitJail', targetId, spawn)
end

RegisterCommand('endadminjail', function(source, args)
    local isConsole = source == 0

    if not isConsole and not exports['nb_group']:HasPermission(source, 'admin') then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    local targetId = tonumber(args[1])
    if not targetId or not GetPlayerName(targetId) then
        local msg = 'Használat: /endadminjail [player_id]'
        if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'warning' }) end
        return
    end

    local targetName = GetPlayerName(targetId)
    releaseFromJail(targetId)

    local msg = ('%s kivéve az adminjailből.'):format(targetName)
    if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'success' }) end
end, false)

-- ============================================================
-- Login - ha van aktív (>0 hátralévő idejű) adminjailje, visszakerül.
-- A tényleges teleportot a KLIENS késlelteti kicsit (a betöltőképernyő
-- mögött), hogy az nb_character normál spawn-folyamata ne írja felül -
-- lásd cl_adminjail.lua.
-- ============================================================
AddEventHandler('nb_accounts:playerLoggedIn', function(source)
    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return end

    local result = MySQL.query.await('SELECT * FROM nb_adminjail WHERE identifier = ?', { playerData.identifier })
    local row = result and result[1]
    if not row then return end

    local remainingSeconds = tonumber(row.remaining_seconds) or 0

    if remainingSeconds <= 0 then
        MySQL.query('DELETE FROM nb_adminjail WHERE identifier = ?', { playerData.identifier })
        return
    end

    activeJails[source] = {
        remainingSeconds = remainingSeconds,
        reason = row.reason,
        adminName = row.admin_name,
        identifier = playerData.identifier
    }

    SetPlayerRoutingBucket(source, source)

    TriggerClientEvent('nb_adminjail:enterJail', source, {
        coords = Config.JailCoords,
        reason = row.reason,
        adminName = row.admin_name,
        remainingSeconds = remainingSeconds
    })
end)

-- ============================================================
-- Countdown - csak ONLINE játékosoknak telik, másodpercenként
-- ============================================================
CreateThread(function()
    while true do
        Wait(1000)

        for source, jail in pairs(activeJails) do
            jail.remainingSeconds = jail.remainingSeconds - 1

            if jail.remainingSeconds <= 0 then
                releaseFromJail(source)
            end
        end
    end
end)

-- Időszakos DB-mentés (biztonsági háló szerver-crash esetére)
CreateThread(function()
    while true do
        Wait(30000)
        for _, jail in pairs(activeJails) do
            saveJailToDb(jail.identifier, jail.adminName, jail.reason, jail.remainingSeconds)
        end
    end
end)

-- Kilépéskor AZONNAL elmentjük a pillanatnyi hátralévő időt (lefagyasztva,
-- hogy ne teljen tovább amíg offline van).
AddEventHandler('playerDropped', function()
    local source = source
    local jail = activeJails[source]

    if jail then
        saveJailToDb(jail.identifier, jail.adminName, jail.reason, jail.remainingSeconds)
    end

    activeJails[source] = nil
end)
