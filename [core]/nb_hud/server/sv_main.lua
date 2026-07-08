-- HUD beállítások (stílus, pozíciók, láthatósági szabályok) mentése/betöltése.

-- A jelenleg betöltött beállítás minden online playerre - más resource-ok
-- (pl. nb_killfeed) ebből tudják lekérdezni egy adott elem pozícióját, hogy
-- ugyanoda rajzolják ki a saját tartalmukat, amit itt csak "helyfoglalóként"
-- lehet pozícionálni az /edithud szerkesztőben.
local currentSettings = {} -- [source] = settings

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

-- Ha egy régebbi mentett beállításból hiányzik egy elem (mert azóta új
-- elemet vezettünk be, pl. Készpénz/Bank/Kills), pótoljuk az alapértelmezett
-- pozíciójával/beállításával - így SOHA nem hiányozhat elem a mentett
-- adatból, és a NUI nem szállhat el rá (xPercent undefined stb.).
local function mergeWithDefaults(saved)
    saved = saved or {}
    saved.style = saved.style or Config.DefaultSettings.style
    saved.elements = saved.elements or {}

    for key, defaultEl in pairs(Config.DefaultSettings.elements) do
        if not saved.elements[key] then
            saved.elements[key] = defaultEl
        end
    end

    return saved
end

local function loadSettingsForPlayer(source)
    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return end

    local result = MySQL.query.await('SELECT settings FROM nb_hud_settings WHERE identifier = ?', { playerData.identifier })
    local row = result and result[1]

    local settings
    if row and row.settings then
        settings = mergeWithDefaults(json.decode(row.settings))
    else
        settings = Config.DefaultSettings
        MySQL.insert.await('INSERT IGNORE INTO nb_hud_settings (identifier, settings) VALUES (?, ?)', {
            playerData.identifier, json.encode(Config.DefaultSettings)
        })
    end

    currentSettings[source] = settings
    TriggerClientEvent('nb_hud:loadSettings', source, settings)
    TriggerEvent('nb_hud:settingsLoaded', source, settings)
end

-- Amint bejelentkezett (nem kell megvárni a karakterkészítőt, a HUD-nak
-- mindegy - de a natívak úgyis csak akkor adnak értelmes adatot, ha már
-- van pedje a playernek, ami login után rögtön megvan).
AddEventHandler('nb_accounts:playerLoggedIn', function(source)
    loadSettingsForPlayer(source)
end)

AddEventHandler('playerDropped', function()
    currentSettings[source] = nil
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

    currentSettings[source] = settings
    exports['nb_core']:Notify(source, { message = 'HUD beállítások elmentve.', type = 'success' })
    TriggerEvent('nb_hud:settingsSaved', source, settings)
end)

RegisterNetEvent('nb_hud:requestReset', function()
    local source = source
    currentSettings[source] = Config.DefaultSettings
    TriggerClientEvent('nb_hud:loadSettings', source, Config.DefaultSettings)
    TriggerEvent('nb_hud:settingsSaved', source, Config.DefaultSettings)
end)

-- Export: egy adott elem jelenlegi beállítása (pozíció + alwaysVisible) egy
-- adott playerre - pl. exports['nb_hud']:GetElementSettings(source, 'killfeed')
exports('GetElementSettings', function(source, key)
    local settings = currentSettings[source]
    return settings and settings.elements and settings.elements[key] or nil
end)
