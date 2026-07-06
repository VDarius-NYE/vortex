Config = Config or {}

-- Melyik nb_group szint kell az egyes parancsokhoz/funkciókhoz (hierarchikus,
-- tehát pl. egy 'support' szintű parancsot admin/owner is tud használni).
Config.Permissions = {
    panel = 'support',
    tp = 'support',
    bring = 'support',
    revive = 'support',
    heal = 'support',
    kick = 'support',
    noclip = 'admin',
    announce = 'admin',
    ban = 'admin',
    unban = 'admin',
    car = 'admin',
    godmode = 'admin',
    duty = 'support',
    viewDetails = 'support',
    warn = 'support',
    setarmor = 'support',
    -- a warn törlése mindig csak owner-nek (nincs külön kulcs, direkt owner-ellenőrzés történik)
}

Config.PanelKeyMapping = 'F4'

Config.DefaultVehicleModel = 'ARMY1' -- /car parancs paraméter nélkül ezt spawnolja (Vortex Military hangulat)
