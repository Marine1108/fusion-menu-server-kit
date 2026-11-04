fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qb-menu'
author 'Fusion Menu'
description 'qb-menu compatibility - rendered by the Fusion UI'
version '1.0.0'

dependency 'fusion-core'
client_script 'client.lua'

-- Cfx.re Asset Escrow: QBCore resources import these files, so they stay readable.
escrow_ignore {
    '*.lua',
    'shared/*.lua',
}
