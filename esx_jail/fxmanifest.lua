fx_version 'cerulean'
game 'gta5'

author 'VotreNom'
description 'Système de prison pour FiveM'
version '1.0.0'

shared_scripts {
    'config.lua',
    '@es_extended/imports.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'es_extended',
    'esx_progressbar'
}