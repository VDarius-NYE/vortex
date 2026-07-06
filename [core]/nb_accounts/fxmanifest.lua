fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Darius'
description 'NB Military Server - Accounts (Registration/Login)'
version '1.0.0'

dependency 'nb_core'

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sha256.lua',
    'server/sv_main.lua'
}

client_scripts {
    'client/cl_main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/script.js'
}
