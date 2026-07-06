-- A kliens oldalon csak egy KÉNYELMI cache van a saját csoportról (pl. UI
-- elemek megjelenítéséhez/elrejtéséhez). A VALÓDI jogosultság-ellenőrzés
-- mindig szerver oldalon történik (exports['nb_group']:HasPermission),
-- ennek a kliens oldali értéknek soha nem szabad biztonsági döntést alapoznia.

local myGroup = 'user'

RegisterNetEvent('nb_group:setGroup', function(groupName)
    myGroup = groupName
end)

exports('GetMyGroup', function()
    return myGroup
end)
