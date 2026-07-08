-- Publikus szerver oldali segédfüggvények / exportok más resource-oknak

function NB.GetPlayer(source)
    return NB.Players[source]
end

function NB.GetPlayerByIdentifier(identifier)
    for _, player in pairs(NB.Players) do
        if player.PlayerData.identifier == identifier then
            return player
        end
    end
    return nil
end

function NB.GetPlayers()
    local players = {}
    for src, _ in pairs(NB.Players) do
        players[#players + 1] = src
    end
    return players
end

exports('GetPlayer', NB.GetPlayer)
exports('GetPlayerByIdentifier', NB.GetPlayerByIdentifier)
exports('GetPlayers', NB.GetPlayers)

-- ============================================================
-- Az alábbi exportok resource-határon át is biztonságosan hívhatók,
-- mert kizárólag primitív adatokat (string/number/bool/plain table)
-- adnak át, sosem a Player objektumot magát (aminek vannak függvény
-- mezői, azok nem szerializálhatók msgpack-al a resource-határon át).
-- MÁS RESOURCE-OK EZEKET HASZNÁLJÁK, ne a GetPlayer()-t közvetlenül!
-- ============================================================

function NB.GetPlayerData(source)
    local player = NB.Players[source]
    if not player then return nil end

    -- sekély másolat, csak primitív/plain table mezőkkel
    return {
        identifier = player.PlayerData.identifier,
        identifierType = player.PlayerData.identifierType,
        source = player.PlayerData.source,
        username = player.PlayerData.username,
        email = player.PlayerData.email,
        playtime = player.PlayerData.playtime,
        bank = player.PlayerData.bank,
        kills = player.PlayerData.kills,
        deaths = player.PlayerData.deaths,
        loggedIn = player.PlayerData.loggedIn,
        characterLoaded = player.PlayerData.characterLoaded,
        faction = player.PlayerData.faction,
        metadata = player.PlayerData.metadata
    }
end

function NB.SetLoggedIn(source, state)
    local player = NB.Players[source]
    if not player then return false end
    player.Functions.SetLoggedIn(state)
    return true
end

function NB.SetCharacterLoaded(source, state)
    local player = NB.Players[source]
    if not player then return false end
    player.Functions.SetCharacterLoaded(state)
    return true
end

function NB.SavePlayer(source)
    local player = NB.Players[source]
    if not player then return false end
    player.Functions.Save()
    return true
end

exports('GetPlayerData', NB.GetPlayerData)
exports('SetLoggedIn', NB.SetLoggedIn)
exports('SetCharacterLoaded', NB.SetCharacterLoaded)
exports('SavePlayer', NB.SavePlayer)

-- Ezt is exportáljuk, mert más resource-oknak (pl. nb_administration ban
-- ellenőrzés) szükségük lehet rá MÉG a player betöltése előtt (playerConnecting
-- fázisban), amikor a Player objektum még nem is létezik.
exports('GetPrimaryIdentifier', NB.GetPrimaryIdentifier)
