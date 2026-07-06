-- Inventory core: betöltés/mentés, item hozzáadás/eltávolítás, súlyszámítás,
-- stackelés, serial generálás. Ugyanezt a réteget használja a player
-- inventory ÉS a stash rendszer is (owner_type: 'player' | 'stash').

NBInv = NBInv or {}

local playerCache = {}   -- [source] = { identifier=, slots={ [slot]={item,quantity,metadata} } }
local stashCache = {}    -- [stashId] = { slots={...} }

CreateThread(function()
    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS nb_inventory_items (
                id INT AUTO_INCREMENT PRIMARY KEY,
                owner_type VARCHAR(10) NOT NULL,
                owner_id VARCHAR(64) NOT NULL,
                slot INT NOT NULL,
                item_name VARCHAR(50) NOT NULL,
                quantity INT NOT NULL DEFAULT 1,
                metadata LONGTEXT,
                UNIQUE KEY owner_slot (owner_type, owner_id, slot)
            )
        ]], {}, function()
            print('^3[nb_inventory]^7 nb_inventory_items tábla ellenőrizve/létrehozva.')
        end)
    end)
end)

math.randomseed(os.time() + GetGameTimer())

function NBInv.GenerateSerial(prefix)
    prefix = prefix or Config.DefaultSerialPrefix
    local chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local id = ''
    for _ = 1, 6 do
        local i = math.random(1, #chars)
        id = id .. chars:sub(i, i)
    end
    return prefix .. id
end

-- ============================================================
-- Betöltés / mentés
-- ============================================================
local function loadSlotsFromDb(ownerType, ownerId)
    local rows = MySQL.query.await('SELECT slot, item_name, quantity, metadata FROM nb_inventory_items WHERE owner_type = ? AND owner_id = ?', {
        ownerType, ownerId
    }) or {}

    local slots = {}
    for _, row in ipairs(rows) do
        slots[row.slot] = {
            item = row.item_name,
            quantity = row.quantity,
            metadata = row.metadata and json.decode(row.metadata) or {}
        }
    end
    return slots
end

local function saveSlotToDb(ownerType, ownerId, slot, data)
    if not data then
        MySQL.query('DELETE FROM nb_inventory_items WHERE owner_type = ? AND owner_id = ? AND slot = ?', { ownerType, ownerId, slot })
    else
        MySQL.query([[
            INSERT INTO nb_inventory_items (owner_type, owner_id, slot, item_name, quantity, metadata)
            VALUES (?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE item_name = VALUES(item_name), quantity = VALUES(quantity), metadata = VALUES(metadata)
        ]], { ownerType, ownerId, slot, data.item, data.quantity, json.encode(data.metadata or {}) })
    end
end

-- ============================================================
-- Player inventory élettartam
-- ============================================================
AddEventHandler('nb_accounts:playerLoggedIn', function(source)
    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return end

    playerCache[source] = {
        identifier = playerData.identifier,
        slots = loadSlotsFromDb('player', playerData.identifier)
    }
end)

local function savePlayerInventory(source)
    local cache = playerCache[source]
    if not cache then return end
    for slot, data in pairs(cache.slots) do
        saveSlotToDb('player', cache.identifier, slot, data)
    end
end

AddEventHandler('playerDropped', function()
    local source = source
    savePlayerInventory(source)
    playerCache[source] = nil
end)

CreateThread(function()
    while true do
        Wait(120000) -- 2 percenként batch mentés, hogy szerver crash esetén se vesszen sok adat
        for source, _ in pairs(playerCache) do
            savePlayerInventory(source)
        end
    end
end)

-- ============================================================
-- Stash cache
-- ============================================================
function NBInv.LoadStash(stashId)
    if stashCache[stashId] then return stashCache[stashId] end
    stashCache[stashId] = { slots = loadSlotsFromDb('stash', tostring(stashId)) }
    return stashCache[stashId]
end

function NBInv.SaveStash(stashId)
    local cache = stashCache[stashId]
    if not cache then return end
    for slot, data in pairs(cache.slots) do
        saveSlotToDb('stash', tostring(stashId), slot, data)
    end
end

CreateThread(function()
    while true do
        Wait(120000)
        for stashId, _ in pairs(stashCache) do
            NBInv.SaveStash(stashId)
        end
    end
end)

-- ============================================================
-- Belső segédfüggvények (owner "handle" alapján dolgoznak, hogy a player és
-- a stash logika ugyanazt a kódot használhassa)
-- ============================================================

--- Visszaadja: slotsTable, saveFn(slot, data), maxSlots, maxWeight
function NBInv.GetHandle(ownerType, ownerRef)
    if ownerType == 'player' then
        local cache = playerCache[ownerRef]
        if not cache then return nil end
        return cache.slots,
            function(slot, data) saveSlotToDb('player', cache.identifier, slot, data) end,
            Config.PlayerSlots, Config.MaxWeight
    elseif ownerType == 'stash' then
        local cache = NBInv.LoadStash(ownerRef)
        local stashInfo = NBInv.GetStashInfo and NBInv.GetStashInfo(ownerRef)
        return cache.slots,
            function(slot, data) saveSlotToDb('stash', tostring(ownerRef), slot, data) end,
            (stashInfo and stashInfo.slot_count) or 50,
            (stashInfo and stashInfo.weight_capacity) or 100
    end
    return nil
end

local getHandle = NBInv.GetHandle

function NBInv.CalcWeight(slots)
    local total = 0
    for _, data in pairs(slots) do
        local def = Config.Items[data.item]
        if def then
            total = total + (def.weight * data.quantity)
        end
    end
    return total
end

local function findStackableSlot(slots, itemName, maxSlots, def)
    if not def.stackable then return nil end
    for slot = 1, maxSlots do
        local data = slots[slot]
        if data and data.item == itemName and data.quantity < (def.maxStack or 999999) then
            return slot
        end
    end
    return nil
end

local function findFreeSlot(slots, maxSlots)
    for slot = 1, maxSlots do
        if not slots[slot] then return slot end
    end
    return nil
end

--- Item hozzáadása egy inventoryhoz (player vagy stash). metadata opcionális
--- (pl. fegyvernél durability/serial). Visszaad: ok(bool), reason(string)
function NBInv.AddItemTo(ownerType, ownerRef, itemName, quantity, metadata)
    local def = Config.Items[itemName]
    if not def then return false, 'Ismeretlen item.' end

    metadata = metadata or {}
    if def.hasDurability and metadata.durability == nil then
        metadata.durability = 100
    end
    if def.hasSerial and metadata.serial == nil then
        metadata.serial = NBInv.GenerateSerial(def.serialPrefix)
    end

    local slots, saveFn, maxSlots, maxWeight = getHandle(ownerType, ownerRef)
    if not slots then return false, 'Az inventory nem elérhető.' end

    local currentWeight = NBInv.CalcWeight(slots)
    local addedWeight = def.weight * quantity
    if currentWeight + addedWeight > maxWeight then
        return false, 'Nincs elég hely (túl nehéz lenne).'
    end

    -- Egyedi metadatás (pl. fegyver serial) itemek sosem stackelődnek egymásra
    local hasUniqueMeta = metadata and (metadata.serial ~= nil)

    if def.stackable and not hasUniqueMeta then
        local stackSlot = findStackableSlot(slots, itemName, maxSlots, def)
        if stackSlot then
            local remaining = (def.maxStack or 999999) - slots[stackSlot].quantity
            local toAdd = math.min(remaining, quantity)
            slots[stackSlot].quantity = slots[stackSlot].quantity + toAdd
            saveFn(stackSlot, slots[stackSlot])
            quantity = quantity - toAdd

            if quantity <= 0 then return true end
        end
    end

    while quantity > 0 do
        local freeSlot = findFreeSlot(slots, maxSlots)
        if not freeSlot then return false, 'Nincs több szabad hely.' end

        local putQuantity = def.stackable and math.min(quantity, def.maxStack or 999999) or 1
        slots[freeSlot] = { item = itemName, quantity = putQuantity, metadata = metadata or {} }
        saveFn(freeSlot, slots[freeSlot])
        quantity = quantity - putQuantity
    end

    return true
end

--- Item eltávolítása egy adott slotból (vagy ha nincs slot megadva, bárhonnan)
function NBInv.RemoveItemFrom(ownerType, ownerRef, itemName, quantity)
    local slots, saveFn = getHandle(ownerType, ownerRef)
    if not slots then return false end

    local remaining = quantity
    for slot, data in pairs(slots) do
        if remaining <= 0 then break end
        if data.item == itemName then
            local take = math.min(data.quantity, remaining)
            data.quantity = data.quantity - take
            remaining = remaining - take

            if data.quantity <= 0 then
                slots[slot] = nil
                saveFn(slot, nil)
            else
                saveFn(slot, data)
            end
        end
    end

    return remaining <= 0
end

function NBInv.GetItemCount(ownerType, ownerRef, itemName)
    local slots = getHandle(ownerType, ownerRef)
    if not slots then return 0 end
    local total = 0
    for _, data in pairs(slots) do
        if data.item == itemName then total = total + data.quantity end
    end
    return total
end

function NBInv.HasItem(ownerType, ownerRef, itemName, quantity)
    return NBInv.GetItemCount(ownerType, ownerRef, itemName) >= (quantity or 1)
end

-- Publikus payload NUI-nak (plain adat, definíciókkal együtt)
function NBInv.BuildPayload(ownerType, ownerRef)
    local slots, _, maxSlots, maxWeight = getHandle(ownerType, ownerRef)
    if not slots then return nil end

    local payloadSlots = {}
    for slot = 1, maxSlots do
        local data = slots[slot]
        if data then
            local def = Config.Items[data.item]
            payloadSlots[tostring(slot)] = {
                item = data.item,
                quantity = data.quantity,
                metadata = data.metadata or {},
                label = def and def.label or data.item,
                weight = def and def.weight or 0,
                icon = def and def.icon or 'fa-solid fa-cube',
                stackable = def and def.stackable or false,
                maxStack = def and def.maxStack or 1,
                usable = def and def.usable or false,
                itemType = def and def.type or 'item',
                hasDurability = def and def.hasDurability or false,
                hasSerial = def and def.hasSerial or false
            }
        end
    end

    return {
        slots = payloadSlots,
        maxSlots = maxSlots,
        weight = NBInv.CalcWeight(slots),
        maxWeight = maxWeight
    }
end

-- ============================================================
-- Publikus exportok
-- ============================================================
exports('GetInventory', function(source) return NBInv.BuildPayload('player', source) end)
exports('AddItem', function(source, itemName, quantity, metadata) return NBInv.AddItemTo('player', source, itemName, quantity or 1, metadata) end)
exports('RemoveItem', function(source, itemName, quantity) return NBInv.RemoveItemFrom('player', source, itemName, quantity or 1) end)
exports('HasItem', function(source, itemName, quantity) return NBInv.HasItem('player', source, itemName, quantity) end)
exports('GetItemCount', function(source, itemName) return NBInv.GetItemCount('player', source, itemName) end)
exports('GetWeight', function(source)
    local slots = getHandle('player', source)
    return slots and NBInv.CalcWeight(slots) or 0
end)
