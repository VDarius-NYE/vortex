-- Ez a resource NEM az alap 'chat' resource-ot módosítja, hanem a FiveM
-- beépített "chat_theme" mechanizmusát használja: a chat resource induláskor
-- összeszedi az összes futó resource-ból a 'chat_theme' metaadatot, és
-- betölti azok style.css/script fájljait. Emiatt EZ HELYETTESÍTI a
-- 'chat-theme-gtao'-t a server.cfg-ben - azt ki kell venni/kikommentezni.

fx_version 'cerulean'
game 'gta5'

author 'Darius'
description 'Vortex Military - Katonai chat téma'
version '1.0.0'

file 'style.css'
file 'shadow.js'

chat_theme 'vortex_military' {
    styleSheet = 'style.css',
    script = 'shadow.js',
    msgTemplates = {
        default = '<b>{0}</b><span>{1}</span>',
        defaultAlt = '<span>{0}</span>'
    }
}
