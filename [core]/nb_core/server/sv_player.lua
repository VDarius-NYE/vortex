-- Player class - minden online játékoshoz ebből jön létre egy objektum

local Player = {}
Player.__index = Player

---@param source number
---@param identifier string
---@param identifierType string
---@param userData table  -- nb_users tábla sora (vagy alap adat, ha új account)
function Player.New(source, identifier, identifierType, userData)
    local self = setmetatable({}, Player)

    self.source = source
    self.PlayerData = {
        identifier = identifier,
        identifierType = identifierType,
        source = source,
        username = userData.username,
        email = userData.email,
        playtime = userData.playtime or 0,
        loggedIn = false,       -- csak akkor true, ha a bejelentkezés (nb_accounts) megtörtént
        characterLoaded = false, -- csak akkor true, ha a karakter (nb_character) betöltődött
        faction = nil,          -- ide köt majd be a jövőbeli nb_factions
        metadata = {}           -- általános kiterjeszthetőség jövőbeli moduloknak
    }

    self.Functions = {}

    function self.Functions.GetIdentifier()
        return self.PlayerData.identifier
    end

    function self.Functions.SetMetaData(key, value)
        self.PlayerData.metadata[key] = value
    end

    function self.Functions.GetMetaData(key)
        return self.PlayerData.metadata[key]
    end

    function self.Functions.SetLoggedIn(state)
        self.PlayerData.loggedIn = state
    end

    function self.Functions.SetCharacterLoaded(state)
        self.PlayerData.characterLoaded = state
    end

    -- DB mentés (playtime, egyéb core szintű mezők)
    function self.Functions.Save()
        MySQL.update('UPDATE nb_users SET playtime = ? WHERE identifier = ?', {
            self.PlayerData.playtime,
            self.PlayerData.identifier
        })
    end

    return self
end

NB.PlayerClass = Player
