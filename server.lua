local wipeRunning = false
local activeCountdown = false
local clientReturnWindowUntil = 0

local function DebugPrint(message)
    if Config.Debug then
        print('[pp_carwipe] ' .. message)
    end
end

local function Trim(value)
    if value == nil then return '' end
    return tostring(value):match('^%s*(.-)%s*$') or ''
end

local function NormalizePlate(value)
    value = Trim(value)
    value = value:gsub('%s+', '')
    value = string.upper(value)
    return value
end

local function SendAnnouncement(message)
    if Config.TxAdminAnnouncement.enabled then
        TriggerClientEvent(
            'txcl:showAnnouncement',
            -1,
            message,
            Config.TxAdminAnnouncement.author or 'txAdmin'
        )
    else
        print('[pp_carwipe] ' .. message)
    end
end

local function SendAnnouncementToPlayer(source, message)
    if Config.TxAdminAnnouncement.enabled then
        TriggerClientEvent(
            'txcl:showAnnouncement',
            source,
            message,
            Config.TxAdminAnnouncement.author or 'txAdmin'
        )
    else
        TriggerClientEvent('chat:addMessage', source, {
            args = { 'Car Wipe', message }
        })
    end
end

local function PlateStartsWithIgnoredPrefix(plate)
    plate = NormalizePlate(plate)

    for _, prefix in pairs(Config.WipeSettings.ignoredPlatePrefixes or {}) do
        prefix = NormalizePlate(prefix)

        if prefix ~= '' and string.sub(plate, 1, #prefix) == prefix then
            return true
        end
    end

    return false
end

local function IsIgnoredVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return true end

    local model = GetEntityModel(vehicle)

    if Config.WipeSettings.ignoredModels and Config.WipeSettings.ignoredModels[model] then
        return true
    end

    local plate = GetVehicleNumberPlateText(vehicle)

    if PlateStartsWithIgnoredPrefix(plate) then
        return true
    end

    return false
end

local function VehicleHasDriver(vehicle)
    if not DoesEntityExist(vehicle) then return false end

    local driver = GetPedInVehicleSeat(vehicle, -1)

    return driver and driver ~= 0 and DoesEntityExist(driver)
end

local function VehicleHasAnyOccupants(vehicle)
    if not DoesEntityExist(vehicle) then return false end

    local model = GetEntityModel(vehicle)
    local seats = GetVehicleModelNumberOfSeats(model)

    for seat = -1, seats - 2 do
        local ped = GetPedInVehicleSeat(vehicle, seat)

        if ped and ped ~= 0 and DoesEntityExist(ped) then
            return true
        end
    end

    return false
end

local function ShouldWipeVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    if IsIgnoredVehicle(vehicle) then return false end

    if Config.WipeSettings.onlyProtectDriver then
        return not VehicleHasDriver(vehicle)
    end

    return not VehicleHasAnyOccupants(vehicle)
end

local function BuildExtraSqlSet()
    local parts = {}
    local values = {}

    for column, value in pairs(Config.Database.extraSetValues or {}) do
        parts[#parts + 1] = string.format('`%s` = ?', column)
        values[#values + 1] = value
    end

    return parts, values
end

local function ReturnOwnedVehicleToGarage(plate)
    if not Config.Database.enabled then return false end
    if not Config.WipeSettings.returnOwnedVehiclesToGarage then return false end

    local cleanPlate = NormalizePlate(plate)

    if cleanPlate == '' then
        return false
    end

    local tableName = Config.Database.table
    local plateColumn = Config.Database.plateColumn
    local stateColumn = Config.Database.stateColumn
    local garageColumn = Config.Database.garageColumn

    local wherePlate = string.format(
        "REPLACE(UPPER(TRIM(`%s`)), ' ', '') = ?",
        plateColumn
    )

    local selectSql = string.format(
        'SELECT `%s` FROM `%s` WHERE %s LIMIT 1',
        plateColumn,
        tableName,
        wherePlate
    )

    local ok, vehicleData = pcall(function()
        return MySQL.single.await(selectSql, { cleanPlate })
    end)

    if not ok then
        print('[pp_carwipe] Database SELECT failed for plate ' .. cleanPlate .. ': ' .. tostring(vehicleData))
        return false
    end

    if not vehicleData then
        DebugPrint('No owned vehicle found for plate: ' .. cleanPlate)
        return false
    end

    local setParts = {
        string.format('`%s` = ?', stateColumn)
    }

    local values = {
        Config.Database.storedValue
    }

    if Config.Database.updateGarage then
        setParts[#setParts + 1] = string.format('`%s` = ?', garageColumn)
        values[#values + 1] = Config.Database.defaultGarage
    end

    local extraParts, extraValues = BuildExtraSqlSet()

    for _, part in ipairs(extraParts) do
        setParts[#setParts + 1] = part
    end

    for _, value in ipairs(extraValues) do
        values[#values + 1] = value
    end

    values[#values + 1] = cleanPlate

    local updateSql = string.format(
        'UPDATE `%s` SET %s WHERE %s',
        tableName,
        table.concat(setParts, ', '),
        wherePlate
    )

    local updateOk, result = pcall(function()
        return MySQL.update.await(updateSql, values)
    end)

    if not updateOk then
        print('[pp_carwipe] Database UPDATE failed for plate ' .. cleanPlate .. ': ' .. tostring(result))
        return false
    end

    DebugPrint('Returned owned vehicle to garage: ' .. cleanPlate)

    return true
end

local function ReturnManyOwnedVehiclesToGarage(plates)
    if type(plates) ~= 'table' then return 0 end

    local returned = 0
    local seen = {}

    for _, plate in pairs(plates) do
        local cleanPlate = NormalizePlate(plate)

        if cleanPlate ~= '' and not seen[cleanPlate] then
            seen[cleanPlate] = true

            if ReturnOwnedVehicleToGarage(cleanPlate) then
                returned = returned + 1
            end
        end
    end

    return returned
end

local function DeleteVehicleServerSide(vehicle)
    if not DoesEntityExist(vehicle) then return false end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    DeleteEntity(vehicle)

    Wait(100)

    if DoesEntityExist(vehicle) and netId and netId ~= 0 then
        local owner = NetworkGetEntityOwner(vehicle)

        if owner and owner > 0 then
            TriggerClientEvent('pp_carwipe:client:deleteVehicleByNetId', owner, netId)
        else
            TriggerClientEvent('pp_carwipe:client:deleteVehicleByNetId', -1, netId)
        end

        Wait(750)
    end

    if DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
        Wait(100)
    end

    return not DoesEntityExist(vehicle)
end

local function RunVehicleWipeInternal(manual)
    if not manual or Config.ManualWipe.announce then
        SendAnnouncement(Config.Messages.wiping)
    end

    Wait((Config.WipeSettings.wipeDelaySeconds or 5) * 1000)

    local deleted = 0
    local returnedToGarage = 0
    local vehicles = GetAllVehicles()

    DebugPrint('Server found ' .. tostring(#vehicles) .. ' vehicles.')

    for _, vehicle in pairs(vehicles) do
        if DoesEntityExist(vehicle) and ShouldWipeVehicle(vehicle) then
            local plate = GetVehicleNumberPlateText(vehicle)
            local ownedVehicleReturned = ReturnOwnedVehicleToGarage(plate)

            if ownedVehicleReturned then
                returnedToGarage = returnedToGarage + 1
            end

            if ownedVehicleReturned or Config.WipeSettings.deleteUnownedVehicles then
                if DeleteVehicleServerSide(vehicle) then
                    deleted = deleted + 1
                end
            end
        end
    end

    if Config.WipeSettings.clientFallbackDelete then
        clientReturnWindowUntil = os.time() + (Config.WipeSettings.clientGarageReturnWindowSeconds or 20)
        TriggerClientEvent('pp_carwipe:client:forceWipe', -1)
        DebugPrint('Client fallback wipe triggered.')
    end

    Wait(2000)

    if not manual or Config.ManualWipe.announce then
        SendAnnouncement(string.format(Config.Messages.complete, deleted, returnedToGarage))
    end

    clientReturnWindowUntil = 0
end

local function RunVehicleWipe(manual)
    if wipeRunning then
        if manual then
            SendAnnouncement(Config.Messages.alreadyRunning)
        end

        return
    end

    wipeRunning = true

    local ok, err = xpcall(function()
        RunVehicleWipeInternal(manual)
    end, debug.traceback)

    if not ok then
        print('[pp_carwipe] Wipe failed:')
        print(err)
        SendAnnouncement('Vehicle wipe had an error. Check server console.')
    end

    wipeRunning = false
end

RegisterNetEvent('pp_carwipe:server:returnOwnedPlates', function(plates)
    if os.time() > clientReturnWindowUntil then
        DebugPrint('Ignored client plate return because return window is closed.')
        return
    end

    local src = source
    local returned = ReturnManyOwnedVehiclesToGarage(plates)

    if returned > 0 then
        DebugPrint('Client ' .. tostring(src) .. ' returned ' .. tostring(returned) .. ' owned vehicle plates to garage.')
    end
end)

local function StartAutoWipeLoop()
    if not Config.AutoWipe.enabled then return end
    if activeCountdown then return end

    activeCountdown = true

    CreateThread(function()
        while Config.AutoWipe.enabled do
            local interval = Config.AutoWipe.intervalMinutes or 30
            local warningTimes = Config.AutoWipe.warningTimes or { interval, 5 }

            table.sort(warningTimes, function(a, b)
                return a > b
            end)

            local lastMinute = interval

            for _, warningMinute in ipairs(warningTimes) do
                if warningMinute <= interval and warningMinute > 0 then
                    local waitMinutes = lastMinute - warningMinute

                    if waitMinutes > 0 then
                        Wait(waitMinutes * 60 * 1000)
                    end

                    SendAnnouncement(string.format(Config.Messages.warning, warningMinute))

                    lastMinute = warningMinute
                end
            end

            if lastMinute > 0 then
                Wait(lastMinute * 60 * 1000)
            end

            RunVehicleWipe(false)
        end

        activeCountdown = false
    end)
end

CreateThread(function()
    Wait(5000)
    StartAutoWipeLoop()
end)

if Config.ManualWipe.enabled then
    RegisterCommand(Config.ManualWipe.command, function(source, args)
        if source ~= 0 then
            if not IsPlayerAceAllowed(source, Config.ManualWipe.acePermission) then
                SendAnnouncementToPlayer(source, Config.Messages.noPermission)
                return
            end
        end

        local delayMinutes = tonumber(args[1])

        if delayMinutes and delayMinutes > 0 then
            if Config.ManualWipe.announce then
                SendAnnouncement(string.format(Config.Messages.warning, delayMinutes))
            end

            CreateThread(function()
                Wait(delayMinutes * 60 * 1000)
                RunVehicleWipe(true)
            end)
        else
            RunVehicleWipe(true)
        end
    end, false)

    RegisterCommand(Config.ManualWipe.resetCommand, function(source)
        if source ~= 0 then
            if not IsPlayerAceAllowed(source, Config.ManualWipe.acePermission) then
                SendAnnouncementToPlayer(source, Config.Messages.noPermission)
                return
            end
        end

        wipeRunning = false
        clientReturnWindowUntil = 0

        SendAnnouncement(Config.Messages.reset)
    end, false)
end
