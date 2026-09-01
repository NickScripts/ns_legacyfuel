local S = NSLegacyFuel.State

local function getFuel(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return 0.0 end
    if not DecorExistOn(vehicle, Config.Fuel.Decor) then
        return GetVehicleFuelLevel(vehicle)
    end
    return DecorGetFloat(vehicle, Config.Fuel.Decor)
end

local function setFuel(vehicle, fuel)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    fuel = tonumber(fuel)
    if not fuel then return false end
    fuel = math.max(0.0, math.min(100.0, fuel))
    SetVehicleFuelLevel(vehicle, fuel + 0.0)
    DecorSetFloat(vehicle, Config.Fuel.Decor, fuel + 0.0)
    return true
end

-- Public exports. These names intentionally stay simple and framework-neutral.
exports("GetFuel", getFuel)
exports("SetFuel", setFuel)

-- Public integration exports. These are intentionally read-only snapshots so
-- other resources can integrate without reaching into internal state.
exports("IsFueling", function()
    return S.nozzleInVehicle == true or S.canFueling == true
end)

exports("GetCurrentPump", function()
    if S.usedPump and DoesEntityExist(S.usedPump) then
        return S.usedPump, S.pumpCoords
    end
    return nil, nil
end)

exports("GetFuelSession", function()
    if not S.nozzleInVehicle and not S.canFueling then
        return nil
    end

    return {
        active = true,
        type = S.canFueling and "jerrycan" or "pump",
        vehicle = S.vehicleFueling or S.canVehicle,
        fuelStart = tonumber(S.fuelSessionStart),
        fuelCurrent = (S.vehicleFueling and getFuel(S.vehicleFueling)) or nil,
        gallons = tonumber(S.fuelSessionGallons) or 0.0,
        grade = S.selectedFuelGrade,
        name = S.selectedFuelName,
        pricePerGallon = tonumber(S.selectedFuelPrice) or 0.0,
        pumpCoords = S.pumpCoords,
    }
end)

-- Also expose the functions globally for compatibility with scripts that
-- previously called GetFuel(vehicle) / SetFuel(vehicle) directly.
GetFuel = getFuel
SetFuel = setFuel

local function roundPaymentAmount(amount)
    -- The pump and the transaction both use cents. Only round the final
    -- calculated amount to two decimal places; never to a whole dollar.
    amount = tonumber(amount) or 0.0
    return math.floor((amount * 100.0) + 0.5) / 100.0
end

local function displayFuelAmount(amount)
    amount = tonumber(amount) or 0.0

    -- The pump display is always penny-accurate.
    return roundPaymentAmount(amount)
end

local function transactionGallons(gallons)
    -- The physical counter can run at sub-cent precision, but a real pump
    -- settles the sale using the gallons shown on its counter. This keeps the
    -- final bill deterministic and guarantees the UI total and server charge
    -- use the exact same gallon value.
    gallons = tonumber(gallons) or 0.0
    return math.floor((math.max(0.0, gallons) * 100.0) + 0.5) / 100.0
end

local function sendUI(message)
    SendNUIMessage(message)
end

function NSLegacyFuel.SendBalances()
    if Config.Framework.Standalone then return end
    sendUI({
        type = "balances",
        bankBalance = NSLegacyFuel.GetBankBalance(),
        cashBalance = NSLegacyFuel.GetCashBalance(),
    })
end

function NSLegacyFuel.OpenSelection()
    if not S.holdingNozzle then return end
    SetNuiFocus(true, true)
    sendUI({
        type = "showSelection",
        fuels = Config.Fuel.Types,
        bankBalance = NSLegacyFuel.GetBankBalance(),
        cashBalance = NSLegacyFuel.GetCashBalance(),
    })
end

function NSLegacyFuel.HideUI()
    SetNuiFocus(false, false)
    sendUI({ type = "status", status = false })
end

function NSLegacyFuel.ShowPaymentSummary(amount, gallons, grade, name)
    SetNuiFocus(true, true)
    sendUI({
        type = "paymentSummary",
        amount = math.max(0.0, tonumber(amount) or 0.0),
        gallons = math.max(0.0, tonumber(gallons) or 0.0),
        grade = grade,
        name = name,
        bankBalance = NSLegacyFuel.GetBankBalance(),
        cashBalance = NSLegacyFuel.GetCashBalance(),
    })
end

function NSLegacyFuel.StartFuelSession(vehicle)
    if not vehicle or vehicle == 0 then return false end
    if not S.selectedFuelGrade or S.selectedFuelPrice <= 0 then return false end
    S.fuelSessionStart = getFuel(vehicle)
    S.fuelSessionGallons = 0.0
    S.vehicleFueling = vehicle
    S.nozzleInVehicle = true
    S.holdingNozzle = false
    S.wastingFuel = false
    S.fuelUIVisible = true
    S.fuelServerSessionStarted = false
    S.fuelServerSessionToken = nil
    NSLegacyFuel.HideUI()
    sendUI({
        type = "fuelSelected",
        grade = S.selectedFuelGrade,
        name = S.selectedFuelName,
        price = S.selectedFuelPrice,
        fuelTank = getFuel(vehicle),
        bankBalance = NSLegacyFuel.GetBankBalance(),
        cashBalance = NSLegacyFuel.GetCashBalance(),
    })
    sendUI({ type = "status", status = true, selection = false })

    -- Tell the server the authoritative starting point for this transaction.
    -- The server will calculate the final amount from its recorded start.
    local pumpKey = S.pumpCoords and string.format("%.1f:%.1f:%.1f", S.pumpCoords.x, S.pumpCoords.y, S.pumpCoords.z)
    if pumpKey then
        TriggerServerEvent("ns_legacyfuel:beginFuelSession", pumpKey, NetworkGetNetworkIdFromEntity(S.usedPump), NetworkGetNetworkIdFromEntity(vehicle), S.fuelSessionStart, S.selectedFuelGrade, S.selectedFuelPrice)
    end

    NSLegacyFuel.PlayPumpFuelingAnimation()
    return true
end

local function availableFunds()
    if Config.Framework.Standalone then return math.huge end

    local bank = NSLegacyFuel.GetBankBalance()
    local cash = NSLegacyFuel.GetCashBalance()

    if Config.Payment.UseBankFirst then
        if bank >= 0 then
            if Config.Payment.AllowCashFallback then
                return math.max(bank, bank + cash)
            end
            return bank
        end
    elseif Config.Payment.AllowCashFallback then
        return bank + cash
    else
        return cash
    end

    return cash
end

function NSLegacyFuel.FinishFuelSession(showSummary)
    NSLegacyFuel.StopPumpFuelingAnimation()

    local price = tonumber(S.selectedFuelPrice) or 0.0
    local grade = S.selectedFuelGrade
    local name = S.selectedFuelName

    -- Capture the REAL final vehicle fuel level before clearing the session.
    -- vehicleFueling remains set while the nozzle is still attached so the
    -- completed UI and hose-distance logic can continue to reference it.
    local finalFuel = 0.0
    if S.vehicleFueling and DoesEntityExist(S.vehicleFueling) then
        finalFuel = getFuel(S.vehicleFueling)
    elseif S.fuelSessionStart then
        finalFuel = tonumber(S.fuelSessionStart) or 0.0
    end

    -- Use the gallons tracked by the fueling loop as the transaction amount.
    -- This keeps the amount charged exactly in sync with the amount shown by
    -- the pump UI. The final tank level is still captured separately for the
    -- vehicle state/display.
    local gallons = transactionGallons(S.fuelSessionGallons)
    local cost = roundPaymentAmount(math.max(0.0, gallons * price))

    if not S.fuelSessionStart or price <= 0 then
        S.fuelSessionStart = nil
        S.fuelSessionGallons = 0.0
        S.fuelUIVisible = false
        return 0.0, gallons, grade, name
    end

    if not Config.Framework.Standalone and cost > 0 and S.fuelServerSessionStarted and S.fuelServerSessionToken then
        TriggerServerEvent("ns_legacyfuel:finishFuelSession", S.fuelServerSessionToken, finalFuel, gallons, grade, price)
    end
    S.fuelServerSessionStarted = false
    S.fuelServerSessionToken = nil

    S.fuelSessionStart = nil
    S.fuelSessionGallons = 0.0
    S.fuelUIVisible = false

    -- Keep the normal refueling/refill screen visible while the nozzle is
    -- still inserted in the vehicle. Do NOT reopen the fuel-grade selector
    -- and do NOT switch to the payment-summary screen here. The UI is closed
    -- when the player pulls the nozzle back into their hand.
    if S.nozzleInVehicle then
        SetNuiFocus(false, false)
        SendNUIMessage({
            type = "fuelFinished",
            grade = grade,
            name = name,
            price = price,
            fuelTank = finalFuel,
            fuelCost = displayFuelAmount(gallons * price),
            gallons = gallons,
            bankBalance = NSLegacyFuel.GetBankBalance(),
            cashBalance = NSLegacyFuel.GetCashBalance(),
        })
        SendNUIMessage({ type = "status", status = true, selection = false })
        S.fuelUIVisible = true
    else
        NSLegacyFuel.HideUI()
    end

    return cost, gallons, grade, name
end

-- Keep the fueling UI local to the pump. Fueling continues even when the
-- player walks away; the UI simply hides until they come back.
CreateThread(function()
    while true do
        Wait(250)

        if S.nozzleInVehicle and S.vehicleFueling and S.pumpCoords and S.selectedFuelPrice > 0 then
            local distance = #(S.pedCoords - S.pumpCoords)
            local threshold = Config.Pump.FuelingUIDistance or 5.0
            local shouldShow = distance <= threshold

            if shouldShow ~= S.fuelUIVisible then
                S.fuelUIVisible = shouldShow
                SendNUIMessage({
                    type = "status",
                    status = shouldShow,
                    selection = false
                })
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(100)
        if S.vehicleFueling and S.nozzleInVehicle and S.selectedFuelPrice > 0 and S.fuelSessionStart ~= nil then
            local vehicle = S.vehicleFueling
            if not DoesEntityExist(vehicle) then
                NSLegacyFuel.FinishFuelSession()
                S.vehicleFueling = nil
                S.nozzleInVehicle = false
            else
                local current = getFuel(vehicle)
                if not S.fuelSessionStart then S.fuelSessionStart = current end

                -- Keep this outside the fuel-level condition so the session
                -- counter always has a valid value on every pump tick.
                local gallonsThisTick = 0.0

                if current < 100.0 then
                    local flowMultiplier = 1.0
                    for _, stage in ipairs(Config.Fuel.FlowTaper or {}) do
                        if current >= stage.minFuel then
                            flowMultiplier = stage.multiplier
                            break
                        end
                    end
                    local gallonsPerSecond = (Config.Fuel.PumpGallonsPerMinute / 60.0) * flowMultiplier
                    gallonsThisTick = gallonsPerSecond * 0.1
                    local percentThisTick = gallonsThisTick / Config.Fuel.GallonsPerFuelPercent
                    current = math.min(100.0, current + percentThisTick)
                    setFuel(vehicle, current)
                end

                -- The dispenser tick is the single source of truth for how
                -- many gallons were purchased. Do NOT recalculate this from
                -- the vehicle's 0-100 fuel percentage: native/decor precision
                -- and fuel-level conversions can drift, especially on larger
                -- purchases.
                S.fuelSessionGallons = math.max(
                    0.0,
                    (tonumber(S.fuelSessionGallons) or 0.0) + gallonsThisTick
                )

                -- The nozzle stays physically connected to the vehicle and
                -- fueling continues if the player walks away. Movement only
                -- breaks the pumping animation, so the player is never locked
                -- in place by the fueling task.
                if IsControlPressed(0, 30) or IsControlPressed(0, 31)
                    or IsControlPressed(0, 32) or IsControlPressed(0, 33)
                    or GetEntitySpeed(S.ped) > 0.25
                then
                    NSLegacyFuel.StopPumpFuelingAnimation()
                end

                local cost = roundPaymentAmount(S.fuelSessionGallons * S.selectedFuelPrice)
                if not Config.Framework.Standalone and cost >= availableFunds() and current < 100.0 then
                    -- Keep the vehicle reference alive through FinishFuelSession
                    -- so the completed UI reports the actual final fuel level.
                    NSLegacyFuel.FinishFuelSession()
                end

                -- Only send live-session updates while a session is still active.
                -- FinishFuelSession clears fuelSessionGallons, so sending another
                -- update after that would overwrite the completed 100% UI with 0.00.
                if S.fuelSessionStart ~= nil then
                    sendUI({
                        type = "update",
                        fuelCost = displayFuelAmount(transactionGallons(S.fuelSessionGallons) * S.selectedFuelPrice),
                        fuelTank = current,
                        gallons = transactionGallons(S.fuelSessionGallons),
                        bankBalance = NSLegacyFuel.GetBankBalance(),
                        cashBalance = NSLegacyFuel.GetCashBalance(),
                        pricePerGallon = S.selectedFuelPrice,
                    })
                end

                if current >= 100.0 then
                    -- Do not clear vehicleFueling here. The nozzle is still in the
                    -- vehicle, and we need the vehicle entity for the final 100%
                    -- display and for the vehicle-drive-away hose check.
                    NSLegacyFuel.FinishFuelSession()
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.Fuel.ConsumptionInterval)
        local vehicle = GetVehiclePedIsIn(S.ped, false)
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == S.ped then
            local class = GetVehicleClass(vehicle)
            local multiplier = Config.Fuel.VehicleClassMultipliers[class] or 0.0

            if not DecorExistOn(vehicle, Config.Fuel.Decor) then
                setFuel(vehicle, math.random(
                    Config.Fuel.InitialFuelMin * 10,
                    Config.Fuel.InitialFuelMax * 10
                ) / 10)
            end

            local current = getFuel(vehicle)
            if GetIsVehicleEngineRunning(vehicle) and multiplier > 0 then
                if current <= Config.Fuel.DisableEngineBelow then
                    DisableControlAction(0, 71, true)
                    SetVehicleEngineOn(vehicle, false, true, true)
                else
                    local rpm = GetVehicleCurrentRpm(vehicle)
                    setFuel(vehicle, current - ((rpm * multiplier) / Config.Fuel.ConsumptionDivisor))
                end
            end
        end
    end
end)

-- NUI callbacks.
RegisterNUICallback("uiReady", function(_, cb)
    SendNUIMessage({
        type = "uiConfig",
        ui = Config.UI,
    })
    cb({ ok = true })
end)

RegisterNUICallback("cancelFuelSelection", function(_, cb)
    NSLegacyFuel.HideUI()
    cb({ ok = true })
end)

RegisterNUICallback("selectFuel", function(data, cb)
    if not S.holdingNozzle or S.nozzleInVehicle or not S.nozzle then
        cb({ ok = false })
        return
    end

    local fuel = NSLegacyFuel.GetFuelType(data and data.grade)
    if not fuel then
        cb({ ok = false })
        return
    end

    S.selectedFuelGrade = tostring(fuel.grade)
    S.selectedFuelPrice = tonumber(fuel.price) or 0.0
    S.selectedFuelName = fuel.name or "REGULAR"

    SetNuiFocus(false, false)
    SendNUIMessage({
        type = "fuelSelected",
        grade = S.selectedFuelGrade,
        name = S.selectedFuelName,
        price = S.selectedFuelPrice,
        bankBalance = NSLegacyFuel.GetBankBalance(),
        cashBalance = NSLegacyFuel.GetCashBalance(),
    })
    cb({ ok = true })
end)

RegisterNetEvent("ns_legacyfuel:fuelSessionStarted", function(token, serverPrice, serverGrade)
    if not token then return end
    if not S.nozzleInVehicle or not S.vehicleFueling then return end

    -- The server is authoritative for the price used by this transaction.
    -- This makes the pump display and the eventual charge use the same grade
    -- price even if the client/server copies were previously out of sync.
    S.fuelServerSessionToken = tostring(token)
    S.fuelServerSessionStarted = true
    if serverGrade ~= nil and tostring(serverGrade) ~= tostring(S.selectedFuelGrade) then
        S.fuelServerSessionStarted = false
        S.fuelServerSessionToken = nil
        return
    end
    if serverPrice ~= nil then
        S.selectedFuelPrice = tonumber(serverPrice) or S.selectedFuelPrice
        SendNUIMessage({
            type = "fuelSelected",
            grade = S.selectedFuelGrade,
            name = S.selectedFuelName,
            price = S.selectedFuelPrice,
            fuelTank = S.vehicleFueling and getFuel(S.vehicleFueling) or 0.0,
            bankBalance = NSLegacyFuel.GetBankBalance(),
            cashBalance = NSLegacyFuel.GetCashBalance(),
        })
    end
end)

RegisterNetEvent("ns_legacyfuel:paymentResult", function(success, bank, cash, paidFrom, amount, rollbackFuel)
    if bank ~= nil or cash ~= nil then
        SendNUIMessage({
            type = "balances",
            bankBalance = bank or 0,
            cashBalance = cash or 0,
        })
    end

    -- Never leave the player with free fuel if the server could not settle the
    -- transaction. Restore the fuel level that existed when the sale began.
    if not success and rollbackFuel ~= nil and S.vehicleFueling and DoesEntityExist(S.vehicleFueling) then
        setFuel(S.vehicleFueling, rollbackFuel)
        S.fuelSessionGallons = 0.0
        SendNUIMessage({
            type = "update",
            fuelCost = 0.0,
            fuelTank = rollbackFuel,
            gallons = 0.0,
            bankBalance = bank or 0,
            cashBalance = cash or 0,
            pricePerGallon = S.selectedFuelPrice,
        })
    end
end)
