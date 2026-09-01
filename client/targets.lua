local targetResource = Config.Target.Resource
local S = NSLegacyFuel.State

local function targetStarted()
    return GetResourceState(targetResource) == "started"
end

CreateThread(function()
    while not targetStarted() do Wait(250) end

    exports[targetResource]:addGlobalObject({
        {
            name = "ns_legacyfuel_grab_pump",
            icon = "fa-solid fa-gas-pump",
            label = Config.Target.GrabNozzle,
            distance = Config.Pump.InteractionDistance,
            canInteract = function(entity)
                return Config.Pump.Models[GetEntityModel(entity)] == true
                    and not S.holdingNozzle
                    and not S.nozzleInVehicle
                    and not NSLegacyFuel.IsJerryCanEquipped()
                    and not isPumpLocked(entity)
                    and not (S.nozzleDropped and S.droppedPumpHandle == entity)
            end,
            onSelect = function(data)
                S.pumpHandle = data.entity
                S.pump = GetEntityCoords(data.entity)
                setPumpLock(S.pump, true, data.entity)
                NSLegacyFuel.GrabNozzleFromPump()
            end,
        },
        {
            name = "ns_legacyfuel_return_hose",
            icon = "fa-solid fa-rotate-left",
            label = Config.Target.ReturnNozzle,
            distance = Config.Pump.InteractionDistance,
            canInteract = function(entity)
                return Config.Pump.Models[GetEntityModel(entity)] == true
                    and S.holdingNozzle
                    and not S.nozzleInVehicle
                    and S.usedPump == entity
            end,
            onSelect = function(data)
                S.pumpHandle = data.entity
                S.pump = GetEntityCoords(data.entity)
                local anim = Config.Animation
                NSLegacyFuel.LoadAnimDict(anim.PumpDict)
                TaskPlayAnim(S.ped, anim.PumpDict, anim.PumpAnim, anim.BlendIn, anim.BlendOut, -1, anim.Flag, 0, false, false, false)
                Wait(300)
                NSLegacyFuel.ReturnNozzleToPump()
                ClearPedTasks(S.ped)
            end,
        },
        {
            name = "ns_legacyfuel_buy_jerrycan",
            icon = "fa-solid fa-gas-can",
            label = Config.Target.BuyJerryCan,
            distance = Config.Pump.InteractionDistance,
            canInteract = function(entity)
                return Config.JerryCan.Enabled
                    and not Config.Framework.Standalone
                    and Config.Pump.Models[GetEntityModel(entity)] == true
                    and not NSLegacyFuel.HasJerryCan()
                    and not NSLegacyFuel.IsJerryCanEquipped()
            end,
            onSelect = function()
                NSLegacyFuel.PurchaseJerryCan()
            end,
        },
        {
            name = "ns_legacyfuel_refill_jerrycan",
            icon = "fa-solid fa-gas-can",
            label = Config.Target.RefillJerryCan,
            distance = Config.Pump.InteractionDistance,
            canInteract = function(entity)
                if not Config.JerryCan.Enabled or Config.Framework.Standalone then return false end
                if Config.Pump.Models[GetEntityModel(entity)] ~= true then return false end
                if not NSLegacyFuel.HasJerryCan() then return false end
                if not NSLegacyFuel.IsJerryCanEquipped() then return false end
                return true
            end,
            onSelect = function()
                NSLegacyFuel.RefillJerryCan()
            end,
        },
    })

    exports[targetResource]:addGlobalVehicle({
        {
            name = "ns_legacyfuel_place_nozzle",
            icon = "fa-solid fa-gas-pump",
            label = Config.Target.PlaceNozzle,
            distance = Config.Pump.VehicleTankDistance,
            canInteract = function(entity)
                if not S.holdingNozzle or S.nozzleInVehicle or not DoesEntityExist(entity) then return false end
                local _, _, _, position = NSLegacyFuel.GetVehicleTankData(entity)
                return position and #(S.pedCoords - position) < Config.Pump.VehicleTankDistance
            end,
            onSelect = function(data)
                local vehicle = data.entity
                local bone, isBike, offset = NSLegacyFuel.GetVehicleTankData(vehicle)
                if not bone then return end

                NSLegacyFuel.PutNozzleInVehicle(vehicle, bone, isBike, offset)
            end,
        },
        {
            name = "ns_legacyfuel_grab_vehicle_nozzle",
            icon = "fa-solid fa-gas-pump",
            label = Config.Target.GrabVehicleNozzle,
            distance = Config.Pump.VehicleTankDistance,
            canInteract = function(entity)
                if not S.nozzleInVehicle or not DoesEntityExist(entity) then return false end
                local _, _, _, position = NSLegacyFuel.GetVehicleTankData(entity)
                return position and #(S.pedCoords - position) < Config.Pump.VehicleTankDistance
            end,
            onSelect = function()
                local anim = Config.Animation
                NSLegacyFuel.LoadAnimDict(anim.FuelDict)
                TaskPlayAnim(S.ped, anim.FuelDict, anim.FuelAnim, 2.0, 8.0, -1, Config.Animation.Flag, 0, false, false, false)
                Wait(300)
                -- Pull the nozzle back out of the vehicle.
                AttachEntityToEntity(
                    S.nozzle,
                    S.ped,
                    GetPedBoneIndex(S.ped, Config.Pump.PlayerAttach.bone),
                    Config.Pump.PlayerAttach.x,
                    Config.Pump.PlayerAttach.y,
                    Config.Pump.PlayerAttach.z,
                    Config.Pump.PlayerAttach.rx,
                    Config.Pump.PlayerAttach.ry,
                    Config.Pump.PlayerAttach.rz,
                    true, true, false, true, 1, true
                )
                -- The grade was selected when the nozzle was first picked up.
                -- Pulling the nozzle out never opens the grade selector again.
                -- The normal refill screen is only displayed while the nozzle
                -- is connected to the vehicle; once it is back in the player's
                -- hand, close all UI immediately.
                if S.vehicleFueling then
                    NSLegacyFuel.FinishFuelSession(false)
                end
                S.holdingNozzle = true
                S.nozzleInVehicle = false
                S.vehicleFueling = false
                ClearPedTasks(S.ped)
                NSLegacyFuel.HideUI()
            end,
        },
        {
            name = "ns_legacyfuel_jerrycan_vehicle",
            icon = "fa-solid fa-gas-can",
            label = Config.Target.FuelVehicleWithJerryCan,
            -- Give ox_target enough range to display the option while the
            -- player is standing at the vehicle's fuel door. The actual tank
            -- distance is checked below.
            distance = 3.0,
            canInteract = function(entity)
                if not Config.JerryCan.Enabled or Config.Framework.Standalone then return false end
                if not DoesEntityExist(entity) or not NSLegacyFuel.IsFuelVehicle(entity) then return false end
                if S.holdingNozzle or S.nozzleInVehicle or S.canFueling then return false end

                -- Equipping the weapon is the authoritative check for this
                -- interaction. It also avoids inventory APIs hiding the option
                -- when the player is visibly holding a petrol can.
                if not NSLegacyFuel.IsJerryCanEquipped() then return false end

                local _, _, _, position = NSLegacyFuel.GetVehicleTankData(entity)
                return position and #(GetEntityCoords(S.ped) - position) < 2.25
            end,
            onSelect = function(data)
                NSLegacyFuel.StartJerryCanFueling(data.entity)
            end,
        },
    })
end)

-- Shared functions for this file. They are local so nothing else can call them
-- accidentally.
function isPumpLocked(entity)
    local key = entity and pumpLockKey(GetEntityCoords(entity))
    local locks = GlobalState.nsLegacyFuelPumpLocks
    return key ~= nil and locks ~= nil and locks[key] == true
end

function pumpLockKey(coords)
    if not coords then return nil end
    return string.format("%.1f:%.1f:%.1f", coords.x, coords.y, coords.z)
end

function setPumpLock(coords, locked, entity)
    local key = pumpLockKey(coords)
    if key then
        local pump = entity or S.pumpHandle
        local netId = pump and NetworkGetNetworkIdFromEntity(pump) or 0
        TriggerServerEvent("ns_legacyfuel:setPumpLock", key, locked == true, netId)
    end
end
