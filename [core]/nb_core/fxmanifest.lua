fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Darius'
description 'Vortex Military - Core Framework'
version '1.1.0'

shared_scripts {
    'config.lua',
    'shared/sh_functions.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_player.lua',
    'server/sv_functions.lua',
    'server/sv_callbacks.lua',
    'server/sv_notify.lua',
    'server/sv_main.lua'
}

client_scripts {
    'client/cl_functions.lua',
    'client/cl_notify.lua',
    'client/cl_main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/notify.css',
    'html/js/notify.js'
}

exports {
    'FreezePlayer',
    'SetLimbo',
    'GetDefaultSpawn',
    'Notify'
}

server_exports {
    'GetPlayer',
    'GetPlayerByIdentifier',
    'GetPlayers',
    'GetPlayerData',
    'SetLoggedIn',
    'SetCharacterLoaded',
    'SavePlayer',
    'GetPrimaryIdentifier',
    'CreateCallback',
    'TriggerClientCallback',
    'Notify'
}
