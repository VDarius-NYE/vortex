-- Közös (client+server) segédfüggvények

function NB.GetIdentifiers(source)
    local identifiers = {
        license = nil,
        license2 = nil,
        discord = nil,
        steam = nil,
        fivem = nil,
        ip = nil
    }

    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id then
            if string.find(id, 'license2:') then
                identifiers.license2 = id
            elseif string.find(id, 'license:') then
                identifiers.license = id
            elseif string.find(id, 'discord:') then
                identifiers.discord = id
            elseif string.find(id, 'steam:') then
                identifiers.steam = id
            elseif string.find(id, 'fivem:') then
                identifiers.fivem = id
            elseif string.find(id, 'ip:') then
                identifiers.ip = id
            end
        end
    end

    return identifiers
end

-- Visszaadja az elsődleges identifiert, fallback lánc alapján
function NB.GetPrimaryIdentifier(source)
    local identifiers = NB.GetIdentifiers(source)

    for _, idType in ipairs(Config.IdentifierFallbackOrder) do
        if identifiers[idType] then
            return identifiers[idType], idType
        end
    end

    return nil, nil
end
