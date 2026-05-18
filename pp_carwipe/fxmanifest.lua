fx_version 'cerulean'
game 'gta5'

author 'Pain & Profit RP'
description 'txAdmin vehicle wipe with garage return'
version '1.6.0-reverted'

lua54 'yes'

shared_script 'config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

client_script 'client.lua'
