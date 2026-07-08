-- Részletes játékos infó (account + karakter + előzmények) az admin panelhez,
-- plusz a warn és kick napló táblák kezelése.

CreateThread(function()
    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS nb_warns (
                id INT AUTO_INCREMENT PRIMARY KEY,
                identifier VARCHAR(64) NOT NULL,
                admin_identifier VARCHAR(64),
                admin_name VARCHAR(50),
                reason TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ]])

        MySQL.query([[
            CREATE TABLE IF NOT EXISTS nb_kicks (
                id INT AUTO_INCREMENT PRIMARY KEY,
                identifier VARCHAR(64) NOT NULL,
                admin_identifier VARCHAR(64),
                admin_name VARCHAR(50),
                reason TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ]])

        -- MariaDB 10.4+ támogatja az ADD COLUMN IF NOT EXISTS-t, így biztonságosan
        -- hozzáadható ez a mező akkor is, ha az nb_users tábla már régebb óta létezik.
        MySQL.query([[
            ALTER TABLE nb_users
            ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ]], {}, function()
            print('^3[nb_administration]^7 nb_warns / nb_kicks tábla és nb_users.updated_at ellenőrizve.')
        end)
    end)
end)

local function logKick(identifier, adminIdentifier, adminName, reason)
    MySQL.insert.await('INSERT INTO nb_kicks (identifier, admin_identifier, admin_name, reason) VALUES (?, ?, ?, ?)', {
        identifier, adminIdentifier, adminName, reason
    })
end

exports('LogKick', logKick)

local function calcKD(kills, deaths)
    kills = kills or 0
    deaths = deaths or 0
    if deaths <= 0 then
        return kills > 0 and string.format('%.2f', kills) or '0.00'
    end
    local ratio = kills / deaths
    if ratio < 0 then ratio = 0 end
    return string.format('%.2f', ratio)
end

-- ============================================================
-- Teljes játékos-részletek lekérdezése (csak online játékosra). MINDIG
-- élő (aktuális, memóriában lévő) adatot ad vissza minden olyan mezőnél,
-- ami menet közben is változhat (playtime, bank, kills/deaths, cash) -
-- nem a (néha percekkel elmaradó) adatbázis-értéket.
-- ============================================================
local function sendPlayerDetails(source, targetId)
    if not exports['nb_group']:HasPermission(source, Config.Permissions.viewDetails) then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    if not targetId or not GetPlayerName(targetId) then
        exports['nb_core']:Notify(source, { message = 'A célpont már nincs a szerveren.', type = 'error' })
        return
    end

    local playerData = exports['nb_core']:GetPlayerData(targetId)
    if not playerData then return end

    local identifier = playerData.identifier

    local userRow = MySQL.query.await('SELECT * FROM nb_users WHERE identifier = ?', { identifier })
    userRow = userRow and userRow[1] or {}

    local charRow = MySQL.query.await('SELECT model, created_at, updated_at FROM nb_characters WHERE identifier = ?', { identifier })
    charRow = charRow and charRow[1]

    local warns = MySQL.query.await('SELECT admin_name, reason, created_at, id FROM nb_warns WHERE identifier = ? ORDER BY created_at DESC', { identifier }) or {}
    local bans = MySQL.query.await('SELECT reason, banned_by_name, banned_at, expires_at FROM nb_bans WHERE identifier = ? ORDER BY banned_at DESC', { identifier }) or {}
    local kicks = MySQL.query.await('SELECT admin_name, reason, created_at FROM nb_kicks WHERE identifier = ? ORDER BY created_at DESC', { identifier }) or {}

    -- Élő készpénz lekérdezése az nb_inventory-ból (pcall, hátha az a resource nem fut)
    local cash = nil
    pcall(function()
        cash = exports['nb_inventory']:GetItemCount(targetId, 'cash')
    end)

    TriggerClientEvent('nb_administration:showDetails', source, {
        targetId = targetId,
        account = {
            identifier = identifier,
            discord = userRow.discord,
            steam = userRow.steam,
            username = userRow.username,
            email = userRow.email,
            playtime = playerData.playtime or 0,  -- ÉLŐ adat, nem a (percekkel elmaradó) DB érték
            created_at = userRow.created_at,
            updated_at = userRow.updated_at,
            last_login = userRow.last_login,
            group = exports['nb_group']:GetGroup(targetId)
        },
        character = charRow and {
            model = charRow.model,
            created_at = charRow.created_at,
            updated_at = charRow.updated_at
        } or nil,
        economy = {
            cash = cash,
            bank = playerData.bank or 0
        },
        stats = {
            kills = playerData.kills or 0,
            deaths = playerData.deaths or 0,
            kd = calcKD(playerData.kills, playerData.deaths)
        },
        warns = warns,
        bans = bans,
        kicks = kicks
    })
end

RegisterNetEvent('nb_administration:requestDetails', function(targetId)
    sendPlayerDetails(source, tonumber(targetId))
end)

-- ============================================================
-- Warn hozzáadása / törlése
-- ============================================================
RegisterNetEvent('nb_administration:addWarn', function(data)
    local source = source
    local targetId = tonumber(data.targetId)

    if not exports['nb_group']:HasPermission(source, Config.Permissions.warn) then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    if not targetId or not GetPlayerName(targetId) then
        exports['nb_core']:Notify(source, { message = 'A célpont már nincs a szerveren.', type = 'error' })
        return
    end

    local reason = (data.reason and data.reason ~= '') and data.reason or 'Nincs megadva indok.'
    local targetPlayerData = exports['nb_core']:GetPlayerData(targetId)
    if not targetPlayerData then return end

    local adminData = exports['nb_core']:GetPlayerData(source)

    MySQL.insert.await('INSERT INTO nb_warns (identifier, admin_identifier, admin_name, reason) VALUES (?, ?, ?, ?)', {
        targetPlayerData.identifier,
        adminData and adminData.identifier,
        GetPlayerName(source),
        reason
    })

    exports['nb_core']:Notify(source, {
        message = ('%s figyelmeztetve. Indok: %s'):format(GetPlayerName(targetId), reason),
        type = 'success'
    })
    exports['nb_core']:Notify(targetId, {
        message = ('Figyelmeztetést kaptál %s admintól. Indok: %s'):format(GetPlayerName(source), reason),
        type = 'warning',
        duration = 8000
    })

    sendPlayerDetails(source, targetId)
end)

RegisterNetEvent('nb_administration:deleteWarn', function(data)
    local source = source

    if not exports['nb_group']:HasPermission(source, 'owner') then
        exports['nb_core']:Notify(source, { message = 'Csak owner törölhet figyelmeztetést.', type = 'error' })
        return
    end

    MySQL.query.await('DELETE FROM nb_warns WHERE id = ?', { tonumber(data.warnId) })
    exports['nb_core']:Notify(source, { message = 'Figyelmeztetés törölve.', type = 'success' })

    if data.targetId then
        sendPlayerDetails(source, tonumber(data.targetId))
    end
end)
