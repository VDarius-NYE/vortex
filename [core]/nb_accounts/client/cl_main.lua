local uiOpen = false

local function openUI(mode)
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', mode = mode })
end

local function closeUI()
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('nb_accounts:openUI', function(mode)
    print(('[nb_accounts] openUI event megérkezett, mode: %s'):format(tostring(mode)))

    -- Race condition ellen: a NUI oldal (HTML/JS) lehet, hogy még nem töltött be
    -- teljesen abban a pillanatban, amikor ez az event megérkezik (pl. ha ez
    -- rögtön a resource indulása után/csatlakozáskor történik). Emiatt nem
    -- elég EGYSZER elküldeni a SendNUIMessage-et, mert az elveszhet, ha még
    -- nincs 'message' listener regisztrálva a JS oldalon.
    -- Ehelyett néhányszor újraküldjük rövid időközönként (max ~3 másodpercig),
    -- amíg a JS jelzi (NUI callback), hogy megkapta és feldolgozta.
    uiOpen = false

    CreateThread(function()
        local attempts = 0
        while not uiOpen and attempts < 20 do
            SetNuiFocus(true, true)
            SendNUIMessage({ action = 'open', mode = mode })
            attempts = attempts + 1
            Wait(150)
        end

        if uiOpen then
            print(('[nb_accounts] UI sikeresen megnyílt %d próbálkozás után.'):format(attempts))
        else
            print('^1[nb_accounts] FIGYELEM: a UI 20 próbálkozás után sem nyílt meg (JS oldali probléma lehet).')
        end
    end)
end)

-- A JS ezt hívja meg amint ténylegesen feldolgozta és megjelenítette az 'open' üzenetet
RegisterNUICallback('uiOpened', function(data, cb)
    uiOpen = true
    cb('ok')
end)

local function onAuthenticated()
    closeUI()
    -- A limbo feloldását és a spawnolást mostantól az nb_character intézi:
    -- ha van már mentett karaktere, csendben alkalmazza és kienged a limboból;
    -- ha nincs, megnyitja a karakterkészítőt (ami a mentés után enged ki).
end

RegisterNetEvent('nb_accounts:registerResult', function(success, errorMsg)
    SendNUIMessage({ action = 'registerResult', success = success, message = errorMsg })
    if success then
        exports['nb_core']:Notify({
            message = 'Sikeres regisztráció! Üdvözlünk a Vortex Military-nél.',
            type = 'success',
            duration = 6000
        })
        onAuthenticated()
    end
end)

RegisterNetEvent('nb_accounts:loginResult', function(success, errorMsg)
    SendNUIMessage({ action = 'loginResult', success = success, message = errorMsg })
    if success then
        exports['nb_core']:Notify({
            message = 'Sikeres bejelentkezés!',
            type = 'success',
            duration = 4000
        })
        onAuthenticated()
    end
end)

RegisterNUICallback('register', function(data, cb)
    print('[nb_accounts] register NUI callback megkapva, adatok: ' .. json.encode(data))
    TriggerServerEvent('nb_accounts:register', data)
    cb('ok')
end)

RegisterNUICallback('login', function(data, cb)
    print('[nb_accounts] login NUI callback megkapva, adatok: ' .. json.encode(data))
    TriggerServerEvent('nb_accounts:login', data)
    cb('ok')
end)

-- Regisztráció/login közben a kamera lassan körbeforog egy katonai bázis felett (esztétika)
CreateThread(function()
    while true do
        Wait(0)
        if uiOpen then
            DisableAllControlActions(0)
        else
            Wait(500)
        end
    end
end)
