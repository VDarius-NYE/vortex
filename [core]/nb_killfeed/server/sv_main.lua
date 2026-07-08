-- Killfeed: PvP kill + generic halál események figyelése és broadcast-olása
-- mindenkinek, plusz a HUD-pozíció szinkronizálása az nb_hud-dal.

RegisterNetEvent('nb_core:playerKilled', function(killerServerId, weaponName)
    local victimSource = source
    if killerServerId == victimSource then return end

    local killerName = GetPlayerName(killerServerId)
    local victimName = GetPlayerName(victimSource)
    if not killerName or not victimName then return end

    TriggerClientEvent('nb_killfeed:add', -1, {
        kind = 'kill',
        killer = killerName,
        victim = victimName,
        weapon = weaponName
    })
end)

RegisterNetEvent('nb_core:playerDiedGeneric', function()
    local victimSource = source
    local victimName = GetPlayerName(victimSource)
    if not victimName then return end

    TriggerClientEvent('nb_killfeed:add', -1, {
        kind = 'generic',
        victim = victimName
    })
end)

-- ============================================================
-- Pozíció-szinkron az nb_hud-dal - amikor a player HUD beállítása betölt
-- vagy mentésre kerül, a 'killfeed' elem pozícióját/be-ki állapotát
-- átadjuk a kliensnek, hogy oda rajzolja ki a feedet.
-- ============================================================
local function pushPosition(source, settings)
    local el = settings and settings.elements and settings.elements.killfeed
    if not el then return end

    TriggerClientEvent('nb_killfeed:updatePosition', source, {
        xPercent = el.xPercent,
        yPercent = el.yPercent,
        enabled = el.alwaysVisible ~= false
    })
end

AddEventHandler('nb_hud:settingsLoaded', function(source, settings)
    pushPosition(source, settings)
end)

AddEventHandler('nb_hud:settingsSaved', function(source, settings)
    pushPosition(source, settings)
end)

-- ============================================================
-- /testkillfeed {darab, max 5} - csak a hívónak jelenik meg, 1mp
-- késleltetéssel, teszteléshez
-- ============================================================
RegisterCommand('testkillfeed', function(source, args)
    if source == 0 then return end

    local count = math.min(tonumber(args[1]) or 1, 5)

    CreateThread(function()
        for i = 1, count do
            if i % 2 == 0 then
                TriggerClientEvent('nb_killfeed:add', source, {
                    kind = 'generic',
                    victim = ('TesztJatekos%d'):format(i)
                })
            else
                TriggerClientEvent('nb_killfeed:add', source, {
                    kind = 'kill',
                    killer = 'TesztOlo',
                    victim = ('TesztAldozat%d'):format(i),
                    weapon = 'WEAPON_PISTOL'
                })
            end
            Wait(1000)
        end
    end)
end, false)
