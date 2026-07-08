-- Szerver leállás/karbantartás: countdown indítása, mindenkinek UI+hang
-- broadcast, lejáratkor kickelés + szerver leállítás, és amíg a countdown
-- (karbantartás módban) fut, új csatlakozók kiszűrése (kivéve owner).

local shutdownActive = false
local maintenanceMode = false
local shutdownReason = ''

-- ============================================================
-- /shutdown {perc} {indok...} {true/false - karbantartás mód, opcionális}
-- Csak OWNER használhatja.
-- ============================================================
RegisterCommand('shutdown', function(source, args)
    local isConsole = source == 0

    if not isConsole then
        local group = nil
        pcall(function() group = exports['nb_group']:GetGroup(source) end)
        if group ~= 'owner' then
            exports['nb_core']:Notify(source, { message = 'Ez a parancs csak owner-eknek elérhető.', type = 'error' })
            return
        end
    end

    if shutdownActive then
        local msg = 'Már fut egy leállás-countdown.'
        if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'warning' }) end
        return
    end

    local minutes = tonumber(args[1])
    if not minutes or minutes <= 0 then
        local msg = 'Használat: /shutdown [perc] [indok] [true/false - karbantartás mód]'
        if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'warning' }) end
        return
    end

    -- Az utolsó argumentum lehet a karbantartás true/false kapcsoló -
    -- ha nem az, egyszerűen a teljes indok része lesz.
    local reasonParts = {}
    local isMaintenance = false
    local lastArg = args[#args]

    if #args > 1 and lastArg and (lastArg:lower() == 'true' or lastArg:lower() == 'false') then
        isMaintenance = lastArg:lower() == 'true'
        for i = 2, #args - 1 do
            reasonParts[#reasonParts + 1] = args[i]
        end
    else
        for i = 2, #args do
            reasonParts[#reasonParts + 1] = args[i]
        end
    end

    local reason = table.concat(reasonParts, ' ')
    if reason == '' then reason = 'Karbantartás.' end

    startShutdownCountdown(minutes, reason, isMaintenance)
end, false)

-- ============================================================
-- Countdown logika
-- ============================================================
function startShutdownCountdown(minutes, reason, isMaintenance)
    shutdownActive = true
    shutdownReason = reason
    maintenanceMode = isMaintenance

    local remainingMinutes = minutes

    CreateThread(function()
        -- Azonnal (a kezdő percnél is) jelzünk UI-t + hangot
        TriggerClientEvent('nb_shutdown:show', -1, { minutes = remainingMinutes, reason = reason })
        TriggerClientEvent('nb_shutdown:playSound', -1)

        while remainingMinutes > 0 do
            Wait(60000)
            remainingMinutes = remainingMinutes - 1

            TriggerClientEvent('nb_shutdown:show', -1, { minutes = remainingMinutes, reason = reason })

            if remainingMinutes > 0 then
                TriggerClientEvent('nb_shutdown:playSound', -1)
            end
        end

        -- Lejárt az idő - mindenkit kickelünk, és bekapcsoljuk (ha még nem
        -- volt) a karbantartás módot, hogy senki (owner kivételével) ne
        -- tudjon visszalépni, amíg te magad ki nem kapcsolod (/endmaintenance).
        -- A szervert magát NEM állítjuk le.
        local kickMsg = ('A szerver leáll. \nIndok: %s'):format(reason)

        for _, playerId in ipairs(GetPlayers()) do
            DropPlayer(tonumber(playerId), kickMsg)
        end

        maintenanceMode = true
        shutdownActive = false

        TriggerClientEvent('nb_shutdown:hide', -1)

        print(('^1[nb_shutdown]^7 Countdown lejárt, mindenki kickelve. Indok: %s'):format(reason))
    end)
end

-- ============================================================
-- Karbantartás mód: új csatlakozók kiszűrése (kivéve owner) - a raw
-- identifiereket az nb_groups táblában nézzük meg közvetlenül, mert
-- ilyenkor a player MÉG NEM ment át a normál login/karakter folyamaton.
-- ============================================================
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local source = source
    deferrals.defer()

    Wait(0)

    if maintenanceMode then
        local identifiers = GetPlayerIdentifiers(source)
        local isOwner = false

        for _, id in ipairs(identifiers) do
            local ok, result = pcall(function()
                return MySQL.query.await('SELECT identifier FROM nb_groups WHERE identifier = ? AND group_name = ?', { id, 'owner' })
            end)
            if ok and result and result[1] then
                isOwner = true
                break
            end
        end

        if not isOwner then
            deferrals.done('A szerveren jelenleg karbantartás folyik, nézz vissza később, vagy figyeld a felhívások szobát a Discord szerverünkön.\nDiscord: https://discord.gg/Szu9T9wdzU')
            return
        end
    end

    deferrals.done()
end)

exports('IsShutdownActive', function() return shutdownActive end)
exports('IsMaintenanceMode', function() return maintenanceMode end)

-- ============================================================
-- /endmaintenance - kikapcsolja a karbantartás módot (owner)
-- ============================================================
RegisterCommand('endmaintenance', function(source)
    local isConsole = source == 0

    if not isConsole then
        local group = nil
        pcall(function() group = exports['nb_group']:GetGroup(source) end)
        if group ~= 'owner' then
            exports['nb_core']:Notify(source, { message = 'Ez a parancs csak owner-eknek elérhető.', type = 'error' })
            return
        end
    end

    if not maintenanceMode then
        local msg = 'Nincs is aktív karbantartás mód.'
        if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'warning' }) end
        return
    end

    maintenanceMode = false

    local msg = 'Karbantartás mód kikapcsolva - a szerver újra nyitva mindenkinek.'
    if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'success' }) end
end, false)
