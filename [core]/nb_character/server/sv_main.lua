-- Karakter mentés/betöltés + admin által is hívható publikus export

CreateThread(function()
    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS nb_characters (
                identifier VARCHAR(64) PRIMARY KEY,
                model VARCHAR(32) DEFAULT 'mp_m_freemode_01',
                appearance LONGTEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ]], {}, function()
            print('^3[nb_character]^7 nb_characters tábla ellenőrizve/létrehozva.')
        end)
    end)
end)

-- Frakció-alapú spawn pont lekérése (ha az nb_factions fut és a playernek
-- van saját frakció-spawnja), egyébként visszaesik az nb_core alap spawnjára.
local function getSpawnPoint(source)
    local spawn = nil
    pcall(function()
        spawn = exports['nb_factions']:GetSpawnPoint(source)
    end)
    if not spawn then
        pcall(function()
            spawn = exports['nb_core']:GetDefaultSpawn()
        end)
    end
    return spawn
end

-- Amint sikeresen bejelentkezett valaki (nb_accounts), eldöntjük: már van mentett
-- karaktere (csendben alkalmazzuk és spawnolunk), vagy nincs (megnyitjuk a creator-t).
AddEventHandler('nb_accounts:playerLoggedIn', function(source)
    local ok, err = pcall(function()
        local playerData = exports['nb_core']:GetPlayerData(source)
        if not playerData then return end

        local result = MySQL.query.await('SELECT model, appearance FROM nb_characters WHERE identifier = ?', { playerData.identifier })
        local row = result and result[1]

        if row and row.appearance then
            exports['nb_core']:SetCharacterLoaded(source, true)
            TriggerClientEvent('nb_character:applySaved', source, {
                model = row.model,
                appearance = json.decode(row.appearance),
                spawn = getSpawnPoint(source)
            })
        else
            TriggerClientEvent('nb_character:openCreator', source, { mode = 'create', appearance = nil })
        end
    end)

    if not ok then
        print(('^1[nb_character] HIBA a playerLoggedIn kezelőben: %s'):format(tostring(err)))
    end
end)

-- Karakter mentése (a creator "Mentés" gombjára)
RegisterNetEvent('nb_character:save', function(payload)
    local source = source
    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return end

    local model = payload.model or 'mp_m_freemode_01'
    local appearanceJson = json.encode(payload.appearance or {})

    MySQL.query.await([[
        INSERT INTO nb_characters (identifier, model, appearance, updated_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE model = VALUES(model), appearance = VALUES(appearance), updated_at = CURRENT_TIMESTAMP
    ]], { playerData.identifier, model, appearanceJson })

    exports['nb_core']:SetCharacterLoaded(source, true)
    exports['nb_core']:Notify(source, {
        message = 'Karakter elmentve!',
        type = 'success',
        duration = 4000
    })

    -- Új karakter létrehozásakor a kliens megvárja ezt az eseményt, mielőtt
    -- ténylegesen spawnolna (a spawn pontot MINDIG a szerver dönti el).
    TriggerClientEvent('nb_character:spawnConfirmed', source, getSpawnPoint(source))

    print(('^2[nb_character]^7 Karakter elmentve: %s'):format(playerData.identifier))
end)

-- ============================================================
-- PUBLIKUS EXPORT - ezt fogja hívni a jövőbeli nb_administration,
-- hogy egy admin megnyithassa a karakterkészítőt egy adott játékosnak
-- (pl. ha elrontotta a kinézetét). A cél player kapja meg a panelt,
-- nem az admin.
-- ============================================================
local function openCreatorFor(targetId, mode)
    mode = mode or 'edit'
    targetId = tonumber(targetId)

    if not targetId or not GetPlayerName(targetId) then
        return false, 'A megadott player ID nem található.'
    end

    local playerData = exports['nb_core']:GetPlayerData(targetId)
    if not playerData then
        return false, 'A player adatai nem elérhetők (nincs bejelentkezve?).'
    end

    local result = MySQL.query.await('SELECT model, appearance FROM nb_characters WHERE identifier = ?', { playerData.identifier })
    local row = result and result[1]

    local appearancePayload = nil
    local model = nil
    if row and row.appearance then
        appearancePayload = json.decode(row.appearance)
        model = row.model
    end

    TriggerClientEvent('nb_character:openCreator', targetId, {
        mode = mode,
        model = model,
        appearance = appearancePayload
    })

    return true
end

exports('OpenCreatorFor', openCreatorFor)

-- /fixappearance [player_id]  (ha nincs megadva id, önmagát nyitja meg)
-- Jogosultság: support szint (nb_group), önmagára viszont bárki használhatja.
RegisterCommand('fixappearance', function(source, args)
    local targetId = tonumber(args[1]) or source

    if source ~= 0 and targetId ~= source then
        if not exports['nb_group']:HasPermission(source, 'support') then
            exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod más játékosra használni ezt.', type = 'error' })
            return
        end
    end

    local ok, errMsg = openCreatorFor(targetId, 'edit')

    if not ok and source ~= 0 then
        exports['nb_core']:Notify(source, { message = errMsg or 'Ismeretlen hiba történt.', type = 'error' })
    end
end, false)
