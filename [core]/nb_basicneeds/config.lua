Config = Config or {}

Config.TickIntervalMs = 10000 -- 10 másodpercenként csökken az érték

Config.HungerDecayDurationMinutes = 180 -- 3 óra alatt megy 100%-ról 0%-ra
Config.ThirstDecayDurationMinutes = 120 -- 2 óra alatt megy 100%-ról 0%-ra

-- Ezeken a küszöbökön (csökkenő sorrendben!) kap egyszeri notify figyelmeztetést
-- a player, amíg vissza nem tölti (evés/ivás) a szintjét e fölé.
Config.WarnThresholds = { 15, 10, 5 }

Config.HungerWarnMessage = 'Éhes vagy, egyél valamit.'
Config.ThirstWarnMessage = 'Szomjazol, igyál valamit.'

Config.SaveIntervalMs = 60000 -- ennyi időnként mentjük DB-be az online playerek értékeit
