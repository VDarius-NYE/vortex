-- NUI által kiváltott akciók: nyitás, item használat, szétválasztás, mozgatás,
-- fegyver durability csökkenés.

local inventoryOpenFor = {}  -- [source] = true/false (van-e most nyitva a NUI-ja)
local openStashFor = {}      -- [source] = stashId vagy nil

local function refresh(source)
    if not inventoryOpenFor[source] then return end

    local playerPayload = NBInv.BuildPayload('player', source)
    local stashPayload = nil

    if openStashFor[source] then
        stashPayload = NBInv.BuildPayload('stash', openStashFor[source])
        if stashPayload then
            stashPayload.stashId = openStashFor[source]
        end
    end

    TriggerClientEvent('nb_inventory:updateUI', source, playerPayload, stashPayload)
end

-- ============================================================
-- Megnyitás
-- ============================================================
RegisterNetEvent('nb_inventory:requestOpen', function()
    local source = source
    local payload = NBInv.BuildPayload('player', source)
    if not payload then return end

    inventoryOpenFor[source] = true
    openStashFor[source] = nil

    TriggerClientEvent('nb_inventory:openUI', source, payload, nil)
end)

RegisterNetEvent('nb_inventory:requestOpenStash', function(stashId)
    local source = source
    local stashInfo = NBInv.GetStashInfo(stashId)
    if not stashInfo then return end

    -- Szerver oldali távolság-ellenőrzés (ne lehessen távolról stash-t nyitni)
    local coords = GetEntityCoords(GetPlayerPed(source))
    local dist = #(vector3(coords.x, coords.y, coords.z) - vector3(stashInfo.x, stashInfo.y, stashInfo.z))
    if dist > 4.0 then
        exports['nb_core']:Notify(source, { message = 'Túl messze vagy a stash-től.', type = 'error' })
        return
    end

    local playerPayload = NBInv.BuildPayload('player', source)
    local stashPayload = NBInv.BuildPayload('stash', stashId)
    if not playerPayload or not stashPayload then return end
    stashPayload.stashId = stashId
    stashPayload.factionId = stashInfo.faction_id

    inventoryOpenFor[source] = true
    openStashFor[source] = stashId

    TriggerClientEvent('nb_inventory:openUI', source, playerPayload, stashPayload)
end)

RegisterNetEvent('nb_inventory:close', function()
    local source = source
    inventoryOpenFor[source] = false
    openStashFor[source] = nil
end)

AddEventHandler('playerDropped', function()
    local source = source
    inventoryOpenFor[source] = nil
    openStashFor[source] = nil
end)

-- ============================================================
-- Item használat
-- ============================================================
RegisterNetEvent('nb_inventory:useItem', function(data)
    local source = source
    if data.side ~= 'player' then return end -- csak a saját inventoryból lehet használni

    local slots, saveFn = NBInv.GetHandle('player', source)
    if not slots then return end

    local item = slots[data.slot]
    if not item then return end

    local def = Config.Items[item.item]
    if not def or not def.usable then return end

    if def.type == 'weapon' then
        TriggerClientEvent('nb_inventory:equipWeapon', source, def.weaponHash, item.metadata or {})
    else
        if def.effect then
            if def.effect.kind == 'hunger' then
                exports['nb_basicneeds']:AddHunger(source, def.effect.amount)
            elseif def.effect.kind == 'thirst' then
                exports['nb_basicneeds']:AddThirst(source, def.effect.amount)
            elseif def.effect.kind == 'health' then
                TriggerClientEvent('nb_inventory:healEffect', source, def.effect.amount)
            end
        end

        item.quantity = item.quantity - 1
        if item.quantity <= 0 then
            slots[data.slot] = nil
            saveFn(data.slot, nil)
        else
            saveFn(data.slot, item)
        end

        exports['nb_core']:Notify(source, { message = ('%s használva.'):format(def.label), type = 'success', duration = 3000 })
    end

    refresh(source)
end)

-- ============================================================
-- Szétválasztás (felezés vagy egyéni mennyiség)
-- ============================================================
RegisterNetEvent('nb_inventory:splitItem', function(data)
    local source = source
    local ownerType = data.side == 'stash' and 'stash' or 'player'
    local ownerRef = data.side == 'stash' and data.stashId or source

    local slots, saveFn, maxSlots = NBInv.GetHandle(ownerType, ownerRef)
    if not slots then return end

    local origin = slots[data.slot]
    if not origin then return end

    local def = Config.Items[origin.item]
    local amount = tonumber(data.amount)

    if not def or not def.stackable or not amount or amount <= 0 or amount >= origin.quantity then
        return
    end

    local freeSlot = nil
    for slot = 1, maxSlots do
        if not slots[slot] then freeSlot = slot break end
    end

    if not freeSlot then
        exports['nb_core']:Notify(source, { message = 'Nincs szabad hely a szétválasztáshoz.', type = 'error' })
        return
    end

    origin.quantity = origin.quantity - amount
    slots[freeSlot] = { item = origin.item, quantity = amount, metadata = origin.metadata }

    saveFn(data.slot, origin)
    saveFn(freeSlot, slots[freeSlot])

    refresh(source)
end)

-- ============================================================
-- Mozgatás (slotok között, akár player<->stash is)
-- ============================================================
RegisterNetEvent('nb_inventory:moveItem', function(data)
    local source = source

    local fromType = data.fromSide == 'stash' and 'stash' or 'player'
    local fromRef = data.fromSide == 'stash' and data.stashId or source
    local toType = data.toSide == 'stash' and 'stash' or 'player'
    local toRef = data.toSide == 'stash' and data.stashId or source

    -- Ha stash érintett, ellenőrizzük hogy tényleg nyitva van-e a playernek
    if (fromType == 'stash' or toType == 'stash') and openStashFor[source] ~= (data.stashId) then
        return
    end

    local fromSlots, fromSave = NBInv.GetHandle(fromType, fromRef)
    local toSlots, toSave, toMaxSlots, toMaxWeight = NBInv.GetHandle(toType, toRef)
    if not fromSlots or not toSlots then return end

    local item = fromSlots[data.fromSlot]
    if not item then return end

    if fromType == toType and fromRef == toRef and data.fromSlot == data.toSlot then return end

    -- Súlykapacitás ellenőrzés, ha másik tulajdonoshoz megy az item
    if fromType ~= toType or fromRef ~= toRef then
        local def = Config.Items[item.item]
        local destWeight = NBInv.CalcWeight(toSlots)
        if destWeight + (def.weight * item.quantity) > toMaxWeight then
            exports['nb_core']:Notify(source, { message = 'Nincs elég hely (túl nehéz lenne).', type = 'error' })
            return
        end
    end

    local existing = toSlots[data.toSlot]

    if existing then
        local def = Config.Items[item.item]
        local hasUniqueMeta = item.metadata and item.metadata.serial ~= nil

        if existing.item == item.item and def.stackable and not hasUniqueMeta then
            local room = (def.maxStack or 999999) - existing.quantity
            local moveQty = math.min(room, item.quantity)

            existing.quantity = existing.quantity + moveQty
            toSave(data.toSlot, existing)
            item.quantity = item.quantity - moveQty

            if item.quantity <= 0 then
                fromSlots[data.fromSlot] = nil
                fromSave(data.fromSlot, nil)
            else
                fromSave(data.fromSlot, item)
            end
        else
            -- Csere (swap)
            fromSlots[data.fromSlot] = existing
            toSlots[data.toSlot] = item
            fromSave(data.fromSlot, existing)
            toSave(data.toSlot, item)
        end
    else
        toSlots[data.toSlot] = item
        fromSlots[data.fromSlot] = nil
        toSave(data.toSlot, item)
        fromSave(data.fromSlot, nil)
    end

    refresh(source)
end)

-- ============================================================
-- Fegyver durability csökkenés lövéskor (a kliens jelenti)
-- ============================================================
RegisterNetEvent('nb_inventory:reportShot', function(weaponHash)
    local source = source
    local slots, saveFn = NBInv.GetHandle('player', source)
    if not slots then return end

    for slot, data in pairs(slots) do
        local def = Config.Items[data.item]
        if def and def.weaponHash and GetHashKey(def.weaponHash) == weaponHash then
            data.metadata = data.metadata or {}
            local dur = data.metadata.durability or 100
            dur = math.max(0, dur - (math.random(10, 30) / 10))
            data.metadata.durability = dur
            saveFn(slot, data)
            break
        end
    end

    refresh(source)
end)
