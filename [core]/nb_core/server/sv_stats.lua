-- Playtime automatikus növelése, bank egyenleg, kill/death követés, és
-- mindezek "kipumpálása" az nb_hud felé (ha fut).

local function pushStatToHud(source, statName, value)
    -- Ha nem fut az nb_hud, ez az export egyszerűen nem létezik - ne dobjon hibát.
    local ok = pcall(function()
        TriggerClientEvent('nb_hud:setStat', source, statName, value)
    end)
end

local function calcKD(kills, deaths)
    if deaths <= 0 then
        return kills > 0 and string.format('%.2f', kills) or '0.00'
    end
    local ratio = kills / deaths
    if ratio < 0 then ratio = 0 end
    return string.format('%.2f', ratio)
end

local function pushAllStats(source)
    local player = NB.Players[source]
    if not player then return end

    pushStatToHud(source, 'playtime', player.PlayerData.playtime)
    pushStatToHud(source, 'bank', player.PlayerData.bank)
    pushStatToHud(source, 'kills', player.PlayerData.kills)
    pushStatToHud(source, 'deaths', player.PlayerData.deaths)
    pushStatToHud(source, 'kd', calcKD(player.PlayerData.kills, player.PlayerData.deaths))
    -- Frakció: egyelőre statikus placeholder, amíg nincs kész az nb_factions
    pushStatToHud(source, 'faction', player.PlayerData.faction or 'Nincs frakció')
end

-- Amint bejelentkezett, egyszer kiküldjük a jelenlegi állapotot a HUD-nak
AddEventHandler('nb_accounts:playerLoggedIn', function(source)
    pushAllStats(source)
end)

-- Playtime: percenként +1, és rögtön ki is küldjük a HUD-nak
CreateThread(function()
    while true do
        Wait(60000)
        for source, player in pairs(NB.Players) do
            player.PlayerData.playtime = (player.PlayerData.playtime or 0) + 1
            pushStatToHud(source, 'playtime', player.PlayerData.playtime)
        end
    end
end)

-- Időszakos mentés (playtime/bank/kills/deaths), hogy ne csak kilépéskor mentődjön
CreateThread(function()
    while true do
        Wait(180000) -- 3 percenként
        for _, player in pairs(NB.Players) do
            player.Functions.Save()
        end
    end
end)

-- ============================================================
-- Bank exportok
-- ============================================================
local function getBank(source)
    local player = NB.Players[source]
    return player and player.PlayerData.bank or 0
end

local function setBank(source, amount)
    local player = NB.Players[source]
    if not player then return false end
    player.PlayerData.bank = math.max(0, math.floor(amount))
    pushStatToHud(source, 'bank', player.PlayerData.bank)
    return true
end

local function addBank(source, amount)
    local player = NB.Players[source]
    if not player then return false end
    return setBank(source, player.PlayerData.bank + amount)
end

local function removeBank(source, amount)
    local player = NB.Players[source]
    if not player then return false end
    if player.PlayerData.bank < amount then return false end
    return setBank(source, player.PlayerData.bank - amount)
end

exports('GetBank', getBank)
exports('SetBank', setBank)
exports('AddBank', addBank)
exports('RemoveBank', removeBank)

-- ============================================================
-- Kill/Death követés - CSAK másik játékos által okozott halál számít
-- ============================================================
RegisterNetEvent('nb_core:playerKilled', function(killerServerId)
    local victimSource = source
    if killerServerId == victimSource then return end -- öngyilkosság ne számítson

    local killer = NB.Players[killerServerId]
    local victim = NB.Players[victimSource]
    if not killer or not victim then return end

    killer.PlayerData.kills = (killer.PlayerData.kills or 0) + 1
    victim.PlayerData.deaths = (victim.PlayerData.deaths or 0) + 1

    pushStatToHud(killerServerId, 'kills', killer.PlayerData.kills)
    pushStatToHud(killerServerId, 'kd', calcKD(killer.PlayerData.kills, killer.PlayerData.deaths))

    pushStatToHud(victimSource, 'deaths', victim.PlayerData.deaths)
    pushStatToHud(victimSource, 'kd', calcKD(victim.PlayerData.kills, victim.PlayerData.deaths))
end)

exports('GetKills', function(source) local p = NB.Players[source] return p and p.PlayerData.kills or 0 end)
exports('GetDeaths', function(source) local p = NB.Players[source] return p and p.PlayerData.deaths or 0 end)
