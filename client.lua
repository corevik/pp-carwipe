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

    local maxPassengers = GetVehicleMaxNumberOfPassengers(vehicle)

    for seat = -1, maxPassengers do
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

local function RequestControl(entity)
    if not DoesEntityExist(entity) then return false end

    local timeout = GetGameTimer() + 3000

    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(entity)
        Wait(50)
    end

    return NetworkHasControlOfEntity(entity)
end

local function DeleteVehicleClientSide(vehicle)
    if not DoesEntityExist(vehicle) then return false end

    RequestControl(vehicle)

    if DoesEntityExist(vehicle) then
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
        DeleteEntity(vehicle)
    end

    Wait(50)

    return not DoesEntityExist(vehicle)
end

RegisterNetEvent('pp_carwipe:client:deleteVehicleByNetId', function(netId)
    if not netId then return end
    if not NetworkDoesNetworkIdExist(netId) then return end

    local vehicle = NetToVeh(netId)

    if not vehicle or vehicle == 0 then return end
    if not DoesEntityExist(vehicle) then return end

    DeleteVehicleClientSide(vehicle)
end)

RegisterNetEvent('pp_carwipe:client:forceWipe', function()
    local vehicles = GetGamePool('CVehicle')
    local platesToReturn = {}
    local seenPlates = {}

    for _, vehicle in pairs(vehicles) do
        if DoesEntityExist(vehicle) and ShouldWipeVehicle(vehicle) then
            local plate = NormalizePlate(GetVehicleNumberPlateText(vehicle))

            if plate ~= '' and not seenPlates[plate] then
                seenPlates[plate] = true
                platesToReturn[#platesToReturn + 1] = plate
            end
        end
    end

    if #platesToReturn > 0 then
        TriggerServerEvent('pp_carwipe:server:returnOwnedPlates', platesToReturn)
    end

    Wait(250)

    for _, vehicle in pairs(vehicles) do
        if DoesEntityExist(vehicle) and ShouldWipeVehicle(vehicle) then
            DeleteVehicleClientSide(vehicle)
        end
    end
end)
