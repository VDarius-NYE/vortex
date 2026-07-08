-- Zóna blipek a térképen: egyszerű pont-blip típusonkénti színnel és
-- felirattal (a kör alakú "radius blip" eltávolítva - felesleges volt,
-- mivel a pontos alakot úgyis a világban látható körvonal mutatja).

local activeBlips = {} -- [zoneId] = blip handle

local blipColors = {
    safe = 2,     -- zöld
    faction = 5,  -- sárga
    danger = 1,   -- piros
    admin = 27,   -- lila
}

local blipLabels = {
    safe = 'Biztonságos zóna',
    faction = 'Frakció zóna',
    danger = 'Veszélyes zóna',
    admin = 'Admin zóna',
}

local function clearAllBlips()
    for _, blip in pairs(activeBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    activeBlips = {}
end

RegisterNetEvent('nb_zones:syncZones', function(zoneList)
    clearAllBlips()

    for _, zone in ipairs(zoneList) do
        local cx, cy = NBZone.Centroid(zone.points)

        local blip = AddBlipForCoord(cx, cy, 0.0)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, blipColors[zone.type] or 2)
        SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(blipLabels[zone.type] or 'Zóna')
        EndTextCommandSetBlipName(blip)

        activeBlips[zone.id] = blip
    end
end)
