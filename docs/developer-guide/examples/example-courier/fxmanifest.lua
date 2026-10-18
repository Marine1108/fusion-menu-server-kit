fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'example-courier'
description 'Example Fusion Menu integration: a parcel courier job (settings page, permissions, job, items, money, menus, third eye, callbacks)'
version '1.0.0'

dependency 'fusion-core'

shared_script '@fusion-core/lib/init.lua'
server_script 'server.lua'
client_script 'client.lua'
