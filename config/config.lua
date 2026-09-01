--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⭐ START HERE - THE ONLY SETTINGS MOST SERVER OWNERS NEED LOOK UP SETTINGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1) Framework
   Config.Framework.Name / Standalone

2) Notifications
   Config.Notifications

3) Fuel prices
   Config.Fuel.BasePricePerGallon
   Config.Fuel.FuelTypes

4) Nozzle/UI distances
   Config.Pump.HoseDropDistance
   Config.Pump.FuelingUIDistance

5) Pump explosions
   Config.Pump.Explosions.Enabled

6) Target interaction
   Config.Target.Resource

7) Jerry cans
   Config.JerryCan.Enabled

Everything else below is OPTIONAL/ADVANCED. Leave it alone unless you
know why you are changing it.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ IMPORTANT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Do NOT put quotes around numbers. Use 5.0, not "5.0".
• true = ON / false = OFF.
• Text uses quotes: "REGULAR".
• If you do not know what a setting does, leave the default value.
• Never delete a comma or closing brace when changing a value.
• For notification exports, copy the example that matches your notify
  resource instead of guessing.

LegacyFuel credit: this resource is a heavily modified derivative of
LegacyFuel by InZidiuZ. See NOTICE.md and LICENSE for attribution/licensing.
]]

Config = {
    -- 🛠️ DEBUG MODE
    -- Leave false on a live server. Turn true on only when troubleshooting.
    Debug = false,

    -- ═══════════════════════════════════════════════════════════════════
    -- 1) FRAMEWORK
    -- ═══════════════════════════════════════════════════════════════════
    -- Most ESX servers: Name = "esx", Standalone = false
    -- No-framework server: Standalone = true
    -- ⚠️ The resource currently expects ESX when Standalone = false.
    Framework = {
        Name = "esx",  -- ONLY ESX AS OF RIGHT NOW
        Standalone = false,
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 2) UI / APPEARANCE
    -- ═══════════════════════════════════════════════════════════════════
    -- Change the text/colors here if you want to brand the UI.
    UI = {
        Title = "GAS STATION",
        Subtitle = "NS Legacy Fuel",
        Currency = "$",
        Locale = "en-US",
        DecimalPlaces = 2,
        CloseOnEscape = true,

        Theme = {
            Red = "#e5092f",
            RedDark = "#9f061f",
            White = "#f4f4f4",
            Muted = "#8e8e94",
        },

        Text = {
            SelectKicker = "PLEASE SELECT",
            SelectTitle = "FUEL TYPE",
            SelectSubtitle = "Choose your grade before fueling",
            SelectedKicker = "SELECTED FUEL",
            TankLabel = "Vehicle tank",
            PriceLabel = "Price per gallon",
            GallonsLabel = "Gallons",
            TotalLabel = "Total price",
            BankLabel = "Bank balance",
            CashLabel = "Cash balance",
            Close = "CLOSE",
            GallonUnit = "GAL",
        },
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 3) NOTIFICATIONS ⭐
    -- ═══════════════════════════════════════════════════════════════════
    -- THIS IS THE IMPORTANT PART FOR CUSTOM NOTIFY SCRIPTS.
    --
    -- EASIEST OPTION: keep Mode = "builtin" for the built-in GTA notification.
    -- Or use Mode = "event" and enter your event below.
    -- Example: TriggerEvent("my_notify:show", title, message, icon, color, duration)
    --
    -- CUSTOM EXPORT: use Mode = "client_export".
    -- Example export:
    -- exports["my_notify"]:Notify(message, color, duration)
    -- Then use:
    -- Mode = "client_export"
    -- Resource = "my_notify"
    -- Export = "Notify"
    -- Arguments = { "message", "color", "duration" }
    --
    -- Supported Arguments (ONLY these words):
    -- "title" "message" "icon" "color" "duration"
    -- Put them in the EXACT order your export expects.
    Notifications = {
        -- CHOOSE ONE:
        --   "builtin"       = GTA feed notification (DEFAULT)
        --   "event"         = your client notification event
        --   "client_export" = your notification export
        --   "server_event"  = server sends your notification event
        --   "server_export" = server directly calls your notification export
        --
        -- ⭐ If you are unsure, use "client_export" and copy your notify
        -- export from that resource's documentation.
        Mode = "event",

        -- EVENT MODE EXAMPLE:
        -- TriggerEvent("gfx_hud:sendNotify", message, icon, color, duration)
        Event = "gfx_hud:sendNotify",

        -- Custom export notification. Example:
        -- Resource = "my_notify",
        -- Export = "Notify",
        -- Arguments controls what gets passed to the export. Supported values:
        -- "title", "message", "icon", "color", "duration"
        -- Example for exports['my_notify']:Notify(message, type, duration):
        -- Arguments = { "message", "color", "duration" },
        Resource = "",
        Export = "",
        Arguments = { "message", "icon", "color", "duration" },

        Icon = "fa-solid fa-bell",
        Color = "red",
        Duration = 5000,
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 4) LOGGING
    -- ═══════════════════════════════════════════════════════════════════
    Logging = {
        -- Console transaction logging is disabled by default to keep busy
        -- servers quiet. Enable it while testing/economy balancing.
        Enabled = false,
        IncludePlayerName = true,
        IncludePlate = true,
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 5) PAYMENT
    -- ═══════════════════════════════════════════════════════════════════
    -- Server-side payment is protected. Do not disable the safety caps.
    Payment = {
        -- Fuel payments use bank first, then cash when enabled.
        UseBankFirst = true,
        AllowCashFallback = true,

        -- Kept for backwards compatibility. Fuel transactions are now always
        -- calculated and charged to the cent, matching the pump display.
        RoundToWholeDollar = false,

        -- Safety cap for a single server-side payment.
        MaxTransaction = 10000,

        InsufficientFundsTitle = "Not Enough Money",
        FuelPaidFormat = "Paid $%.2f from %s",
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 6) FUEL / PRICES / CONSUMPTION
    -- ═══════════════════════════════════════════════════════════════════
    Fuel = {
        Decor = "_NS_LEGACYFUEL_",

        -- 💵 DEFAULT PRICE: change this to your regular fuel price.
        BasePricePerGallon = 4.29,

        -- GTA fuel is stored as 0-100. This controls the visual gallon
        -- calculation only. 0.15 means 15% fuel = roughly 1 gallon.
        GallonsPerFuelPercent = 0.15,

        -- Real-world-ish dispenser flow.
        PumpGallonsPerMinute = 16.0,

        -- Slow the dispenser as the tank approaches full, like a real pump.
        FlowTaper = {
            { minFuel = 99.0, multiplier = 0.15 },
            { minFuel = 97.0, multiplier = 0.35 },
            { minFuel = 90.0, multiplier = 0.65 },
            { minFuel = 0.0,  multiplier = 1.00 },
        },

        -- Server-side fuel transaction sanity checks.
        MaxGallonsPerSession = 100.0,

        -- Server-side anti-exploit allowance. The client cannot finish a
        -- session with more gallons than the configured pump could physically
        -- dispense during the session, plus this grace period.
        TransactionTimeGraceSeconds = 3,

        -- Vehicle fuel consumption.
        ConsumptionInterval = 3500,
        ConsumptionDivisor = 1.7,
        DisableEngineBelow = 5.0,
        InitialFuelMin = 20.0,
        InitialFuelMax = 80.0,

        -- GTA vehicle classes 0-21.
        VehicleClassMultipliers = {
            [0] = 0.30, -- Compacts
            [1] = 0.40, -- Sedans
            [2] = 0.60, -- SUVs
            [3] = 0.40, -- Coupes
            [4] = 0.50, -- Muscle
            [5] = 0.40, -- Sports Classics
            [6] = 0.60, -- Sports
            [7] = 0.70, -- Super
            [8] = 0.20, -- Motorcycles
            [9] = 0.50, -- Off-road
            [10] = 0.40, -- Industrial
            [11] = 0.40, -- Utility
            [12] = 0.50, -- Vans
            [13] = 0.00, -- Cycles
            [14] = 0.40, -- Boats
            [15] = 0.60, -- Helicopters
            [16] = 0.70, -- Planes
            [17] = 0.30, -- Service
            [18] = 0.40, -- Emergency
            [19] = 0.80, -- Military
            [20] = 0.70, -- Commercial
            [21] = 0.20, -- Trains
        },

        -- ⛽ FUEL PRICES ⭐
        -- Change priceOffset to change each grade's price.
        -- Final price = BasePricePerGallon + priceOffset.
        -- Example: base 4.29 + premium offset 1.10 = $5.39.
        FuelTypes = {
            {
                grade = 87,
                name = "REGULAR",
                description = "Regular unleaded",
                priceOffset = 0.00,
            },
            {
                grade = 91,
                name = "PLUS",
                description = "Plus unleaded",
                priceOffset = 0.60,
            },
            {
                grade = 93,
                name = "PREMIUM",
                description = "Premium unleaded",
                priceOffset = 1.10,
            },
        },

        -- ⚡ ELECTRIC VEHICLES
        -- Add model names here if your server has additional EVs.
        ElectricVehicles = {
            "Imorgon",
            "Neon",
            "Raiden",
            "Cyclone",
            "Voltic",
            "Voltic2",
            "Tezeract",
            "Dilettante",
            "Dilettante2",
            "Airtug",
            "Caddy",
            "Caddy2",
            "Caddy3",
            "Surge",
            "Khamelion",
            "RCBandito",
        },
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 7) GAS PUMPS / NOZZLE
    -- ═══════════════════════════════════════════════════════════════════
    Pump = {
        SearchRadius = 0.8,
        InteractionDistance = 2.0,
        VehicleTankDistance = 1.8,
        -- 🚗/🪢 NOZZLE DROP DISTANCE: same distance is used for a player
        -- walking away or a vehicle pulling the hose too far.
        HoseDropDistance = 6.0,
        DroppedNozzleLifetime = 600, -- seconds
        FuelingTankDistance = 1.2,
        -- 🖥️ UI DISTANCE: walk farther than this from the pump and the
        -- fueling UI hides. It returns when you come back.
        FuelingUIDistance = 5.0,

        -- A player can legitimately walk away while the nozzle remains in a
        -- vehicle, so this timeout is intentionally generous. It is only a
        -- failsafe for abandoned/stale server-side pump locks.
        LockTimeout = 900,

        -- Gas-pump impact/explosion behavior.
        -- 💥 PUMP EXPLOSIONS ⭐
        -- OFF by default. Set Enabled = true only if you want this feature.
        -- PreventNativeExplosions = true keeps normal GTA behavior from
        -- bypassing this setting.
        Explosions = {
            Enabled = false,
            AllowVehicleImpact = true,
            AllowPlayerKick = true,
            VehicleMinSpeed = 4.0,       -- m/s (~9 mph)
            VehicleImpactRadius = 2.25,
            PlayerKickRadius = 1.65,
            Cooldown = 15,               -- seconds before the same pump can explode again
            RespawnAfter = 300,          -- seconds; 0 = never reset the pump lockout
            ExplosionType = 2,            -- GTA explosion type
            ExplosionDamageScale = 1.0,
            ExplosionCameraShake = 1.0,
            ExplosionAudible = true,
            ExplosionInvisible = false,
            DeletePumpAfterExplosion = false,
            DestroyedPumpInteractionDisabled = true,
            PreventNativeExplosions = true,
        },

        NozzleModel = "prop_cs_fuel_nozle",

        PlayerAttach = { x = 0.11, y = 0.02, z = 0.02, rx = -80.0, ry = -90.0, rz = 15.0, bone = 0x49D9 },
        RopePumpOffset = { x = 0.0, y = 0.0, z = 1.45 },
        RopeNozzleOffset = { x = 0.0, y = -0.033, z = -0.195 },
        VehicleAttach = {
            Bike = { x = 0.0, y = -0.2, z = 0.2, rx = -80.0, ry = 0.0, rz = 0.0 },
            Vehicle = { x = -0.18, y = 0.0, z = 0.75, rx = -125.0, ry = -90.0, rz = -90.0 },
        },

        Models = {
            [-2007231801] = true,
            [1339433404] = true,
            [1694452750] = true,
            [1933174915] = true,
            [-462817101] = true,
            [-469694731] = true,
            [-164877493] = true,
        },

        -- Optional extra pumps created by this resource.
        SpawnedPumps = {
            { hash = "prop_vintage_pump", coords = vector3(-674.08, -2396.20, 13.94) },
        },
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 8) JERRY CAN
    -- ═══════════════════════════════════════════════════════════════════
    JerryCan = {
        -- 🛢️ Set false if your server does not use jerry cans.
        Enabled = true,
        Item = "weapon_petrolcan",
        WeaponHash = 883325847,
        Capacity = 500,

        PurchasePrice = 250,
        RefillCost = 100,

        -- Refill cost is based on how empty the can is.
        UseBankFirst = false,
        AllowCashFallback = false,

        FuelPerAmmo = 0.15,
        AmmoPerTick = 3,
        FuelingDistance = 2.25,
        HoldControl = 51, -- E

        -- Inventory detection.
        -- auto = use ox_inventory when available, otherwise ESX inventory/loadout.
        Inventory = {
            Mode = "auto",
            Resource = "ox_inventory",
        },

        -- z offset for the 3D prompt by vehicle class.
        NozzleZOffsets = {
            [0] = 0.65, [1] = 0.65, [2] = 0.85, [3] = 0.60,
            [4] = 0.55, [5] = 0.60, [6] = 0.60, [7] = 0.55,
            [8] = 0.12, [9] = 0.80, [10] = 0.70, [11] = 0.60,
            [12] = 0.70, [13] = 0.00, [14] = 0.00, [15] = 0.00,
            [16] = 0.00, [17] = 0.60, [18] = 0.65, [19] = 0.65,
            [20] = 0.75, [21] = 0.00,
        },
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 9) TARGET / INTERACTION
    -- ═══════════════════════════════════════════════════════════════════
    -- Change Resource only if your server uses another target system that
    -- this resource supports. The default is ox_target.
    Target = {
        Resource = "ox_target",
        GrabNozzle = "Grab Nozzle",
        ReturnNozzle = "Return Nozzle",
        PlaceNozzle = "Place Nozzle",
        GrabVehicleNozzle = "Grab Nozzle",
        FuelVehicleWithJerryCan = "Fuel Vehicle with Gas Can",
        BuyJerryCan = "Purchase Gas Can",
        RefillJerryCan = "Refill Gas Can",
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 10) MAP BLIPS
    -- ═══════════════════════════════════════════════════════════════════
    Blips = {
        Enabled = true,
        Sprite = 361,
        Scale = 0.9,
        Colour = 4,
        Display = 4,
        ShortRange = true,
        Name = "Gas Station",

        Locations = {
            vector3(49.4187, 2778.793, 58.043),
            vector3(263.894, 2606.463, 44.983),
            vector3(1039.958, 2671.134, 39.550),
            vector3(1207.260, 2660.175, 37.899),
            vector3(2539.685, 2594.192, 37.944),
            vector3(2679.858, 3263.946, 55.240),
            vector3(2005.055, 3773.887, 32.403),
            vector3(1687.156, 4929.392, 42.078),
            vector3(1701.314, 6416.028, 32.763),
            vector3(179.857, 6602.839, 31.868),
            vector3(-94.4619, 6419.594, 31.489),
            vector3(-2554.996, 2334.40, 33.078),
            vector3(-1800.375, 803.661, 138.651),
            vector3(-1437.622, -276.747, 46.207),
            vector3(-2096.243, -320.286, 13.168),
            vector3(-724.619, -935.1631, 19.213),
            vector3(-526.019, -1211.003, 18.184),
            vector3(-70.2148, -1761.792, 29.534),
            vector3(265.648, -1261.309, 29.292),
            vector3(819.653, -1028.846, 26.403),
            vector3(1208.951, -1402.567, 35.224),
            vector3(1181.381, -330.847, 69.316),
            vector3(620.843, 269.100, 103.089),
            vector3(2581.321, 362.039, 108.468),
            vector3(176.631, -1562.025, 29.263),
            vector3(-319.292, -1471.715, 30.549),
            vector3(1784.324, 3330.55, 41.253),
        },
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 11) ANIMATIONS (ADVANCED)
    -- ═══════════════════════════════════════════════════════════════════
    Animation = {
        -- Animation used while the pump nozzle is inserted in a vehicle.
        -- Flag 49 is upper-body/looping and allows the player to walk away.
        PumpFuelingDict = "timetable@gardener@filling_can",
        PumpFuelingAnim = "gar_ig_5_filling_can",
        PumpFuelingFlag = 49,
        PumpFuelingBlendIn = 2.0,
        PumpFuelingBlendOut = 8.0,

        -- Animation used when fueling with a jerry can.
        FuelDict = "timetable@gardener@filling_can",
        FuelAnim = "gar_ig_5_filling_can",
        PickupDict = "anim@mp_snowball",
        PickupAnim = "pickup_snowball",
        PumpDict = "anim@am_hold_up@male",
        PumpAnim = "shoplift_high",
        BlendIn = 2.0,
        BlendOut = 8.0,
        Flag = 50,
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 12) EFFECTS (ADVANCED)
    -- ═══════════════════════════════════════════════════════════════════
    Effects = {
        ParticleAsset = "core",
        ParticleName = "veh_trailer_petrol_spray",
        Duration = 100,
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- 13) HOSE/ROPE PHYSICS (ADVANCED)
    -- ═══════════════════════════════════════════════════════════════════
    Rope = {
        Length = 3.0,
        Type = 1,
        MaxLength = 1000.0,
        Breakable = 5.0,
    },
}

-- Build the final fuel type list from the easy-to-edit offsets above.
Config.Fuel.Types = {}
for _, fuel in ipairs(Config.Fuel.FuelTypes) do
    Config.Fuel.Types[#Config.Fuel.Types + 1] = {
        grade = fuel.grade,
        name = fuel.name,
        description = fuel.description,
        price = Config.Fuel.BasePricePerGallon + (tonumber(fuel.priceOffset) or 0.0),
    }
end

-- Include resource-spawned pump models in the same target/model lookup so
-- spawned pumps behave exactly like map pumps.
for _, pump in ipairs(Config.Pump.SpawnedPumps or {}) do
    local hash = type(pump.hash) == "number" and pump.hash or joaat(pump.hash)
    Config.Pump.Models[hash] = true
end

-- Convert readable vehicle model names into hash lookups once.
Config.Fuel.ElectricVehicleHashes = {}
for _, model in ipairs(Config.Fuel.ElectricVehicles) do
    Config.Fuel.ElectricVehicleHashes[joaat(model)] = true
end


-- ═══════════════════════════════════════════════════════════════════════
-- CONFIG SAFETY CHECKS
-- ═══════════════════════════════════════════════════════════════════════
-- These checks do not change your settings. They only print a helpful
-- warning instead of making you hunt through client/server files.
CreateThread(function()
    Wait(0)

    local function warn(message)
        print("^3[ns_legacyfuel config] " .. message .. "^0")
    end

    if Config.Framework.Standalone ~= true and string.lower(tostring(Config.Framework.Name or "")) ~= "esx" then
        warn('Framework.Name should normally be "esx" unless Standalone = true.')
    end

    local notifyMode = string.lower(tostring(Config.Notifications.Mode or "event"))
    local validModes = { builtin = true, event = true, client_export = true, server_event = true, server_export = true }
    if not validModes[notifyMode] then
        warn('Notifications.Mode is invalid. Use "builtin", "event", "client_export", "server_event", or "server_export".')
    elseif notifyMode == "client_export" or notifyMode == "server_export" then
        if tostring(Config.Notifications.Resource or "") == "" or tostring(Config.Notifications.Export or "") == "" then
            warn('Custom notification mode is selected, but Notifications.Resource or Notifications.Export is empty.')
        end
    end

    if tonumber(Config.Fuel.BasePricePerGallon) == nil or tonumber(Config.Fuel.BasePricePerGallon) < 0 then
        warn("Fuel.BasePricePerGallon must be a number greater than or equal to 0.")
    end

    if tonumber(Config.Pump.HoseDropDistance) == nil or tonumber(Config.Pump.HoseDropDistance) <= 0 then
        warn("Pump.HoseDropDistance should be greater than 0.")
    end

    if tonumber(Config.Pump.FuelingUIDistance) == nil or tonumber(Config.Pump.FuelingUIDistance) <= 0 then
        warn("Pump.FuelingUIDistance should be greater than 0.")
    end

    if Config.Pump.Explosions.Enabled == true and Config.Pump.Explosions.PreventNativeExplosions ~= true then
        warn("Pump explosions are enabled while native explosion protection is disabled. This can allow GTA behavior to bypass your settings.")
    end

    if type(Config.Fuel.FuelTypes) ~= "table" or #Config.Fuel.FuelTypes == 0 then
        warn("Fuel.FuelTypes is empty. Players will not have a fuel grade to select.")
    end

    local can = Config.JerryCan or {}
    if can.Enabled then
        if tonumber(can.Capacity) == nil or tonumber(can.Capacity) <= 0 then warn("JerryCan.Capacity must be greater than 0.") end
        if tonumber(can.FuelPerAmmo) == nil or tonumber(can.FuelPerAmmo) <= 0 then warn("JerryCan.FuelPerAmmo must be greater than 0.") end
        if tonumber(can.AmmoPerTick) == nil or tonumber(can.AmmoPerTick) <= 0 then warn("JerryCan.AmmoPerTick must be greater than 0.") end
    end

    if GetResourceState(Config.Target.Resource) == "missing" then
        warn(("Target resource '%s' is not installed."):format(tostring(Config.Target.Resource)))
    end
end)
