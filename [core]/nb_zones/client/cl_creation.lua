-- Zóna létrehozás közbeni vizuális segítség: jelölők a lerakott sarkoknál +
-- vonalak a sarkok között, hogy lássa az owner mit rajzol ki.

local creating = false
local creationType = nil
local points = {} -- { {x,y}, ... }

local typeColors = {
    safe = { 80, 180, 255 },
    faction = { 220, 180, 60 },
    danger = { 220, 60, 60 },
}

RegisterNetEvent('nb_zones:startCreation', function(zoneType)
    creating = true
    creationType = zoneType
    points = {}
end)

RegisterNetEvent('nb_zones:pointAdded', function(newPoints)
    points = newPoints
end)

RegisterNetEvent('nb_zones:endCreation', function()
    creating = false
    points = {}
end)

CreateThread(function()
    while true do
        if creating then
            Wait(0)

            local color = typeColors[creationType] or { 255, 255, 255 }
            local ped = PlayerPedId()
            local groundZ = GetEntityCoords(ped).z - 1.0

            for _, p in ipairs(points) do
                DrawMarker(1, p.x, p.y, groundZ, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 1.0, color[1], color[2], color[3], 150, false, false, 2, false, nil, nil, false)
            end

            for i = 1, #points - 1 do
                DrawLine(points[i].x, points[i].y, groundZ, points[i + 1].x, points[i + 1].y, groundZ, color[1], color[2], color[3], 200)
            end

            if #points >= 3 then
                -- záró vonal az utolsó és az első pont közt, hogy lásd a végleges alakzatot
                DrawLine(points[#points].x, points[#points].y, groundZ, points[1].x, points[1].y, groundZ, color[1], color[2], color[3], 120)
            end

            SetTextComponentFormat('STRING')
            AddTextComponentString(('Zóna létrehozás (%s) - %d sarokpont. /zonepoint hozzáadáshoz, /finishzone lezáráshoz, /cancelzone megszakításhoz.'):format(creationType, #points))
            DisplayHelpTextFromStringLabel(0, 0, 1, -1)
        else
            Wait(500)
        end
    end
end)
