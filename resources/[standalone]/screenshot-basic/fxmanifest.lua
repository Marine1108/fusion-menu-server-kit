-- screenshot-basic by The CitizenFX Developers (MIT, see LICENSE), pre-built for Fusion Menu so it starts
-- without the yarn / webpack build step. Original: https://github.com/citizenfx/screenshot-basic
fx_version 'cerulean'
game 'common'

name 'screenshot-basic'
description 'Screenshots of the game view for other scripts (evidence, CCTV, MDTs, phone cameras)'

client_script 'dist/client.js'
server_script 'dist/server.js'

files {
    'dist/ui.html',
}

ui_page 'dist/ui.html'
