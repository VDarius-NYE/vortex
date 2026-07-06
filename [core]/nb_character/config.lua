Config = Config or {}

-- A karakterkészítő ugyanabban a magasban lévő "limbo" zónában zajlik, mint a
-- login/regisztráció, csak közelebbi kamerával és látható peddel.
Config.CreatorCoords = {
    x = 0.0, y = 0.0, z = 1000.0, heading = 180.0
}

Config.DefaultModel = 'mp_m_freemode_01'

-- Melyik ruházati komponens-slotokat engedjük szerkeszteni (GTA V standard indexek)
-- 0=arc(nem szerk.) 1=maszk 2=haj(külön kezelve) 3=felsőtest(alsó réteg) 4=láb
-- 5=táska/kéztáska 6=cipő 7=nyak/sál 8=felsőtest(alap póló) 9=testpáncél/extra
-- 10=jelmez extra 11=felsőruha
Config.ClothingComponents = { 3, 4, 5, 6, 7, 8, 9, 10, 11 }

-- Kiegészítő (prop) slotok: 0=kalap 1=szemüveg 2=fülbevaló 6=óra 7=karkötő
Config.PropSlots = { 0, 1, 2, 6, 7 }

-- Head overlay indexek (GTA V standard) - amiket a UI-n megjelenítünk
Config.HeadOverlays = {
    { id = 0,  name = 'Foltok/Hegek',        hasColor = false },
    { id = 1,  name = 'Szakáll',              hasColor = true  },
    { id = 2,  name = 'Szemöldök',            hasColor = true  },
    { id = 3,  name = 'Öregedés',             hasColor = false },
    { id = 4,  name = 'Smink',                hasColor = true  },
    { id = 5,  name = 'Pirosító',             hasColor = true  },
    { id = 6,  name = 'Bőrtónus (komplexió)', hasColor = false },
    { id = 7,  name = 'Napégés',              hasColor = false },
    { id = 8,  name = 'Rúzs',                 hasColor = true  },
    { id = 9,  name = 'Szeplők/Anyajegyek',   hasColor = false },
    { id = 10, name = 'Mellszőrzet',          hasColor = true  },
    { id = 11, name = 'Testfoltok',           hasColor = false },
}

Config.FaceFeatureCount = 20
