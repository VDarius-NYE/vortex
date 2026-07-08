-- A killfeed NUI mindig aktív (nincs SetNuiFocus, nem interaktív felület),
-- csak a szerver eseményeit továbbítja a HTML/JS felé.

RegisterNetEvent('nb_killfeed:add', function(data)
    SendNUIMessage({ action = 'add', data = data })
end)

RegisterNetEvent('nb_killfeed:updatePosition', function(pos)
    SendNUIMessage({ action = 'updatePosition', pos = pos })
end)
