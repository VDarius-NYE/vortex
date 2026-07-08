-- Halál detektálás (natív halál elkapása + felülbírálása), stabil "földön
-- fekszik" animáció, teljes kontroll-tiltás, deathscreen, respawn/revive.

local isDead = false
local WRITHE_DICT = 'combat@damage@writhe'
local WRITHE_ANIM = 'writhe_loop'

-- Ismert fegyver hash -> item kulcs (nb_inventory-ban is ezt a nevet
-- használjuk), hogy a killfeed tudja melyik fegyverképet mutassa.
local weaponHashToName = {
    [GetHashKey('WEAPON_PISTOL')] = 'WEAPON_PISTOL',
    [GetHashKey('WEAPON_KNIFE')] = 'WEAPON_KNIFE',
    [GetHashKey('WEAPON_SMG')] = 'WEAPON_SMG',
    [GetHashKey('WEAPON_ASSAULTRIFLE')] = 'WEAPON_ASSAULTRIFLE',
}

-- ============================================================
-- Az alap FiveM/spawnmanager automatikus respawnjának letiltása - MI
-- kezeljük innentől teljesen a halál/respawn folyamatot.
-- ============================================================
CreateThread(function()
    Wait(1000)
    pcall(function()
        exports.spawnmanager:setAutoSpawn(false)
    end)
end)

-- ============================================================
-- Halál detektálása - a natív "meghalás" pillanatában AZONNAL visszaadjuk
-- az életet (hogy a játék saját fekete-fehér "wasted" respawn logikája ne
-- fusson le), és innentől MI szimuláljuk a halál-állapotot.
-- ============================================================
local function getKillerServerId(ped)
    local killerPed = GetPedSourceOfDeath(ped)
    if killerPed and killerPed ~= 0 and killerPed ~= ped and IsPedAPlayer(killerPed) then
        local idx = NetworkGetPlayerIndexFromPed(killerPed)
        if idx and idx ~= -1 then
            local sid = GetPlayerServerId(idx)
            if sid and sid > 0 then return sid end
        end
    end
    return nil
end

local function enterDeathState()
    if isDead then return end
    isDead = true

    local ped = PlayerPedId()
    local killerServerId = getKillerServerId(ped)

    -- A LÉNYEGI jelentések (deathscreen megjelenítése, statok, killfeed)
    -- MINDIG lefutnak, ELŐSZÖR, mielőtt bármi "díszítő" natívval
    -- bajlódnánk - így ha egy natív hívás hibázna valamiért lentebb, attól
    -- még a deathscreen biztosan megjelenik.
    TriggerServerEvent('nb_death:reportDeath', killerServerId)

    if killerServerId then
        local weaponHash = GetPedCauseOfDeath(ped)
        local weaponName = weaponHashToName[weaponHash]
        TriggerServerEvent('nb_core:playerKilled', killerServerId, weaponName)
    else
        TriggerServerEvent('nb_core:playerDiedGeneric')
    end

    -- Innentől a vizuális "díszítés" (ragdoll, animáció, health-visszanyomás)
    -- - pcall-lal védve, hogy egy esetleges natív hiba (pl. elgépelt/nem
    -- létező natív név) SOHA ne tudja megszakítani a fenti, lényegi részt.
    pcall(function()
        -- Visszaadjuk az életét, hogy a natív halál-flow (fekete-fehér fade,
        -- alap respawn) ne induljon el - innentől mi "díszítjük ki" a halált.
        -- FONTOS: a GTA natívoknál a ped "halál küszöbe" 100 (nem 0!), a
        -- teljes maximum health pedig 200 (=100% a HUD-on). Pontosan a
        -- küszöbre állítjuk (100), hogy a HUD helyesen 0%-ot mutasson.
        SetEntityHealth(ped, 100)
        ClearPedTasksImmediately(ped)
        SetEntityInvincible(ped, true)

        -- 1. FÁZIS: rövid ragdoll, hogy természetesen essen össze
        SetPedToRagdoll(ped, 1200, 1200, 0, false, false, false)
    end)

    CreateThread(function()
        Wait(1200)
        if not isDead then return end

        pcall(function()
            -- 2. FÁZIS: stabil, HURKOLT animáció ("sebesült fekszik a
            -- földön") - ez nem jár le magától, ezért nem áll fel.
            RequestAnimDict(WRITHE_DICT)
            local timeout = 0
            while not HasAnimDictLoaded(WRITHE_DICT) and timeout < 2000 do
                Wait(50)
                timeout = timeout + 50
            end

            while isDead do
                local p = PlayerPedId()

                if not IsEntityPlayingAnim(p, WRITHE_DICT, WRITHE_ANIM, 3) then
                    TaskPlayAnim(p, WRITHE_DICT, WRITHE_ANIM, 8.0, -8.0, -1, 1, 0, false, false, false)
                end
                Wait(500)
            end

            RemoveAnimDict(WRITHE_DICT)
        end)
    end)
end

CreateThread(function()
    local wasDead = false
    while true do
        Wait(0)
        local ped = PlayerPedId()
        local dead = IsEntityDead(ped)

        if dead and not wasDead then
            enterDeathState()
        end

        wasDead = dead
    end
end)

-- Kombat-halálnál (CEventNetworkEntityDamage) is elkapjuk, hátha gyorsabb
-- mint a per-tick IsEntityDead ellenőrzés - a guard (isDead) miatt nem fut
-- le kétszer.
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    if isDead then return end

    local victim = args[1]
    local victimDied = args[6] == 1

    if victim == PlayerPedId() and victimDied then
        enterDeathState()
    end
end)

-- ============================================================
-- Teljes kontroll-tiltás (mozgás + kamera is), amíg "halott" vagyunk
-- ============================================================
CreateThread(function()
    while true do
        if isDead then
            Wait(0)
            DisableAllControlActions(0)
        else
            Wait(300)
        end
    end
end)

-- ============================================================
-- Deathscreen megjelenítés + countdown
-- ============================================================
RegisterNetEvent('nb_death:showDeathScreen', function(data)
    SendNUIMessage({
        action = 'show',
        killerName = data.killerName
    })

    CreateThread(function()
        local remaining = data.seconds

        while remaining > 0 and isDead do
            SendNUIMessage({ action = 'updateTimer', seconds = remaining })
            Wait(1000)
            remaining = remaining - 1
        end

        if isDead then
            TriggerServerEvent('nb_death:requestRespawn')
        end
    end)
end)

-- ============================================================
-- Közös "kilépés a halál-állapotból" logika (respawn ÉS revive is ezt
-- használja) - mindig lefut, feltétel nélkül, védőhálóként.
-- ============================================================
local function exitDeathState()
    isDead = false -- ez állítja le a fenti animáció-loopot is
    SendNUIMessage({ action = 'hide' })

    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
end

-- ============================================================
-- Respawn (5 perc lejárta után)
-- ============================================================
RegisterNetEvent('nb_death:doRespawn', function(spawn)
    exitDeathState()

    local ped = PlayerPedId()

    if spawn then
        NetworkResurrectLocalPlayer(spawn.x, spawn.y, spawn.z, spawn.heading or 0.0, true, false)
    else
        NetworkResurrectLocalPlayer(GetEntityCoords(ped), 0.0, true, false)
    end

    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
end)

-- ============================================================
-- Admin /revive - FONTOS: RegisterNetEvent kell (nem sima AddEventHandler),
-- különben a FiveM "was not safe for net" hibát dob, mert ez az esemény
-- hálózaton keresztül (a szervertől) érkezik, és minden resource-nak, ami
-- kezelni akarja, saját magának is regisztrálnia kell hálózati eseményként.
-- ============================================================
RegisterNetEvent('nb_administration:revive', function()
    local wasDead = isDead
    exitDeathState()

    if wasDead then
        TriggerServerEvent('nb_death:reportRevived')
    end
end)
