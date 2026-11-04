fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qb-core'
author 'Fusion Menu'
description 'QBCore compatibility layer - routes QBCore resources to fusion-core. Do not remove.'
version '1.3.0'

dependency 'fusion-core'

shared_scripts {
    'shared/locale.lua',
}

server_script 'server.lua'
client_script 'client.lua'

files {
    'shared/locale.lua',
    'import.lua',
}

-- Cfx.re Asset Escrow: QBCore resources import these files, so they stay readable.
escrow_ignore {
    '*.lua',
    'shared/*.lua',
}
