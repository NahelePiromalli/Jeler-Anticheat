fx_version 'cerulean'
game 'gta5'
author 'Jeler Security Systems'
description 'Jeler Anti-Cheat v13.0 (Protected)'
version '13.0.0'
lua54 'yes'

shared_script 'config.lua'

server_scripts {
    'server/math_utils.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

-- ESTA ES LA PARTE MÁGICA
-- Todo lo que pongas aquí será VISIBLE y EDITABLE para el comprador.
-- Todo lo que NO esté aquí, se encriptará y será imposible de leer.
escrow_ignore {
    'config.lua',     -- El cliente DEBE ver esto para configurar
    'bans.json',      -- El cliente necesita ver la lista de bans (opcional)
    'README.md'       -- Instrucciones
}

dependency '/assetpacks' -- Necesario para que funcione la encriptación