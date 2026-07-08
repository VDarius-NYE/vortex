fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Darius'
description 'Vortex Military - Inventory'
version '1.3.0'

dependency 'nb_core'
dependency 'nb_group'
dependency 'nb_basicneeds'
dependency 'nb_interact'
dependency 'nb_progressbar'

shared_scripts {
    'config/main.lua',
    'config/items.lua',
    'config/weapons.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua',
    'server/sv_stash.lua',
    'server/sv_actions.lua',
    'server/sv_admin.lua',
    'server/sv_positions.lua'
}

client_scripts {
    'client/cl_inventory.lua',
    'client/cl_stash.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/script.js',
    'html/assets/items/*.png'
}

server_exports {
    'GetInventory',
    'AddItem',
    'RemoveItem',
    'HasItem',
    'GetItemCount',
    'GetWeight',
    'GetItemDef',
    'GenerateSerial',
    'DumpToGroundStash'
}
