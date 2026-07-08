-- A zóna körvonalai a világban (nem a térképen) - mindenki látja, ha elég
-- közel van hozzá. "Kerítés"-szerű hatás: alsó + felső vonal + függőleges
-- sarok-vonalak, típus szerinti színnel.
--
-- FONTOS: a sarokpontok magassága a TEREPHEZ van rögzítve (egyszer
-- kiszámolva és gyorsítótárazva sarokpontonként), NEM a player aktuális
-- magasságához - így nem "úszik" fel-le a jelző, ahogy a player dombon/
-- lépcsőn mozog.

local zones = {}

local RENDER_DISTANCE = 100.0
local WALL_HEIGHT = 3.0

local typeColors = {
    safe = { 80, 180, 255 },
    faction = { 220, 180, 60 },
    danger = { 220, 60, 60 },
    admin = { 160, 70, 220 },
}

RegisterNetEvent('nb_zones:syncZones', function(zoneList)
    zones = zoneList
    for _, zone in ipairs(zones) do
        zone.groundZ = {} -- új lista -> friss gyorsítótár
    end
end)

--- Egy adott sarokpont talajmagasságát adja vissza, gyorsítótárazva (csak
--- egyszer számolja ki zónánként/sarkonként, utána mindig ugyanazt adja).
local function getPointGroundZ(zone, index, point)
    if zone.groundZ[index] then return zone.groundZ[index] end

    local found, groundZ = GetGroundZFor_3dCoord(point.x + 0.0, point.y + 0.0, 1000.0, false)
    local z = found and groundZ or (GetEntityCoords(PlayerPedId()).z - 1.0)

    zone.groundZ[index] = z
    return z
end

CreateThread(function()
    while true do
        Wait(0)

        local coords = GetEntityCoords(PlayerPedId())

        for _, zone in ipairs(zones) do
            local cx, cy = NBZone.Centroid(zone.points)
            local dist = #(vector2(coords.x, coords.y) - vector2(cx, cy))

            if dist <= RENDER_DISTANCE then
                local color = typeColors[zone.type] or { 255, 255, 255 }
                local n = #zone.points

                for i = 1, n do
                    local i2 = (i % n) + 1
                    local p1 = zone.points[i]
                    local p2 = zone.points[i2]

                    local z1 = getPointGroundZ(zone, i, p1)
                    local z2 = getPointGroundZ(zone, i2, p2)

                    -- alsó (talaj-szintű) vonal - követi a terepet, mert
                    -- sarkonként a SAJÁT (rögzített) talajmagasságát használja
                    DrawLine(p1.x, p1.y, z1, p2.x, p2.y, z2, color[1], color[2], color[3], 220)
                    -- felső vonal - ettől néz ki "kerítésnek"
                    DrawLine(p1.x, p1.y, z1 + WALL_HEIGHT, p2.x, p2.y, z2 + WALL_HEIGHT, color[1], color[2], color[3], 140)
                    -- függőleges sarok-vonal
                    DrawLine(p1.x, p1.y, z1, p1.x, p1.y, z1 + WALL_HEIGHT, color[1], color[2], color[3], 100)
                end
            end
        end
    end
end)
