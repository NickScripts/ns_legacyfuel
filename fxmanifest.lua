fx_version "cerulean"
game "gta5"
author "NS Legacy Fuel"
description "Realistic multiplayer fuel system with physical nozzles, fuel grades, jerry cans and configurable gas-pump behavior"
version "1.0.2"

dependency "ox_target"

shared_script "config/config.lua"

server_scripts {
    "server/main.lua",
}

client_scripts {
    "client/shared.lua",
    "client/fuel.lua",
    "client/nozzle.lua",
    "client/jerrycan.lua",
    "client/targets.lua",
    "client/main.lua",
}

files {
    "ui/index.html",
    "ui/style.css",
    "ui/script.js",
    "ui/digital-counter-7.ttf",
    "ui/background.png",
}

ui_page "ui/index.html"

exports {
    "GetFuel",
    "SetFuel",
}
