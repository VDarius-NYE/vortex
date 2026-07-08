-- Univerzális 3D interakciós pont rendszer. Bármelyik resource regisztrálhat
-- egy pontot (pl. stash, item pickup, NPC), ami zöld pontként látszik
-- távolról, közelről pedig egy négyzetté vált a gomb feliratával.
--
-- FONTOS: mivel resource-ok között nem adható át Lua függvény (csak plain
-- adat), a callback egy EVENT NÉV + argumentum lista - amikor a player
-- interaktál, ezt az eventet triggereljük lokálisan (TriggerEvent).

local points = {} -- [id] = { coords={x,y,z}, label, eventName, eventArgs, distance, interactDistance, key }

local function addPoint(id, data)
    data.distance = data.distance or 10.0
    data.interactDistance = data.interactDistance or 1.5
    data.key = data.key or 38 -- E
    points[id] = data
end

local function removePoint(id)
    points[id] = nil
end

exports('AddPoint', addPoint)
exports('RemovePoint', removePoint)

CreateThread(function()
    while true do
        Wait(0)

        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local visible = {}
        local nearestId, nearestDist = nil, 999999.0

        for id, p in pairs(points) do
            local dist = #(pedCoords - vector3(p.coords.x, p.coords.y, p.coords.z))
            if dist <= p.distance then
                local onScreen, sx, sy = GetScreenCoordFromWorldCoord(p.coords.x, p.coords.y, p.coords.z)
                if onScreen then
                    local near = dist <= p.interactDistance
                    visible[#visible + 1] = { id = tostring(id), x = sx, y = sy, near = near, label = p.label or '' }

                    if near and dist < nearestDist then
                        nearestDist = dist
                        nearestId = id
                    end
                end
            end
        end

        SendNUIMessage({ action = 'update', points = visible })

        if nearestId and IsControlJustPressed(0, points[nearestId].key) then
            local p = points[nearestId]
            TriggerEvent(p.eventName, table.unpack(p.eventArgs or {}))
        end
    end
end)
