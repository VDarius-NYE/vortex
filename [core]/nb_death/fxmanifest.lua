fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Darius'
description 'Vortex Military - Halál rendszer (deathscreen, ragdoll, kifosztás)'
version '1.0.0'

dependency 'nb_core'
dependency 'nb_group'
dependency 'nb_factions'
dependency 'nb_inventory'
dependency 'nb_interact'

shared_scripts {
    'config.lua'
}

server_scripts {
    'server/sv_main.lua'
}

client_scripts {
    'client/cl_death.lua',
    'client/cl_corpse.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/script.js'
}
