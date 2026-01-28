fx_version 'cerulean'
game 'gta5'
author 'Jeler Security Systems'
description 'Competitive Anti-Cheat Ultimate'
version '4.0.0'
lua54 'yes' -- CRÍTICO: Optimización OneSync

shared_script 'config.lua'

server_scripts {
    'server/math_utils.lua', -- Cargar primero (Librería)
    'server/main.lua'        -- Cargar segundo (Lógica)
}

client_scripts {
    'client/main.lua'
}

-- Proteger código lógica, dejar config abierta para el cliente
escrow_ignore {
    'config.lua',
    'README.md'
}

dependency '/assetpacks'