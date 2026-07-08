fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Darius'
description 'Vortex Military - Saját járművek / garázs'
version '1.0.0'

dependency 'nb_core'
dependency 'nb_factions'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua'
}

client_scripts {
    'client/cl_garage.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/script.js',
    'html/assets/imgs/*.png'
}

server_exports {
    'AddOwnedVehicle',
    'GetOwnedVehicles'
}
