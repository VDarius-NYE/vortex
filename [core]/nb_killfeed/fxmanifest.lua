fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Darius'
description 'Vortex Military - Killfeed'
version '1.0.0'

dependency 'nb_core'

server_scripts {
    'server/sv_main.lua'
}

client_scripts {
    'client/cl_killfeed.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/script.js'
}
