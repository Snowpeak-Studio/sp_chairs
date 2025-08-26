fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'sp_chairs'
author 'Snowpeak Studio / KodeRed'
version '1.0.0'
dependencies {
    'ox_lib',
    'ox_target',
}
shared_scripts {
    '@ox_lib/init.lua',

}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

files {
    'client/*.lua',
    'shared/*.lua',
}