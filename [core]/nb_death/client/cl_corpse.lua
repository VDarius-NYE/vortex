-- A halott játékosok "hulláját" mindenki más kliense saját maga
-- regisztrálja nb_interact ponttal (a pontok kliensenként lokálisak, ezért
-- mindenkinek külön kell felvennie, aki érzékeli a halált).

RegisterNetEvent('nb_death:corpseDown', function(data)
    -- A saját magunk hulláját nem kell nekünk lootolhatóvá tennünk
    if data.victim == GetPlayerServerId(PlayerId()) then return end

    exports['nb_interact']:AddPoint('nb_death_corpse_' .. data.victim, {
        coords = data.coords,
        label = ('Kifosztás: %s'):format(data.victimName),
        eventName = 'nb_death:lootInteract',
        eventArgs = { data.victim },
        distance = Config.LootInteractDistance,
        interactDistance = Config.LootInteractRange
    })
end)

RegisterNetEvent('nb_death:removeCorpse', function(victimServerId)
    exports['nb_interact']:RemovePoint('nb_death_corpse_' .. victimServerId)
end)

AddEventHandler('nb_death:lootInteract', function(victimServerId)
    TriggerServerEvent('nb_death:requestLoot', victimServerId)
end)
