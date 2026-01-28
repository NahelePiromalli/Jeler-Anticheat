fx_version 'cerulean'
game 'gta5'
author 'Jeler Security Systems'
description 'Elite Secure Anti-Cheat'
version '6.0.0'
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