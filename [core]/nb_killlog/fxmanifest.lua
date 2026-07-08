fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Darius'
description 'Vortex Military - Admin Kill Log (F5)'
version '1.0.0'

dependency 'nb_core'
dependency 'nb_group'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua'
}

client_scripts {
    'client/cl_killlog.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/script.js'
}
