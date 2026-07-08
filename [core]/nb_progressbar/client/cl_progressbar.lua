-- Univerzális progress bar. Más resource-ok így hívhatják (a hívás
-- BLOKKOL, amíg a bár le nem fut vagy meg nem szakad - ez a FiveM export +
-- promise mechanizmusa miatt működik ilyen "szinkron" módon):
--
--   local finished = exports['nb_progressbar']:Start({
--       label = 'Kenyér elfogyasztása',
--       duration = 5000,       -- ms
--       canCancel = true       -- ESC-cel megszakítható-e (alapértelmezett: true)
--   })
--   if finished then ... végrehajtjuk a hatást ... end

local active = false

local function start(data)
    if active then return false end -- ne fusson egyszerre kettő
    active = true

    local duration = tonumber(data.duration) or 3000
    local label = data.label or ''
    local canCancel = data.canCancel
    if canCancel == nil then canCancel = true end

    SendNUIMessage({ action = 'start', label = label, duration = duration })

    local p = promise.new()

    CreateThread(function()
        local cancelled = false
        local startTime = GetGameTimer()

        while GetGameTimer() - startTime < duration do
            Wait(0)

            -- Mozgás/ütés/lövés/belépés letiltása, amíg fut a bár
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 21, true)  -- Sprint
            DisableControlAction(0, 22, true)  -- Jump
            DisableControlAction(0, 23, true)  -- Enter vehicle

            if canCancel and IsControlJustPressed(0, 322) then -- ESC
                cancelled = true
                break
            end
        end

        SendNUIMessage({ action = 'stop', cancelled = cancelled })
        active = false
        p:resolve(not cancelled)
    end)

    return Citizen.Await(p)
end

exports('Start', start)
