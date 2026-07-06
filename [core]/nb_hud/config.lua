Config = Config or {}

Config.EditHudKeyMapping = 'F9' -- gyors billentyű az /edithud parancshoz

-- Alapértelmezett HUD beállítások - ezt kapja meg minden új account, és erre
-- lehet visszaállítani az "Alaphelyzet" gombbal az /edithud szerkesztőben.
Config.DefaultSettings = {
    style = 'bar', -- 'bar' | 'radial' | 'numeric'
    elements = {
        health  = { xPercent = 3,  yPercent = 78, alwaysVisible = true,  threshold = 100 },
        armor   = { xPercent = 3,  yPercent = 83, alwaysVisible = false, threshold = 100 },
        hunger  = { xPercent = 3,  yPercent = 88, alwaysVisible = false, threshold = 80 },
        thirst  = { xPercent = 3,  yPercent = 93, alwaysVisible = false, threshold = 80 },
        stamina = { xPercent = 3,  yPercent = 73, alwaysVisible = false, threshold = 90 },
    }
}

-- Elemek megjelenítési sorrendje/neve/ikonja (FontAwesome class-ok)
Config.ElementDefs = {
    { key = 'health',  label = 'Életerő',    icon = 'fa-solid fa-heart-pulse' },
    { key = 'armor',   label = 'Páncél',     icon = 'fa-solid fa-shield-halved' },
    { key = 'hunger',  label = 'Éhség',      icon = 'fa-solid fa-drumstick-bite' },
    { key = 'thirst',  label = 'Szomjúság',  icon = 'fa-solid fa-droplet' },
    { key = 'stamina', label = 'Stamina',    icon = 'fa-solid fa-bolt' },
}
