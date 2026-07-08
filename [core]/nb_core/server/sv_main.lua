-- Player connect / join kezelés + alap tábla létrehozása

CreateThread(function()
    MySQL.ready(function()
        NB.Debug('Adatbázis kapcsolat rendben.')

        MySQL.query([[
            CREATE TABLE IF NOT EXISTS nb_users (
                identifier VARCHAR(64) PRIMARY KEY,
                identifier_type VARCHAR(16) NOT NULL,
                license VARCHAR(64) DEFAULT NULL,
                discord VARCHAR(32) DEFAULT NULL,
                steam VARCHAR(32) DEFAULT NULL,
                username VARCHAR(32) DEFAULT NULL,
                email VARCHAR(100) DEFAULT NULL,
                password VARCHAR(255) DEFAULT NULL,
                playtime INT DEFAULT 0,
                last_login TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ]], {}, function()
            MySQL.query([[
                ALTER TABLE nb_users
                ADD COLUMN IF NOT EXISTS bank INT NOT NULL DEFAULT 0,
                ADD COLUMN IF NOT EXISTS kills INT NOT NULL DEFAULT 0,
                ADD COLUMN IF NOT EXISTS deaths INT NOT NULL DEFAULT 0
            ]], {}, function()
                NB.Debug('nb_users tábla ellenőrizve/létrehozva.')
            end)
        end)
    end)
end)

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local source = source
    deferrals.defer()

    Wait(0)
    deferrals.update('Azonosítók ellenőrzése...')

    local identifier, identifierType = NB.GetPrimaryIdentifier(source)

    if not identifier then
        deferrals.done('Nem sikerült azonosítani a Rockstar licenszedet. Csatlakozás megszakítva.')
        return
    end

    local identifiers = NB.GetIdentifiers(source)

    -- Ellenőrizzük hogy létezik-e már account, ha nem, létrehozzuk az alap sort
    local result = MySQL.query.await('SELECT * FROM nb_users WHERE identifier = ?', { identifier })

    if not result or #result == 0 then
        local ok, err = pcall(function()
            MySQL.insert.await('INSERT IGNORE INTO nb_users (identifier, identifier_type, license, discord, steam) VALUES (?, ?, ?, ?, ?)', {
                identifier, identifierType, identifiers.license, identifiers.discord, identifiers.steam
            })
        end)
        if ok then
            NB.Debug(('Új account létrehozva: %s'):format(identifier))
        else
            print(('^1[nb_core] HIBA account létrehozásnál: %s'):format(tostring(err)))
        end
    end

    deferrals.done()
end)

AddEventHandler('playerJoining', function()
    local source = source
    local identifier, identifierType = NB.GetPrimaryIdentifier(source)

    if not identifier then return end

    local result = MySQL.query.await('SELECT * FROM nb_users WHERE identifier = ?', { identifier })
    local userData = (result and result[1]) or {}

    local player = NB.PlayerClass.New(source, identifier, identifierType, userData)
    NB.Players[source] = player

    NB.Debug(('Player betöltve memóriába: %s (identifier: %s)'):format(GetPlayerName(source), identifier))

    -- Ezt az eventet hallgatja majd a nb_accounts (login/regisztráció indítása)
    -- és később a nb_factions is, ha be van kötve.
    -- FONTOS: csak a source-ot adjuk át, a Player objektumot SOHA ne adjuk át
    -- resource-ok között eventen/exporton keresztül, mert az függvényeket
    -- tartalmaz, amik nem szerializálhatók (msgpack) a resource-határon át.
    NB.Debug('nb_core:playerLoaded event kilövése...')
    TriggerEvent('nb_core:playerLoaded', source)
    NB.Debug('nb_core:playerLoaded event lefutott (hívások visszatértek).')
end)

AddEventHandler('playerDropped', function(reason)
    local source = source
    local player = NB.Players[source]

    if player then
        player.Functions.Save()
        NB.Debug(('Player mentve és eltávolítva: %s'):format(player.PlayerData.identifier))
        NB.Players[source] = nil
    end
end)

-- Egyéb resource-ok számára export, hogy megvárhassák míg a core betölt egy playert
NB.CreateCallback('nb_core:isLoggedIn', function(source, cb)
    local player = NB.Players[source]
    cb(player and player.PlayerData.loggedIn or false)
end)

-- Szerver oldali export (a kliens oldali mellett), hogy más resource-ok
-- SZERVERRŐL is le tudják kérdezni az alap spawn pontot (pl. nb_factions
-- a frakció-alapú spawn fallback-jéhez).
exports('GetDefaultSpawn', function() return Config.DefaultSpawn end)
