Config = Config or {}

Config.DefaultFactionId = 0 -- mindenki ebbe kerül alapból

Config.NpcTagPrefix = '[NPC]'   -- ez lesz a tag eleje minden shop/garázs NPC felett
Config.NpcTagDistance = 15.0    -- ennyi méterről látszik a névtábla
Config.NpcInteractDistance = 2.0

-- ============================================================
-- FRAKCIÓK
-- ============================================================
-- Minden frakciónak lehet TÖBB item shopja, weapon shopja, vehicle shopja,
-- ÉS legalább egy garázs NPC-je (a saját járművei lehívásához).
--
-- shop item ár: 0 = "Ingyenes" felirat az árhely helyén.
-- coords formátuma: vector4(x, y, z, heading) - ÁLLÍTSD BE A SAJÁT
-- TÉRKÉPEDNEK MEGFELELŐEN, ezek csak helykitöltő értékek!
Config.Factions = {
    [0] = {
        name = 'Nomad', -- alap frakció, mindenki ide kerül belépéskor
        serialPrefix = 'NOM', -- az innen vett fegyverek serialja ezzel az előtaggal generálódik
        -- Akinek nincs frakciója (mindenki alapból), ide spawnol be - EZ A
        -- SAFEZONE KOORDINÁTÁJA legyen (lásd nb_zones), hogy védett helyen
        -- kezdjen mindenki, ne a reptéren.
        spawnCoords = vector4(215.0, -800.0, 30.7, 160.0),

        itemShops = {
            {
                npcName = 'Mindenes Joe',
                model = 'a_m_m_business_01',
                coords = vector4(215.0, -810.0, 30.7, 160.0),
                items = {
                    { item = 'water_bottle', price = 50 },
                    { item = 'bread', price = 40 },
                    { item = 'bandage', price = 120 },
                }
            }
        },

        weaponShops = {
            {
                npcName = 'Fegyveres Misi',
                model = 'g_m_y_lost_01',
                coords = vector4(225.0, -815.0, 30.7, 160.0),
                items = {
                    { item = 'WEAPON_PISTOL', price = 5000 },
                    { item = 'WEAPON_KNIFE', price = 800 },
                    { item = 'ammo_9', price = 25 },
                }
            }
        },

        vehicleShops = {
            {
                npcName = 'Kereskedő Bácsi',
                model = 'a_m_m_farmer_01',
                coords = vector4(235.0, -820.0, 30.7, 160.0),
                vehicles = {
                    { model = 'ARMY1', label = 'Katonai teherautó', price = 0 },
                }
            },
            {
                -- Légi jármű shop (heli + repülő egyben) - FONTOS: a
                -- helikoptereknek/repülőknek SAJÁT spawnCoords-ot adtunk
                -- (helipad/kifutó), mert nekik fel kell tudni szállniuk,
                -- nem ugyanoda spawnolhatnak mint a földi járművek. Ha
                -- egy jármű bejegyzésnél NINCS spawnCoords, a garázs
                -- alap spawnCoords-ára esik vissza.
                npcName = 'HelicopterShop',
                model = 'a_m_m_business_01',
                coords = vector4(245.0, -790.0, 30.7, 160.0),
                vehicles = {
                    { model = 'MAVERICK', label = 'Maverick helikopter', price = 350000, spawnCoords = vector4(200.0, -900.0, 45.0, 0.0) },
                }
            },
            {
                npcName = 'PlaneShop',
                model = 'a_m_m_business_01',
                coords = vector4(255.0, -790.0, 30.7, 160.0),
                vehicles = {
                    { model = 'VELUM', label = 'Velum vadászgép', price = 500000, spawnCoords = vector4(-1000.0, -2900.0, 13.9, 320.0) },
                }
            }
        },

        garages = {
            {
                npcName = 'Garázs Matyi',
                model = 'a_m_m_hillbilly_01',
                coords = vector4(245.0, -825.0, 30.7, 160.0),
                spawnCoords = vector4(248.0, -830.0, 30.5, 160.0) -- ide spawnol a lehívott jármű
            }
        }
    },

    [1] = {
        name = 'ISIS', -- alap frakció, mindenki ide kerül belépéskor
        serialPrefix = 'IS', -- az innen vett fegyverek serialja ezzel az előtaggal generálódik
        -- Akinek nincs frakciója (mindenki alapból), ide spawnol be - EZ A
        -- SAFEZONE KOORDINÁTÁJA legyen (lásd nb_zones), hogy védett helyen
        -- kezdjen mindenki, ne a reptéren.
        spawnCoords = vector4(2496.4314, 4969.2183, 44.5895, 133.1782),

        itemShops = {
            {
                npcName = 'Mindenes Joe',
                model = 'a_m_m_business_01',
                coords = vector4(2495.2336, 4965.4058, 44.6021, 47.1365),
                items = {
                    { item = 'water_bottle', price = 50 },
                    { item = 'bread', price = 40 },
                    { item = 'bandage', price = 120 },
                }
            }
        },

        weaponShops = {
            {
                npcName = 'Fegyveres Misi',
                model = 'g_m_y_lost_01',
                coords = vector4(2492.3755, 4968.5005, 44.6481, 220.6420),
                items = {
                    { item = 'WEAPON_PISTOL', price = 5000 },
                    { item = 'WEAPON_KNIFE', price = 800 },
                    { item = 'ammo_9', price = 25 },
                }
            }
        },

        vehicleShops = {
            {
                npcName = 'Kereskedő Bácsi',
                model = 'a_m_m_farmer_01',
                coords = vector4(2492.0688, 4961.8271, 44.6305, 49.5378),
                vehicles = {
                    { model = 'ARMY1', label = 'Katonai teherautó', price = 0 },
                }
            },
            {
                -- Légi jármű shop (heli + repülő egyben) - FONTOS: a
                -- helikoptereknek/repülőknek SAJÁT spawnCoords-ot adtunk
                -- (helipad/kifutó), mert nekik fel kell tudni szállniuk,
                -- nem ugyanoda spawnolhatnak mint a földi járművek. Ha
                -- egy jármű bejegyzésnél NINCS spawnCoords, a garázs
                -- alap spawnCoords-ára esik vissza.
                npcName = 'HelicopterShop',
                model = 'a_m_m_business_01',
                coords = vector4(2437.1260, 4907.9917, 59.8365, 46.9874),
                vehicles = {
                    { model = 'MAVERICK', label = 'Maverick helikopter', price = 350000, spawnCoords = vector4(2429.2578, 4912.2446, 59.7174, 226.1517) },
                }
            },
            {
                npcName = 'PlaneShop',
                model = 'a_m_m_business_01',
                coords = vector4(2430.9373, 4898.6074, 57.9077, 231.5729),
                vehicles = {
                    { model = 'lazer', label = 'Vadaszgep', price = 500000, spawnCoords = vector4(2432.3579, 4894.1245, 57.8982, 133.6302) },
                }
            }
        },

        garages = {
            {
                npcName = 'Garázs Matyi',
                model = 'a_m_m_hillbilly_01',
                coords = vector4(2483.9973, 4959.6572, 44.8512, 219.9224),
                spawnCoords = vector4(2481.2146, 4954.7329, 44.9981, 136.7763) -- ide spawnol a lehívott jármű
            }
        }
    },

    --[[ Példa egy jövőbeli frakcióra - csak másold a fenti mintát:
    [1] = {
        name = 'HUN',
        serialPrefix = 'HUN',
        spawnCoords = vector4(x, y, z, heading), -- a HUN tagok ide spawnolnak
        itemShops = { ... },
        weaponShops = { ... },
        vehicleShops = { ... },
        garages = { ... }
    },
    ]]
}
