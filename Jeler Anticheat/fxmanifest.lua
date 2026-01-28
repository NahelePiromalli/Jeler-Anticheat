fx_version 'cerulean'
game 'gta5'
author 'Jeler Security Systems'
description 'Universal Competitive Anti-Cheat'
version '5.5.0'
lua54 'yes' -- Requerido para máximo rendimiento y matemáticas precisas

shared_script 'config.lua'

server_scripts {
    'server/math_utils.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

-- Deja la config abierta para que el dueño la edite
escrow_ignore {
    'config.lua',
    'README.md'
}

dependency '/assetpacks'