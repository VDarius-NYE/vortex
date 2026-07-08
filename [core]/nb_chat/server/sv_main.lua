-- Chat-szűrés/formázás a FiveM alap 'chatMessage' szerver eseményén és a
-- CancelEvent()-en keresztül - ez UGYANAZ a mechanizmus, amit a beépített
-- "X joined."/"X left" üzenetek is használnak (megbízhatóan működik,
-- semmilyen sablon/args bizonytalanság nincs benne).
--
-- Menete: a chat resource minden begépelt (nem parancsként futó) üzenetnél
-- kilövi a 'chatMessage' eventet, MIELŐTT kiküldené a végleges üzenetet.
-- Ha itt CancelEvent()-et hívunk, a saját, eredeti üzenete SOHA nem jut ki
-- senkinek - utána mi magunk küldjük ki (vagy nem) a saját formázásunkkal.

local groupLabels = {
    owner = 'Tulajdonos',
    admin = 'Admin',
    support = 'Support'
}

-- FiveM chat natív '^N' színkódok a szövegen belül (ugyanaz a rendszer, mint
-- a régi Rockstar-féle chat-színkódok - lásd nb_chattheme .color-N osztályok)
local groupColorCodes = {
    owner = '^1',   -- piros
    admin = '^4',   -- kék
    support = '^7', -- neon zöld (egyedi, lásd nb_chattheme/style.css .color-7)
}

--- Visszaadja: isStaff(bool), group(string vagy nil)
local function checkStaff(source)
    local ok, group = pcall(function() return exports['nb_group']:GetGroup(source) end)
    if not ok then return false, nil end
    return groupLabels[group] ~= nil, group
end

AddEventHandler('chatMessage', function(source, name, message)
    if type(source) ~= 'number' or source == 0 then return end

    local staff, group = checkStaff(source)

    -- A saját (eredeti) üzenetet MINDIG elnyomjuk itt - vagy egyáltalán nem
    -- küldünk semmit (sima player), vagy a saját formázásunkkal küldjük ki
    -- újra (staff -> admin chat).
    CancelEvent()

    if not staff then
        return -- sima játékos szabad szövege sosem jelenik meg senkinek
    end

    local playerName = GetPlayerName(source)
    local label = groupLabels[group]
    local colorCode = groupColorCodes[group] or '^0'

    -- A csoport-címke a saját színében jelenik meg, utána ^0-val
    -- visszaváltunk fehérre a névhez/ID-hoz/üzenethez.
    local formatted = ('%s(%s)^0 %s [%d]: %s'):format(colorCode, label, playerName, source, message)

    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if checkStaff(pid) then
            TriggerClientEvent('chatMessage', pid, '', { 255, 255, 255 }, formatted)
        end
    end

    print(('[nb_chat/admin] %s'):format(formatted))
end)

-- ============================================================
-- /gov {üzenet} - CSAK azok használhatják, akiknek a frakciója NEM a 0-ás
-- (Nomad, alap frakció) - tehát a jövőbeli egyéb frakciók tagjai. A Nomad
-- tagoknak (és minden jelenlegi playernek, hiszen még nincs más frakció)
-- egyelőre nem elérhető.
-- ============================================================
RegisterCommand('gov', function(source, args)
    if source == 0 then return end

    local factionId = 0
    pcall(function() factionId = exports['nb_factions']:GetFaction(source) end)

    if factionId == 0 then
        exports['nb_core']:Notify(source, { message = 'Ez a parancs nem elérhető a frakciód számára.', type = 'error' })
        return
    end

    local text = table.concat(args, ' ')
    if text == '' then
        exports['nb_core']:Notify(source, { message = 'Használat: /gov [üzenet]', type = 'warning' })
        return
    end

    local factionName = 'Ismeretlen frakció'
    pcall(function() factionName = exports['nb_factions']:GetFactionName(source) end)

    local name = GetPlayerName(source)
    local formatted = ('[KORMÁNY - %s] %s [%d] : %s'):format(factionName, name, source, text)

    TriggerClientEvent('chatMessage', -1, '', { 90, 160, 220 }, formatted)
end, false)
