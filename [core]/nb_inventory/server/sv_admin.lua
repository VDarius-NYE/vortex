-- Admin parancsok: item adás, teljes inventory ürítés.

-- ============================================================
-- /giveitem [player_id] [item_kulcs] [mennyiség]
-- pl: /giveitem 1 WEAPON_ASSAULTRIFLE 1   vagy   /giveitem 1 water_bottle 5
-- ============================================================
RegisterCommand('giveitem', function(source, args)
    local isConsole = source == 0

    if not isConsole and not exports['nb_group']:HasPermission(source, 'admin') then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    local targetId = tonumber(args[1])
    local itemName = args[2]
    local amount = tonumber(args[3]) or 1

    if not targetId or not itemName or not GetPlayerName(targetId) then
        local msg = 'Használat: /giveitem [player_id] [item_kulcs] [mennyiség]'
        if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'warning' }) end
        return
    end

    if not Config.Items[itemName] then
        local msg = ('Ismeretlen item: %s'):format(itemName)
        if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'error' }) end
        return
    end

    local ok, err = NBInv.AddItemTo('player', targetId, itemName, amount)

    if ok then
        NBInv.SendPopup(targetId, itemName, 'received', amount)

        local label = Config.Items[itemName].label
        local msg = ('%s kapott: %d db %s'):format(GetPlayerName(targetId), amount, label)
        if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'success' }) end

        if not isConsole and targetId ~= source then
            exports['nb_core']:Notify(targetId, { message = ('Kaptál: %d db %s'):format(amount, label), type = 'success' })
        end
    else
        if isConsole then print('HIBA: ' .. (err or '')) else exports['nb_core']:Notify(source, { message = err or 'Hiba történt.', type = 'error' }) end
    end
end, false)

-- ============================================================
-- /clearinv [player_id] (ha nincs megadva, önmagad)
-- ============================================================
RegisterCommand('clearinv', function(source, args)
    local isConsole = source == 0

    if not isConsole and not exports['nb_group']:HasPermission(source, 'admin') then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    local targetId = tonumber(args[1]) or source
    if isConsole and not tonumber(args[1]) then
        print('Használat: /clearinv [player_id]')
        return
    end
    if not GetPlayerName(targetId) then
        local msg = 'Nincs ilyen player ID.'
        if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'warning' }) end
        return
    end

    NBInv.ClearInventory('player', targetId)
    TriggerEvent('nb_inventory:internalRefresh', targetId)

    local msg = ('%s inventoryja kiürítve.'):format(GetPlayerName(targetId))
    if isConsole then print(msg) else exports['nb_core']:Notify(source, { message = msg, type = 'success' }) end
end, false)
