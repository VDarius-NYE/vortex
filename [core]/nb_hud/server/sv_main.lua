-- HUD beállítások (stílus, pozíciók, láthatósági szabályok) mentése/betöltése.

CreateThread(function()
    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS nb_hud_settings (
                identifier VARCHAR(64) PRIMARY KEY,
                settings LONGTEXT,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        ]], {}, function()
            print('^3[nb_hud]^7 nb_hud_settings tábla ellenőrizve/létrehozva.')
        end)
    end)
end)

local function loadSettingsForPlayer(source)
    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return end

    local result = MySQL.query.await('SELECT settings FROM nb_hud_settings WHERE identifier = ?', { playerData.identifier })
    local row = result and result[1]

    local settings
    if row and row.settings then
        settings = json.decode(row.settings)
    else
        settings = Config.DefaultSettings
        MySQL.insert.await('INSERT IGNORE INTO nb_hud_settings (identifier, settings) VALUES (?, ?)', {
            playerData.identifier, json.encode(Config.DefaultSettings)
        })
    end

    TriggerClientEvent('nb_hud:loadSettings', source, settings)
end

-- Amint bejelentkezett (nem kell megvárni a karakterkészítőt, a HUD-nak
-- mindegy - de a natívak úgyis csak akkor adnak értelmes adatot, ha már
-- van pedje a playernek, ami login után rögtön megvan).
AddEventHandler('nb_accounts:playerLoggedIn', function(source)
    loadSettingsForPlayer(source)
end)

RegisterNetEvent('nb_hud:saveSettings', function(settings)
    local source = source
    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return end

    MySQL.query.await([[
        INSERT INTO nb_hud_settings (identifier, settings)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE settings = VALUES(settings), updated_at = CURRENT_TIMESTAMP
    ]], { playerData.identifier, json.encode(settings) })

    exports['nb_core']:Notify(source, { message = 'HUD beállítások elmentve.', type = 'success' })
end)

RegisterNetEvent('nb_hud:requestReset', function()
    local source = source
    TriggerClientEvent('nb_hud:loadSettings', source, Config.DefaultSettings)
end)
