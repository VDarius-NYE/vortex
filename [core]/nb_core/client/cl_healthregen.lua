-- Globálisan letiltjuk a natív GTA életerő-regenerációt mindenkinek - ettől
-- a HP a natív halál-küszöbön (100) is stabilan ott marad, nem kúszik fel
-- magától. Ismétlődő hívás, hátha valami visszaállítaná.

CreateThread(function()
    while true do
        SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0)
        Wait(5000)
    end
end)
