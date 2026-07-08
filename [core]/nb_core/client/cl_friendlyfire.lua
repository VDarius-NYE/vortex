-- A FiveM friss/alap session-ökben a játékosok közti sebzés (PvP) ALAPBÓL
-- KI van kapcsolva, amíg egy script explicit be nem kapcsolja - ez teljesen
-- független bármilyen zónától/ghost course-tól. Enélkül senki nem tud
-- senkit megsebezni, sehol a mapon.

CreateThread(function()
    while true do
        NetworkSetFriendlyFireOption(true)
        Wait(5000)
    end
end)
