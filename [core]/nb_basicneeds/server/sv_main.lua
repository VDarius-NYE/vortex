-- Éhség/szomjúság kezelése: időbeli csökkenés, DB mentés, figyelmeztetések,
-- és exportok más resource-oknak (nb_inventory evés/ivás, nb_administration).

local needs = {} -- [source] = { hunger = 100, thirst = 100, warnedHunger = {}, warnedThirst = {} }

local hungerDecayPerTick = 100 / ((Config.HungerDecayDurationMinutes * 60000) / Config.TickIntervalMs)
local thirstDecayPerTick = 100 / ((Config.ThirstDecayDurationMinutes * 60000) / Config.TickIntervalMs)

CreateThread(function()
    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS nb_basicneeds (
                identifier VARCHAR(64) PRIMARY KEY,
                hunger FLOAT DEFAULT 100,
                thirst FLOAT DEFAULT 100,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        ]], {}, function()
            print('^3[nb_basicneeds]^7 nb_basicneeds tábla ellenőrizve/létrehozva.')
        end)
    end)
end)

local function pushToHud(source)
    local data = needs[source]
    if not data then return end
    TriggerClientEvent('nb_hud:setStat', source, 'hunger', math.floor(data.hunger + 0.5))
    TriggerClientEvent('nb_hud:setStat', source, 'thirst', math.floor(data.thirst + 0.5))
end

local function resetWarnings(data)
    data.warnedHunger = {}
    data.warnedThirst = {}
end

-- Betöltés belépéskor
AddEventHandler('nb_accounts:playerLoggedIn', function(source)
    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return end

    local result = MySQL.query.await('SELECT hunger, thirst FROM nb_basicneeds WHERE identifier = ?', { playerData.identifier })
    local row = result and result[1]

    if row then
        needs[source] = { hunger = row.hunger, thirst = row.thirst, warnedHunger = {}, warnedThirst = {} }
    else
        needs[source] = { hunger = 100, thirst = 100, warnedHunger = {}, warnedThirst = {} }
        MySQL.insert.await('INSERT IGNORE INTO nb_basicneeds (identifier, hunger, thirst) VALUES (?, ?, ?)', {
            playerData.identifier, 100, 100
        })
    end

    pushToHud(source)
end)

local function saveNeeds(source)
    local data = needs[source]
    if not data then return end

    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return end

    MySQL.query('INSERT INTO nb_basicneeds (identifier, hunger, thirst) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE hunger = VALUES(hunger), thirst = VALUES(thirst)', {
        playerData.identifier, data.hunger, data.thirst
    })
end

AddEventHandler('playerDropped', function()
    local source = source
    saveNeeds(source)
    needs[source] = nil
end)

-- Időszakos mentés minden online playerre
CreateThread(function()
    while true do
        Wait(Config.SaveIntervalMs)
        for source, _ in pairs(needs) do
            saveNeeds(source)
        end
    end
end)

-- Csökkenés + küszöb-figyelmeztetések
local function checkWarnings(source, data)
    -- csökkenő sorrendben nézzük a küszöböket, hogy a legalacsonyabb (legsúlyosabb)
    -- állapot üzenete jöjjön ki utoljára, ha több határt is átlép egy tick alatt
    for _, threshold in ipairs(Config.WarnThresholds) do
        if data.hunger <= threshold and not data.warnedHunger[threshold] then
            data.warnedHunger[threshold] = true
            exports['nb_core']:Notify(source, { message = Config.HungerWarnMessage, type = 'warning', duration = 6000 })
        end
        if data.thirst <= threshold and not data.warnedThirst[threshold] then
            data.warnedThirst[threshold] = true
            exports['nb_core']:Notify(source, { message = Config.ThirstWarnMessage, type = 'warning', duration = 6000 })
        end
    end
end

CreateThread(function()
    while true do
        Wait(Config.TickIntervalMs)

        for source, data in pairs(needs) do
            data.hunger = math.max(0, data.hunger - hungerDecayPerTick)
            data.thirst = math.max(0, data.thirst - thirstDecayPerTick)

            checkWarnings(source, data)
            pushToHud(source)
        end
    end
end)

-- ============================================================
-- Exportok
-- ============================================================
local function getHunger(source)
    return needs[source] and needs[source].hunger or nil
end

local function getThirst(source)
    return needs[source] and needs[source].thirst or nil
end

local function setHunger(source, value)
    local data = needs[source]
    if not data then return false end

    value = math.max(0, math.min(100, value))
    if value > data.hunger then resetWarnings(data) end
    data.hunger = value
    pushToHud(source)
    return true
end

local function setThirst(source, value)
    local data = needs[source]
    if not data then return false end

    value = math.max(0, math.min(100, value))
    if value > data.thirst then resetWarnings(data) end
    data.thirst = value
    pushToHud(source)
    return true
end

local function addHunger(source, amount)
    local data = needs[source]
    if not data then return false end
    return setHunger(source, data.hunger + amount)
end

local function addThirst(source, amount)
    local data = needs[source]
    if not data then return false end
    return setThirst(source, data.thirst + amount)
end

exports('GetHunger', getHunger)
exports('GetThirst', getThirst)
exports('SetHunger', setHunger)
exports('SetThirst', setThirst)
exports('AddHunger', addHunger)
exports('AddThirst', addThirst)
