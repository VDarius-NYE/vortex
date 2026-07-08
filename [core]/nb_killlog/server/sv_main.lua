-- Minden PvP kill naplózása (48 órás megőrzéssel), + az F5 admin panel
-- kiszolgálása. Ugyanarra az eseményre iratkozunk fel, amit az nb_death
-- már triggerel (nb_core:playerKilled) - FONTOS: RegisterNetEvent kell
-- (nem AddEventHandler), mert ez egy hálózati esemény, minden resource-nak
-- saját magának kell regisztrálnia, különben "not safe for net" hibát dob.

CreateThread(function()
    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS nb_killlog (
                id INT AUTO_INCREMENT PRIMARY KEY,
                killer_name VARCHAR(50) NOT NULL,
                killer_id INT NOT NULL,
                victim_name VARCHAR(50) NOT NULL,
                victim_id INT NOT NULL,
                weapon VARCHAR(50),
                weapon_serial VARCHAR(20),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ]], {}, function()
            print('^3[nb_killlog]^7 nb_killlog tábla ellenőrizve/létrehozva.')
        end)
    end)
end)

RegisterNetEvent('nb_core:playerKilled', function(killerServerId, weaponName)
    local victimSource = source
    if not killerServerId or killerServerId == victimSource then return end

    local killerName = GetPlayerName(killerServerId)
    local victimName = GetPlayerName(victimSource)
    if not killerName or not victimName then return end

    -- Best-effort: megpróbáljuk kinyerni a gyilkos fegyverének serialját az
    -- inventoryjából (ha van ilyen fegyvere és van neki serialja) - ha
    -- bármi okból nem megy, egyszerűen nil marad, nem probléma.
    local weaponSerial = nil
    if weaponName then
        pcall(function()
            local inv = exports['nb_inventory']:GetInventory(killerServerId)
            if inv and inv.slots then
                for _, slot in pairs(inv.slots) do
                    if slot.item == weaponName and slot.metadata and slot.metadata.serial then
                        weaponSerial = slot.metadata.serial
                        break
                    end
                end
            end
        end)
    end

    MySQL.insert('INSERT INTO nb_killlog (killer_name, killer_id, victim_name, victim_id, weapon, weapon_serial) VALUES (?, ?, ?, ?, ?, ?)', {
        killerName, killerServerId, victimName, victimSource, weaponName, weaponSerial
    })
end)

-- 48 óránál régebbi bejegyzések törlése óránként
CreateThread(function()
    while true do
        Wait(3600000)
        MySQL.query('DELETE FROM nb_killlog WHERE created_at < NOW() - INTERVAL 48 HOUR')
    end
end)

-- ============================================================
-- F5 panel megnyitás - admin jogosultság kell
-- ============================================================
RegisterNetEvent('nb_killlog:requestOpen', function()
    local source = source

    if not exports['nb_group']:HasPermission(source, 'admin') then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        TriggerClientEvent('nb_killlog:closeUI', source)
        return
    end

    local rows = MySQL.query.await('SELECT * FROM nb_killlog WHERE created_at >= NOW() - INTERVAL 48 HOUR ORDER BY created_at DESC', {}) or {}

    TriggerClientEvent('nb_killlog:openUI', source, rows)
end)
