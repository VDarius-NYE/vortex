NB = NB or {}
NB.Players = NB.Players or {}

Config = {}

Config.ServerName = 'VORTEX MILITARY'

-- Elsődleges identifier típus, amivel a rendszer azonosítja a játékost.
-- Fallback sorrend, ha az elsődleges nem elérhető (pl. license hiányzik, ami ritka).
Config.PrimaryIdentifier = 'license'
Config.IdentifierFallbackOrder = { 'license', 'license2', 'discord', 'steam', 'fivem' }

-- Alapértelmezett spawn koordináta (military bázis bejárat, később módosítható)
Config.DefaultSpawn = {
    x = -1035.71, y = -2731.87, z = 20.17, heading = 330.0
}

-- Ide kerül a player regisztráció/login alatt (magasan az ég felett, hogy ne
-- lásson bele a világba, és ne eshessen le, amíg be van fagyasztva)
Config.LimboCoords = {
    x = 0.0, y = 0.0, z = 1000.0
}

-- Alap freemode modellek amiket a karakterkészítő enged
Config.AllowedModels = {
    male = 'mp_m_freemode_01',
    female = 'mp_f_freemode_01'
}

-- Debug print-ek engedélyezése konzolon
Config.Debug = true

function NB.Debug(msg)
    if Config.Debug then
        print(('^3[nb_core]^7 %s'):format(msg))
    end
end
