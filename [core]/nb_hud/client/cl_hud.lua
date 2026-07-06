-- HUD statok gyűjtése és a NUI felé küldése, plusz a szerkesztő mód (/edithud).

NBHud = NBHud or {}

local settings = Config.DefaultSettings
local settingsReady = false
local editMode = false
local uiAck = false

local stats = {
    health = 100,
    armor = 0,
    hunger = 100,
    thirst = 100,
    stamina = 100
}

-- ============================================================
-- Publikus exportok (pl. a jövőbeli nb_basicneeds ezt hívja majd az
-- éhség/szomjúság frissítéséhez)
-- ============================================================
function NBHud.SetStat(name, value)
    if stats[name] == nil then return end
    stats[name] = math.max(0, math.min(100, value))
end

function NBHud.GetStat(name)
    return stats[name]
end

exports('SetStat', NBHud.SetStat)
exports('GetStat', NBHud.GetStat)

RegisterNetEvent('nb_hud:setStat', function(name, value)
    NBHud.SetStat(name, value)
end)

-- ============================================================
-- Beállítások betöltése (szerver küldi login után, vagy reset/mentés után)
-- ============================================================
RegisterNetEvent('nb_hud:loadSettings', function(newSettings)
    settings = newSettings
    settingsReady = true

    -- Mindig frissítjük a NUI-t is (nem csak szerkesztés közben), hogy a
    -- mentett beállítások azonnal érvényesüljenek, amint betöltődnek -
    -- nem kell hozzá megnyitni az /edithud-ot.
    SendNUIMessage({ action = 'updateSettings', settings = settings })
end)

-- ============================================================
-- Fő render/adatgyűjtő ciklus - csak azután indul, hogy a player TÉNYLEGESEN
-- lespawnolt (login/regisztráció + karakterkészítés kész), nem korábban.
-- ============================================================

local spawned = false

-- A GetPlayerSprintStaminaRemaining ismert sajátossága, hogy amíg a stamina
-- rendszer nincs inicializálva (pl. friss spawn után), 0-ról indul és úgy
-- tűnik mintha "feltöltődne", ahelyett hogy 100-ról fogyna futás közben.
-- Ezzel egyszer teljesre állítjuk, utána már helyesen viselkedik.
local function initStamina()
    RestorePlayerStamina(PlayerId(), 1.0)
end

AddEventHandler('playerSpawned', function()
    initStamina()
end)

-- ============================================================
-- A minimap alatti natív GTA egészség/páncél ív elrejtése, mivel a saját
-- HUD-unk már megjeleníti ugyanezt az infót. A minimap scaleform saját
-- SETUP_HEALTH_ARMOUR függvényét írjuk felül minden tick-ben egy olyan
-- móddal (3 = golf minijáték módja), ami nem rajzol ki semmit.
CreateThread(function()
    local minimap = RequestScaleformMovie('minimap')
    SetRadarBigmapEnabled(true, false)
    Wait(0)
    SetRadarBigmapEnabled(false, false)

    while true do
        Wait(0)
        if spawned then
            BeginScaleformMovieMethod(minimap, 'SETUP_HEALTH_ARMOUR')
            ScaleformMovieMethodAddParamInt(3)
            EndScaleformMovieMethod()
        end
    end
end)

local function sendInit()
    uiAck = false
    CreateThread(function()
        local attempts = 0
        while not uiAck and attempts < 20 do
            SendNUIMessage({ action = 'init', settings = settings, stats = stats, elementDefs = Config.ElementDefs })
            attempts = attempts + 1
            Wait(150)
        end
    end)
end

RegisterNUICallback('hudReady', function(data, cb)
    uiAck = true
    cb('ok')
end)

-- Ez az esemény akkor sül el, amikor a player kilép a "limbo" állapotból,
-- vagyis ténylegesen lespawnolt a világba - eddig a pillanatig a HUD nem
-- jelenik meg (sem login, sem regisztráció, sem karakterkészítés alatt).
AddEventHandler('nb_core:playerSpawned', function()
    spawned = true
    initStamina()
    sendInit()
end)

CreateThread(function()
    while true do
        Wait(250)

        if spawned then
            local ped = PlayerPedId()
            if ped and ped ~= 0 then
                stats.health = math.max(0, math.min(100, math.floor(((GetEntityHealth(ped) - 100) / (GetEntityMaxHealth(ped) - 100)) * 100)))
                stats.armor = math.floor(GetPedArmour(ped))
                -- A natív valójában fordítva viselkedik a névvel ellentétben ebben a
                -- környezetben (0-ról 100-ra nő futás közben) - ezért invertáljuk,
                -- hogy a HUD-on 100-ról fogyjon a stamina, ahogy elvárt.
                stats.stamina = 100 - math.floor(GetPlayerSprintStaminaRemaining(PlayerId()))
            end

            if settingsReady then
                SendNUIMessage({ action = 'updateStats', stats = stats })
            end
        end
    end
end)

-- ============================================================
-- Szerkesztő mód (/edithud vagy F9)
-- ============================================================
local function enterEditMode()
    editMode = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'enterEditMode', settings = settings, elementDefs = Config.ElementDefs })
end

local function exitEditMode()
    editMode = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'exitEditMode' })
end

RegisterCommand('edithud', function()
    if editMode then
        exitEditMode()
    else
        enterEditMode()
    end
end, false)

RegisterKeyMapping('edithud', 'HUD szerkesztő megnyitása/bezárása', 'keyboard', Config.EditHudKeyMapping)

RegisterNUICallback('closeEditor', function(data, cb)
    exitEditMode()
    cb('ok')
end)

RegisterNUICallback('saveSettings', function(data, cb)
    settings = data.settings
    TriggerServerEvent('nb_hud:saveSettings', settings)
    cb('ok')
end)

RegisterNUICallback('resetSettings', function(data, cb)
    TriggerServerEvent('nb_hud:requestReset')
    cb('ok')
end)

-- Élő pozíció-előnézet szerkesztés közben (nem menti DB-be, csak lokálisan tartja)
RegisterNUICallback('updateLive', function(data, cb)
    settings = data.settings
    cb('ok')
end)
