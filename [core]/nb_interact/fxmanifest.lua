fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Darius'
description 'Vortex Military - 3D Interact rendszer'
version '1.0.0'

client_scripts {
    'client/cl_interact.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/script.js'
}

exports {
    'AddPoint',
    'RemovePoint'
}
