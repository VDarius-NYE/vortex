-- Countdown UI megjelenítése + hangjelzés lejátszása minden percnél.

RegisterNetEvent('nb_shutdown:show', function(data)
    SendNUIMessage({
        action = 'show',
        minutes = data.minutes,
        reason = data.reason
    })
end)

RegisterNetEvent('nb_shutdown:playSound', function()
    SendNUIMessage({ action = 'playSound' })
end)

RegisterNetEvent('nb_shutdown:hide', function()
    SendNUIMessage({ action = 'hide' })
end)
