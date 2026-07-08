fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Darius'
description 'Vortex Military - Administration'
version '1.0.0'

dependency 'nb_core'
dependency 'nb_group'
dependency 'nb_basicneeds'
dependency 'nb_inventory'

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_bans.lua',
    'server/sv_duty.lua',
    'server/sv_commands.lua',
    'server/sv_panel.lua',
    'server/sv_details.lua'
}

client_scripts {
    'client/cl_commands.lua',
    'client/cl_panel.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/script.js'
}

server_exports {
    'BanIdentifier',
    'UnbanIdentifier',
    'IsOnDuty'
}
