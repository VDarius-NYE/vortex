-- Regisztráció / bejelentkezés kezelése

math.randomseed(os.time() + GetGameTimer())

local function generateSalt()
    local chars = '0123456789abcdef'
    local salt = ''
    for _ = 1, 16 do
        local i = math.random(1, #chars)
        salt = salt .. chars:sub(i, i)
    end
    return salt
end

local function hashPassword(password, salt)
    return SHA256(salt .. password)
end

-- Amint a nb_core betöltötte a playert, eldöntjük hogy regisztráció vagy login kell
AddEventHandler('nb_core:playerLoaded', function(source)
    print(('^2[nb_accounts]^7 nb_core:playerLoaded event megérkezett, source: %s'):format(tostring(source)))

    local ok, result = pcall(function()
        local playerData = exports['nb_core']:GetPlayerData(source)
        print(('^2[nb_accounts]^7 GetPlayerData eredmény: %s'):format(json.encode(playerData or 'NIL')))

        local identifier = playerData.identifier

        local dbResult = MySQL.query.await('SELECT username, email, password FROM nb_users WHERE identifier = ?', { identifier })
        local row = dbResult and dbResult[1]

        print(('^2[nb_accounts]^7 DB lekérdezés eredménye: %s'):format(json.encode(dbResult or 'NIL')))

        if not row or not row.password then
            print('^2[nb_accounts]^7 Regisztrációs UI megnyitása...')
            TriggerClientEvent('nb_accounts:openUI', source, 'register')
        else
            print('^2[nb_accounts]^7 Login UI megnyitása...')
            TriggerClientEvent('nb_accounts:openUI', source, 'login')
        end
    end)

    if not ok then
        print(('^1[nb_accounts] HIBA a playerLoaded kezelőben: %s'):format(tostring(result)))
    end
end)

RegisterNetEvent('nb_accounts:register', function(data)
    local source = source
    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return end

    local username = data.username and data.username:gsub('%s+', '')
    local email = data.email and data.email:lower():gsub('%s+', '')
    local password = data.password

    -- Validáció
    if not username or #username < Config.Account.minUsernameLength or #username > Config.Account.maxUsernameLength then
        TriggerClientEvent('nb_accounts:registerResult', source, false, 'A felhasználónév 3-20 karakter hosszú lehet.')
        return
    end

    if not email or not email:match('^[%w%.%-_]+@[%w%.%-_]+%.%a+$') then
        TriggerClientEvent('nb_accounts:registerResult', source, false, 'Érvénytelen email cím.')
        return
    end

    if not password or #password < Config.Account.minPasswordLength then
        TriggerClientEvent('nb_accounts:registerResult', source, false, ('A jelszó legalább %d karakter legyen.'):format(Config.Account.minPasswordLength))
        return
    end

    -- Egyediség ellenőrzés
    local existing = MySQL.query.await('SELECT identifier FROM nb_users WHERE (username = ? OR email = ?) AND identifier != ?', {
        username, email, playerData.identifier
    })

    if existing and #existing > 0 then
        TriggerClientEvent('nb_accounts:registerResult', source, false, 'Ez a felhasználónév vagy email cím már foglalt.')
        return
    end

    local salt = generateSalt()
    local hashed = hashPassword(password, salt)
    local storedPassword = ('%s:%s'):format(salt, hashed)

    MySQL.update.await('UPDATE nb_users SET username = ?, email = ?, password = ? WHERE identifier = ?', {
        username, email, storedPassword, playerData.identifier
    })

    exports['nb_core']:SetLoggedIn(source, true)

    print(('^3[nb_accounts]^7 Új regisztráció: %s (%s)'):format(username, playerData.identifier))

    TriggerClientEvent('nb_accounts:registerResult', source, true)
    TriggerEvent('nb_accounts:playerLoggedIn', source)
end)

RegisterNetEvent('nb_accounts:login', function(data)
    local source = source
    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return end

    local usernameOrEmail = data.username and data.username:gsub('%s+', '')
    local password = data.password

    if not usernameOrEmail or not password then
        TriggerClientEvent('nb_accounts:loginResult', source, false, 'Töltsd ki az összes mezőt.')
        return
    end

    local result = MySQL.query.await('SELECT * FROM nb_users WHERE identifier = ? AND (username = ? OR email = ?)', {
        playerData.identifier, usernameOrEmail, usernameOrEmail:lower()
    })

    local row = result and result[1]

    if not row then
        TriggerClientEvent('nb_accounts:loginResult', source, false, 'Nincs ilyen fiók ehhez a Rockstar accounthoz kötve.')
        return
    end

    local salt, storedHash = row.password:match('^(.-):(.+)$')
    local attemptHash = hashPassword(password, salt)

    if attemptHash ~= storedHash then
        TriggerClientEvent('nb_accounts:loginResult', source, false, 'Hibás jelszó.')
        return
    end

    MySQL.update('UPDATE nb_users SET last_login = CURRENT_TIMESTAMP WHERE identifier = ?', { playerData.identifier })

    exports['nb_core']:SetLoggedIn(source, true)

    print(('^3[nb_accounts]^7 Bejelentkezés sikeres: %s'):format(row.username))

    TriggerClientEvent('nb_accounts:loginResult', source, true)
    TriggerEvent('nb_accounts:playerLoggedIn', source)
end)
