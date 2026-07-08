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

    -- A kliens hotbar-jának is kell egy kezdeti adat, hogy már az UI
    -- megnyitása előtt is működjön az 1-5 gomb.
    TriggerClientEvent('nb_inventory:silentSync', source, NBInv.BuildPayload('player', source))

    -- Kezdeti készpénz-adat a HUD-nak (ha fut)
    pcall(function()
        TriggerClientEvent('nb_hud:setStat', source, 'cash', NBInv.GetItemCount('player', source, 'cash'))
    end)
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
        ownerRef = tonumber(ownerRef) or ownerRef
        local cache = NBInv.LoadStash(ownerRef)
        local stashInfo = NBInv.GetStashInfo and NBInv.GetStashInfo(ownerRef)
        return cache.slots,
            function(slot, data) saveSlotToDb('stash', tostring(ownerRef), slot, data) end,
            tonumber(stashInfo and stashInfo.slot_count) or Config.DefaultStashSlots,
            tonumber(stashInfo and stashInfo.weight_capacity) or Config.DefaultStashWeight
    end
    return nil
end

local getHandle = NBInv.GetHandle

--- Egy inventory teljes ürítése (pl. /clearinv admin parancshoz)
function NBInv.ClearInventory(ownerType, ownerRef)
    local slots, saveFn, maxSlots = getHandle(ownerType, ownerRef)
    if not slots then return false end

    for slot = 1, maxSlots do
        if slots[slot] then
            slots[slot] = nil
            saveFn(slot, nil)
        end
    end
    return true
end

--- Egy player TELJES inventoryjának áthelyezése egy (adott koordinátán lévő,
--- vagy ott újonnan létrehozott) Föld-kupacba, majd a player inventoryjának
--- ürítése. Visszaadja a Föld-kupac ID-ját (vagy nil, ha nem sikerült).
--- Ezt használja pl. az nb_death a halott játékos kifosztásához.
function NBInv.DumpToGroundStash(source, coords)
    local slots = getHandle('player', source)
    if not slots then return nil end

    local groundId = NBInv.FindOrCreateGroundStash(coords)
    if not groundId then return nil end

    for _, data in pairs(slots) do
        NBInv.AddItemTo('stash', groundId, data.item, data.quantity, data.metadata)
    end

    NBInv.ClearInventory('player', source)

    return groundId
end

exports('DumpToGroundStash', function(source, coords) return NBInv.DumpToGroundStash(source, coords) end)

-- ============================================================
-- Popup értesítések (kapott/használt/eldobott item) - mindig látszik,
-- függetlenül attól hogy nyitva van-e a fő inventory UI
-- ============================================================
function NBInv.SendPopup(source, itemName, kind, quantity)
    local def = Config.Items[itemName]
    if not def then return end

    local text
    if kind == 'received' then
        text = ('+%d db %s'):format(quantity or 1, def.label)
    elseif kind == 'used' then
        text = ('Használva x%d db %s'):format(quantity or 1, def.label)
    elseif kind == 'drawn' then
        text = ('%s elővéve'):format(def.label)
    elseif kind == 'equipped' then
        text = ('%s elrakva'):format(def.label)
    elseif kind == 'dropped' then
        text = ('x%d db %s eldobva'):format(quantity or 1, def.label)
    else
        return
    end

    TriggerClientEvent('nb_inventory:popup', source, {
        item = itemName,
        label = def.label,
        text = text
    })
end

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
--- (pl. fegyvernél durability/serial). serialPrefixOverride opcionális -
--- ha meg van adva, ez felülírja az item saját alapértelmezett serial
--- előtagját (pl. shopoknál a frakció-alapú serial előtaghoz).
--- Visszaad: ok(bool), reason(string)
local function AddItemToImpl(ownerType, ownerRef, itemName, quantity, metadata, serialPrefixOverride)
    local def = Config.Items[itemName]
    if not def then return false, 'Ismeretlen item.' end

    metadata = metadata or {}

    local slots, saveFn, maxSlots, maxWeight = getHandle(ownerType, ownerRef)
    if not slots then return false, 'Az inventory nem elérhető.' end

    local currentWeight = NBInv.CalcWeight(slots)
    local addedWeight = def.weight * quantity
    if currentWeight + addedWeight > maxWeight then
        return false, 'Nincs elég hely (túl nehéz lenne).'
    end

    -- Egyedi metadatás (pl. fegyver serial) itemek sosem stackelődnek egymásra.
    -- FONTOS: ha nem stackelhető az item (pl. fegyver), minden egyes
    -- példánynak SAJÁT metadata táblát generálunk (saját serial/durability),
    -- sosem osztozhatnak ugyanazon a táblán.
    local hasUniqueMeta = not def.stackable or (metadata.serial ~= nil)

    if def.stackable and not hasUniqueMeta then
        if def.hasDurability and metadata.durability == nil then metadata.durability = 100 end

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

        local putQuantity
        local instanceMetadata

        if def.stackable then
            putQuantity = math.min(quantity, def.maxStack or 999999)
            instanceMetadata = metadata
            if def.hasDurability and instanceMetadata.durability == nil then instanceMetadata.durability = 100 end
        else
            putQuantity = 1
            -- Saját, friss tábla PÉLDÁNYONKÉNT - ne osztozzon senki mással
            instanceMetadata = {}
            for k, v in pairs(metadata) do instanceMetadata[k] = v end
            if def.hasDurability and instanceMetadata.durability == nil then instanceMetadata.durability = 100 end
            if def.hasSerial and instanceMetadata.serial == nil then
                instanceMetadata.serial = NBInv.GenerateSerial(serialPrefixOverride or def.serialPrefix)
            end
        end

        slots[freeSlot] = { item = itemName, quantity = putQuantity, metadata = instanceMetadata }
        saveFn(freeSlot, slots[freeSlot])
        quantity = quantity - putQuantity
    end

    return true
end

--- Item eltávolítása egy adott slotból (vagy ha nincs slot megadva, bárhonnan)
local function RemoveItemFromImpl(ownerType, ownerRef, itemName, quantity)
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

-- A HUD-nak minden készpénzt érintő változás után jeleznünk kell, függetlenül
-- attól hogy a hívás honnan jött (NUI akció, /giveitem admin parancs, stb.) -
-- ezért itt, a legalsó, KÖZÖS ponton toljuk ki, nem az egyes hívóhelyeken.
local function pushCashIfPlayer(ownerType, ownerRef)
    if ownerType ~= 'player' then return end
    pcall(function()
        TriggerClientEvent('nb_hud:setStat', ownerRef, 'cash', NBInv.GetItemCount('player', ownerRef, 'cash'))
    end)
end

function NBInv.AddItemTo(ownerType, ownerRef, itemName, quantity, metadata, serialPrefixOverride)
    local ok, reason = AddItemToImpl(ownerType, ownerRef, itemName, quantity, metadata, serialPrefixOverride)
    if ok then pushCashIfPlayer(ownerType, ownerRef) end
    return ok, reason
end

function NBInv.RemoveItemFrom(ownerType, ownerRef, itemName, quantity)
    local ok = RemoveItemFromImpl(ownerType, ownerRef, itemName, quantity)
    if ok then pushCashIfPlayer(ownerType, ownerRef) end
    return ok
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
exports('GetItemDef', function(itemName) return Config.Items[itemName] end)
exports('AddItem', function(source, itemName, quantity, metadata, serialPrefix) return NBInv.AddItemTo('player', source, itemName, quantity or 1, metadata, serialPrefix) end)
exports('GenerateSerial', function(prefix) return NBInv.GenerateSerial(prefix) end)
exports('RemoveItem', function(source, itemName, quantity) return NBInv.RemoveItemFrom('player', source, itemName, quantity or 1) end)
exports('HasItem', function(source, itemName, quantity) return NBInv.HasItem('player', source, itemName, quantity) end)
exports('GetItemCount', function(source, itemName) return NBInv.GetItemCount('player', source, itemName) end)
exports('GetWeight', function(source)
    local slots = getHandle('player', source)
    return slots and NBInv.CalcWeight(slots) or 0
end)
