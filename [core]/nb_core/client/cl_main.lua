-- Alap kliens állapot: amíg nincs bejelentkezve / karakter betöltve a player
-- "limbo" állapotban van - magasan az ég felett, lefagyasztva, láthatatlanul,
-- egy lassan forgó kamerával, hogy ne lásson bele a világba és ne eshessen le
-- a login/regisztráció/karakterkészítő UI alatt.

local isFrozen = false
local inLimbo = false
local limboCam = nil

function NB.FreezePlayer(state)
    local ped = PlayerPedId()
    isFrozen = state
    SetEntityVisible(ped, not state, false)
    FreezeEntityPosition(ped, state)
    SetPlayerControl(PlayerId(), not state, 0)
    DisplayRadar(not state)
end

function NB.SetLimbo(state)
    local ped = PlayerPedId()
    inLimbo = state

    if state then
        SetEntityCoordsNoOffset(ped, Config.LimboCoords.x, Config.LimboCoords.y, Config.LimboCoords.z, false, false, false)
        FreezeEntityPosition(ped, true)
        SetEntityVisible(ped, false, false)
        SetEntityInvincible(ped, true)
        SetPlayerControl(PlayerId(), false, 0)
        DisplayRadar(false)
        DisplayHud(false)

        if not limboCam then
            limboCam = CreateCamWithParams(
                'DEFAULT_SCRIPTED_CAMERA',
                Config.LimboCoords.x, Config.LimboCoords.y, Config.LimboCoords.z - 3.0,
                -10.0, 0.0, 0.0,
                60.0, false, 0
            )
            SetCamActive(limboCam, true)
            RenderScriptCams(true, true, 800, true, true)

            CreateThread(function()
                local heading = 0.0
                while inLimbo and limboCam do
                    heading = heading + 0.03
                    if heading >= 360.0 then heading = 0.0 end
                    SetCamRot(limboCam, -10.0, 0.0, heading, 2)
                    Wait(0)
                end
            end)
        end
    else
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        SetEntityInvincible(ped, false)
        SetPlayerControl(PlayerId(), true, 0)
        DisplayRadar(true)
        DisplayHud(true)

        if limboCam then
            RenderScriptCams(false, true, 800, true, true)
            DestroyCam(limboCam, false)
            limboCam = nil
        end

        -- Ez a pillanat, amikor a player ténylegesen "lespawnolt" a világba
        -- (login/regisztráció + karakterkészítés kész). Más resource-ok
        -- (pl. nb_hud) erre várnak, mielőtt bármit megjelenítenének.
        TriggerEvent('nb_core:playerSpawned')
    end
end

CreateThread(function()
    -- Ismert FiveM hiba workaround-ja: néha a NUI kurzor "technikailag aktív,
    -- de nem látszik" állapotba ragad (pl. F8 konzol nyitás/zárás után, vagy
    -- SetNuiFocusKeepInput használat után egy korábbi munkameneteben).
    -- Egy gyors ki-be kapcsolás resetli a belső fókusz/kurzor állapotot,
    -- mielőtt bármelyik resource ténylegesen megnyitná a saját NUI-ját.
    SetNuiFocus(true, true)
    Wait(0)
    SetNuiFocus(false, false)

    -- Amint a kliens betölt, azonnal limbo állapotba kerül, amíg a nb_accounts
    -- (majd később a nb_character) fel nem oldja.
    NB.SetLimbo(true)
end)

exports('FreezePlayer', NB.FreezePlayer)
exports('SetLimbo', NB.SetLimbo)

exports('GetDefaultSpawn', function()
    return Config.DefaultSpawn
end)
