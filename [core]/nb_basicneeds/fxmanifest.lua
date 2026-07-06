fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Darius'
description 'Vortex Military - Basic Needs (éhség/szomjúság)'
version '1.0.0'

dependency 'nb_core'

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua'
}

server_exports {
    'GetHunger',
    'GetThirst',
    'SetHunger',
    'SetThirst',
    'AddHunger',
    'AddThirst'
}
