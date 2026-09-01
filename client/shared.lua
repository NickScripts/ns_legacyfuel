NSLegacyFuel = NSLegacyFuel or {}
NSLegacyFuel.State = NSLegacyFuel.State or {
    ped = 0,
    pedCoords = vector3(0.0, 0.0, 0.0),
    pump = nil,
    pumpHandle = nil,

    nozzle = nil,
    rope = nil,
    usedPump = nil,
    pumpCoords = nil,

    holdingNozzle = false,
    nozzleInVehicle = false,
    nozzleDropped = false,
    nozzleDropInProgress = false,
    nozzleDropBlockedUntil = 0,
    vehicleFueling = nil,
    wastingFuel = false,
    usingCan = false,
    canFueling = false,
    canVehicle = nil,
    canFuelUIVisible = false,
    fuelUIVisible = false,

    selectedFuelGrade = nil,
    selectedFuelPrice = 0.0,
    selectedFuelName = "REGULAR",
    fuelSessionStart = nil,
    fuelSessionGallons = 0.0,
    fuelServerSessionStarted = false,
    fuelServerSessionToken = nil,

    droppedPumpHandle = nil,
    droppedPumpCoords = nil,
    abandonedNozzles = {},
}

local S = NSLegacyFuel.State

function NSLegacyFuel.Debug(...)
    if not Config.Debug then return end
    print(("[ns_legacyfuel] "):gsub("%s+$", ""), ...)
end

function NSLegacyFuel.Notify(title, message, color)
    local notifications = Config.Notifications or {}
    local mode = string.lower(tostring(notifications.Mode or "event"))
    local icon = notifications.Icon or "fa-solid fa-bell"
    local notifyColor = color or notifications.Color or "red"
    local duration = tonumber(notifications.Duration) or 5000

    if mode == "client_export" then
        local resource = tostring(notifications.Resource or "")
        local exportName = tostring(notifications.Export or "")
        if resource == "" or exportName == "" then
            print("^1[ns_legacyfuel] Notifications.Mode is client_export but Resource/Export is not configured.^0")
            return
        end

        if GetResourceState(resource) ~= "started" then
            print(("^1[ns_legacyfuel] Notification resource '%s' is not started.^0"):format(resource))
            return
        end

        local values = {
            title = title,
            message = message,
            icon = icon,
            color = notifyColor,
            duration = duration,
        }
        local arguments = notifications.Arguments or { "title", "message", "icon", "color", "duration" }
        local args = {}
        for _, key in ipairs(arguments) do
            key = string.lower(tostring(key))
            if values[key] ~= nil then
                args[#args + 1] = values[key]
            else
                print(("^3[ns_legacyfuel] Unknown notification argument '%s'.^0"):format(tostring(key)))
                return
            end
        end

        local ok, err = pcall(function()
            exports[resource][exportName](table.unpack(args))
        end)
        if not ok then
            print(("^1[ns_legacyfuel] Notification export %s:%s failed: %s^0"):format(resource, exportName, tostring(err)))
        end
        return
    end

    if mode == "builtin" then
        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName(('%s: %s'):format(tostring(title or "Fuel"), tostring(message or "")))
        EndTextCommandThefeedPostTicker(false, true)
        return
    end

    if mode == "event" then
        local event = notifications.Event
        if not event or event == "" then
            print("^3[ns_legacyfuel] Notifications.Mode is event but Notifications.Event is empty. Falling back to builtin notification.^0")
            BeginTextCommandThefeedPost("STRING")
            AddTextComponentSubstringPlayerName(("%s: %s"):format(tostring(title or "Fuel"), tostring(message or "")))
            EndTextCommandThefeedPostTicker(false, true)
            return
        end

        local values = {
            title = title,
            message = message,
            icon = icon,
            color = notifyColor,
            duration = duration,
        }

        local arguments = notifications.Arguments or { "title", "message", "icon", "color", "duration" }
        local args = {}

        for _, key in ipairs(arguments) do
            key = string.lower(tostring(key))
            if values[key] ~= nil then
                args[#args + 1] = values[key]
            else
                print(("^3[ns_legacyfuel] Unknown notification event argument '%s'.^0"):format(tostring(key)))
                return
            end
        end

        local ok, err = pcall(function()
            TriggerEvent(event, table.unpack(args))
        end)

        if not ok then
            print(("^1[ns_legacyfuel] Notification event '%s' failed: %s^0"):format(tostring(event), tostring(err)))
        end
        return
    end

    print(("^3[ns_legacyfuel] Unsupported client notification mode '%s'. Use 'event' or 'client_export'.^0"):format(mode))
end

RegisterNetEvent("ns_legacyfuel:notify", function(title, message, color)
    NSLegacyFuel.Notify(title, message, color)
end)

function NSLegacyFuel.LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end
end


function NSLegacyFuel.IsJerryCanEquipped()
    return Config.JerryCan.Enabled
        and GetSelectedPedWeapon(S.ped) == Config.JerryCan.WeaponHash
end

function NSLegacyFuel.GetJerryCanInventoryCount()
    if not Config.JerryCan.Enabled or Config.Framework.Standalone then return 0 end

    -- Equipped means the player definitely owns a can. Some ox_inventory
    -- versions represent weapon items differently from normal items.
    if GetSelectedPedWeapon(S.ped) == Config.JerryCan.WeaponHash then
        return 1
    end

    local itemName = tostring(Config.JerryCan.Item or "weapon_petrolcan")
    local itemNameLower = string.lower(itemName)
    local inventory = Config.JerryCan.Inventory or {}
    local mode = string.lower(tostring(inventory.Mode or "auto"))
    local resource = inventory.Resource or "ox_inventory"

    if (mode == "auto" or mode == "ox_inventory") and GetResourceState(resource) == "started" then
        for _, name in ipairs({ itemName, string.upper(itemName) }) do
            local ok, count = pcall(function()
                return exports[resource]:Search("count", name)
            end)
            if ok and tonumber(count) and tonumber(count) > 0 then
                return tonumber(count)
            end
        end

        local ok, items = pcall(function()
            return exports[resource]:GetInventoryItems()
        end)
        if ok and type(items) == "table" then
            local total = 0
            for _, item in pairs(items) do
                if string.lower(tostring(item.name or "")) == itemNameLower then
                    total = total + (tonumber(item.count) or tonumber(item.amount) or 1)
                end
            end
            if total > 0 then return total end
        end
    end

    local playerData = ESX and ESX.GetPlayerData() or nil
    if playerData then
        local total = 0
        if playerData.inventory then
            for _, item in pairs(playerData.inventory) do
                if string.lower(tostring(item.name or "")) == itemNameLower then
                    total = total + (tonumber(item.count) or tonumber(item.amount) or 0)
                end
            end
        end
        if total == 0 and playerData.loadout then
            for _, weapon in pairs(playerData.loadout) do
                if string.lower(tostring(weapon.name or "")) == itemNameLower then
                    total = 1
                    break
                end
            end
        end
        if total > 0 then return total end
    end

    if HasPedGotWeapon(S.ped, Config.JerryCan.WeaponHash, false) then
        return 1
    end

    return 0
end

function NSLegacyFuel.HasJerryCan()
    return NSLegacyFuel.GetJerryCanInventoryCount() > 0
end

function NSLegacyFuel.PlayPumpFuelingAnimation()
    if not S.ped or S.ped == 0 then return end
    local anim = Config.Animation
    NSLegacyFuel.LoadAnimDict(anim.PumpFuelingDict)
    if not IsEntityPlayingAnim(S.ped, anim.PumpFuelingDict, anim.PumpFuelingAnim, 3) then
        TaskPlayAnim(
            S.ped, anim.PumpFuelingDict, anim.PumpFuelingAnim,
            anim.PumpFuelingBlendIn, anim.PumpFuelingBlendOut, -1,
            anim.PumpFuelingFlag, 0, false, false, false
        )
    end
end

function NSLegacyFuel.StopPumpFuelingAnimation()
    local anim = Config.Animation
    if IsEntityPlayingAnim(S.ped, anim.PumpFuelingDict, anim.PumpFuelingAnim, 3) then
        StopAnimTask(S.ped, anim.PumpFuelingDict, anim.PumpFuelingAnim, anim.BlendOut)
    end
end

function NSLegacyFuel.GetBankBalance()
    if Config.Framework.Standalone then return 0 end
    local xPlayer = ESX.GetPlayerData()
    if not xPlayer or not xPlayer.accounts then return 0 end
    for _, account in pairs(xPlayer.accounts) do
        if account.name == "bank" then
            return tonumber(account.money or account.balance or 0) or 0
        end
    end
    return 0
end

function NSLegacyFuel.GetCashBalance()
    if Config.Framework.Standalone then return 0 end
    local xPlayer = ESX.GetPlayerData()
    return xPlayer and tonumber(xPlayer.money or xPlayer.cash or 0) or 0
end

function NSLegacyFuel.GetFuelType(grade)
    for _, fuel in ipairs(Config.Fuel.Types) do
        if tostring(fuel.grade) == tostring(grade) then
            return fuel
        end
    end
end

function NSLegacyFuel.IsElectric(vehicle)
    if not vehicle or vehicle == 0 then return false end
    if not DoesEntityExist(vehicle) then return false end
    if not IsEntityAVehicle(vehicle) then return false end

    -- ox_target can briefly hand us a stale entity handle while an entity is
    -- streaming out. Protect the native lookup so the target option cannot
    -- crash the client in that case.
    local ok, model = pcall(GetEntityModel, vehicle)
    if not ok or not model then return false end

    return Config.Fuel.ElectricVehicleHashes[model] == true
end

function NSLegacyFuel.IsFuelVehicle(vehicle)
    if not vehicle or vehicle == 0 then return false end
    if not DoesEntityExist(vehicle) then return false end
    if not IsEntityAVehicle(vehicle) then return false end

    local ok, vehicleClass = pcall(GetVehicleClass, vehicle)
    if not ok or vehicleClass == nil then return false end

    return vehicleClass ~= 13 and not NSLegacyFuel.IsElectric(vehicle)
end

function NSLegacyFuel.GetVehicleTankData(vehicle)
    if not NSLegacyFuel.IsFuelVehicle(vehicle) then return nil end

    local class = GetVehicleClass(vehicle)
    local bone = -1
    local isBike = false
    local offset = { x = 0.0, y = 0.0, z = 0.0 }

    if class == 8 then
        bone = GetEntityBoneIndexByName(vehicle, "petrolcap")
        if bone == -1 then bone = GetEntityBoneIndexByName(vehicle, "petroltank") end
        if bone == -1 then bone = GetEntityBoneIndexByName(vehicle, "engine") end
        isBike = true
    else
        bone = GetEntityBoneIndexByName(vehicle, "petrolcap")
        if bone == -1 then bone = GetEntityBoneIndexByName(vehicle, "petroltank_l") end
        if bone == -1 then bone = GetEntityBoneIndexByName(vehicle, "hub_lr") end
        if bone == -1 then
            bone = GetEntityBoneIndexByName(vehicle, "handle_dside_r")
            offset.x, offset.y, offset.z = 0.1, -0.5, -0.6
        end
    end

    if bone == -1 then return nil end
    local position = GetWorldPositionOfEntityBone(vehicle, bone)
    if not position then return nil end

    return bone, isBike, offset, position
end

function NSLegacyFuel.VehicleInFront()
    local offset = GetOffsetFromEntityInWorldCoords(S.ped, 0.0, 2.0, 0.0)
    local ray = CastRayPointToPoint(
        S.pedCoords.x, S.pedCoords.y, S.pedCoords.z - 1.3,
        offset.x, offset.y, offset.z,
        10, S.ped, 0
    )
    local _, _, _, _, entity = GetRaycastResult(ray)
    if IsEntityAVehicle(entity) then return entity end
end

function NSLegacyFuel.NearPump(coords)
    if not coords then return nil end
    for hash in pairs(Config.Pump.Models) do
        local entity = GetClosestObjectOfType(
            coords.x, coords.y, coords.z,
            Config.Pump.SearchRadius, hash, true, true, true
        )
        if entity and entity ~= 0 then
            return GetEntityCoords(entity), entity
        end
    end
end

function NSLegacyFuel.DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.4, 0.4)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextEntry("STRING")
    SetTextCentre(true)
    SetTextColour(255, 255, 255, 255)
    SetTextOutline()
    AddTextComponentString(text)
    DrawText(sx, sy)
end
