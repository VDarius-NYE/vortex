Config = Config or {}

Config.PlayerSlots = 40        -- az első 5 slot egyben a hotbar (1-5 gombbal használható)
Config.HotbarSlots = 5
Config.MaxWeight = 50.0        -- kg

Config.DefaultStashModel = 'prop_box_wood01a'

-- Fegyver serial: alapértelmezett előtag, később frakciónként felülírható
-- (pl. HUN, RUS) egy jövőbeli nb_factions hook-on keresztül.
Config.DefaultSerialPrefix = 'VM'

-- ============================================================
-- ITEM REGISZTER
-- ============================================================
-- weight: kg / darab
-- stackable + maxStack: hány db fér egy slotba
-- usable: van-e "Használat" gomb
-- type: 'item' | 'weapon' | 'ammo' | 'money'
-- effect: mi történik "Használat"-kor (item eltűnik utána, ha nem 'weapon')
Config.Items = {
    cash = {
        label = 'Készpénz', weight = 0, stackable = true, maxStack = 999999,
        usable = false, type = 'money', icon = 'fa-solid fa-money-bill-wave'
    },
    water_bottle = {
        label = 'Vizes palack', weight = 0.5, stackable = true, maxStack = 10,
        usable = true, type = 'item', icon = 'fa-solid fa-bottle-water',
        effect = { kind = 'thirst', amount = 40 }
    },
    bread = {
        label = 'Kenyér', weight = 0.3, stackable = true, maxStack = 10,
        usable = true, type = 'item', icon = 'fa-solid fa-bread-slice',
        effect = { kind = 'hunger', amount = 35 }
    },
    bandage = {
        label = 'Kötszer', weight = 0.2, stackable = true, maxStack = 20,
        usable = true, type = 'item', icon = 'fa-solid fa-suitcase-medical',
        effect = { kind = 'health', amount = 25 }
    },
    weapon_pistol = {
        label = 'Pisztoly', weight = 1.2, stackable = false,
        usable = true, type = 'weapon', icon = 'fa-solid fa-gun',
        weaponHash = 'WEAPON_PISTOL', hasDurability = true, hasSerial = true
    },
    weapon_knife = {
        label = 'Kés', weight = 0.4, stackable = false,
        usable = true, type = 'weapon', icon = 'fa-solid fa-knife',
        weaponHash = 'WEAPON_KNIFE', hasDurability = true, hasSerial = true
    },
    ammo_pistol = {
        label = 'Pisztoly lőszer', weight = 0.02, stackable = true, maxStack = 250,
        usable = false, type = 'ammo', icon = 'fa-solid fa-bullets'
    },
}
