local S = NSLegacyFuel.State

if not Config.Framework.Standalone then
    ESX = exports["es_extended"]:getSharedObject()
end

-- Show one canonical gas-can fuel field in ox_inventory.
CreateThread(function()
    if GetResourceState("ox_inventory") == "started" then
        pcall(function()
            exports.ox_inventory:displayMetadata({ fuel = "Fuel Level" })
        end)
    end
end)

CreateThread(function()
    while true do
        S.ped = PlayerPedId()
        S.pedCoords = GetEntityCoords(S.ped)
        S.pump, S.pumpHandle = NSLegacyFuel.NearPump(S.pedCoords)
        Wait((S.holdingNozzle or S.nozzleInVehicle or S.nozzleDropped) and 150 or 750)
    end
end)

CreateThread(function()
    DecorRegister(Config.Fuel.Decor, 1)
end)

CreateThread(function()
    if not Config.Blips.Enabled then return end

    for _, coords in ipairs(Config.Blips.Locations) do
        local blip = AddBlipForCoord(coords)
        SetBlipSprite(blip, Config.Blips.Sprite)
        SetBlipScale(blip, Config.Blips.Scale)
        SetBlipColour(blip, Config.Blips.Colour)
        SetBlipDisplay(blip, Config.Blips.Display)
        SetBlipAsShortRange(blip, Config.Blips.ShortRange)

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Blips.Name)
        EndTextCommandSetBlipName(blip)
    end
end)

CreateThread(function()
    for _, pump in ipairs(Config.Pump.SpawnedPumps) do
        local object = CreateObject(
            joaat(pump.hash),
            pump.coords.x, pump.coords.y, pump.coords.z - 1.0,
            true, true, true
        )
        if object and object ~= 0 then
            SetEntityAsMissionEntity(object, true, true)
        end
    end
end)

-- Hose distance/drop monitoring is handled by client/nozzle.lua. Keeping a
-- single monitor prevents two threads from racing when a nozzle is picked up
-- or dropped.

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    SetNuiFocus(false, false)

    if S.nozzle and DoesEntityExist(S.nozzle) then
        if GetResourceState(Config.Target.Resource) == "started" then
            exports[Config.Target.Resource]:removeLocalEntity(S.nozzle)
        end
        SetEntityDrawOutline(S.nozzle, false)
        DeleteEntity(S.nozzle)
    end

    for entity in pairs(S.abandonedNozzles) do
        if DoesEntityExist(entity) then
            if GetResourceState(Config.Target.Resource) == "started" then
                exports[Config.Target.Resource]:removeLocalEntity(entity)
            end
            SetEntityDrawOutline(entity, false)
            DeleteEntity(entity)
        end
    end

    if S.rope then DeleteRope(S.rope) end
    RopeUnloadTextures()
end)

-- -------------------------------------------------------------------------
-- Gas-pump impact / explosion system
-- -------------------------------------------------------------------------
local pumpExplosionLocal = {}

local function getNearbyFuelPump(coords, radius)
    for modelHash, enabled in pairs(Config.Pump.Models or {}) do
        if enabled then
            local pump = GetClosestObjectOfType(
                coords.x, coords.y, coords.z,
                radius,
                modelHash,
                false, false, false
            )
            if pump and pump ~= 0 and DoesEntityExist(pump) then
                return pump
            end
        end
    end

    -- Also support pumps spawned by this resource even if their model is not
    -- included in the normal map-pump model table.
    for _, data in ipairs(Config.Pump.SpawnedPumps or {}) do
        local hash = type(data.hash) == "number" and data.hash or joaat(data.hash)
        local pump = GetClosestObjectOfType(
            coords.x, coords.y, coords.z,
            radius,
            hash,
            false, false, false
        )
        if pump and pump ~= 0 and DoesEntityExist(pump) then
            return pump
        end
    end

    return nil
end

local function pumpKeyFromEntity(pump)
    if not pump or pump == 0 or not DoesEntityExist(pump) then return nil end
    local c = GetEntityCoords(pump)
    return string.format("%.1f:%.1f:%.1f", c.x, c.y, c.z), c
end

-- Prevent GTA's built-in gas-pump destruction/explosion from bypassing the
-- configurable explosion system. Nearby pumps are protected and the resource
-- performs the custom explosion only when Config.Pump.Explosions.Enabled is true.
CreateThread(function()
    while true do
        local cfg = Config.Pump.Explosions
        if not cfg or cfg.PreventNativeExplosions ~= true then
            Wait(2000)
        else
            local ped = PlayerPedId()
            local pcoords = GetEntityCoords(ped)
            local found = false

            for modelHash, enabled in pairs(Config.Pump.Models or {}) do
                if enabled then
                    local pump = GetClosestObjectOfType(pcoords.x, pcoords.y, pcoords.z, 35.0, modelHash, false, false, false)
                    if pump and pump ~= 0 and DoesEntityExist(pump) then
                        SetEntityInvincible(pump, true)
                        SetEntityCanBeDamaged(pump, false)
                        found = true
                    end
                end
            end

            for _, data in ipairs(Config.Pump.SpawnedPumps or {}) do
                local hash = type(data.hash) == "number" and data.hash or joaat(data.hash)
                local pump = GetClosestObjectOfType(pcoords.x, pcoords.y, pcoords.z, 35.0, hash, false, false, false)
                if pump and pump ~= 0 and DoesEntityExist(pump) then
                    SetEntityInvincible(pump, true)
                    SetEntityCanBeDamaged(pump, false)
                    found = true
                end
            end

            Wait(found and 500 or 1500)
        end
    end
end)

RegisterNetEvent("ns_legacyfuel:pumpExplosion", function(pumpKey, coords)
    if not Config.Pump.Explosions or Config.Pump.Explosions.Enabled ~= true then return end
    if type(coords) ~= "vector3" and type(coords) ~= "table" then return end

    local now = GetGameTimer()
    local localCooldown = (tonumber(Config.Pump.Explosions.Cooldown) or 15) * 1000
    if pumpExplosionLocal[pumpKey] and now - pumpExplosionLocal[pumpKey] < localCooldown then
        return
    end
    pumpExplosionLocal[pumpKey] = now

    local c = vector3(coords.x, coords.y, coords.z)
    local cfg = Config.Pump.Explosions

    AddExplosion(
        c.x, c.y, c.z,
        tonumber(cfg.ExplosionType) or 2,
        tonumber(cfg.ExplosionDamageScale) or 1.0,
        cfg.ExplosionAudible ~= false,
        cfg.ExplosionInvisible == true,
        tonumber(cfg.ExplosionCameraShake) or 1.0
    )

    if cfg.DeletePumpAfterExplosion then
        local pump = getNearbyFuelPump(c, 2.5)
        if pump and DoesEntityExist(pump) then
            SetEntityAsMissionEntity(pump, true, true)
            DeleteEntity(pump)
        end
    end
end)

CreateThread(function()
    while true do
        local cfg = Config.Pump.Explosions
        if not cfg or cfg.Enabled ~= true then
            Wait(2000)
        else
            local ped = PlayerPedId()
            local pcoords = GetEntityCoords(ped)
            local vehicle = GetVehiclePedIsIn(ped, false)
            local shouldCheck = false

            if cfg.AllowVehicleImpact and vehicle ~= 0 and DoesEntityExist(vehicle) then
                if GetEntitySpeed(vehicle) >= (tonumber(cfg.VehicleMinSpeed) or 4.0)
                    and HasEntityCollidedWithAnything(vehicle) then
                    shouldCheck = true
                end
            end

            if not shouldCheck and cfg.AllowPlayerKick and vehicle == 0 then
                if IsControlJustPressed(0, 24)
                    and GetSelectedPedWeapon(ped) == `WEAPON_UNARMED` then
                    shouldCheck = true
                end
            end

            if shouldCheck then
                local radius = vehicle ~= 0
                    and (tonumber(cfg.VehicleImpactRadius) or 2.25)
                    or (tonumber(cfg.PlayerKickRadius) or 1.65)
                local pump = getNearbyFuelPump(pcoords, radius)
                if pump then
                    local key, coords = pumpKeyFromEntity(pump)
                    if key and coords then
                        TriggerServerEvent("ns_legacyfuel:requestPumpExplosion", key, {
                            x = coords.x, y = coords.y, z = coords.z
                        })
                    end
                end
            end

            Wait(100)
        end
    end
end)
