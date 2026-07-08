-- ============================================================
-- ITEM REGISZTER (nem fegyver itemek)
-- ============================================================
-- weight: kg / darab
-- stackable + maxStack: hány db fér egy slotba
-- usable: van-e "Használat" gomb
-- type: 'item' | 'ammo' | 'money'
-- effect: mi történik "Használat"-kor
--
-- A kép: assets/items/{item_kulcs}.png (kisbetűvel keresi a UI). Ha nincs
-- kép, a megadott FontAwesome `icon` a tartalék.
Config.Items = {
    cash = {
        label = 'Készpénz', weight = 0, stackable = true, maxStack = 999999,
        usable = false, type = 'money', icon = 'fa-solid fa-money-bill-wave'
    },
    water_bottle = {
        label = 'Vizes palack', weight = 0.5, stackable = true, maxStack = 10,
        usable = true, type = 'item', icon = 'fa-solid fa-bottle-water',
        effect = { kind = 'thirst', amount = 40 },
        progressBar = { label = 'Víz elfogyasztása', duration = 3000 }
    },
    bread = {
        label = 'Kenyér', weight = 0.3, stackable = true, maxStack = 10,
        usable = true, type = 'item', icon = 'fa-solid fa-bread-slice',
        effect = { kind = 'hunger', amount = 35 },
        progressBar = { label = 'Kenyér elfogyasztása', duration = 5000 }
    },
    bandage = {
        label = 'Kötszer', weight = 0.2, stackable = true, maxStack = 20,
        usable = true, type = 'item', icon = 'fa-solid fa-suitcase-medical',
        effect = { kind = 'health', amount = 25 },
        progressBar = { label = 'Sebek ellátása', duration = 4000 }
    },

    -- Lőszerek - a fegyverek ezeket használják (lásd weapons.lua ammoItem mező)
    ammo_9 = {
        label = '9mm lőszer', weight = 0.015, stackable = true, maxStack = 250,
        usable = false, type = 'ammo', icon = 'fa-solid fa-bullets'
    },
    ammo_rifle = {
        label = '5.56mm lőszer', weight = 0.02, stackable = true, maxStack = 250,
        usable = false, type = 'ammo', icon = 'fa-solid fa-bullets'
    },
}
