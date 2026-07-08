-- Eldobott itemek: világban megjelenő prop, amit nb_interact-tal lehet
-- felszedni. Egyelőre memóriában tartva (nem DB-ben - szerver restart törli
-- a földön heverő itemeket, ez egy jövőbeli finomítás lehet).

local drops = {} -- [dropId] = { id, item, quantity, metadata, x, y, z }
local nextDropId = 1

local function broadcastDrop(drop)
    TriggerClientEvent('nb_inventory:spawnDrop', -1, drop)
end

--- Létrehoz egy dropot adott koordinátán. Visszaadja a dropId-t.
function NBInv.CreateDrop(itemName, quantity, metadata, coords)
    local dropId = nextDropId
    nextDropId = nextDropId + 1

    local drop = {
        id = dropId,
        item = itemName,
        quantity = quantity,
        metadata = metadata or {},
        x = coords.x, y = coords.y, z = coords.z
    }

    drops[dropId] = drop
    broadcastDrop(drop)

    return dropId
end

RegisterNetEvent('nb_inventory:requestPickup', function(dropId)
    local source = source
    local drop = drops[dropId]
    if not drop then return end

    local ok, err = NBInv.AddItemTo('player', source, drop.item, drop.quantity, drop.metadata)

    if ok then
        drops[dropId] = nil
        TriggerClientEvent('nb_inventory:removeDrop', -1, dropId)
        NBInv.SendPopup(source, drop.item, 'received', drop.quantity)
        TriggerEvent('nb_inventory:internalRefresh', source)
    else
        exports['nb_core']:Notify(source, { message = err or 'Nem sikerült felvenni.', type = 'error' })
    end
end)
