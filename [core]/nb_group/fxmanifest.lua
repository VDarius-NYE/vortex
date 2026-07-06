fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Darius'
description 'Vortex Military - Group / Permission System'
version '1.0.0'

dependency 'nb_core'

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua'
}

client_scripts {
    'client/cl_main.lua'
}

server_exports {
    'GetGroup',
    'GetGroupLevel',
    'HasPermission',
    'SetGroup',
    'GetGroupByIdentifier'
}

exports {
    'GetMyGroup'
}
