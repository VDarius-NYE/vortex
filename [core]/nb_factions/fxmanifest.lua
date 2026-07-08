fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Darius'
description 'Vortex Military - Frakciók'
version '1.0.0'

dependency 'nb_core'
dependency 'nb_group'
dependency 'nb_interact'
dependency 'nb_hud'

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua'
}

client_scripts {
    'client/cl_npcs.lua'
}

server_exports {
    'GetFaction',
    'GetFactionName',
    'SetFaction',
    'GetFactionConfig',
    'GetShopDef',
    'GetGarageDef',
    'GetSpawnPoint'
}
