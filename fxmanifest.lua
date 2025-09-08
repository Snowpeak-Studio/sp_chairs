fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'sp_chairs'
author 'Snowpeak Studio / KodeRed'
version '0.0.4'
ox_lib 'locale'
dependencies {
    'ox_lib',
    'ox_target',
    'sp_core',
}
shared_scripts {
    '@ox_lib/init.lua',
    '@sp_core/init.lua',
    '@sp_core/bridge/init.lua',
    'shared/main.lua',

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
    'locales/*.json',
}