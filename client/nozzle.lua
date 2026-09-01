local S = NSLegacyFuel.State

local function deleteRope()
    if S.rope then
        DeleteRope(S.rope)
        S.rope = nil
    end
end

local function pumpLockKey(coords)
    if not coords then return nil end
    return string.format("%.1f:%.1f:%.1f", coords.x, coords.y, coords.z)
end

local function setPumpLock(coords, locked)
    local key = pumpLockKey(coords)
    if key then
        TriggerServerEvent("ns_legacyfuel:setPumpLock", key, locked == true, (S.pumpHandle and NetworkGetNetworkIdFromEntity(S.pumpHandle) or 0))
    end
end

local function isPumpLocked(entity)
    if not entity or entity == 0 then return false end
    local key = pumpLockKey(GetEntityCoords(entity))
    local locks = GlobalState.nsLegacyFuelPumpLocks
    return key ~= nil and locks ~= nil and locks[key] == true
end

local function clearDroppedPumpLock()
    if S.droppedPumpCoords then
        setPumpLock(S.droppedPumpCoords, false)
    end
    S.droppedPumpHandle = nil
    S.droppedPumpCoords = nil
end

local function createRope()
    if not S.nozzle or not DoesEntityExist(S.nozzle) then return false end
    if not S.usedPump or not DoesEntityExist(S.usedPump) then return false end

    deleteRope()
    S.pumpCoords = GetEntityCoords(S.usedPump)

    RopeLoadTextures()
    local timeout = GetGameTimer() + 5000
    while not RopeAreTexturesLoaded() and GetGameTimer() < timeout do Wait(0) end
    if not RopeAreTexturesLoaded() then return false end

    local cfg = Config.Rope
    S.rope = AddRope(
        S.pumpCoords.x, S.pumpCoords.y, S.pumpCoords.z,
        0.0, 0.0, 0.0,
        cfg.Length, cfg.Type, cfg.MaxLength, 0.0, 1.0,
        false, false, false, 1.0, true
    )

    if not S.rope then return false end
    ActivatePhysics(S.rope)
    Wait(50)

    local nozzleOffset = Config.Pump.RopeNozzleOffset
    local pumpOffset = Config.Pump.RopePumpOffset
    local nozzlePos = GetOffsetFromEntityInWorldCoords(
        S.nozzle, nozzleOffset.x, nozzleOffset.y, nozzleOffset.z
    )
    AttachEntitiesToRope(
        S.rope,
        S.usedPump,
        S.nozzle,
        S.pumpCoords.x + pumpOffset.x,
        S.pumpCoords.y + pumpOffset.y,
        S.pumpCoords.z + pumpOffset.z,
        nozzlePos.x, nozzlePos.y, nozzlePos.z,
        cfg.Breakable, false, false, nil, nil
    )
    return true
end

local function attachNozzleToPlayer()
    AttachEntityToEntity(
        S.nozzle, S.ped, GetPedBoneIndex(S.ped, Config.Pump.PlayerAttach.bone),
        Config.Pump.PlayerAttach.x,
        Config.Pump.PlayerAttach.y,
        Config.Pump.PlayerAttach.z,
        Config.Pump.PlayerAttach.rx,
        Config.Pump.PlayerAttach.ry,
        Config.Pump.PlayerAttach.rz,
        true, true, false, true, 1, true
    )
end

function NSLegacyFuel.GrabNozzleFromPump()
    if not S.pumpHandle or S.pumpHandle == 0 then return end

    local anim = Config.Animation
    NSLegacyFuel.LoadAnimDict(anim.PumpDict)
    TaskPlayAnim(S.ped, anim.PumpDict, anim.PumpAnim, anim.BlendIn, anim.BlendOut, -1, anim.Flag, 0, false, false, false)
    Wait(300)

    S.nozzle = CreateObject(
        joaat(Config.Pump.NozzleModel),
        0.0, 0.0, 0.0,
        true, true, true
    )
    if not S.nozzle then return end

    attachNozzleToPlayer()
    S.usedPump = S.pumpHandle
    S.pumpCoords = GetEntityCoords(S.pumpHandle)

    createRope()

    S.nozzleDropped = false
    S.nozzleDropBlockedUntil = GetGameTimer() + 1500
    S.holdingNozzle = true
    S.nozzleInVehicle = false
    S.vehicleFueling = false
    S.selectedFuelGrade = nil
    S.selectedFuelPrice = 0.0
    S.fuelSessionStart = nil
    S.fuelSessionGallons = 0.0

    NSLegacyFuel.OpenSelection()
end

function NSLegacyFuel.GrabExistingNozzle()
    if not S.nozzle or not DoesEntityExist(S.nozzle) then return end

    if S.droppedPumpCoords then
        setPumpLock(S.droppedPumpCoords, false)
        S.droppedPumpHandle = nil
        S.droppedPumpCoords = nil
    end

    if S.nozzleInVehicle then
        NSLegacyFuel.FinishFuelSession()
    end

    SetEntityDrawOutline(S.nozzle, false)
    attachNozzleToPlayer()
    createRope()

    S.nozzleDropped = false
    S.nozzleDropBlockedUntil = GetGameTimer() + 1500
    S.holdingNozzle = true
    S.nozzleInVehicle = false
    S.vehicleFueling = false
    S.selectedFuelGrade = nil
    S.selectedFuelPrice = 0.0
    S.fuelSessionStart = nil
    S.fuelSessionGallons = 0.0

    NSLegacyFuel.OpenSelection()
end

function NSLegacyFuel.PutNozzleInVehicle(vehicle, tankBone, isBike, tankOffset)
    if not S.nozzle or not DoesEntityExist(S.nozzle) then return false end
    tankOffset = tankOffset or { x = 0.0, y = 0.0, z = 0.0 }

    if isBike then
        AttachEntityToEntity(
            S.nozzle, vehicle, tankBone,
            Config.Pump.VehicleAttach.Bike.x + tankOffset.x,
            Config.Pump.VehicleAttach.Bike.y + tankOffset.y,
            Config.Pump.VehicleAttach.Bike.z + tankOffset.z,
            Config.Pump.VehicleAttach.Bike.rx,
            Config.Pump.VehicleAttach.Bike.ry,
            Config.Pump.VehicleAttach.Bike.rz,
            true, true, false, false, 1, true
        )
    else
        AttachEntityToEntity(
            S.nozzle, vehicle, tankBone,
            Config.Pump.VehicleAttach.Vehicle.x + tankOffset.x,
            Config.Pump.VehicleAttach.Vehicle.y + tankOffset.y,
            Config.Pump.VehicleAttach.Vehicle.z + tankOffset.z,
            Config.Pump.VehicleAttach.Vehicle.rx,
            Config.Pump.VehicleAttach.Vehicle.ry,
            Config.Pump.VehicleAttach.Vehicle.rz,
            true, true, false, false, 1, true
        )
    end

    if not S.selectedFuelGrade or S.selectedFuelPrice <= 0 then return false end

    S.nozzleDropped = false
    S.nozzleDropBlockedUntil = GetGameTimer() + 1000
    S.holdingNozzle = false
    S.wastingFuel = false

    return NSLegacyFuel.StartFuelSession(vehicle)
end

function NSLegacyFuel.DropNozzle()
    if S.nozzleDropInProgress then return end
    if GetGameTimer() < (S.nozzleDropBlockedUntil or 0) then return end
    if not S.nozzle or not DoesEntityExist(S.nozzle) then return end

    -- Guard against multiple distance-monitor threads firing on the same tick.
    -- Without this, two DropNozzle calls can race and leave the nozzle in a
    -- state where it immediately drops again after being picked up.
    S.nozzleDropInProgress = true

    if S.nozzleInVehicle then
        NSLegacyFuel.FinishFuelSession()
    end

    S.droppedPumpHandle = S.usedPump
    S.droppedPumpCoords = S.pumpCoords
    -- The original pump lock remains owned by this player while the nozzle is dropped.
    -- Do not re-request the lock here because the player is intentionally beyond the pump radius.

    S.abandonedNozzles[S.nozzle] = {
        pump = S.usedPump,
        coords = S.pumpCoords,
        droppedAt = GetGameTimer(),
    }

    deleteRope()
    DetachEntity(S.nozzle, true, true)
    PlaceObjectOnGroundProperly(S.nozzle)
    FreezeEntityPosition(S.nozzle, false)
    SetEntityCollision(S.nozzle, true, true)
    SetEntityDrawOutline(S.nozzle, false)
    SetEntityDrawOutlineColor(229, 9, 47, 220)

    local droppedNetId = NetworkGetNetworkIdFromEntity(S.nozzle)
    local pumpKey = S.pumpCoords and string.format("%.1f:%.1f:%.1f", S.pumpCoords.x, S.pumpCoords.y, S.pumpCoords.z)
    if pumpKey then TriggerServerEvent("ns_legacyfuel:dropNozzle", pumpKey) end

    if GetResourceState(Config.Target.Resource) == "started" then
        exports[Config.Target.Resource]:addLocalEntity(S.nozzle, {
            {
                name = "ns_legacyfuel_pickup_dropped_nozzle",
                icon = "fa-solid fa-hand",
                label = "Pick Up Dropped Nozzle",
                distance = 3.0,
                canInteract = function(entity)
                    return not S.holdingNozzle
                        and not S.nozzleInVehicle
                        and S.abandonedNozzles[entity] ~= nil
                end,
                onSelect = function(data)
                    local droppedEntity = data.entity
                    if not S.abandonedNozzles[droppedEntity] then return end

                    local anim = Config.Animation
                    NSLegacyFuel.LoadAnimDict(anim.PickupDict)
                    TaskPlayAnim(S.ped, anim.PickupDict, anim.PickupAnim, anim.BlendIn, anim.BlendOut, -1, anim.Flag, 0, false, false, false)
                    Wait(700)

                    S.nozzle = droppedEntity
                    S.usedPump = S.abandonedNozzles[droppedEntity].pump
                    S.pumpCoords = S.abandonedNozzles[droppedEntity].coords
                    S.abandonedNozzles[droppedEntity] = nil
                    if GetResourceState(Config.Target.Resource) == "started" then
                        exports[Config.Target.Resource]:removeLocalEntity(droppedEntity)
                    end

                    NSLegacyFuel.GrabExistingNozzle()
                    ClearPedTasks(S.ped)
                end,
            },
        })
    end

    S.nozzleDropped = true
    S.holdingNozzle = false
    S.nozzleInVehicle = false
    S.vehicleFueling = false
    S.nozzleDropInProgress = false
    S.nozzleDropBlockedUntil = GetGameTimer() + 1000

    NSLegacyFuel.HideUI()
end

function NSLegacyFuel.ReturnNozzleToPump()
    if S.nozzleInVehicle then
        NSLegacyFuel.FinishFuelSession()
    end

    if S.nozzle and GetResourceState(Config.Target.Resource) == "started" then
        exports[Config.Target.Resource]:removeLocalEntity(S.nozzle)
    end

    if S.nozzle then
        S.abandonedNozzles[S.nozzle] = nil
        SetEntityDrawOutline(S.nozzle, false)
        DeleteEntity(S.nozzle)
    end

    deleteRope()
    RopeUnloadTextures()

    if S.pumpCoords then setPumpLock(S.pumpCoords, false) end
    clearDroppedPumpLock()

    S.nozzle = nil
    S.nozzleDropped = false
    S.nozzleDropInProgress = false
    S.nozzleDropBlockedUntil = GetGameTimer() + 500
    S.holdingNozzle = false
    S.nozzleInVehicle = false
    S.vehicleFueling = false
    S.usedPump = nil
    S.pumpCoords = nil
    S.selectedFuelGrade = nil
    S.selectedFuelPrice = 0.0
    S.fuelSessionStart = nil
    S.fuelSessionGallons = 0.0

    NSLegacyFuel.HideUI()
end

CreateThread(function()
    local wait = 500
    while true do
        Wait(wait)

        if S.holdingNozzle or S.nozzleInVehicle or S.nozzleDropped then
            wait = S.nozzleDropped and 250 or 100

            if S.pumpCoords and S.nozzle and not S.nozzleDropped
                and DoesEntityExist(S.nozzle) then
                local threshold = Config.Pump.HoseDropDistance or 6.0

                if GetGameTimer() >= (S.nozzleDropBlockedUntil or 0) then
                    if S.holdingNozzle and not S.nozzleInVehicle then
                        local attachedToPlayer = IsEntityAttachedToEntity(S.nozzle, S.ped)
                        if attachedToPlayer then
                            local playerDistance = #(GetEntityCoords(S.ped) - S.pumpCoords)
                            if playerDistance > threshold then
                                NSLegacyFuel.DropNozzle()
                            end
                        end
                    elseif S.nozzleInVehicle and S.vehicleFueling
                        and DoesEntityExist(S.vehicleFueling) then
                        local attachedToVehicle = IsEntityAttachedToEntity(S.nozzle, S.vehicleFueling)
                        if attachedToVehicle then
                            local vehicleDistance = #(GetEntityCoords(S.vehicleFueling) - S.pumpCoords)
                            if vehicleDistance > threshold then
                                NSLegacyFuel.DropNozzle()
                            end
                        end
                    end
                end
            end

            if S.holdingNozzle and S.nozzle then
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)

                if IsDisabledControlPressed(0, 24) then
                    local vehicle = NSLegacyFuel.VehicleInFront()
                    local bone, isBike, offset, tankPos = NSLegacyFuel.GetVehicleTankData(vehicle)

                    if tankPos and #(S.pedCoords - tankPos) < Config.Pump.FuelingTankDistance then
                        if not IsEntityPlayingAnim(
                            S.ped, Config.Animation.FuelDict, Config.Animation.FuelAnim, 3
                        ) then
                            local anim = Config.Animation
                            NSLegacyFuel.LoadAnimDict(anim.FuelDict)
                            TaskPlayAnim(S.ped, anim.FuelDict, anim.FuelAnim, anim.BlendIn, anim.BlendOut, -1, anim.Flag, 0, false, false, false)
                        end
                        S.wastingFuel = false
                        NSLegacyFuel.PutNozzleInVehicle(vehicle, bone, isBike, offset)
                    else
                        if not S.wastingFuel then
                            S.fuelSessionStart = 0.0
                            S.fuelSessionGallons = 0.0
                        end
                        S.wastingFuel = true
                        if DoesEntityExist(S.nozzle) then
                            CreateThread(function()
                                local effect = Config.Effects
                                local pos = GetOffsetFromEntityInWorldCoords(S.nozzle, 0.0, 0.28, 0.17)
                                UseParticleFxAssetNextCall(effect.ParticleAsset)
                                local pfx = StartParticleFxLoopedAtCoord(effect.ParticleName, pos.x, pos.y, pos.z, 0.0, 0.0, GetEntityHeading(S.nozzle), 1.0, false, false, false, false)
                                Wait(effect.Duration)
                                StopParticleFxLooped(pfx, 0)
                            end)
                        end
                    end
                else
                    S.vehicleFueling = false
                    if S.wastingFuel and S.fuelSessionGallons > 0 then
                        NSLegacyFuel.FinishFuelSession()
                    end
                    S.wastingFuel = false
                    if IsEntityPlayingAnim(S.ped, Config.Animation.FuelDict, Config.Animation.FuelAnim, 3) then
                        ClearPedTasks(S.ped)
                    end
                end
            end
        else
            wait = 500
        end
    end
end)


CreateThread(function()
    while true do
        Wait(100)

        if S.wastingFuel and S.holdingNozzle and S.selectedFuelPrice > 0 then
            local gallonsPerSecond = Config.Fuel.PumpGallonsPerMinute / 60.0
            local gallonsThisTick = gallonsPerSecond * 0.1
            S.fuelSessionGallons = S.fuelSessionGallons + gallonsThisTick

            local cost = S.fuelSessionGallons * S.selectedFuelPrice
            -- Keep the pump display penny-accurate while fuel is being wasted.
            local displayCost = math.floor((cost * 100.0) + 0.5) / 100.0

            SendNUIMessage({
                type = "update",
                fuelCost = displayCost,
                fuelTank = 0.0,
                gallons = S.fuelSessionGallons,
                bankBalance = NSLegacyFuel.GetBankBalance(),
                cashBalance = NSLegacyFuel.GetCashBalance(),
                pricePerGallon = S.selectedFuelPrice,
            })
        end
    end
end)



-- Only outline dropped nozzles when the player is within the same hose distance.
CreateThread(function()
    while true do
        local wait = 1000
        if S.nozzleDropped and S.nozzle and DoesEntityExist(S.nozzle) then
            wait = 250
            local distance = #(GetEntityCoords(S.ped) - GetEntityCoords(S.nozzle))
            local threshold = Config.Pump.HoseDropDistance or 6.0
            local outline = distance <= threshold
            SetEntityDrawOutline(S.nozzle, outline)
            if outline then SetEntityDrawOutlineColor(229, 9, 47, 220) end
        end
        Wait(wait)
    end
end)

-- Clean up forgotten dropped nozzles so a busy server cannot accumulate them forever.
CreateThread(function()
    while true do
        Wait(30000)
        local now = GetGameTimer()
        local lifetime = (Config.Pump.DroppedNozzleLifetime or 600) * 1000
        for entity, data in pairs(S.abandonedNozzles) do
            if not DoesEntityExist(entity) or (data.droppedAt and now - data.droppedAt > lifetime) then
                if DoesEntityExist(entity) then
                    if GetResourceState(Config.Target.Resource) == "started" then
                        exports[Config.Target.Resource]:removeLocalEntity(entity)
                    end
                    SetEntityDrawOutline(entity, false)
                    DeleteEntity(entity)
                end
                S.abandonedNozzles[entity] = nil
                if data and data.coords then setPumpLock(data.coords, false) end
            end
        end
    end
end)
