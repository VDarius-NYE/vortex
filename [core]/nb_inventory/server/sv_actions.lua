-- NUI által kiváltott akciók: nyitás, item használat, szétválasztás, mozgatás,
-- fegyver durability csökkenés.

local inventoryOpenFor = {}  -- [source] = true/false (van-e most nyitva a NUI-ja)
local openStashFor = {}      -- [source] = stashId vagy nil

local function refresh(source)
    -- A saját inventory cache-t MINDIG frissítjük (a hotbar erre támaszkodik,
    -- akkor is ha nincs nyitva a fő UI).
    local playerPayload = NBInv.BuildPayload('player', source)
    TriggerClientEvent('nb_inventory:silentSync', source, playerPayload)

    -- A HUD-nak is jelezzük a jelenlegi készpénz mennyiséget (ha az nb_hud fut)
    pcall(function()
        TriggerClientEvent('nb_hud:setStat', source, 'cash', NBInv.GetItemCount('player', source, 'cash'))
    end)

    if not inventoryOpenFor[source] then return end

    local stashPayload = nil
    if openStashFor[source] then
        stashPayload = NBInv.BuildPayload('stash', openStashFor[source])
        if stashPayload then
            stashPayload.stashId = openStashFor[source]
        end
    end

    TriggerClientEvent('nb_inventory:updateUI', source, playerPayload, stashPayload)
end

-- Más fájlok (pl. sv_admin.lua) ezen keresztül kérhetik egy nyitva lévő UI frissítését
AddEventHandler('nb_inventory:internalRefresh', function(targetSource)
    refresh(targetSource)
end)

-- ============================================================
-- Megnyitás
-- ============================================================
RegisterNetEvent('nb_inventory:requestOpen', function()
    local source = source
    local payload = NBInv.BuildPayload('player', source)
    if not payload then return end

    inventoryOpenFor[source] = true
    openStashFor[source] = nil

    TriggerClientEvent('nb_inventory:openUI', source, payload, nil, NBInv.GetPositions(source))
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

    TriggerClientEvent('nb_inventory:openUI', source, playerPayload, stashPayload, NBInv.GetPositions(source))
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

-- Első előhúzás - itt vonjuk le a lőszert az inventoryból és töltjük be a fegyverbe.
RegisterNetEvent('nb_inventory:requestDraw', function(data)
    local source = source

    local slots, saveFn = NBInv.GetHandle('player', source)
    if not slots then return end

    local item = slots[data.slot]
    if not item then return end

    local def = Config.Items[item.item]
    if not def or def.type ~= 'weapon' then return end

    local loadAmount = 0
    if def.ammoItem then
        local have = NBInv.GetItemCount('player', source, def.ammoItem)
        loadAmount = math.min(have, def.magazineSize or 999)
        if loadAmount > 0 then
            NBInv.RemoveItemFrom('player', source, def.ammoItem, loadAmount)
        end
    end

    TriggerClientEvent('nb_inventory:equipWeapon', source, item.item, loadAmount)
    NBInv.SendPopup(source, item.item, 'drawn')

    refresh(source)
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
    if not def or not def.usable or def.type == 'weapon' then return end

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

    NBInv.SendPopup(source, item.item, 'used', 1)

    refresh(source)
end)

-- Ismételt elő-/elrakás (amikor a fegyver már korábban be lett töltve
-- ebben a szesszióban) - itt nincs lőszer-levonás, csak popup visszajelzés.
RegisterNetEvent('nb_inventory:weaponToggled', function(itemKey, kind)
    local source = source
    NBInv.SendPopup(source, itemKey, kind == 'holster' and 'equipped' or 'drawn')
end)

-- Fegyver újratöltése (csak akkor hívja a kliens, ha a tár üres) - annyi
-- lőszert von le az inventoryból, amennyi a tárba fér, és azt be is tölti.
RegisterNetEvent('nb_inventory:reloadWeapon', function(itemKey)
    local source = source
    local def = Config.Items[itemKey]
    if not def or def.type ~= 'weapon' or not def.ammoItem then return end

    local have = NBInv.GetItemCount('player', source, def.ammoItem)
    local loadAmount = math.min(have, def.magazineSize or 999)

    if loadAmount <= 0 then
        exports['nb_core']:Notify(source, { message = 'Nincs lőszered ehhez a fegyverhez.', type = 'error' })
        return
    end

    NBInv.RemoveItemFrom('player', source, def.ammoItem, loadAmount)
    TriggerClientEvent('nb_inventory:reloadAmmo', source, itemKey, loadAmount)
    exports['nb_core']:Notify(source, { message = ('Újratöltve: %d db %s.'):format(loadAmount, Config.Items[def.ammoItem].label), type = 'success' })

    refresh(source)
end)

-- ============================================================
-- Eldobás
-- ============================================================
RegisterNetEvent('nb_inventory:dropItem', function(data)
    local source = source
    local ownerType = data.side == 'stash' and 'stash' or 'player'
    local ownerRef = data.side == 'stash' and data.stashId or source

    local slots, saveFn = NBInv.GetHandle(ownerType, ownerRef)
    if not slots then return end

    local item = slots[data.slot]
    if not item then return end

    local quantity = item.quantity
    slots[data.slot] = nil
    saveFn(data.slot, nil)

    -- A dobás mindig a JÁTÉKOS aktuális pozíciójára kerül (egy közeli, le nem
    -- járt Föld-kupacba, vagy ha nincs ilyen a közelben, egy újba).
    local coords = GetEntityCoords(GetPlayerPed(source))
    local groundStashId = NBInv.FindOrCreateGroundStash(coords)
    NBInv.AddItemTo('stash', groundStashId, item.item, quantity, item.metadata)

    if ownerType == 'player' then
        NBInv.SendPopup(source, item.item, 'dropped', quantity)
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

    -- Ha egy Föld-kupacból vettünk ki valamit és az ezáltal kiürült, töröljük
    -- automatikusan (prop/interact is eltűnik minden kliensen), és ha nálam
    -- éppen nyitva van, zárjuk be a Föld panelt.
    if fromType == 'stash' then
        local deleted = NBInv.CheckGroundStashEmpty(fromRef)
        if deleted and openStashFor[source] == fromRef then
            openStashFor[source] = nil
            TriggerClientEvent('nb_inventory:closeStash', source)
        end
    end
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
        if def and def.type == 'weapon' and GetHashKey(data.item) == weaponHash then
            data.metadata = data.metadata or {}
            local dur = data.metadata.durability or 100
            dur = math.max(0, dur - (math.random(2, 6) / 100))
            data.metadata.durability = dur
            saveFn(slot, data)
            break
        end
    end

    refresh(source)
end)

-- ============================================================
-- Kényszerített stash-megnyitás (más resource-ok számára, pl. nb_death a
-- kifosztott halott játékos inventoryjának megnyitásához) - nincs
-- távolság-ellenőrzés, mert a hívó resource már validálta a kontextust.
-- ============================================================
AddEventHandler('nb_inventory:forceOpenStash', function(source, stashId)
    local playerPayload = NBInv.BuildPayload('player', source)
    local stashPayload = NBInv.BuildPayload('stash', stashId)
    if not playerPayload or not stashPayload then return end

    stashPayload.stashId = stashId
    stashPayload.factionId = 'GROUND'

    inventoryOpenFor[source] = true
    openStashFor[source] = stashId

    TriggerClientEvent('nb_inventory:openUI', source, playerPayload, stashPayload, NBInv.GetPositions(source))
end)
