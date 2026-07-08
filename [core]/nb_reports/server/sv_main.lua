-- Report rendszer: beküldés, admin lista, elfogadás/lezárás/elhagyás,
-- élő kétirányú chat, admin gyors-akció gombok (Revive/Kill/Heal/TP/Bring/
-- Freeze/Unfreeze).

local reports = {} -- [id] = { id, identifier, playerSource, playerName, category, title, description, status, claimedBy, claimedByName, messages={} }
local playerActiveReport = {} -- [source] = reportId

CreateThread(function()
    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS nb_reports (
                id INT AUTO_INCREMENT PRIMARY KEY,
                identifier VARCHAR(64) NOT NULL,
                player_name VARCHAR(50) NOT NULL,
                category VARCHAR(30) NOT NULL,
                title VARCHAR(100) NOT NULL,
                description TEXT NOT NULL,
                status VARCHAR(20) NOT NULL DEFAULT 'open',
                claimed_by_name VARCHAR(50),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                closed_at TIMESTAMP NULL DEFAULT NULL
            )
        ]], {}, function()
            MySQL.query([[
                CREATE TABLE IF NOT EXISTS nb_report_messages (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    report_id INT NOT NULL,
                    sender_type VARCHAR(10) NOT NULL,
                    sender_name VARCHAR(50) NOT NULL,
                    message TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ]], {}, function()
                -- Resource-restart után a "függőben lévő" reportok forrás-
                -- hivatkozásai (playerSource) úgyis érvénytelenek lennének -
                -- lezárjuk őket takarításként.
                MySQL.query("UPDATE nb_reports SET status = 'closed', closed_at = NOW() WHERE status != 'closed'")
                print('^3[nb_reports]^7 nb_reports/nb_report_messages táblák ellenőrizve/létrehozva.')
            end)
        end)
    end)
end)

local function isStaff(source)
    local ok, result = pcall(function() return exports['nb_group']:HasPermission(source, Config.AdminPermission) end)
    return ok and result
end

local function categoryLabel(key)
    for _, c in ipairs(Config.Categories) do
        if c.key == key then return c.label end
    end
    return key
end

-- ============================================================
-- Admin lista broadcast (mindenkinek, aki staff és online)
-- ============================================================
local function broadcastList()
    local list = {}
    for id, r in pairs(reports) do
        if r.status ~= 'closed' then
            list[#list + 1] = {
                id = r.id,
                playerName = r.playerName,
                category = r.category,
                categoryLabel = categoryLabel(r.category),
                title = r.title,
                description = r.description,
                status = r.status,
                claimedByName = r.claimedByName
            }
        end
    end

    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if isStaff(pid) then
            TriggerClientEvent('nb_reports:listUpdate', pid, list)
        end
    end
end

-- ============================================================
-- Beküldés (F3 form "Beküldés" gomb)
-- ============================================================
RegisterNetEvent('nb_reports:submit', function(category, title, description)
    local source = source

    if playerActiveReport[source] then
        exports['nb_core']:Notify(source, { message = 'Már van aktív reportod.', type = 'warning' })
        return
    end

    if not title or title == '' or not description or description == '' then
        exports['nb_core']:Notify(source, { message = 'Töltsd ki a címet és a leírást.', type = 'warning' })
        return
    end

    local playerData = exports['nb_core']:GetPlayerData(source)
    if not playerData then return end

    local playerName = GetPlayerName(source)

    local dbId = MySQL.insert.await('INSERT INTO nb_reports (identifier, player_name, category, title, description) VALUES (?, ?, ?, ?, ?)', {
        playerData.identifier, playerName, category, title, description
    })

    reports[dbId] = {
        id = dbId,
        identifier = playerData.identifier,
        playerSource = source,
        playerName = playerName,
        category = category,
        title = title,
        description = description,
        status = 'open',
        claimedBy = nil,
        claimedByName = nil,
        messages = {}
    }

    playerActiveReport[source] = dbId

    TriggerClientEvent('nb_reports:openChat', source, {
        id = dbId,
        title = title,
        categoryLabel = categoryLabel(category),
        status = 'open',
        claimedByName = nil,
        isAdmin = false,
        messages = {}
    })

    broadcastList()
end)

-- ============================================================
-- Admin lista kérése (F1 megnyitás)
-- ============================================================
RegisterNetEvent('nb_reports:requestList', function()
    local source = source
    if not isStaff(source) then
        exports['nb_core']:Notify(source, { message = 'Nincs jogosultságod ehhez.', type = 'error' })
        return
    end

    local list = {}
    for id, r in pairs(reports) do
        if r.status ~= 'closed' then
            list[#list + 1] = {
                id = r.id,
                playerName = r.playerName,
                category = r.category,
                categoryLabel = categoryLabel(r.category),
                title = r.title,
                description = r.description,
                status = r.status,
                claimedByName = r.claimedByName
            }
        end
    end

    TriggerClientEvent('nb_reports:openPanel', source, list)
end)

-- ============================================================
-- Elfogadás (Elfogadás gomb)
-- ============================================================
RegisterNetEvent('nb_reports:claim', function(reportId)
    local source = source
    if not isStaff(source) then return end

    local report = reports[reportId]
    if not report or report.status == 'closed' then
        exports['nb_core']:Notify(source, { message = 'Ez a report már nem elérhető.', type = 'error' })
        return
    end
    if report.status == 'claimed' then
        exports['nb_core']:Notify(source, { message = 'Ezt a reportot már valaki más kezeli.', type = 'error' })
        return
    end

    report.status = 'claimed'
    report.claimedBy = source
    report.claimedByName = GetPlayerName(source)

    MySQL.query('UPDATE nb_reports SET status = ?, claimed_by_name = ? WHERE id = ?', { 'claimed', report.claimedByName, reportId })

    TriggerClientEvent('nb_reports:openAdminChat', source, {
        id = report.id,
        title = report.title,
        categoryLabel = categoryLabel(report.category),
        playerName = report.playerName,
        description = report.description,
        status = report.status,
        claimedByName = report.claimedByName,
        isAdmin = true,
        messages = report.messages
    })

    if report.playerSource then
        TriggerClientEvent('nb_reports:systemMessage', report.playerSource, reportId, ('%s csatlakozott.'):format(report.claimedByName))
        TriggerClientEvent('nb_reports:statusUpdate', report.playerSource, reportId, report.status, report.claimedByName)
    end

    broadcastList()
end)

-- ============================================================
-- Csevegés elhagyása (admin lemondja, report visszaáll "Szabad"-ra)
-- ============================================================
RegisterNetEvent('nb_reports:leaveChat', function(reportId)
    local source = source
    local report = reports[reportId]
    if not report or report.claimedBy ~= source then return end

    report.status = 'open'
    report.claimedBy = nil
    local formerAdminName = report.claimedByName
    report.claimedByName = nil

    MySQL.query('UPDATE nb_reports SET status = ?, claimed_by_name = NULL WHERE id = ?', { 'open', reportId })

    if report.playerSource then
        TriggerClientEvent('nb_reports:systemMessage', report.playerSource, reportId, ('%s elhagyta a csevegést.'):format(formerAdminName))
        TriggerClientEvent('nb_reports:statusUpdate', report.playerSource, reportId, report.status, nil)
    end

    broadcastList()
end)

-- ============================================================
-- Lezárás (csak admin, ez zárja le VÉGLEGESEN a reportot)
-- ============================================================
RegisterNetEvent('nb_reports:close', function(reportId)
    local source = source
    local report = reports[reportId]
    if not report then return end
    if not isStaff(source) then return end

    report.status = 'closed'
    MySQL.query('UPDATE nb_reports SET status = ?, closed_at = NOW() WHERE id = ?', { 'closed', reportId })

    if report.playerSource then
        playerActiveReport[report.playerSource] = nil
        TriggerClientEvent('nb_reports:chatClosed', report.playerSource, reportId)
    end

    if report.claimedBy and report.claimedBy ~= source then
        TriggerClientEvent('nb_reports:chatClosed', report.claimedBy, reportId)
    end

    reports[reportId] = nil
    broadcastList()
end)

-- ============================================================
-- Üzenetküldés (mindkét irányba)
-- ============================================================
RegisterNetEvent('nb_reports:sendMessage', function(reportId, text)
    local source = source
    local report = reports[reportId]
    if not report or not text or text == '' then return end

    local isPlayer = report.playerSource == source
    local isAdmin = report.claimedBy == source

    if not isPlayer and not isAdmin then return end

    local senderName = GetPlayerName(source)
    local senderType = isAdmin and 'admin' or 'player'

    local msg = { sender = senderType, senderName = senderName, text = text, timestamp = os.time() * 1000 }
    table.insert(report.messages, msg)

    MySQL.query('INSERT INTO nb_report_messages (report_id, sender_type, sender_name, message) VALUES (?, ?, ?, ?)', {
        reportId, senderType, senderName, text
    })

    if report.playerSource then
        TriggerClientEvent('nb_reports:newMessage', report.playerSource, reportId, msg)
    end
    if report.claimedBy then
        TriggerClientEvent('nb_reports:newMessage', report.claimedBy, reportId, msg)
    end
end)

-- ============================================================
-- Admin gyors-akciók (Revive/Kill/Heal/TP/Bring/Freeze/Unfreeze)
-- ============================================================
local actionLabels = {
    revive = 'újraélesztett',
    heal = 'meggyógyított',
    kill = 'megölt',
    tp = 'odateleportált magához',
    bring = 'magához hozott',
    freeze = 'lefagyasztott',
    unfreeze = 'feloldott',
}

RegisterNetEvent('nb_reports:adminAction', function(reportId, action)
    local source = source
    local report = reports[reportId]
    if not report or report.claimedBy ~= source then return end

    local targetId = report.playerSource
    if not targetId or not GetPlayerName(targetId) then
        exports['nb_core']:Notify(source, { message = 'A játékos már nincs a szerveren.', type = 'error' })
        return
    end

    if action == 'revive' then
        TriggerClientEvent('nb_administration:revive', targetId)
    elseif action == 'heal' then
        TriggerClientEvent('nb_administration:heal', targetId)
        pcall(function()
            exports['nb_basicneeds']:SetHunger(targetId, 100)
            exports['nb_basicneeds']:SetThirst(targetId, 100)
        end)
    elseif action == 'kill' then
        TriggerClientEvent('nb_administration:forceKill', targetId)
    elseif action == 'tp' then
        local coords = GetEntityCoords(GetPlayerPed(targetId))
        TriggerClientEvent('nb_administration:teleport', source, { x = coords.x, y = coords.y, z = coords.z })
    elseif action == 'bring' then
        local coords = GetEntityCoords(GetPlayerPed(source))
        TriggerClientEvent('nb_administration:teleport', targetId, { x = coords.x, y = coords.y, z = coords.z })
    elseif action == 'freeze' then
        TriggerClientEvent('nb_reports:setFreeze', targetId, true)
    elseif action == 'unfreeze' then
        TriggerClientEvent('nb_reports:setFreeze', targetId, false)
    else
        return
    end

    -- Ez a rendszerüzenet SZÁNDÉKOSAN csak a játékosnak megy ki.
    if actionLabels[action] then
        TriggerClientEvent('nb_reports:systemMessage', targetId, reportId, ('%s %s téged.'):format(report.claimedByName or 'Egy admin', actionLabels[action]))
    end
end)

-- ============================================================
-- Lecsatlakozás kezelése
-- ============================================================
AddEventHandler('playerDropped', function()
    local source = source

    local reportId = playerActiveReport[source]
    if reportId and reports[reportId] then
        local report = reports[reportId]
        report.status = 'closed'
        MySQL.query('UPDATE nb_reports SET status = ?, closed_at = NOW() WHERE id = ?', { 'closed', reportId })

        if report.claimedBy then
            TriggerClientEvent('nb_reports:systemMessage', report.claimedBy, reportId, 'A játékos lecsatlakozott, a report lezárva.')
            TriggerClientEvent('nb_reports:chatClosed', report.claimedBy, reportId)
        end

        reports[reportId] = nil
        broadcastList()
    end
    playerActiveReport[source] = nil

    -- Ha egy admin csatlakozott le, aki épp kezelt egy reportot, az
    -- automatikusan visszaáll "Szabad"-ra.
    for id, report in pairs(reports) do
        if report.claimedBy == source then
            report.status = 'open'
            report.claimedBy = nil
            report.claimedByName = nil
            MySQL.query('UPDATE nb_reports SET status = ?, claimed_by_name = NULL WHERE id = ?', { 'open', id })

            if report.playerSource then
                TriggerClientEvent('nb_reports:systemMessage', report.playerSource, id, 'Az admin lecsatlakozott.')
                TriggerClientEvent('nb_reports:statusUpdate', report.playerSource, id, 'open', nil)
            end
        end
    end
    broadcastList()
end)
