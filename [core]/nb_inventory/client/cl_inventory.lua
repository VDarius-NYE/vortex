-- Inventory NUI vezérlés, hotbar (1-5), fegyver equip, durability figyelés.

-- Az alap GTA fegyverkerék (tár/select weapon) letiltása - a fegyvereket
-- mostantól kizárólag az inventoryból lehet elő-/elrakni.
CreateThread(function()
    while true do
        Wait(0)
        DisableControlAction(0, 37, true) -- INPUT_SELECT_WEAPON
    end
end)

local invOpen = false
local uiAck = false
local cachedPlayerInventory = nil -- a legutóbb kapott saját inventory payload (hotbar-hoz kell)

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

RegisterNetEvent('nb_inventory:silentSync', function(payload)
    cachedPlayerInventory = payload
end)

RegisterNetEvent('nb_inventory:openUI', function(playerPayload, stashPayload, positions)
    invOpen = true
    cachedPlayerInventory = playerPayload
    openUIWithRetry({ action = 'open', player = playerPayload, stash = stashPayload, positions = positions })
end)

RegisterNetEvent('nb_inventory:updateUI', function(playerPayload, stashPayload)
    cachedPlayerInventory = playerPayload
    SendNUIMessage({ action = 'update', player = playerPayload, stash = stashPayload })
end)

RegisterNetEvent('nb_inventory:popup', function(data)
    SendNUIMessage({ action = 'popup', item = data.item, label = data.label, text = data.text })
end)

local function closeInventory()
    invOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('nb_inventory:close')
end

-- Ha egy Föld-kupac kiürül miközben nyitva van, az egész panel bezáródik
RegisterNetEvent('nb_inventory:closeStash', function()
    if invOpen then
        closeInventory()
    end
end)

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

-- Melyik fegyver item van most kint (nil = semmi). Ezt SAJÁT MAGUNK követjük,
-- nem natív lekérdezésekre (GetSelectedPedWeapon stb.) támaszkodunk, mert
-- azok időzítés-érzékenyek lehetnek és megbízhatatlan togglet eredményeztek.
local currentlyEquippedItem = nil

-- Közös logika: ezt hívja a NUI "Használat" gomb ÉS a hotbar (1-5) is,
-- hogy pontosan ugyanúgy viselkedjen mindkét helyről.
local function handleUseItem(itemKey, side, slot, stashId)
    if not itemKey then return end
    local def = Config.Items[itemKey]

    if def and def.type == 'weapon' then
        local ped = PlayerPedId()
        local hash = GetHashKey(itemKey)

        if currentlyEquippedItem == itemKey then
            -- Ki van véve -> vagy újratöltjük (ha üres a tár), vagy elrakjuk
            local currentAmmo = GetAmmoInPedWeapon(ped, hash)
            if currentAmmo <= 0 then
                TriggerServerEvent('nb_inventory:reloadWeapon', itemKey)
            else
                SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
                currentlyEquippedItem = nil
                TriggerServerEvent('nb_inventory:weaponToggled', itemKey, 'holster')
            end
        elseif HasPedGotWeapon(ped, hash, false) then
            -- Korábban már elővettük ebben a szesszióban - csak visszaváltunk rá, lőszer-levonás nélkül
            SetCurrentPedWeapon(ped, hash, true)
            currentlyEquippedItem = itemKey
            TriggerServerEvent('nb_inventory:weaponToggled', itemKey, 'draw')
        else
            -- Első előhúzás - a szerver dönt a lőszer-levonásról
            TriggerServerEvent('nb_inventory:requestDraw', { side = side, slot = slot, stashId = stashId })
        end
    else
        if def and def.progressBar then
            -- Elindítjuk a progress bar-t, és csak sikeres (nem megszakított)
            -- lefutás után küldjük el a szervernek a tényleges használatot.
            CreateThread(function()
                local finished = exports['nb_progressbar']:Start({
                    label = def.progressBar.label,
                    duration = def.progressBar.duration
                })
                if finished then
                    TriggerServerEvent('nb_inventory:useItem', { side = side, slot = slot, stashId = stashId })
                end
            end)
        else
            TriggerServerEvent('nb_inventory:useItem', { side = side, slot = slot, stashId = stashId })
        end
    end
end

RegisterNUICallback('useItem', function(data, cb)
    handleUseItem(data.item, data.side, data.slot, data.stashId)
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

RegisterNUICallback('dropItem', function(data, cb)
    TriggerServerEvent('nb_inventory:dropItem', data)
    cb('ok')
end)

RegisterNUICallback('savePosition', function(data, cb)
    TriggerServerEvent('nb_inventory:savePosition', data)
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
        if not cachedPlayerInventory then return end

        local slotData = cachedPlayerInventory.slots[tostring(i)]
        if not slotData then return end

        handleUseItem(slotData.item, 'player', i, nil)
    end, false)
    RegisterKeyMapping('hotbarslot' .. i, ('Hotbar %d. slot használata'):format(i), 'keyboard', tostring(i))
end

-- ============================================================
-- Fegyver equip
-- ============================================================
RegisterNetEvent('nb_inventory:equipWeapon', function(weaponItemKey, ammoCount)
    local ped = PlayerPedId()
    local hash = GetHashKey(weaponItemKey)
    RequestWeaponAsset(hash, 31, 0)
    local timeout = 0
    while not HasWeaponAssetLoaded(hash) and timeout < 2000 do
        Wait(50)
        timeout = timeout + 50
    end

    GiveWeaponToPed(ped, hash, ammoCount or 0, false, true)
    SetCurrentPedWeapon(ped, hash, true)
    RemoveWeaponAsset(hash)

    currentlyEquippedItem = weaponItemKey
end)

RegisterNetEvent('nb_inventory:reloadAmmo', function(weaponItemKey, addAmount)
    local ped = PlayerPedId()
    local hash = GetHashKey(weaponItemKey)
    AddAmmoToPed(ped, hash, addAmount)
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
