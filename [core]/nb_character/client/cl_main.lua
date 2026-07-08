-- Karakterkészítő kliens logika: kamera, ped-modell kezelés, NUI életciklus,
-- és admin által is újranyitható "edit" mód (visszaállítja az előző helyzetet).

local creatorActive = false
local creatorCam = nil
local currentMode = nil        -- 'create' | 'edit'
local currentAppearance = nil
local previousState = nil      -- edit módban ide mentjük a visszaállítandó állapotot

local orbitAngle = 0.0
local orbitSpeed = 1.6 -- fok/tick
local cameraMode = 'body' -- 'body' (teljes alak) vagy 'face' (közeli arc)

local CAMERA_PRESETS = {
    body = { radius = 3.4, height = -0.35, aimZ = 0.0 },  -- teljes alak, lábtól fejig
    face = { radius = 0.75, height = 0.62, aimZ = 0.62 }  -- közeli, fej/arc szintű
}

local function loadModel(model)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 5000 do
        Wait(50)
        timeout = timeout + 50
    end
    return hash
end

local function updateCreatorCamPosition()
    if not creatorCam then return end
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local rad = math.rad(orbitAngle)
    local preset = CAMERA_PRESETS[cameraMode] or CAMERA_PRESETS.body

    local camX = pedCoords.x + math.sin(rad) * preset.radius
    local camY = pedCoords.y - math.cos(rad) * preset.radius
    local camZ = pedCoords.z + preset.height

    SetCamCoord(creatorCam, camX, camY, camZ)
    PointCamAtEntity(creatorCam, ped, 0.0, 0.0, preset.aimZ, true)
end

local function setCameraMode(mode)
    if not CAMERA_PRESETS[mode] then return end
    cameraMode = mode
    updateCreatorCamPosition()
end

local function createCreatorCam(ped)
    if creatorCam then
        DestroyCam(creatorCam, false)
        creatorCam = nil
    end

    orbitAngle = 0.0

    creatorCam = CreateCamWithParams(
        'DEFAULT_SCRIPTED_CAMERA',
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        40.0, false, 0
    )
    SetCamActive(creatorCam, true)
    RenderScriptCams(true, true, 500, true, true)
    updateCreatorCamPosition()
end

local function destroyCreatorCam()
    if creatorCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(creatorCam, false)
        creatorCam = nil
    end
end

local rotateDirection = 'none' -- 'left' | 'right' | 'none' - a JS küldi (A/D billentyű)

-- Amíg a karakterkészítő aktív: a kamera a JS által jelzett irányba forog.
-- FONTOS: itt SEMMILYEN inputot nem engedünk át a játéknak (nincs
-- SetNuiFocusKeepInput, nincs IsControlPressed-alapú vezérlés) - a JS oldal
-- figyeli az A/D lenyomását (ott a NUI-nak amúgy is van kulcsfókusza), és
-- egy NUI callback-kel jelzi nekünk az irányt. Így a kattintás/billentyű
-- SOHA nem jut el a karakterhez (nem üt, nem sétál).
CreateThread(function()
    while true do
        if creatorActive then
            if rotateDirection ~= 'none' and creatorCam then
                if rotateDirection == 'left' then
                    orbitAngle = orbitAngle - orbitSpeed
                    if orbitAngle < 0 then orbitAngle = orbitAngle + 360.0 end
                else
                    orbitAngle = orbitAngle + orbitSpeed
                    if orbitAngle >= 360.0 then orbitAngle = orbitAngle - 360.0 end
                end
                updateCreatorCamPosition()
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

local uiAck = false

RegisterNUICallback('creatorReady', function(data, cb)
    uiAck = true
    cb('ok')
end)

-- A JS küldi, amikor a felhasználó tabot vált (test/arc közeli nézet)
RegisterNUICallback('setCameraMode', function(data, cb)
    setCameraMode(data.mode)
    cb('ok')
end)

-- A JS küldi, amikor lenyomja/felengedi az A vagy D billentyűt
RegisterNUICallback('cameraRotate', function(data, cb)
    rotateDirection = data.direction or 'none'
    cb('ok')
end)

-- NUI megnyitás retry-jal (ugyanaz a race-condition elleni védelem, mint az nb_accounts-ban)
local function openCreatorUI(payload)
    SetNuiFocus(true, true)
    uiAck = false

    CreateThread(function()
        local attempts = 0
        while not uiAck and attempts < 20 do
            SendNUIMessage(payload)
            attempts = attempts + 1
            Wait(150)
        end
    end)
end

local function enterCreator(ped, mode, model, appearance)
    currentMode = mode
    creatorActive = true
    cameraMode = 'body' -- kezdéskor a "Modell" tab aktív, ott teljes alak kell
    rotateDirection = 'none'

    model = model or (appearance and appearance.model) or Config.DefaultModel
    local hash = loadModel(model)
    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)

    ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)

    currentAppearance = appearance or NBChar.GetDefaultAppearance(model)
    currentAppearance.model = model

    NBChar.ApplyAppearance(ped, currentAppearance)

    local coords = Config.CreatorCoords
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, coords.heading)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, true)
    SetPlayerControl(PlayerId(), false, 0) -- most már nyugodtan letilthatjuk, nem az IsControlPressed-en múlik a kamera
    DisplayRadar(false)
    DisplayHud(false)

    createCreatorCam(ped)

    local limits = NBChar.BuildLimits(ped)

    local overlayDefs = {}
    for _, overlay in ipairs(Config.HeadOverlays) do
        overlayDefs[#overlayDefs + 1] = { id = overlay.id, name = overlay.name, hasColor = overlay.hasColor }
    end

    openCreatorUI({
        action = 'open',
        mode = mode,
        appearance = currentAppearance,
        limits = limits,
        overlayDefs = overlayDefs
    })
end

local function exitCreator()
    creatorActive = false
    rotateDirection = 'none'
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    destroyCreatorCam()
end

-- ============================================================
-- Belépési pontok
-- ============================================================

-- Első bejelentkezés, még nincs mentett karaktere -> kötelező létrehozás
RegisterNetEvent('nb_character:openCreator', function(payload)
    local ped = PlayerPedId()

    if payload.mode == 'edit' then
        -- Elmentjük a jelenlegi állapotot, hogy Mentés/Mégse után visszaállhassunk
        local coords = GetEntityCoords(ped)
        previousState = {
            x = coords.x, y = coords.y, z = coords.z,
            heading = GetEntityHeading(ped)
        }
    else
        previousState = nil
    end

    enterCreator(ped, payload.mode or 'create', payload.model, payload.appearance)
end)

-- Már van mentett karaktere -> csendben alkalmazzuk, nincs UI, egyenesen spawn
RegisterNetEvent('nb_character:applySaved', function(payload)
    local hash = loadModel(payload.model or Config.DefaultModel)
    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)

    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    NBChar.ApplyAppearance(ped, payload.appearance)

    local spawn = payload.spawn or exports['nb_core']:GetDefaultSpawn()
    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
    SetEntityHeading(ped, spawn.heading)

    exports['nb_core']:SetLimbo(false)
end)

-- Új karakter létrehozása után a szerver küldi vissza a tényleges spawn
-- pontot (frakció-alapú), csak EKKOR spawnolunk ténylegesen.
RegisterNetEvent('nb_character:spawnConfirmed', function(spawn)
    if not spawn then spawn = exports['nb_core']:GetDefaultSpawn() end

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
    SetEntityHeading(ped, spawn.heading)

    exports['nb_core']:SetLimbo(false)
end)

-- ============================================================
-- NUI callback-ek
-- ============================================================

-- Élő előnézet: valahányszor a felhasználó módosít bármit a panelen.
-- Csak a ténylegesen változott mezőt alkalmazzuk (ApplyPartial), nem az
-- egész megjelenést, hogy ne akadjon be a karakter minden apró módosításnál.
RegisterNUICallback('update', function(data, cb)
    currentAppearance = data.appearance
    local ped = PlayerPedId()
    NBChar.ApplyPartial(ped, currentAppearance, data.changed)
    cb('ok')
end)

-- Modellváltás (férfi/nő) - újra kell tölteni a pedet és a limiteket
RegisterNUICallback('changeModel', function(data, cb)
    local model = data.model
    local hash = loadModel(model)
    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)

    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)

    currentAppearance = NBChar.GetDefaultAppearance(model)
    NBChar.ApplyAppearance(ped, currentAppearance)

    local coords = Config.CreatorCoords
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, coords.heading)

    createCreatorCam(ped)

    local limits = NBChar.BuildLimits(ped)

    cb({ appearance = currentAppearance, limits = limits })
end)

RegisterNUICallback('save', function(data, cb)
    currentAppearance = data.appearance
    currentAppearance.model = data.model

    TriggerServerEvent('nb_character:save', {
        model = data.model,
        appearance = currentAppearance
    })

    local ped = PlayerPedId()

    if currentMode == 'create' then
        exitCreator()
        -- A tényleges spawn pozíciót a szerver dönti el (frakció-alapú spawn),
        -- lásd a 'nb_character:spawnConfirmed' eseményt lentebb. Addig is a
        -- player a limbo-ban marad (nem hívjuk itt a SetLimbo(false)-t).
    else
        -- 'edit' mód (admin által nyitva): visszaállítjuk oda, ahol a player volt
        exitCreator()

        SetEntityInvincible(ped, false)
        FreezeEntityPosition(ped, false)
        SetPlayerControl(PlayerId(), true, 0)
        DisplayRadar(true)
        DisplayHud(true)

        if previousState then
            SetEntityCoordsNoOffset(ped, previousState.x, previousState.y, previousState.z, false, false, false)
            SetEntityHeading(ped, previousState.heading)
        end
    end

    cb('ok')
end)

RegisterNUICallback('cancel', function(data, cb)
    local ped = PlayerPedId()
    exitCreator()

    if currentMode == 'edit' then
        SetEntityInvincible(ped, false)
        FreezeEntityPosition(ped, false)
        SetPlayerControl(PlayerId(), true, 0)
        DisplayRadar(true)
        DisplayHud(true)

        -- Visszaállítjuk az eredeti (mentett) kinézetet is, mert a preview közben módosult
        if currentAppearance then
            NBChar.ApplyAppearance(ped, currentAppearance)
        end

        if previousState then
            SetEntityCoordsNoOffset(ped, previousState.x, previousState.y, previousState.z, false, false, false)
            SetEntityHeading(ped, previousState.heading)
        end
    end
    -- 'create' módban nincs Mégse gomb a UI-n, ide elvileg nem futunk be

    cb('ok')
end)
