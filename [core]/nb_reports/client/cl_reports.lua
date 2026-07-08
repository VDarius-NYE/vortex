-- F3 (player report form) és F1 (admin panel) billentyűk, NUI életciklus,
-- freeze kezelés az admin gyors-akcióhoz.
--
-- FONTOS: a chat ablak NEM tart folyamatos NUI fókuszt (a form/panel igen,
-- azok rövid életű modálisok) - a chat mellett tovább lehet mozogni/
-- játszani, és az [ALT] gombbal lehet elő-/eltüntetni az egeret, amikor
-- épp írni/kattintani szeretnél benne.

local formOpen = false
local panelOpen = false
local chatOpen = false
local chatFocused = false

local function updateFocus()
    if formOpen or panelOpen then
        SetNuiFocus(true, true)
    elseif chatOpen and chatFocused then
        SetNuiFocus(true, true)
    else
        SetNuiFocus(false, false)
    end
end

-- ============================================================
-- F3 - Player report form
-- ============================================================
RegisterCommand('openreportform', function()
    if chatOpen then
        exports['nb_core']:Notify({ message = 'Már van aktív reportod - előbb azt kell lezárnia egy adminnak.', type = 'warning' })
        return
    end
    if formOpen then return end

    formOpen = true
    updateFocus()
    SendNUIMessage({ action = 'openForm' })
end, false)

RegisterKeyMapping('openreportform', 'Report form megnyitása', 'keyboard', Config.PlayerOpenKey)

-- ============================================================
-- F1 - Admin panel
-- ============================================================
RegisterCommand('openreportpanel', function()
    if panelOpen then
        panelOpen = false
        SendNUIMessage({ action = 'closePanel' })
        updateFocus()
        return
    end

    TriggerServerEvent('nb_reports:requestList')
end, false)

RegisterKeyMapping('openreportpanel', 'Report admin panel megnyitása', 'keyboard', Config.AdminPanelKey)

RegisterNetEvent('nb_reports:openPanel', function(list)
    panelOpen = true
    updateFocus()
    SendNUIMessage({ action = 'openPanel', reports = list })
end)

RegisterNetEvent('nb_reports:listUpdate', function(list)
    SendNUIMessage({ action = 'updateList', reports = list })
end)

-- ============================================================
-- Chat ablak (player oldal) - NEM kap automatikus fókuszt, [ALT]-tal
-- kapcsolható be/ki (lásd lentebb).
-- ============================================================
RegisterNetEvent('nb_reports:openChat', function(data)
    formOpen = false
    chatOpen = true
    chatFocused = false
    updateFocus()
    SendNUIMessage({ action = 'openChat', report = data })
end)

RegisterNetEvent('nb_reports:chatClosed', function(reportId)
    chatOpen = false
    chatFocused = false
    SendNUIMessage({ action = 'closeChat', reportId = reportId })
    updateFocus()
end)

RegisterNetEvent('nb_reports:statusUpdate', function(reportId, status, claimedByName)
    SendNUIMessage({ action = 'statusUpdate', reportId = reportId, status = status, claimedByName = claimedByName })
end)

-- ============================================================
-- Admin chat ablak
-- ============================================================
RegisterNetEvent('nb_reports:openAdminChat', function(data)
    panelOpen = false
    chatOpen = true
    chatFocused = false
    updateFocus()
    SendNUIMessage({ action = 'openChat', report = data })
end)

-- ============================================================
-- Közös - üzenetek / rendszerüzenetek
-- ============================================================
RegisterNetEvent('nb_reports:newMessage', function(reportId, msg)
    SendNUIMessage({ action = 'newMessage', reportId = reportId, message = msg })
end)

RegisterNetEvent('nb_reports:systemMessage', function(reportId, text)
    SendNUIMessage({ action = 'systemMessage', reportId = reportId, text = text })
end)

-- ============================================================
-- NUI callback-ek
-- ============================================================
RegisterNUICallback('closeForm', function(data, cb)
    formOpen = false
    updateFocus()
    cb('ok')
end)

RegisterNUICallback('submitReport', function(data, cb)
    TriggerServerEvent('nb_reports:submit', data.category, data.title, data.description)
    cb('ok')
end)

RegisterNUICallback('closePanel', function(data, cb)
    panelOpen = false
    updateFocus()
    cb('ok')
end)

RegisterNUICallback('claimReport', function(data, cb)
    TriggerServerEvent('nb_reports:claim', data.reportId)
    cb('ok')
end)

RegisterNUICallback('closeReport', function(data, cb)
    TriggerServerEvent('nb_reports:close', data.reportId)
    cb('ok')
end)

RegisterNUICallback('leaveChat', function(data, cb)
    TriggerServerEvent('nb_reports:leaveChat', data.reportId)
    chatOpen = false
    chatFocused = false
    updateFocus()
    cb('ok')
end)

RegisterNUICallback('sendMessage', function(data, cb)
    TriggerServerEvent('nb_reports:sendMessage', data.reportId, data.text)
    cb('ok')
end)

RegisterNUICallback('adminAction', function(data, cb)
    TriggerServerEvent('nb_reports:adminAction', data.reportId, data.action)
    cb('ok')
end)

CreateThread(function()
    while true do
        Wait(0)
        if formOpen or panelOpen then
            if IsControlJustPressed(0, 322) then -- ESC
                if formOpen then
                    formOpen = false
                    SendNUIMessage({ action = 'closeForm' })
                end
                if panelOpen then
                    panelOpen = false
                    SendNUIMessage({ action = 'closePanel' })
                end
                -- A chat ablakot ESC NEM zárja be (élő beszélgetés, ne
                -- essen ki belőle véletlenül) - csak összecsukható/[ALT]-tal
                -- kikapcsolható a fókusza.
                updateFocus()
            end
        else
            Wait(300)
        end
    end
end)

-- ============================================================
-- [ALT] - a chat ablak egér/fókusz be-/kikapcsolása (amíg nyitva van)
--
-- FONTOS: amint SetNuiFocus(true, true) aktív, a billentyűzet a NUI-hoz
-- (böngészőhöz) kerül, NEM a játékhoz - emiatt a RegisterKeyMapping-es
-- ALT lenyomás csak az ELSŐ (bekapcsoló) váltásnál sül el megbízhatóan
-- (amikor még a JÁTÉKNAK van fókusza). A kikapcsoláshoz a NUI-nak MAGÁNAK
-- kell figyelnie az ALT billentyűt (lásd script.js), és egy callback-kel
-- jeleznie ide.
-- ============================================================
local function toggleChatFocus()
    if not chatOpen then return end
    chatFocused = not chatFocused
    updateFocus()
    SendNUIMessage({ action = 'setChatInteractive', interactive = chatFocused })
end

RegisterCommand('togglereportchatfocus', toggleChatFocus, false)
RegisterKeyMapping('togglereportchatfocus', 'Report chat egér mutatása/elrejtése', 'keyboard', 'LMENU')

RegisterNUICallback('toggleChatFocus', function(data, cb)
    toggleChatFocus()
    cb('ok')
end)

-- ============================================================
-- Freeze/Unfreeze (admin gyors-akció)
-- ============================================================
RegisterNetEvent('nb_reports:setFreeze', function(freeze)
    FreezeEntityPosition(PlayerPedId(), freeze)
end)
