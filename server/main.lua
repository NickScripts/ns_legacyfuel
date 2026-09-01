local ESX = nil
if not Config.Framework.Standalone then
    ESX = exports["es_extended"]:getSharedObject()
end
local pumpLocks = {}
local fuelSessions = {}
local jerryCanState = {}
math.randomseed(os.time() + GetGameTimer())

local function isValidPumpEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    local model = GetEntityModel(entity)
    if Config.Pump.Models[model] == true then return true end
    for _, data in ipairs(Config.Pump.SpawnedPumps or {}) do
        local hash = type(data.hash) == "number" and data.hash or joaat(data.hash)
        if hash == model then return true end
    end
    return false
end

local function playerNearEntity(src, entity, maxDistance)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    return #(GetEntityCoords(ped) - GetEntityCoords(entity)) <= maxDistance
end

local function getJerryCanServerState(src)
    local capacity = math.max(1, tonumber(Config.JerryCan.Capacity) or 4500)
    if GetResourceState("ox_inventory") == "started" then
        local ox = exports.ox_inventory
        local ok, weapon = pcall(function() return ox:GetCurrentWeapon(src) end)
        if ok and weapon and tostring(weapon.name) == tostring(Config.JerryCan.Item) and weapon.slot then
            local metadata = weapon.metadata or {}
            -- `fuel` is the canonical jerry-can level. Do not use ox weapon
            -- ammo metadata here: ox_inventory can use that value for weapon/item
            -- handling and weight calculations.
            local ammo = tonumber(metadata.fuel)
            if ammo == nil then ammo = tonumber(weapon.ammo) end
            if ammo == nil then ammo = capacity end
            return math.max(0, math.min(capacity, math.floor(ammo))), weapon.slot, metadata
        end
        local okSlot, slot = pcall(function() return ox:GetSlotIdWithItem(src, Config.JerryCan.Item) end)
        if okSlot and slot then
            local okData, data = pcall(function() return ox:GetSlot(src, slot) end)
            if okData and data then
                local metadata = data.metadata or {}
                local ammo = tonumber(metadata.fuel)
                if ammo == nil then ammo = tonumber(data.ammo) end
                if ammo == nil then ammo = capacity end
                return math.max(0, math.min(capacity, math.floor(ammo))), slot, metadata
            end
        end
    end

    local xPlayer = ESX and ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.getWeapon then
        local ok, weapon = pcall(function() return xPlayer.getWeapon(Config.JerryCan.Item) end)
        if ok and weapon then
            return math.max(0, math.min(capacity, math.floor(tonumber(weapon.ammo) or 0))), nil, nil
        end
    end
    return nil, nil, nil
end

local function setJerryCanServerState(src, ammo, slot, metadata)
    local capacity = math.max(1, tonumber(Config.JerryCan.Capacity) or 4500)
    ammo = math.max(0, math.min(capacity, math.floor(tonumber(ammo) or 0)))
    local percent = math.max(0.0, math.min(100.0, (ammo / capacity) * 100.0))

    local xPlayer = ESX and ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.updateWeaponAmmo then
        pcall(function() xPlayer.updateWeaponAmmo(Config.JerryCan.Item, ammo) end)
    end

    if GetResourceState("ox_inventory") == "started" then
        local ox = exports.ox_inventory
        if slot then
            metadata = metadata or {}
            metadata.fuel = ammo
            -- Remove old fields left by previous versions. `ammo` metadata can
            -- alter ox_inventory weapon weight and `durability` caused duplicate UI.
            metadata.ammo = nil
            metadata.durability = nil
            pcall(function() ox:SetMetadata(src, slot, metadata) end)
        end
    end

    jerryCanState[src] = ammo
    return ammo, percent
end

local function notifyPlayer(src, title, message, color)
    local notifications = Config.Notifications or {}
    local mode = string.lower(tostring(notifications.Mode or "event"))
    local icon = notifications.Icon or "fa-solid fa-bell"
    local notifyColor = color or notifications.Color or "red"
    local duration = tonumber(notifications.Duration) or 5000

    if mode == "server_export" then
        local resource = tostring(notifications.Resource or "")
        local exportName = tostring(notifications.Export or "")
        if resource == "" or exportName == "" then
            print("^1[ns_legacyfuel] Notifications.Mode is server_export but Resource/Export is not configured.^0")
            return
        end
        if GetResourceState(resource) ~= "started" then
            print(("^1[ns_legacyfuel] Notification resource '%s' is not started.^0"):format(resource))
            return
        end

        local ok, err = pcall(function()
            exports[resource][exportName](src, title, message, icon, notifyColor, duration)
        end)
        if not ok then
            print(("^1[ns_legacyfuel] Server notification export %s:%s failed: %s^0"):format(resource, exportName, tostring(err)))
        end
        return
    end

    -- Route server-side notifications through the client helper. This keeps
    -- the configured event argument order consistent with client notifications.
    if mode == "event" or mode == "server_event" then
        TriggerClientEvent("ns_legacyfuel:notify", src, title, message, notifyColor)
        return
    end

    -- For a client export, route the notification through the shared client helper.
    if mode == "client_export" then
        TriggerClientEvent("ns_legacyfuel:notify", src, title, message, notifyColor)
        return
    end

    print(("^3[ns_legacyfuel] Unsupported server notification mode '%s'.^0"):format(mode))
end

local function publishPumpLocks()
    local publicLocks = {}
    for key, data in pairs(pumpLocks) do
        publicLocks[key] = true
    end
    GlobalState.nsLegacyFuelPumpLocks = publicLocks
end

local function getFuelPrice(grade)
    grade = tostring(grade or "")

    -- Read the raw configured grade table on the server instead of relying on
    -- the derived Config.Fuel.Types table. This makes the price used for money
    -- transactions unambiguous: BasePricePerGallon + that grade's priceOffset.
    for _, fuel in ipairs(Config.Fuel.FuelTypes or {}) do
        if tostring(fuel.grade) == grade then
            local base = tonumber(Config.Fuel.BasePricePerGallon) or 0.0
            local offset = tonumber(fuel.priceOffset) or 0.0
            return math.floor(((base + offset) * 100.0) + 0.5) / 100.0
        end
    end

    return nil
end

local function newFuelSessionToken(src)
    return (('%s:%s:%s'):format(tostring(src), tostring(GetGameTimer()), tostring(math.random(100000, 999999))))
end

local function roundAmount(amount)
    -- Gas pumps bill to the cent. Keep the exact transaction amount shown
    -- by the UI and only round the final result to two decimal places.
    amount = tonumber(amount) or 0.0
    return math.floor((amount * 100.0) + 0.5) / 100.0
end

local function safeVehicleFromNetId(netId)
    netId = tonumber(netId) or 0
    if netId <= 0 then return 0 end

    local ok, entity = pcall(function()
        return NetworkGetEntityFromNetworkId(netId)
    end)
    if not ok or not entity or entity == 0 or not DoesEntityExist(entity) then
        return 0
    end

    local okType, entityType = pcall(function()
        return GetEntityType(entity)
    end)
    if okType and entityType ~= 2 then
        return 0
    end

    return entity
end

local function logTransaction(src, session, finalFuel, gallons, amount, paidFrom)
    local logging = Config.Logging or {}
    if logging.Enabled ~= true then return end

    local playerName = GetPlayerName(src) or ("ID " .. tostring(src))
    local plate = "UNKNOWN"
    local vehicle = safeVehicleFromNetId(session.netId)
    if vehicle ~= 0 then
        local ok, value = pcall(function() return GetVehicleNumberPlateText(vehicle) end)
        if ok and value and value ~= "" then plate = value end
    end

    local playerPart = logging.IncludePlayerName ~= false and (" player=" .. playerName) or ""
    local platePart = logging.IncludePlate ~= false and (" plate=" .. plate) or ""
    print(("[ns_legacyfuel] transaction src=%s%s%s pump=%s grade=%s start=%.2f final=%.2f gallons=%.2f amount=$%.2f payment=%s"):format(
        src, playerPart, platePart, session.pumpKey, session.grade,
        tonumber(session.startFuel) or 0.0, tonumber(finalFuel) or 0.0,
        tonumber(gallons) or 0.0, tonumber(amount) or 0.0, paidFrom or "UNKNOWN"
    ))
end

local function balances(xPlayer)
    local bankAccount = xPlayer.getAccount("bank")
    local bank = bankAccount and tonumber(bankAccount.money or 0) or 0
    local cash = tonumber(xPlayer.getMoney() or 0) or 0
    return bank, cash
end

local function removePayment(xPlayer, amount, bankFirst, cashFallback)
    local bank, cash = balances(xPlayer)
    local paidFrom

    if bankFirst and bank >= amount then
        xPlayer.removeAccountMoney("bank", amount)
        paidFrom = "BANK"
    elseif cashFallback and cash >= amount then
        xPlayer.removeMoney(amount)
        paidFrom = "CASH"
    elseif not bankFirst and cash >= amount then
        xPlayer.removeMoney(amount)
        paidFrom = "CASH"
    elseif not bankFirst and cashFallback and bank >= amount then
        xPlayer.removeAccountMoney("bank", amount)
        paidFrom = "BANK"
    end

    if not paidFrom then return false, bank, cash end

    local newBank, newCash = balances(xPlayer)
    return paidFrom, newBank, newCash
end

RegisterNetEvent("ns_legacyfuel:setPumpLock", function(key, locked, pumpNetId)
    if type(key) ~= "string" or #key > 64 then return end
    local src = source
    local x, y, z = key:match("^([%-0-9%.]+):([%-0-9%.]+):([%-0-9%.]+)$")
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z or math.abs(x) > 10000 or math.abs(y) > 10000 or z < -100 or z > 2000 then return end

    -- Map pumps are often local/non-networked entities, so a server-side
    -- network-id lookup is not reliable for every FiveM map. Instead validate
    -- that the player is actually at the pump coordinates. The lock itself is
    -- only a concurrency control and never grants money/items.
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    if #(GetEntityCoords(ped) - vector3(x, y, z)) > ((tonumber(Config.Pump.InteractionDistance) or 2.0) + 2.5) then return end

    if locked then
        local existing = pumpLocks[key]
        if existing and existing.owner ~= src then return end
        pumpLocks[key] = { owner = src, at = os.time(), pumpNetId = tonumber(pumpNetId) or 0 }
    else
        local existing = pumpLocks[key]
        if existing and existing.owner ~= src then return end
        pumpLocks[key] = nil
    end
    publishPumpLocks()
end)

RegisterNetEvent("ns_legacyfuel:beginFuelSession", function(pumpKey, pumpNetId, netId, startFuel, grade, clientPrice)
    if type(pumpKey) ~= "string" or #pumpKey > 64 then return end
    local src = source
    local existing = pumpLocks[pumpKey]
    if not existing or existing.owner ~= src then return end

    if fuelSessions[src] then return end

    local price = getFuelPrice(grade)
    clientPrice = tonumber(clientPrice)
    startFuel = tonumber(startFuel)
    local vehicle = safeVehicleFromNetId(netId)
    if not price or not startFuel or startFuel < 0 or startFuel > 100 then return end
    if vehicle == 0 then return end

    local px, py, pz = pumpKey:match("^([%-0-9%.]+):([%-0-9%.]+):([%-0-9%.]+)$")
    px, py, pz = tonumber(px), tonumber(py), tonumber(pz)
    if not px or not py or not pz then return end
    local pumpCoords = vector3(px, py, pz)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    if #(GetEntityCoords(ped) - pumpCoords) > ((tonumber(Config.Pump.VehicleTankDistance) or 3.0) + 4.0) then return end
    if #(GetEntityCoords(vehicle) - pumpCoords) > ((tonumber(Config.Pump.HoseDropDistance) or 6.0) + 4.0) then return end

    -- The grade is authoritative. The client price is accepted only as a
    -- diagnostic value; the server always uses the configured price for that
    -- grade, so a client cannot invent a cheaper or more expensive price.
    local token = newFuelSessionToken(src)
    fuelSessions[src] = {
        token = token,
        pumpKey = pumpKey,
        pumpNetId = tonumber(pumpNetId) or 0,
        netId = tonumber(netId) or 0,
        startFuel = startFuel,
        grade = tostring(grade),
        price = price,
        clientPrice = clientPrice,
        startedAt = GetGameTimer(),
        paid = false,
    }

    TriggerClientEvent("ns_legacyfuel:fuelSessionStarted", src, token, price, tostring(grade))
end)

RegisterNetEvent("ns_legacyfuel:finishFuelSession", function(token, finalFuel, reportedGallons, clientGrade, clientPrice)
    local src = source
    local session = fuelSessions[src]
    if not session or session.paid then return end
    if tostring(token or "") ~= tostring(session.token or "") then return end
    if clientGrade ~= nil and tostring(clientGrade) ~= tostring(session.grade) then return end
    if clientPrice ~= nil and math.abs((tonumber(clientPrice) or 0.0) - (tonumber(session.price) or 0.0)) > 0.001 then
        if Config.Debug then
            print(("^3[ns_legacyfuel] price mismatch src=%s grade=%s client=%.2f server=%.2f; using server price.^0"):format(src, session.grade, tonumber(clientPrice) or 0.0, tonumber(session.price) or 0.0))
        end
    end
    fuelSessions[src] = nil

    local xPlayer = ESX and ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local function reject(reason)
        local bank, cash = balances(xPlayer)
        if Config.Debug then
            print(("^3[ns_legacyfuel] fuel transaction rejected src=%s reason=%s^0"):format(src, reason or "unknown"))
        end
        TriggerClientEvent(
            "ns_legacyfuel:paymentResult",
            src,
            false,
            bank,
            cash,
            nil,
            0.0,
            tonumber(session.startFuel) or 0.0
        )
        notifyPlayer(src, Config.Payment.InsufficientFundsTitle,
            "Fuel transaction could not be completed. No money was taken.", Config.Notifications.Color)
    end

    -- Do not use the replicated vehicle fuel level to calculate the bill. It can
    -- be one or more network ticks behind the dispenser. It is retained only as
    -- a sanity value and for transaction logging.
    finalFuel = tonumber(finalFuel)
    if not finalFuel then
        reject("invalid final fuel")
        return
    end

    local elapsed = math.max(0.0, (GetGameTimer() - session.startedAt) / 1000.0)
    if elapsed > 1800 then
        reject("session timeout")
        return
    end

    -- The dispenser counter is the transaction source of truth. The vehicle's
    -- 0-100 native fuel value is only a gameplay representation and can lag or
    -- quantize on the final network tick.
    reportedGallons = tonumber(reportedGallons)
    if not reportedGallons or reportedGallons < 0 then
        reject("invalid gallons")
        return
    end

    -- Settle to the same two-decimal gallon amount the pump UI uses.
    local gallons = math.floor((math.max(0.0, reportedGallons) * 100.0) + 0.5) / 100.0
    if gallons > (Config.Fuel.MaxGallonsPerSession or 100.0) then
        reject("gallon limit")
        return
    end

    -- Anti-exploit rate check. Use a precise millisecond server timer rather
    -- than os.time(), which only has one-second resolution and was responsible
    -- for valid short transactions occasionally failing validation.
    local pumpGallonsPerMinute = tonumber(Config.Fuel.PumpGallonsPerMinute) or 16.0
    local grace = tonumber(Config.Fuel.TransactionTimeGraceSeconds) or 3.0
    local maxDispensed = (pumpGallonsPerMinute / 60.0) * (elapsed + grace)
    if gallons > maxDispensed + 0.25 then
        reject("dispense rate")
        return
    end

    -- Exact pump math: gallons x price, rounded only to the nearest cent.
    local amount = roundAmount(gallons * session.price)
    if amount <= 0 then
        -- Nothing was dispensed; this is a completed zero-dollar transaction,
        -- not an error and should not remove money.
        local bank, cash = balances(xPlayer)
        TriggerClientEvent("ns_legacyfuel:paymentResult", src, true, bank, cash, "NONE", 0.0)
        return
    end
    if amount > Config.Payment.MaxTransaction then
        reject("transaction cap")
        return
    end

    -- Charge exactly once. Bank is preferred; if the bank cannot cover the full
    -- transaction, cash is used when fallback is enabled. No split charge is
    -- performed, so the player never gets a partial/duplicated deduction.
    local paidFrom, bankOrNew, cashOrNew = removePayment(
        xPlayer, amount, Config.Payment.UseBankFirst, Config.Payment.AllowCashFallback
    )
    if not paidFrom then
        TriggerClientEvent("ns_legacyfuel:paymentResult", src, false, bankOrNew, cashOrNew, nil, amount, session.startFuel)
        notifyPlayer(src, Config.Payment.InsufficientFundsTitle,
            "You do not have enough money for this fuel.", Config.Notifications.Color)
        return
    end

    session.paid = true
    logTransaction(src, session, finalFuel, gallons, amount, paidFrom)
    TriggerClientEvent("ns_legacyfuel:paymentResult", src, true, bankOrNew, cashOrNew, paidFrom, amount)
    notifyPlayer(src, "Fuel",
        string.format(Config.Payment.FuelPaidFormat, amount, paidFrom), Config.Notifications.Color)
end)

RegisterNetEvent("ns_legacyfuel:dropNozzle", function(pumpKey)
    local src = source
    if type(pumpKey) ~= "string" then return end
    local lock = pumpLocks[pumpKey]
    if lock and lock.owner == src then
        lock.at = os.time()
    end
end)

RegisterNetEvent("ns_legacyfuel:purchaseJerryCan", function()
    if Config.Framework.Standalone or not ESX or not Config.JerryCan.Enabled then return end
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local alreadyHasCan = false
    if GetResourceState("ox_inventory") == "started" then
        local ok, count = pcall(function() return exports.ox_inventory:Search(src, "count", Config.JerryCan.Item) end)
        alreadyHasCan = ok and (tonumber(count) or 0) > 0
    end
    if not alreadyHasCan and xPlayer.getInventoryItem then
        local item = xPlayer.getInventoryItem(Config.JerryCan.Item)
        alreadyHasCan = item and (tonumber(item.count) or 0) > 0
    end
    if not alreadyHasCan and xPlayer.hasWeapon then
        local ok, result = pcall(function() return xPlayer.hasWeapon(Config.JerryCan.Item) end)
        alreadyHasCan = ok and result == true
    end
    if alreadyHasCan then
        TriggerClientEvent("ns_legacyfuel:jerryCanResult", src, false, "owned")
        return
    end

    local price = math.max(0, math.floor(tonumber(Config.JerryCan.PurchasePrice) or 0))
    local paidFrom, bankOrNew, cashOrNew = removePayment(xPlayer, price, Config.JerryCan.UseBankFirst, Config.JerryCan.AllowCashFallback)
    if not paidFrom then
        local bank, cash = balances(xPlayer)
        TriggerClientEvent("ns_legacyfuel:jerryCanResult", src, false, "purchase", bank, cash)
        return
    end

    local added = false
    if GetResourceState("ox_inventory") == "started" then
        local ok, result = pcall(function() return exports.ox_inventory:AddItem(src, Config.JerryCan.Item, 1, { fuel = Config.JerryCan.Capacity }) end)
        added = ok and result ~= false
    else
        local ok = pcall(function() xPlayer.addInventoryItem(Config.JerryCan.Item, 1) end)
        added = ok
    end

    if not added then
        -- Never charge for an item that could not be added.
        if paidFrom == "BANK" then xPlayer.addAccountMoney("bank", price) else xPlayer.addMoney(price) end
        return
    end

    jerryCanState[src] = Config.JerryCan.Capacity
    TriggerClientEvent("ns_legacyfuel:jerryCanResult", src, true, "purchase", bankOrNew, cashOrNew, price, Config.JerryCan.Capacity)
end)

RegisterNetEvent("ns_legacyfuel:refillJerryCan", function()
    if Config.Framework.Standalone or not ESX or not Config.JerryCan.Enabled then return end
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local ammo, slot, metadata = getJerryCanServerState(src)
    if ammo == nil then
        TriggerClientEvent("ns_legacyfuel:jerryCanResult", src, false, "missing")
        return
    end
    if ammo >= Config.JerryCan.Capacity then
        TriggerClientEvent("ns_legacyfuel:jerryCanResult", src, false, "full")
        return
    end

    local missing = Config.JerryCan.Capacity - ammo
    local price = math.max(0, math.ceil((missing / Config.JerryCan.Capacity) * (tonumber(Config.JerryCan.RefillCost) or 0)))
    local paidFrom, bankOrNew, cashOrNew = removePayment(xPlayer, price, Config.JerryCan.UseBankFirst, Config.JerryCan.AllowCashFallback)
    if not paidFrom then
        local bank, cash = balances(xPlayer)
        TriggerClientEvent("ns_legacyfuel:jerryCanResult", src, false, "refill", bank, cash)
        return
    end

    setJerryCanServerState(src, Config.JerryCan.Capacity, slot, metadata)
    TriggerClientEvent("ns_legacyfuel:jerryCanResult", src, true, "refill", bankOrNew, cashOrNew, price, Config.JerryCan.Capacity)
end)

RegisterNetEvent("ns_legacyfuel:requestJerryCanSync", function()
    local src = source
    local ammo = getJerryCanServerState(src)
    if ammo ~= nil then
        jerryCanState[src] = ammo
        TriggerClientEvent("ns_legacyfuel:syncJerryCanAmmo", src, ammo)
    end
end)

RegisterNetEvent("ns_legacyfuel:updateJerryCanAmmo", function(ammo)
    if Config.Framework.Standalone or not ESX or not Config.JerryCan.Enabled then return end
    local src = source
    local proposed = math.max(0, math.min(tonumber(Config.JerryCan.Capacity) or 4500, math.floor(tonumber(ammo) or 0)))
    local current, slot, metadata = getJerryCanServerState(src)
    if current == nil then return end

    -- This event is only allowed to consume fuel. Increasing a can's fuel is
    -- performed exclusively by the purchase/refill handlers above.
    if proposed > current then return end
    if jerryCanState[src] and proposed > jerryCanState[src] then return end

    setJerryCanServerState(src, proposed, slot, metadata)
end)

AddEventHandler("playerDropped", function()
    local src = source
    fuelSessions[src] = nil
    jerryCanState[src] = nil
    local changed = false
    for key, data in pairs(pumpLocks) do
        if data.owner == src then
            pumpLocks[key] = nil
            changed = true
        end
    end
    if changed then publishPumpLocks() end
end)

CreateThread(function()
    while true do
        Wait(60000)

        local timeout = tonumber(Config.Pump.LockTimeout) or 900
        if timeout > 0 then
            local now = os.time()
            local changed = false

            for key, data in pairs(pumpLocks) do
                if data and data.at and now - data.at > timeout then
                    pumpLocks[key] = nil
                    changed = true
                end
            end

            if changed then publishPumpLocks() end
        end
    end
end)

publishPumpLocks()

-- Pump explosion authority. The client detects the physical impact, but the
-- server owns the cooldown so multiple nearby players cannot trigger the same
-- pump explosion repeatedly on the same tick.
local pumpExplosionCooldowns = {}

RegisterNetEvent("ns_legacyfuel:requestPumpExplosion", function(pumpKey, coords)
    local src = source
    if not Config.Pump.Explosions or Config.Pump.Explosions.Enabled ~= true then return end
    if type(pumpKey) ~= "string" or type(coords) ~= "table" then return end

    local now = os.time()
    local cooldown = tonumber(Config.Pump.Explosions.Cooldown) or 15
    local rearm = tonumber(Config.Pump.Explosions.RespawnAfter) or 0
    local last = pumpExplosionCooldowns[pumpKey] or 0
    -- Cooldown prevents duplicate requests; RespawnAfter controls how long
    -- that particular pump remains armed after an explosion.
    local requiredDelay = math.max(cooldown, rearm)
    if now - last < requiredDelay then return end

    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)
    if not x or not y or not z then return end

    if math.abs(x) > 10000 or math.abs(y) > 10000 or z < -100 or z > 2000 then return end


    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        local pc = GetEntityCoords(ped)
        local dx, dy, dz = pc.x - x, pc.y - y, pc.z - z
        if (dx * dx + dy * dy + dz * dz) > (12.0 * 12.0) then return end
    end

    pumpExplosionCooldowns[pumpKey] = now
    TriggerClientEvent("ns_legacyfuel:pumpExplosion", -1, pumpKey, vector3(x, y, z))
end)
