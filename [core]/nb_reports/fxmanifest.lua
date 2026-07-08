fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Darius'
description 'Vortex Military - Report rendszer (F3 player / F1 admin)'
version '1.0.0'

dependency 'nb_core'
dependency 'nb_group'
dependency 'nb_administration'

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua'
}

client_scripts {
    'client/cl_reports.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/script.js'
}
