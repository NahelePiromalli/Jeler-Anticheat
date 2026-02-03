fx_version 'cerulean'
game 'gta5'
author 'Jeler Security Systems'
description 'Jeler Anti-Cheat v14.5 (Production Ready)'
version '14.5.0'
lua54 'yes'

shared_script 'config.lua'

server_scripts {
    'server/math_utils.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

-- Configuración para Asset Escrow (Tebex)
-- Si vendes el script, el comprador SOLO podrá editar estos archivos:
escrow_ignore {
    'config.lua',
    'bans.json',
    'README.md'
}

dependency '/assetpacks'