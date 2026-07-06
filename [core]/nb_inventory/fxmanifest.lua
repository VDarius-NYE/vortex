fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Darius'
description 'Vortex Military - Inventory'
version '1.0.0'

dependency 'nb_core'
dependency 'nb_group'
dependency 'nb_basicneeds'

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua',
    'server/sv_stash.lua',
    'server/sv_actions.lua'
}

client_scripts {
    'client/cl_inventory.lua',
    'client/cl_stash.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/script.js'
}

server_exports {
    'GetInventory',
    'AddItem',
    'RemoveItem',
    'HasItem',
    'GetItemCount',
    'GetWeight'
}
