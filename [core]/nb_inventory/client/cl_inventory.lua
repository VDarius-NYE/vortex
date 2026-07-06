-- Inventory NUI vezérlés, hotbar (1-5), fegyver equip, durability figyelés.

local invOpen = false
local uiAck = false

local function openUIWithRetry(payload)
    SetNuiFocus(true, true)
    uiAck = false
    CreateThread(function()
        local attempts = 0
        while not uiAck and attempts < 20 do
            SendNUIMessage(payload)
            attempts = attempts + 1
            Wait(150)
        end
    end)
end

RegisterNUICallback('inventoryReady', function(data, cb)
    uiAck = true
    cb('ok')
end)

RegisterNetEvent('nb_inventory:openUI', function(playerPayload, stashPayload)
    invOpen = true
    openUIWithRetry({ action = 'open', player = playerPayload, stash = stashPayload })
end)

RegisterNetEvent('nb_inventory:updateUI', function(playerPayload, stashPayload)
    SendNUIMessage({ action = 'update', player = playerPayload, stash = stashPayload })
end)

local function closeInventory()
    invOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('nb_inventory:close')
end

RegisterCommand('inventory', function()
    if invOpen then
        closeInventory()
    else
        TriggerServerEvent('nb_inventory:requestOpen')
    end
end, false)

RegisterKeyMapping('inventory', 'Inventory megnyitása/bezárása', 'keyboard', 'I')

RegisterNUICallback('closeInventory', function(data, cb)
    closeInventory()
    cb('ok')
end)

RegisterNUICallback('useItem', function(data, cb)
    TriggerServerEvent('nb_inventory:useItem', data)
    cb('ok')
end)

RegisterNUICallback('splitItem', function(data, cb)
    TriggerServerEvent('nb_inventory:splitItem', data)
    cb('ok')
end)

RegisterNUICallback('moveItem', function(data, cb)
    TriggerServerEvent('nb_inventory:moveItem', data)
    cb('ok')
end)

-- ESC-cel is bezárható
CreateThread(function()
    while true do
        Wait(0)
        if invOpen then
            if IsControlJustPressed(0, 322) then -- ESC
                closeInventory()
            end
        else
            Wait(300)
        end
    end
end)

-- ============================================================
-- Hotbar (1-5 gomb) - gyors használat a teljes UI megnyitása nélkül
-- ============================================================
for i = 1, 5 do
    RegisterCommand('hotbarslot' .. i, function()
        if invOpen then return end -- ha nyitva a UI, ott kattintással használjon
        TriggerServerEvent('nb_inventory:useItem', { side = 'player', slot = i })
    end, false)
    RegisterKeyMapping('hotbarslot' .. i, ('Hotbar %d. slot használata'):format(i), 'keyboard', tostring(i))
end

-- ============================================================
-- Fegyver equip
-- ============================================================
RegisterNetEvent('nb_inventory:equipWeapon', function(weaponHash, metadata)
    local ped = PlayerPedId()
    local hash = GetHashKey(weaponHash)
    RequestWeaponAsset(hash, 31, 0)
    local timeout = 0
    while not HasWeaponAssetLoaded(hash) and timeout < 2000 do
        Wait(50)
        timeout = timeout + 50
    end

    GiveWeaponToPed(ped, hash, 120, false, true)
    SetCurrentPedWeapon(ped, hash, true)
    RemoveWeaponAsset(hash)
end)

RegisterNetEvent('nb_inventory:healEffect', function(amount)
    local ped = PlayerPedId()
    local newHealth = math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + amount)
    SetEntityHealth(ped, newHealth)
end)

-- ============================================================
-- Fegyver durability csökkenés - lövés detektálás (ammó-csökkenés figyelés)
-- ============================================================
local lastAmmo = {}

CreateThread(function()
    while true do
        Wait(300)
        local ped = PlayerPedId()
        local weaponHash = GetSelectedPedWeapon(ped)

        if weaponHash and weaponHash ~= GetHashKey('WEAPON_UNARMED') then
            local ammo = GetAmmoInPedWeapon(ped, weaponHash)
            if lastAmmo[weaponHash] and ammo < lastAmmo[weaponHash] then
                TriggerServerEvent('nb_inventory:reportShot', weaponHash)
            end
            lastAmmo[weaponHash] = ammo
        end
    end
end)
