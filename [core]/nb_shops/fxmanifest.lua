fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Darius'
description 'Vortex Military - Boltok (item/weapon/vehicle shop)'
version '1.0.0'

dependency 'nb_core'
dependency 'nb_factions'
dependency 'nb_inventory'
dependency 'nb_ownvehicles'

server_scripts {
    'server/sv_shop.lua'
}

client_scripts {
    'client/cl_shop.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/script.js'
}
