Config = Config or {}

-- Automatikus hierarchia: magasabb szám = több jog. Egy "owner" jogosultság-
-- ellenőrzés mindig igaz lesz "admin"-ra, "support"-ra és "user"-re is, mert
-- a szintje nagyobb vagy egyenlő.
Config.Hierarchy = {
    user = 0,
    support = 1,
    admin = 2,
    owner = 3
}

Config.DefaultGroup = 'user'

-- BOOTSTRAP: mivel a csoportok adatbázisban vannak tárolva és a /setgroup
-- parancs saját magát owner jogosultsághoz köti, KELL legalább egy kezdeti
-- owner, különben soha senki nem tudna owner-t kinevezni. Ide írd be a saját
-- license identifieredet (a szerver konzol logban látod csatlakozáskor, vagy
-- az nb_users táblában). Ez a lista csak akkor számít, amikor egy identifier
-- ELŐSZÖR kerül be az nb_groups táblába - utána már a DB/parancs dönt.
Config.BootstrapOwners = {
    'license:f4d29553122e598ae72020546cc91439ad79a73b',
}
