Config = Config or {}

Config.CheckIntervalMs = 1000  -- ennyi időnként ellenőrizzük melyik zónában van a player
Config.NearbyRadius = 150.0    -- /nearbyzones ennyi méteren belülieket listázza (középpont alapján)
Config.MinZonePoints = 3       -- ennyi saroktól kezdve zárható le egy zóna

-- Zóna típusonként: kell-e "ghost mode" (sebezhetetlenség + ütközés-mentesség)
Config.GhostModeTypes = { safe = true, admin = true, faction = false, danger = false }

-- Zóna Infó szövegek
Config.Messages = {
    safe = 'Jelenleg biztonságos zónában vagy. Amint elhagyod a zónát zéró tolerancia vár rád!',
    danger = 'Jelenleg egy veszélyes zónában vagy, figyelj oda, mert itt nincsenek szabályok!',
    admin = 'Jelenleg egy admin zónában vagy, figyelj oda, itt OOC tartózkodsz, ha ide menekültél azonnal hagyd el a zónát, mert szankcióban részesülhetsz ha nem így teszel. Ha nem tartozol az ügyhöz szintén hagyd el a zónát.',
    faction_member = 'Jelenleg %s zónájában vagy. Nem vagy biztonságban, bármikor megtámadhatnak, vigyázz, szerelkezz fel.',
    faction_nonmember = 'Jelenleg %s zónájában vagy. Ez nem biztonságos zóna, mert nem vagy a frakció tagja.'
}

-- ============================================================
-- Polygon-teszt (ray casting) - SHARED, kliens és szerver is ugyanezt
-- használja, hogy konzisztens legyen a "ki van benn" döntés.
-- ============================================================
NBZone = NBZone or {}

function NBZone.PointInPolygon(px, py, points)
    local inside = false
    local n = #points
    local j = n

    for i = 1, n do
        local xi, yi = points[i].x, points[i].y
        local xj, yj = points[j].x, points[j].y

        if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi + 0.0000001) + xi) then
            inside = not inside
        end
        j = i
    end

    return inside
end

function NBZone.Centroid(points)
    local sx, sy = 0, 0
    for _, p in ipairs(points) do
        sx = sx + p.x
        sy = sy + p.y
    end
    return sx / #points, sy / #points
end
