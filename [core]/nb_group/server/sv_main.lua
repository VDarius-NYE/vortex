-- Csoport/jogosultság kezelés: adatbázis-alapú, automatikus hierarchiával.

local groupCache = {} -- [source] = groupName

CreateThread(function()
    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS nb_groups (
                identifier VARCHAR(64) PRIMARY KEY,
                group_name VARCHAR(20) NOT NULL DEFAULT 'user',
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ]], {}, function()
            print('^3[nb_group]^7 nb_groups tábla ellenőrizve/létrehozva.')
        end)
    end)
end)

local function isBootstrapOwner(identifier)
    for _, id in ipairs(Config.BootstrapOwners) do
        if id == identifier then return true end
    end
    return false
end

-- Amint a core beazonosította a playert (még a login előtt), betöltjük a csoportját.
AddEventHandler('nb_core:playerLoaded', function(source)
    local ok, err = pcall(function()
        local playerData = exports['nb_core']:GetPlayerData(source)
        if not playerData then return end

        local identifier = playerData.identifier
        local result = MySQL.query.await('SELECT group_name FROM nb_groups WHERE identifier = ?', { identifier })
        local row = result and result[1]

        local groupName

        if row then
            groupName = row.group_name
        else
            groupName = isBootstrapOwner(identifier) and 'owner' or Config.DefaultGroup
            MySQL.insert.await('INSERT IGNORE INTO nb_groups (identifier, group_name) VALUES (?, ?)', {
                identifier, groupName
            })
            if groupName == 'owner' then
                print(('^2[nb_group]^7 Bootstrap owner beállítva: %s'):format(identifier))
            end
        end

        groupCache[source] = groupName
        TriggerClientEvent('nb_group:setGroup', source, groupName)
    end)

    if not ok then
        print(('^1[nb_group] HIBA a playerLoaded kezelőben: %s'):format(tostring(err)))
    end
end)

AddEventHandler('playerDropped', function()
    local source = source
    groupCache[source] = nil
end)

-- ============================================================
-- Exportok
-- ============================================================

local function getGroup(source)
    return groupCache[source] or Config.DefaultGroup
end

local function getGroupLevel(source)
    local group = getGroup(source)
    return Config.Hierarchy[group] or 0
end

--- Igaz, ha a player csoportszintje eléri (vagy meghaladja) a kért csoport szintjét.
--- Pl. HasPermission(source, 'admin') igaz lesz owner-re és admin-ra is.
local function hasPermission(source, requiredGroup)
    local playerLevel = getGroupLevel(source)
    local requiredLevel = Config.Hierarchy[requiredGroup]
    if not requiredLevel then return false end
    return playerLevel >= requiredLevel
end

local function getGroupByIdentifier(identifier)
    local result = MySQL.query.await('SELECT group_name FROM nb_groups WHERE identifier = ?', { identifier })
    local row = result and result[1]
    return row and row.group_name or Config.DefaultGroup
end

--- Csoport beállítása egy ONLINE playernek (source alapján).
--- Visszaad: ok (bool), errorMessage (string vagy nil)
local function setGroup(targetSource, groupName)
    if not Config.Hierarchy[groupName] then
        return false, ('Ismeretlen csoport: %s'):format(tostring(groupName))
    end

    local playerData = exports['nb_core']:GetPlayerData(targetSource)
    if not playerData then
        return false, 'A célpont nincs bejelentkezve / nem elérhető.'
    end

    MySQL.query.await([[
        INSERT INTO nb_groups (identifier, group_name)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE group_name = VALUES(group_name), updated_at = CURRENT_TIMESTAMP
    ]], { playerData.identifier, groupName })

    groupCache[targetSource] = groupName
    TriggerClientEvent('nb_group:setGroup', targetSource, groupName)

    return true
end

exports('GetGroup', getGroup)
exports('GetGroupLevel', getGroupLevel)
exports('HasPermission', hasPermission)
exports('SetGroup', setGroup)
exports('GetGroupByIdentifier', getGroupByIdentifier)

-- ============================================================
-- /setgroup parancs (csak owner használhatja, konzolról mindig elérhető)
-- ============================================================
RegisterCommand('setgroup', function(source, args)
    local isConsole = source == 0

    if not isConsole and not hasPermission(source, 'owner') then
        exports['nb_core']:Notify(source, {
            message = 'Nincs jogosultságod ehhez a parancshoz.',
            type = 'error'
        })
        return
    end

    local targetId = tonumber(args[1])
    local groupName = args[2]

    if not targetId or not groupName then
        local usage = 'Használat: /setgroup [player_id] [user|support|admin|owner]'
        if isConsole then
            print(usage)
        else
            exports['nb_core']:Notify(source, { message = usage, type = 'warning' })
        end
        return
    end

    local ok, errMsg = setGroup(targetId, groupName)

    if ok then
        local msg = ('%s csoportja mostantól: %s'):format(GetPlayerName(targetId) or targetId, groupName)
        if isConsole then
            print(msg)
        else
            exports['nb_core']:Notify(source, { message = msg, type = 'success' })
        end
        exports['nb_core']:Notify(targetId, {
            message = ('A csoportod megváltozott: %s'):format(groupName),
            type = 'info'
        })
    else
        if isConsole then
            print('HIBA: ' .. errMsg)
        else
            exports['nb_core']:Notify(source, { message = errMsg, type = 'error' })
        end
    end
end, false)

-- Gyors info parancs: /mygroup - megmutatja a saját csoportodat
RegisterCommand('mygroup', function(source)
    if source == 0 then return end
    exports['nb_core']:Notify(source, {
        message = ('A csoportod: %s'):format(getGroup(source)),
        type = 'info'
    })
end, false)
