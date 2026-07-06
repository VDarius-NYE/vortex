-- Admin panel (F4) - játékoslista gyors akciókkal.

local GROUPS_ORDERED = { 'user', 'support', 'admin', 'owner' }

local function buildPlayerList()
    local list = {}
    for _, playerId in ipairs(GetPlayers()) do
        local id = tonumber(playerId)
        list[#list + 1] = {
            id = id,
            name = GetPlayerName(id) or ('Player #%d'):format(id),
            group = exports['nb_group']:GetGroup(id),
            onDuty = exports['nb_administration']:IsOnDuty(id)
        }
    end
    return list
end

RegisterNetEvent('nb_administration:requestPanel', function()
    local source = source

    if not exports['nb_group']:HasPermission(source, Config.Permissions.panel) then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod a panelhez.', type = 'error' })
        return
    end

    TriggerClientEvent('nb_administration:openPanel', source, {
        players = buildPlayerList(),
        groups = GROUPS_ORDERED,
        myGroup = exports['nb_group']:GetGroup(source)
    })
end)

RegisterNetEvent('nb_administration:refreshPanel', function()
    local source = source
    if not exports['nb_group']:HasPermission(source, Config.Permissions.panel) then return end
    TriggerClientEvent('nb_administration:updatePlayerList', source, buildPlayerList())
end)

-- Egységes akció-kezelő a panel gombjaihoz (ugyanazokat a jogosultsági
-- szinteket használja, mint a chat parancsok).
RegisterNetEvent('nb_administration:panelAction', function(data)
    local source = source
    local action = data.action
    local targetId = tonumber(data.targetId)

    if not targetId or not GetPlayerName(targetId) then
        exports['nb_core']:Notify(source, { message = 'A célpont már nincs a szerveren.', type = 'error' })
        return
    end

    local function hasPerm(permKey)
        return exports['nb_group']:HasPermission(source, Config.Permissions[permKey])
    end

    local function deny()
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
    end

    if action == 'tp' then
        if not hasPerm('tp') then return deny() end
        local coords = GetEntityCoords(GetPlayerPed(targetId))
        TriggerClientEvent('nb_administration:teleport', source, { x = coords.x, y = coords.y, z = coords.z })
        exports['nb_core']:Notify(source, {
            message = ('Ráteleportáltál %s játékosra.'):format(GetPlayerName(targetId)),
            type = 'success'
        })
        exports['nb_core']:Notify(targetId, {
            message = ('%s rádteleportált.'):format(GetPlayerName(source)),
            type = 'info'
        })

    elseif action == 'bring' then
        if not hasPerm('bring') then return deny() end
        local coords = GetEntityCoords(GetPlayerPed(source))
        TriggerClientEvent('nb_administration:teleport', targetId, { x = coords.x, y = coords.y, z = coords.z })
        exports['nb_core']:Notify(source, {
            message = ('Magadhoz teleportáltad %s játékost.'):format(GetPlayerName(targetId)),
            type = 'success'
        })
        exports['nb_core']:Notify(targetId, {
            message = ('%s magához teleportált téged.'):format(GetPlayerName(source)),
            type = 'info'
        })

    elseif action == 'revive' then
        if not hasPerm('revive') then return deny() end
        TriggerClientEvent('nb_administration:revive', targetId)
        if targetId == source then
            exports['nb_core']:Notify(source, { message = 'Feltámasztottad magad.', type = 'success' })
        else
            exports['nb_core']:Notify(source, {
                message = ('Feltámasztottad %s játékost.'):format(GetPlayerName(targetId)),
                type = 'success'
            })
            exports['nb_core']:Notify(targetId, {
                message = ('%s feltámasztott téged.'):format(GetPlayerName(source)),
                type = 'info'
            })
        end

    elseif action == 'heal' then
        if not hasPerm('heal') then return deny() end
        TriggerClientEvent('nb_administration:heal', targetId)
        exports['nb_basicneeds']:SetHunger(targetId, 100)
        exports['nb_basicneeds']:SetThirst(targetId, 100)
        if targetId == source then
            exports['nb_core']:Notify(source, { message = 'Meggyógyítottad magad (étel/víz is feltöltve).', type = 'success' })
        else
            exports['nb_core']:Notify(source, {
                message = ('Meggyógyítottad %s játékost (étel/víz is feltöltve).'):format(GetPlayerName(targetId)),
                type = 'success'
            })
            exports['nb_core']:Notify(targetId, {
                message = ('%s meggyógyított téged.'):format(GetPlayerName(source)),
                type = 'info'
            })
        end

    elseif action == 'kick' then
        if not hasPerm('kick') then return deny() end
        local reason = (data.reason and data.reason ~= '') and data.reason or 'Nincs megadva indok.'
        local name = GetPlayerName(targetId)
        local targetPlayerData = exports['nb_core']:GetPlayerData(targetId)
        if targetPlayerData then
            local adminData = exports['nb_core']:GetPlayerData(source)
            exports['nb_administration']:LogKick(targetPlayerData.identifier, adminData and adminData.identifier, GetPlayerName(source), reason)
        end
        DropPlayer(targetId, ('Kirúgva a szerverről. Indok: %s'):format(reason))
        exports['nb_core']:Notify(source, {
            message = ('Kirúgtad %s játékost. Indok: %s'):format(name, reason),
            type = 'success'
        })

    elseif action == 'ban' then
        if not hasPerm('ban') then return deny() end
        local reason = (data.reason and data.reason ~= '') and data.reason or 'Nincs megadva indok.'
        local targetPlayerData = exports['nb_core']:GetPlayerData(targetId)
        if not targetPlayerData then return end

        local adminData = exports['nb_core']:GetPlayerData(source)
        exports['nb_administration']:BanIdentifier(
            targetPlayerData.identifier, reason,
            adminData and adminData.identifier, GetPlayerName(source), nil
        )
        local name = GetPlayerName(targetId)
        DropPlayer(targetId, ('Kitiltva a szerverről. Indok: %s'):format(reason))
        exports['nb_core']:Notify(source, {
            message = ('Kitiltottad %s játékost. Indok: %s'):format(name, reason),
            type = 'success'
        })

    elseif action == 'setgroup' then
        if not exports['nb_group']:HasPermission(source, 'owner') then return deny() end
        local ok, err = exports['nb_group']:SetGroup(targetId, data.group)
        if ok then
            exports['nb_core']:Notify(source, {
                message = ('%s csoportja mostantól: %s'):format(GetPlayerName(targetId), data.group),
                type = 'success'
            })
            if targetId ~= source then
                exports['nb_core']:Notify(targetId, {
                    message = ('A csoportod megváltozott: %s'):format(data.group),
                    type = 'info'
                })
            end
        else
            exports['nb_core']:Notify(source, { message = err or 'Hiba történt.', type = 'error' })
        end
    end

    -- Frissített lista visszaküldése minden akció után
    TriggerClientEvent('nb_administration:updatePlayerList', source, buildPlayerList())
end)
