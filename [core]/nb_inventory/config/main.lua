Config = Config or {}

Config.PlayerSlots = 25        -- 5x5 standard, az első 5 (első sor) egyben a hotbar
Config.HotbarSlots = 5
Config.GridColumns = 5         -- ennyi oszlopos a rács (görgetés csak függőlegesen van)
Config.MaxWeight = 50.0        -- kg

Config.DefaultStashModel = 'prop_ld_int_safe_01'
Config.GroundStashModel = 'prop_cs_heist_bag_01'
Config.DefaultStashSlots = 50
Config.DefaultStashWeight = 100.0

-- Fegyver serial: alapértelmezett előtag, később frakciónként felülírható
-- (pl. HUN, RUS) egy jövőbeli nb_factions hook-on keresztül.
Config.DefaultSerialPrefix = 'VM'
