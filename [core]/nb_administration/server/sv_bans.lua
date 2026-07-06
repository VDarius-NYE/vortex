-- Ban rendszer: adatbázisban tárolt tiltások, csatlakozáskor ellenőrizve.

CreateThread(function()
    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS nb_bans (
                id INT AUTO_INCREMENT PRIMARY KEY,
                identifier VARCHAR(64) NOT NULL,
                reason TEXT,
                banned_by_identifier VARCHAR(64),
                banned_by_name VARCHAR(50),
                banned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                expires_at TIMESTAMP NULL DEFAULT NULL
            )
        ]], {}, function()
            print('^3[nb_administration]^7 nb_bans tábla ellenőrizve/létrehozva.')
        end)
    end)
end)

-- Csatlakozáskor ellenőrizzük, van-e érvényes (nem lejárt) tiltás az identifierhez.
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local source = source
    deferrals.defer()
    Wait(0)

    local identifier = exports['nb_core']:GetPrimaryIdentifier(source)
    if not identifier then
        deferrals.done()
        return
    end

    local result = MySQL.query.await([[
        SELECT reason, banned_at, expires_at FROM nb_bans
        WHERE identifier = ? AND (expires_at IS NULL OR expires_at > NOW())
        ORDER BY banned_at DESC LIMIT 1
    ]], { identifier })

    local ban = result and result[1]

    if ban then
        local expiry = ban.expires_at and ('Lejár: %s'):format(ban.expires_at) or 'Végleges tiltás.'
        deferrals.done(('Ki vagy tiltva a Vortex Military szerverről.\nIndok: %s\n%s'):format(
            ban.reason or 'Nincs megadva indok.', expiry
        ))
        return
    end

    deferrals.done()
end)

local function banIdentifier(identifier, reason, bannedByIdentifier, bannedByName, durationMinutes)
    local expiresAt = nil
    if durationMinutes and durationMinutes > 0 then
        expiresAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + durationMinutes * 60)
    end

    MySQL.insert.await([[
        INSERT INTO nb_bans (identifier, reason, banned_by_identifier, banned_by_name, expires_at)
        VALUES (?, ?, ?, ?, ?)
    ]], { identifier, reason, bannedByIdentifier, bannedByName, expiresAt })
end

local function unbanIdentifier(identifier)
    MySQL.query.await('DELETE FROM nb_bans WHERE identifier = ?', { identifier })
end

exports('BanIdentifier', banIdentifier)
exports('UnbanIdentifier', unbanIdentifier)

-- /ban [player_id] [indok...]   - csak online játékosra (permanens)
RegisterCommand('ban', function(source, args)
    local isConsole = source == 0
    if not isConsole and not exports['nb_group']:HasPermission(source, Config.Permissions.ban) then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    local targetId = tonumber(args[1])
    if not targetId or not GetPlayerName(targetId) then
        local msg = 'Használat: /ban [player_id] [indok]'
        if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'warning' }) end
        return
    end

    local reason = table.concat(args, ' ', 2) ~= '' and table.concat(args, ' ', 2) or 'Nincs megadva indok.'
    local targetPlayerData = exports['nb_core']:GetPlayerData(targetId)
    if not targetPlayerData then return end

    local bannedByIdentifier, bannedByName = nil, 'Konzol'
    if not isConsole then
        local adminData = exports['nb_core']:GetPlayerData(source)
        bannedByIdentifier = adminData and adminData.identifier
        bannedByName = GetPlayerName(source)
    end

    banIdentifier(targetPlayerData.identifier, reason, bannedByIdentifier, bannedByName, nil)
    DropPlayer(targetId, ('Kitiltva a szerverről. Indok: %s'):format(reason))

    local msg = ('%s kitiltva. Indok: %s'):format(GetPlayerName(targetId) or targetId, reason)
    if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'success' }) end
end, false)

-- /unban [identifier]   - a teljes identifier stringet kell megadni (pl. license:...)
RegisterCommand('unban', function(source, args)
    local isConsole = source == 0
    if not isConsole and not exports['nb_group']:HasPermission(source, Config.Permissions.unban) then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    local identifier = args[1]
    if not identifier then
        local msg = 'Használat: /unban [identifier]'
        if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'warning' }) end
        return
    end

    unbanIdentifier(identifier)
    local msg = ('Feloldva: %s'):format(identifier)
    if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'success' }) end
end, false)
