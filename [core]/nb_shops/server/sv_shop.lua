-- Bolt megnyitás (jogosultság-ellenőrzéssel: a 0-ás (alap) frakció boltjai
-- mindenkinek elérhetők, a többi frakcióé csak a saját tagjainak), kosár
-- checkout (készpénz/kártya), jármű vásárlás.

local function canAccessFactionShop(source, factionId)
    if factionId == 0 then return true end -- alap frakció boltjai mindig nyitva mindenkinek
    return exports['nb_factions']:GetFaction(source) == factionId
end

-- ============================================================
-- Megnyitás
-- ============================================================
RegisterNetEvent('nb_shops:requestOpen', function(shopType, factionId, shopIndex)
    local source = source

    if not canAccessFactionShop(source, factionId) then
        exports['nb_core']:Notify(source, { message = 'Ez a bolt csak a saját frakciód tagjainak elérhető.', type = 'error' })
        return
    end

    local shopDef = exports['nb_factions']:GetShopDef(factionId, shopType, shopIndex)
    if not shopDef then return end

    if shopType == 'vehicle' then
        local ownedModels = {}
        local owned = exports['nb_ownvehicles']:GetOwnedVehicles(source) or {}
        for _, v in ipairs(owned) do ownedModels[v.model] = true end

        local vehicles = {}
        for i, v in ipairs(shopDef.vehicles) do
            vehicles[#vehicles + 1] = {
                index = i,
                model = v.model,
                label = v.label,
                price = v.price,
                owned = ownedModels[v.model] == true
            }
        end

        TriggerClientEvent('nb_shops:openUI', source, {
            shopType = 'vehicle',
            factionId = factionId,
            shopIndex = shopIndex,
            title = shopDef.npcName,
            vehicles = vehicles
        })
    else
        local items = {}
        for _, entry in ipairs(shopDef.items) do
            local def = exports['nb_inventory']:GetItemDef(entry.item)
            items[#items + 1] = {
                item = entry.item,
                price = entry.price,
                label = def and def.label or entry.item,
                icon = def and def.icon or 'fa-solid fa-cube'
            }
        end

        TriggerClientEvent('nb_shops:openUI', source, {
            shopType = shopType,
            factionId = factionId,
            shopIndex = shopIndex,
            title = shopDef.npcName,
            items = items
        })
    end
end)

-- ============================================================
-- Fizetés (visszaad: ok, hiba)
-- ============================================================
local function tryPay(source, amount, method)
    if amount <= 0 then return true end -- ingyenes

    if method == 'card' then
        return exports['nb_core']:RemoveBank(source, amount)
    else
        return exports['nb_inventory']:RemoveItem(source, 'cash', amount)
    end
end

-- ============================================================
-- Kosár checkout (item/weapon shop)
-- ============================================================
RegisterNetEvent('nb_shops:checkout', function(data)
    local source = source

    if not canAccessFactionShop(source, data.factionId) then return end

    local shopDef = exports['nb_factions']:GetShopDef(data.factionId, data.shopType, data.shopIndex)
    if not shopDef then return end

    -- Az árakat/tételeket SOSEM a kliens adatából vesszük készpénznek - a
    -- shop configból nézzük ki újra, tétel szerint.
    local validItems = {}
    for _, entry in ipairs(shopDef.items) do
        validItems[entry.item] = entry.price
    end

    local total = 0
    local toGive = {}

    for _, cartEntry in ipairs(data.cart or {}) do
        local price = validItems[cartEntry.item]
        local quantity = tonumber(cartEntry.quantity)
        if price and quantity and quantity > 0 then
            total = total + (price * quantity)
            toGive[#toGive + 1] = { item = cartEntry.item, quantity = quantity }
        end
    end

    if #toGive == 0 then
        exports['nb_core']:Notify(source, { message = 'Üres a kosár.', type = 'warning' })
        return
    end

    if not tryPay(source, total, data.paymentMethod) then
        exports['nb_core']:Notify(source, { message = 'Nincs elég pénzed ehhez a vásárláshoz.', type = 'error' })
        return
    end

    local factionDef = exports['nb_factions']:GetFactionConfig(data.factionId)
    local serialPrefix = factionDef and factionDef.serialPrefix

    for _, entry in ipairs(toGive) do
        local ok, err = exports['nb_inventory']:AddItem(source, entry.item, entry.quantity, nil, serialPrefix)
        if not ok then
            exports['nb_core']:Notify(source, { message = err or 'Nem fért be minden az inventorydba.', type = 'warning' })
        end
    end

    exports['nb_core']:Notify(source, { message = ('Vásárlás sikeres (%d Ft).'):format(total), type = 'success' })
    TriggerClientEvent('nb_shops:checkoutDone', source)
end)

-- ============================================================
-- Jármű vásárlás (nincs kosár, direkt vétel)
-- ============================================================
RegisterNetEvent('nb_shops:buyVehicle', function(data)
    local source = source

    if not canAccessFactionShop(source, data.factionId) then return end

    local shopDef = exports['nb_factions']:GetShopDef(data.factionId, 'vehicle', data.shopIndex)
    if not shopDef then return end

    local vehicleDef = shopDef.vehicles[tonumber(data.vehicleIndex)]
    if not vehicleDef then return end

    -- Szerver oldali védelem: ne lehessen kétszer megvenni ugyanazt a modellt
    -- (a kliens oldali letiltott gomb csak UX, nem biztonsági határ)
    local owned = exports['nb_ownvehicles']:GetOwnedVehicles(source) or {}
    for _, v in ipairs(owned) do
        if v.model == vehicleDef.model then
            exports['nb_core']:Notify(source, { message = 'Ez a jármű már a tiéd.', type = 'error' })
            return
        end
    end

    if not tryPay(source, vehicleDef.price, data.paymentMethod) then
        exports['nb_core']:Notify(source, { message = 'Nincs elég pénzed ehhez a vásárláshoz.', type = 'error' })
        TriggerClientEvent('nb_shops:vehiclePurchaseFailed', source, data.vehicleIndex)
        return
    end

    exports['nb_ownvehicles']:AddOwnedVehicle(source, vehicleDef.model, vehicleDef.label, data.factionId, vehicleDef.spawnCoords)

    exports['nb_core']:Notify(source, {
        message = ('Megvetted: %s. Vedd fel bármelyik garázsnál.'):format(vehicleDef.label),
        type = 'success'
    })
    TriggerClientEvent('nb_shops:checkoutDone', source)
end)
