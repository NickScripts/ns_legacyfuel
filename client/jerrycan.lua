local S = NSLegacyFuel.State
local canWeapon = Config.JerryCan.WeaponHash
local jerryCanFuel = 0

RegisterNetEvent("ns_legacyfuel:syncJerryCanFuel", function(fuel)
    local capacity = math.max(1, tonumber(Config.JerryCan.Capacity) or 4500)
    jerryCanFuel = math.max(0, math.min(capacity, tonumber(fuel) or 0))
end)

-- Ask the server for the canonical metadata.fuel value whenever the can is equipped.
CreateThread(function()
    local wasEquipped = false
    while true do
        local equipped = GetSelectedPedWeapon(PlayerPedId()) == canWeapon
        if equipped and not wasEquipped then
            TriggerServerEvent("ns_legacyfuel:requestJerryCanSync")
        end
        wasEquipped = equipped
        Wait(equipped and 250 or 750)
    end
end)

RegisterNetEvent("ns_legacyfuel:jerryCanResult", function(success, action, newBank, newCash, amount, fuel)
    if newBank ~= nil or newCash ~= nil then
        SendNUIMessage({
            type = "balances",
            bankBalance = newBank or 0,
            cashBalance = newCash or 0,
        })
    end

    if not success then
        if action == "owned" then
            NSLegacyFuel.Notify("Jerry Can", "You already have a gas can.", "red")
        elseif action == "full" then
            NSLegacyFuel.Notify("Jerry Can", "Your gas can is already full.", "red")
        elseif action == "missing" then
            NSLegacyFuel.Notify("Jerry Can", "No gas can was found in your inventory.", "red")
        else
            NSLegacyFuel.Notify(Config.Payment.InsufficientFundsTitle, "You cannot afford that.", "red")
        end
        return
    end

    if action == "purchase" or action == "refill" then
        jerryCanFuel = math.max(0, math.min(Config.JerryCan.Capacity, tonumber(fuel) or Config.JerryCan.Capacity))
        if action == "purchase" then
            NSLegacyFuel.Notify("Jerry Can", "Jerry can purchased for $" .. tostring(amount) .. " (full)", "green")
        else
            NSLegacyFuel.Notify("Jerry Can", "Jerry can refilled for $" .. tostring(amount), "green")
        end
    end
end)

local function canUseJerryCan()
    return Config.JerryCan.Enabled
        and not Config.Framework.Standalone
        and GetSelectedPedWeapon(S.ped) == canWeapon
        and not S.holdingNozzle
        and not S.nozzleInVehicle
end

function NSLegacyFuel.StopJerryCanFueling()
    if not S.canFueling then return end

    S.canFueling = false
    S.usingCan = false
    S.canVehicle = nil
    S.canFuelUIVisible = false

    if IsEntityPlayingAnim(S.ped, Config.Animation.FuelDict, Config.Animation.FuelAnim, 3) then
        ClearPedTasks(S.ped)
    end

    SendNUIMessage({ type = "jerryStatus", status = false })
end

function NSLegacyFuel.StartJerryCanFueling(vehicle)
    if not canUseJerryCan() then return false end
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end

    local _, _, _, tankPos = NSLegacyFuel.GetVehicleTankData(vehicle)
    if not tankPos then return false end

    local fuel = GetFuel(vehicle)
    local canFuel = jerryCanFuel

    if fuel >= 100.0 then
        NSLegacyFuel.Notify("Jerry Can", "This vehicle is already full.", "red")
        return false
    end

    if canFuel <= 0 then
        NSLegacyFuel.Notify("Jerry Can", "Your gas can is empty.", "red")
        return false
    end

    S.canFueling = true
    S.usingCan = true
    S.canVehicle = vehicle
    S.canFuelUIVisible = true

    local anim = Config.Animation
    NSLegacyFuel.LoadAnimDict(anim.FuelDict)
    TaskPlayAnim(
        S.ped, anim.FuelDict, anim.FuelAnim,
        anim.BlendIn, anim.BlendOut, -1, anim.Flag, 0, false, false, false
    )

    SendNUIMessage({
        type = "jerryStatus",
        status = true,
        fuel = fuel,
        canFuel = canFuel,
        capacity = Config.JerryCan.Capacity,
        canPercent = (canFuel / Config.JerryCan.Capacity) * 100.0
    })

    return true
end

-- Third-eye vehicle fueling. Selecting the vehicle with the equipped can
-- starts fueling; walking away stops the fueling/animation.
CreateThread(function()
    while true do
        Wait(100)

        if S.canFueling and S.canVehicle then
            local vehicle = S.canVehicle

            if not DoesEntityExist(vehicle)
                or not canUseJerryCan()
            then
                NSLegacyFuel.StopJerryCanFueling()
            else
                local _, _, _, tankPos = NSLegacyFuel.GetVehicleTankData(vehicle)
                local distance = tankPos and #(S.pedCoords - tankPos) or 999.0
                local canFuel = jerryCanFuel
                local fuel = GetFuel(vehicle)

                -- Any movement breaks the fueling animation/session. This
                -- prevents the player from being glued to the vehicle.
                if distance > (Config.JerryCan.FuelingDistance + 0.75)
                    or IsControlPressed(0, 30) or IsControlPressed(0, 31)
                    or IsControlPressed(0, 32) or IsControlPressed(0, 33)
                    or GetEntitySpeed(S.ped) > 0.25
                    or IsPedDeadOrDying(S.ped, true)
                    or IsPedRagdoll(S.ped)
                then
                    NSLegacyFuel.StopJerryCanFueling()
                elseif canFuel <= 0 or fuel >= 100.0 then
                    NSLegacyFuel.StopJerryCanFueling()
                else
                    if not IsEntityPlayingAnim(S.ped, Config.Animation.FuelDict, Config.Animation.FuelAnim, 3) then
                        local a = Config.Animation
                        NSLegacyFuel.LoadAnimDict(a.FuelDict)
                        TaskPlayAnim(S.ped, a.FuelDict, a.FuelAnim, a.BlendIn, a.BlendOut, -1, a.Flag, 0, false, false, false)
                    end

                    local fuelPerTick = Config.JerryCan.AmmoPerTick * Config.JerryCan.FuelPerAmmo
                    local newFuel = math.min(100.0, fuel + fuelPerTick)
                    local used = math.max(1, math.min(
                        Config.JerryCan.AmmoPerTick,
                        math.ceil((newFuel - fuel) / Config.JerryCan.FuelPerAmmo)
                    ))

                    local remainingFuel = math.max(0, canFuel - used)
                    jerryCanFuel = remainingFuel

                    TriggerServerEvent("ns_legacyfuel:updateJerryCanFuel", remainingFuel)
                    SetFuel(vehicle, newFuel)

                    SendNUIMessage({
                        type = "jerryUpdate",
                        fuel = newFuel,
                        canFuel = remainingFuel,
                        capacity = Config.JerryCan.Capacity,
                        canPercent = (remainingFuel / Config.JerryCan.Capacity) * 100.0
                    })

                    if remainingFuel <= 0 then
                        NSLegacyFuel.Notify("Jerry Can", "Your gas can is empty. Refill it at a pump.", "red")
                        NSLegacyFuel.StopJerryCanFueling()
                    end
                end
            end
        end
    end
end)

function NSLegacyFuel.PurchaseJerryCan()
    if not Config.JerryCan.Enabled then return end
    if NSLegacyFuel.HasJerryCan() then
        NSLegacyFuel.Notify("Jerry Can", "You already have a gas can.", "red")
        return
    end
    TriggerServerEvent("ns_legacyfuel:purchaseJerryCan")
end

function NSLegacyFuel.RefillJerryCan()
    if not Config.JerryCan.Enabled then return end
    if not NSLegacyFuel.HasJerryCan() or GetSelectedPedWeapon(S.ped) ~= canWeapon then
        NSLegacyFuel.Notify("Jerry Can", "Equip your gas can first.", "red")
        return
    end

    if jerryCanFuel >= Config.JerryCan.Capacity then
        NSLegacyFuel.Notify("Jerry Can", "Your gas can is already full.", "red")
        return
    end

    TriggerServerEvent("ns_legacyfuel:refillJerryCan")
end
