-- Halál-állapot követése, respawn pont kiadása (frakció-alapú), kifosztás.

local downedPlayers = {} -- [source] = true, amíg a player "földön fekszik"

-- ============================================================
-- Halál jelentése (a kliens hívja, miután elkapta a natív halált)
-- ============================================================
RegisterNetEvent('nb_death:reportDeath', function(killerServerId)
    local source = source
    downedPlayers[source] = true

    local killerName = nil
    if killerServerId and killerServerId > 0 and killerServerId ~= source then
        killerName = GetPlayerName(killerServerId)
    end

    TriggerClientEvent('nb_death:showDeathScreen', source, {
        killerName = killerName,
        seconds = Config.RespawnSeconds
    })

    -- Mindenki más kliensének jelezzük, hogy itt egy "hulla" van, hogy
    -- regisztrálhassák a kifosztás-interakciót (a nb_interact pontok
    -- kliensenként lokálisak, ezért mindenkinek külön kell regisztrálnia).
    local coords = GetEntityCoords(GetPlayerPed(source))
    TriggerClientEvent('nb_death:corpseDown', -1, {
        victim = source,
        victimName = GetPlayerName(source),
        coords = { x = coords.x, y = coords.y, z = coords.z }
    })
end)

-- ============================================================
-- Respawn pont kérése (5 perc lejártakor vagy admin életre keltés után)
-- ============================================================
local function getSpawnPoint(source)
    local spawn = nil
    pcall(function() spawn = exports['nb_factions']:GetSpawnPoint(source) end)
    if not spawn then
        pcall(function() spawn = exports['nb_core']:GetDefaultSpawn() end)
    end
    return spawn
end

RegisterNetEvent('nb_death:requestRespawn', function()
    local source = source
    downedPlayers[source] = nil

    TriggerClientEvent('nb_death:doRespawn', source, getSpawnPoint(source))
    TriggerClientEvent('nb_death:removeCorpse', -1, source)
end)

-- Admin /revive esetén is töröljük az állapotot + a hulla-pontot - ezt a
-- kliens (cl_death.lua) jelzi vissza a 'nb_death:reportRevived' eseménnyel,
-- miután elkapta a saját 'nb_administration:revive' eseményét.
RegisterNetEvent('nb_death:reportRevived', function()
    local source = source
    downedPlayers[source] = nil
    TriggerClientEvent('nb_death:removeCorpse', -1, source)
end)

-- ============================================================
-- Kifosztás - a halott player TELJES inventoryja egy Föld-kupacba kerül,
-- amit a fosztogató azonnal meg is nyit.
-- ============================================================
RegisterNetEvent('nb_death:requestLoot', function(victimServerId)
    local source = source

    if not downedPlayers[victimServerId] then
        exports['nb_core']:Notify(source, { message = 'Ez a játékos már nincs lefosztható állapotban.', type = 'error' })
        return
    end

    local victimPed = GetPlayerPed(victimServerId)
    if not victimPed or victimPed == 0 then return end

    local coords = GetEntityCoords(victimPed)
    local groundId = exports['nb_inventory']:DumpToGroundStash(victimServerId, { x = coords.x, y = coords.y, z = coords.z })

    if not groundId then
        exports['nb_core']:Notify(source, { message = 'Nem sikerült a fosztogatás.', type = 'error' })
        return
    end

    TriggerEvent('nb_inventory:forceOpenStash', source, groundId)

    -- A hulla inventoryja kiürült, a kifosztás-pont többé nem kell
    TriggerClientEvent('nb_death:removeCorpse', -1, victimServerId)
end)

AddEventHandler('playerDropped', function()
    downedPlayers[source] = nil
end)

exports('IsDowned', function(source) return downedPlayers[source] == true end)
