fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Darius'
description 'Vortex Military - Zónák (safe/faction/danger/admin)'
version '1.0.0'

dependency 'nb_core'
dependency 'nb_group'
dependency 'nb_factions'

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua',
    'server/sv_commands.lua'
}

client_scripts {
    'client/cl_zones.lua',
    'client/cl_creation.lua',
    'client/cl_blips.lua',
    'client/cl_boundaries.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/script.js'
}
