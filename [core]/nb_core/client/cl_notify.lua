-- Notify rendszer - más resource-ok is használhatják:
--   exports['nb_core']:Notify({ message = '...', type = 'success', duration = 5000 })
-- vagy szerverről:
--   exports['nb_core']:Notify(source, { message = '...', type = 'error' })
--
-- Típusok: 'success', 'error', 'warning', 'info'

function NB.Notify(data)
    SendNUIMessage({
        action = 'notify',
        message = data.message or '',
        type = data.type or 'info',
        duration = data.duration or 5000
    })
end

RegisterNetEvent('nb_core:notify', function(data)
    NB.Notify(data)
end)

exports('Notify', NB.Notify)

-- Gyors teszt parancs: /testnotify [type]
RegisterCommand('testnotify', function(source, args)
    local type = args[1] or 'info'
    NB.Notify({
        message = ('Ez egy teszt (%s) értesítés!'):format(type),
        type = type,
        duration = 4000
    })
end, false)
