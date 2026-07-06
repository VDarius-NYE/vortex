-- Szerver oldalról bármelyik resource ezzel tud notify-t küldeni egy adott playernek:
--   exports['nb_core']:Notify(source, { message = '...', type = 'success', duration = 5000 })

local function notifyPlayer(source, data)
    TriggerClientEvent('nb_core:notify', source, data)
end

exports('Notify', notifyPlayer)
