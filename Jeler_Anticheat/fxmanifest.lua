fx_version 'cerulean'
game 'gta5'
author 'Jeler Security Systems'
description 'Executioner Anti-Cheat v7'
version '7.0.0'
lua54 'yes' -- CRÍTICO: Optimización OneSync

shared_script 'config.lua'

server_scripts {
    'server/math_utils.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

escrow_ignore {
    'config.lua',
    'README.md'
}

dependency '/assetpacks'