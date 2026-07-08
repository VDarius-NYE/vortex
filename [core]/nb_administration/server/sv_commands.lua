-- Admin parancsok, mind az nb_group hierarchián keresztül jogosultsághoz kötve.

local function checkPermission(source, permKey)
    if source == 0 then return true end -- konzol mindig mehet
    return exports['nb_group']:HasPermission(source, Config.Permissions[permKey])
end

local function denyMessage(source, isConsole)
    local msg = 'Nincs jogosultságod ehhez a parancshoz.'
    if isConsole then
        print(msg)
    else
        exports['nb_core']:Notify(source, { message = msg, type = 'error' })
    end
end

local function usageMessage(source, isConsole, usage)
    if isConsole then
        print(usage)
    else
        exports['nb_core']:Notify(source, { message = usage, type = 'warning' })
    end
end

-- ============================================================
-- /tp [player_id] - odateleportál a megadott playerhez
-- ============================================================
RegisterCommand('tp', function(source, args)
    local isConsole = source == 0
    if not checkPermission(source, 'tp') then return denyMessage(source, isConsole) end
    if isConsole then return usageMessage(source, isConsole, '/tp csak játékban használható.') end

    local targetId = tonumber(args[1])
    if not targetId or not GetPlayerName(targetId) then
        return usageMessage(source, isConsole, 'Használat: /tp [player_id]')
    end

    local targetPed = GetPlayerPed(targetId)
    local coords = GetEntityCoords(targetPed)
    TriggerClientEvent('nb_administration:teleport', source, { x = coords.x, y = coords.y, z = coords.z })

    exports['nb_core']:Notify(source, {
        message = ('Ráteleportáltál %s játékosra.'):format(GetPlayerName(targetId)),
        type = 'success'
    })
    exports['nb_core']:Notify(targetId, {
        message = ('%s rádteleportált.'):format(GetPlayerName(source)),
        type = 'info'
    })
end, false)

-- ============================================================
-- /bring [player_id] - a megadott playert magadhoz teleportálja
-- ============================================================
RegisterCommand('bring', function(source, args)
    local isConsole = source == 0
    if not checkPermission(source, 'bring') then return denyMessage(source, isConsole) end
    if isConsole then return usageMessage(source, isConsole, '/bring csak játékban használható.') end

    local targetId = tonumber(args[1])
    if not targetId or not GetPlayerName(targetId) then
        return usageMessage(source, isConsole, 'Használat: /bring [player_id]')
    end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    TriggerClientEvent('nb_administration:teleport', targetId, { x = coords.x, y = coords.y, z = coords.z })

    exports['nb_core']:Notify(source, {
        message = ('Magadhoz teleportáltad %s játékost.'):format(GetPlayerName(targetId)),
        type = 'success'
    })
    exports['nb_core']:Notify(targetId, {
        message = ('%s magához teleportált téged.'):format(GetPlayerName(source)),
        type = 'info'
    })
end, false)

-- ============================================================
-- /revive [player_id] (ha nincs megadva, önmagadat élesztheted fel)
-- ============================================================
RegisterCommand('revive', function(source, args)
    local isConsole = source == 0
    if not checkPermission(source, 'revive') then return denyMessage(source, isConsole) end

    local targetId = tonumber(args[1]) or source
    if isConsole and not tonumber(args[1]) then
        return usageMessage(source, isConsole, 'Használat: /revive [player_id]')
    end
    if not GetPlayerName(targetId) then
        return usageMessage(source, isConsole, 'Nincs ilyen player ID.')
    end

    TriggerClientEvent('nb_administration:revive', targetId)

    if isConsole then return end

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
end, false)

-- ============================================================
-- /heal [player_id] (ha nincs megadva, önmagad)
-- ============================================================
RegisterCommand('heal', function(source, args)
    local isConsole = source == 0
    if not checkPermission(source, 'heal') then return denyMessage(source, isConsole) end

    local targetId = tonumber(args[1]) or source
    if isConsole and not tonumber(args[1]) then
        return usageMessage(source, isConsole, 'Használat: /heal [player_id]')
    end
    if not GetPlayerName(targetId) then
        return usageMessage(source, isConsole, 'Nincs ilyen player ID.')
    end

    TriggerClientEvent('nb_administration:heal', targetId)
    exports['nb_basicneeds']:SetHunger(targetId, 100)
    exports['nb_basicneeds']:SetThirst(targetId, 100)

    if isConsole then return end

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
end, false)

-- ============================================================
-- /setarmor [mennyiség 0-100] [player_id] (ha nincs id megadva, önmagad)
-- ============================================================
RegisterCommand('setarmor', function(source, args)
    local isConsole = source == 0
    if not checkPermission(source, 'setarmor') then return denyMessage(source, isConsole) end
    if isConsole then return usageMessage(source, isConsole, '/setarmor csak játékban használható.') end

    local amount = tonumber(args[1])
    if not amount then
        return usageMessage(source, isConsole, 'Használat: /setarmor [mennyiség 0-100] [player_id]')
    end
    amount = math.max(0, math.min(100, amount))

    local targetId = tonumber(args[2]) or source
    if not GetPlayerName(targetId) then
        return usageMessage(source, isConsole, 'Nincs ilyen player ID.')
    end

    TriggerClientEvent('nb_administration:setArmor', targetId, amount)

    if targetId == source then
        exports['nb_core']:Notify(source, { message = ('Páncélod beállítva: %d%%.'):format(amount), type = 'success' })
    else
        exports['nb_core']:Notify(source, {
            message = ('%s páncélját beállítottad: %d%%.'):format(GetPlayerName(targetId), amount),
            type = 'success'
        })
        exports['nb_core']:Notify(targetId, {
            message = ('%s beállította a páncélodat: %d%%.'):format(GetPlayerName(source), amount),
            type = 'info'
        })
    end
end, false)

-- ============================================================
-- /kick [player_id] [indok...]
-- ============================================================
RegisterCommand('kick', function(source, args)
    local isConsole = source == 0
    if not checkPermission(source, 'kick') then return denyMessage(source, isConsole) end

    local targetId = tonumber(args[1])
    if not targetId or not GetPlayerName(targetId) then
        return usageMessage(source, isConsole, 'Használat: /kick [player_id] [indok]')
    end

    local reason = (args[2] and table.concat(args, ' ', 2)) or 'Nincs megadva indok.'
    local targetPlayerData = exports['nb_core']:GetPlayerData(targetId)
    local name = GetPlayerName(targetId)

    if targetPlayerData then
        local adminIdentifier, adminName = nil, 'Konzol'
        if not isConsole then
            local adminData = exports['nb_core']:GetPlayerData(source)
            adminIdentifier = adminData and adminData.identifier
            adminName = GetPlayerName(source)
        end
        exports['nb_administration']:LogKick(targetPlayerData.identifier, adminIdentifier, adminName, reason)
    end

    DropPlayer(targetId, ('Kirúgva a szerverről. Indok: %s'):format(reason))

    local msg = ('%s kirúgva. Indok: %s'):format(name or targetId, reason)
    if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'success' }) end
end, false)

-- ============================================================
-- /noclip - saját magadra kapcsolod be/ki
-- ============================================================
RegisterCommand('noclip', function(source)
    if source == 0 then return end
    if not checkPermission(source, 'noclip') then return denyMessage(source, false) end
    TriggerClientEvent('nb_administration:toggleNoclip', source)
end, false)

-- ============================================================
-- /godmode - saját magadra kapcsolod be/ki (sebezhetetlenség)
-- ============================================================
RegisterCommand('godmode', function(source)
    if source == 0 then return end
    if not checkPermission(source, 'godmode') then return denyMessage(source, false) end
    TriggerClientEvent('nb_administration:toggleGodmode', source)
end, false)

-- ============================================================
-- /announce [üzenet...] - mindenkinek notify
-- ============================================================
RegisterCommand('announce', function(source, args)
    local isConsole = source == 0
    if not checkPermission(source, 'announce') then return denyMessage(source, isConsole) end

    local message = table.concat(args, ' ')
    if message == '' then
        return usageMessage(source, isConsole, 'Használat: /announce [üzenet]')
    end

    for _, playerId in ipairs(GetPlayers()) do
        exports['nb_core']:Notify(tonumber(playerId), {
            message = ('[SZERVER KÖZLEMÉNY] %s'):format(message),
            type = 'warning',
            duration = 8000
        })
    end

    if not isConsole then exports['nb_core']:Notify(source, { message = 'Közlemény elküldve.', type = 'success' }) end
end, false)

-- ============================================================
-- /car [model] - jármű spawnolása (alapértelmezett: Config.DefaultVehicleModel)
-- ============================================================
RegisterCommand('car', function(source, args)
    local isConsole = source == 0
    if isConsole then return end
    if not checkPermission(source, 'car') then return denyMessage(source, isConsole) end

    local model = args[1] or Config.DefaultVehicleModel
    TriggerClientEvent('nb_administration:spawnVehicle', source, model)
end, false)

-- ============================================================
-- /tpm - a kitűzött térkép-útvonalhoz (waypoint) teleportál
-- ============================================================
RegisterCommand('tpm', function(source)
    local isConsole = source == 0
    if isConsole then return end
    if not checkPermission(source, 'tpm') then return denyMessage(source, isConsole) end

    TriggerClientEvent('nb_administration:requestWaypoint', source)
end, false)

RegisterNetEvent('nb_administration:doTpmCoords', function(x, y)
    local source = source
    if not checkPermission(source, 'tpm') then return end
    TriggerClientEvent('nb_administration:doTpm', source, x, y)
end)

-- ============================================================
-- /dv [radius] - közeli járművek törlése (radius nélkül: amiben ülsz)
-- ============================================================
RegisterCommand('dv', function(source, args)
    local isConsole = source == 0
    if isConsole then return end
    if not checkPermission(source, 'dv') then return denyMessage(source, isConsole) end

    local radius = tonumber(args[1])
    TriggerClientEvent('nb_administration:doDeleteVehicles', source, radius)
end, false)

RegisterNetEvent('nb_administration:reportDeletedVehicles', function(count)
    local source = source
    exports['nb_core']:Notify(source, { message = ('%d jármű törölve.'):format(count), type = 'success' })
end)

-- ============================================================
-- /kill [player_id] - azonnali "megölés" (generic halálként regisztrálódik)
-- ============================================================
RegisterCommand('kill', function(source, args)
    local isConsole = source == 0
    if not checkPermission(source, 'kill') then return denyMessage(source, isConsole) end

    local targetId = tonumber(args[1])
    if not targetId or not GetPlayerName(targetId) then
        return usageMessage(source, isConsole, 'Használat: /kill [player_id]')
    end

    TriggerClientEvent('nb_administration:forceKill', targetId)

    local msg = ('%s megölve.'):format(GetPlayerName(targetId))
    if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'success' }) end
end, false)
