-- Bolt NUI vezérlés (item/weapon shop kosárral, vehicle shop kosár nélkül).

local shopOpen = false

RegisterNetEvent('nb_shops:openUI', function(payload)
    shopOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', payload = payload })
end)

RegisterNetEvent('nb_shops:checkoutDone', function()
    -- sikeres vásárlás után a NUI maga eldönti hogy zárjon-e vagy maradjon nyitva
    SendNUIMessage({ action = 'checkoutDone' })
end)

RegisterNetEvent('nb_shops:vehiclePurchaseFailed', function(vehicleIndex)
    SendNUIMessage({ action = 'vehiclePurchaseFailed', vehicleIndex = vehicleIndex })
end)

local function closeShop()
    shopOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('closeShop', function(data, cb)
    closeShop()
    cb('ok')
end)

RegisterNUICallback('checkout', function(data, cb)
    TriggerServerEvent('nb_shops:checkout', data)
    cb('ok')
end)

RegisterNUICallback('buyVehicle', function(data, cb)
    TriggerServerEvent('nb_shops:buyVehicle', data)
    cb('ok')
end)

CreateThread(function()
    while true do
        Wait(0)
        if shopOpen then
            if IsControlJustPressed(0, 322) then -- ESC
                closeShop()
            end
        else
            Wait(300)
        end
    end
end)
