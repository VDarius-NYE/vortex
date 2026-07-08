Config = Config or {}

Config.EditHudKeyMapping = 'F9' -- gyors billentyű az /edithud parancshoz

-- Alapértelmezett HUD beállítások - ezt kapja meg minden új account, és erre
-- lehet visszaállítani az "Alaphelyzet" gombbal az /edithud szerkesztőben.
Config.DefaultSettings = {
    style = 'radial', -- 'bar' | 'radial' | 'numeric' - CSAK a 'vital' kategóriájú elemekre vonatkozik
    elements = {
        -- "Vital" elemek (3 stílus közül választható, küszöb-alapú láthatóság)
        health  = { xPercent = 1.3203125,  yPercent = 76.81944444444446, alwaysVisible = true, threshold = 100 },
        armor   = { xPercent = 4.0546875,  yPercent = 76.81944444444444, alwaysVisible = true, threshold = 100 },
        hunger  = { xPercent = 9.6015625,  yPercent = 76.81944444444444, alwaysVisible = true, threshold = 80 },
        thirst  = { xPercent = 12.453125,  yPercent = 76.88888888888889, alwaysVisible = true, threshold = 80 },
        stamina = { xPercent = 6.7890625,  yPercent = 76.81944444444444, alwaysVisible = true, threshold = 90 },

        -- "Info" elemek (mindig egyfajta "csík" kinézet, csak be/kikapcsolható,
        -- nincs küszöb-alapú láthatóság, mert nem százalékos értékek)
        cash     = { xPercent = 16.5625,   yPercent = 79.66666666666667,   alwaysVisible = true },
        bank     = { xPercent = 16.5625,   yPercent = 82.72222222222223,   alwaysVisible = true },
        faction  = { xPercent = 16.5625,   yPercent = 85.77777777777779,   alwaysVisible = true },
        kills    = { xPercent = 16.5625,   yPercent = 88.7638888888889,    alwaysVisible = true },
        deaths   = { xPercent = 16.5625,   yPercent = 91.75,               alwaysVisible = true },
        kd       = { xPercent = 16.5703125, yPercent = 94.73611111111112,  alwaysVisible = true },
        playtime = { xPercent = 16.5703125, yPercent = 97.72222222222224,  alwaysVisible = true },

        -- Killfeed - csak pozíció + be/ki, a tényleges tartalmat az
        -- nb_killfeed resource rajzolja ki (ez itt csak a helyfoglaló doboz
        -- a szerkesztőben, hogy be lehessen állítani hova kerüljön).
        killfeed = { xPercent = 86.59375, yPercent = 6.12499999999998, alwaysVisible = true },
    }
}

-- Elemek megjelenítési sorrendje/neve/ikonja (FontAwesome class-ok).
-- category = 'vital' (3 stílus, küszöb-láthatóság) | 'info' (mindig "csík", egyszerű be/ki)
--            | 'killfeed' (csak pozíció/be-ki, a tartalmat más resource rajzolja)
-- format: hogyan formázzuk a nyers értéket megjelenítéskor (csak info elemeknél számít)
Config.ElementDefs = {
    { key = 'health',  label = 'Életerő',    icon = 'fa-solid fa-heart-pulse',    category = 'vital' },
    { key = 'armor',   label = 'Páncél',     icon = 'fa-solid fa-shield-halved',  category = 'vital' },
    { key = 'hunger',  label = 'Éhség',      icon = 'fa-solid fa-drumstick-bite', category = 'vital' },
    { key = 'thirst',  label = 'Szomjúság',  icon = 'fa-solid fa-droplet',        category = 'vital' },
    { key = 'stamina', label = 'Stamina',    icon = 'fa-solid fa-bolt',           category = 'vital' },

    { key = 'cash',     label = 'Készpénz',        icon = 'fa-solid fa-money-bill-wave',   category = 'info', format = 'currency' },
    { key = 'bank',     label = 'Banki egyenleg',  icon = 'fa-solid fa-building-columns',   category = 'info', format = 'currency' },
    { key = 'faction',  label = 'Frakció',         icon = 'fa-solid fa-flag',              category = 'info', format = 'text' },
    { key = 'kills',    label = 'Kills',           icon = 'fa-solid fa-crosshairs',         category = 'info', format = 'number' },
    { key = 'deaths',   label = 'Deaths',          icon = 'fa-solid fa-skull',              category = 'info', format = 'number' },
    { key = 'kd',       label = 'K/D arány',       icon = 'fa-solid fa-chart-line',         category = 'info', format = 'text' },
    { key = 'playtime', label = 'Játékidő',        icon = 'fa-solid fa-clock',              category = 'info', format = 'duration' },

    { key = 'killfeed', label = 'Killfeed', icon = 'fa-solid fa-skull-crossbones', category = 'killfeed' },
}
