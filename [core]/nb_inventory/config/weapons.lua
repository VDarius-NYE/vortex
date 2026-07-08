-- ============================================================
-- FEGYVER REGISZTER
-- ============================================================
-- FONTOS: a kulcsok szándékosan pontosan a natív GTA weapon hash nevek
-- (pl. WEAPON_PISTOL), mert így a /giveitem parancsnál ugyanazt az
-- azonosítót használod, mint amit a GTA natívjai is ismernek
-- (pl. /giveitem 1 WEAPON_ASSAULTRIFLE 1).
--
-- ammoItem: melyik lőszer itemet fogyasztja/tölti be a fegyver
-- magazineSize: legfeljebb ennyi lőszert tölt be egyszerre "Használat"-kor
--   (annyit tölt be, amennyi lőszered VAN, de ennél többet sosem)
Config.Items = Config.Items or {}

Config.Items.WEAPON_PISTOL = {
    label = 'Pisztoly', weight = 1.2, stackable = false,
    usable = true, type = 'weapon', icon = 'fa-solid fa-gun',
    hasDurability = true, hasSerial = true,
    ammoItem = 'ammo_9', magazineSize = 17
}

Config.Items.WEAPON_KNIFE = {
    label = 'Kés', weight = 0.4, stackable = false,
    usable = true, type = 'weapon', icon = 'fa-solid fa-knife',
    hasDurability = true, hasSerial = true
    -- nincs ammoItem - a kés közelharci fegyver, nem igényel lőszert
}

Config.Items.WEAPON_SMG = {
    label = 'Géppisztoly', weight = 2.0, stackable = false,
    usable = true, type = 'weapon', icon = 'fa-solid fa-gun',
    hasDurability = true, hasSerial = true,
    ammoItem = 'ammo_9', magazineSize = 30
}

Config.Items.WEAPON_ASSAULTRIFLE = {
    label = 'Assault Rifle', weight = 3.2, stackable = false,
    usable = true, type = 'weapon', icon = 'fa-solid fa-gun',
    hasDurability = true, hasSerial = true,
    ammoItem = 'ammo_rifle', magazineSize = 30
}
