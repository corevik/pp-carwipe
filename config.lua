Config = {}

Config.Debug = true

Config.AutoWipe = {
    enabled = true,

    -- Full wipe cycle time
    intervalMinutes = 30,

    -- Announcements before the wipe
    warningTimes = {
        30,
        5
    }
}

Config.ManualWipe = {
    enabled = true,

    -- /carwipe
    -- /carwipe 5
    command = 'carwipe',

    -- Emergency reset command if a wipe ever gets stuck
    -- /carwipereset
    resetCommand = 'carwipereset',

    -- ACE permission required for manual commands
    acePermission = 'pp_carwipe.admin',

    announce = true
}

Config.TxAdminAnnouncement = {
    enabled = true,

    -- Name shown on the txAdmin announcement
    author = 'Pain & Profit RP'
}

Config.WipeSettings = {
    -- true = cars with a driver are safe, cars with only passengers can wipe
    -- false = any vehicle with any player inside is safe
    onlyProtectDriver = true,

    -- Delay after the "wiping" announcement
    wipeDelaySeconds = 5,

    -- Send owned cars back to garage database before deleting them from the world
    returnOwnedVehiclesToGarage = true,

    -- Delete NPC/unowned vehicles too
    deleteUnownedVehicles = true,

    -- Client fallback catches vehicles the server cannot delete due to ownership/control
    clientFallbackDelete = true,

    -- How long clients can send plates back during a wipe
    clientGarageReturnWindowSeconds = 20,

    -- Ignore plates that start with these prefixes
    ignoredPlatePrefixes = {
        -- 'POL',
        -- 'EMS',
    },

    -- Ignore specific models
    ignoredModels = {
        -- [`police`] = true,
        -- [`ambulance`] = true,
    }
}

Config.Database = {
    enabled = true,

    -- QBX / QBCore owned vehicle table
    table = 'player_vehicles',

    -- Column names
    plateColumn = 'plate',
    garageColumn = 'garage',
    stateColumn = 'state',

    -- QBX/QBCore:
    -- 0 = out
    -- 1 = in garage
    -- 2 = impound
    storedValue = 1,

    -- Keep false so it returns to whatever garage it was already assigned to
    updateGarage = false,

    -- Only used if updateGarage = true
    defaultGarage = 'legionsquare',

    -- Add extra database columns only if your table actually has them
    extraSetValues = {
        -- ['stored'] = 1,
        -- ['in_garage'] = 1,
    }
}

Config.Messages = {
    warning = 'All cars without a driver will be wiped in %s mins',
    wiping = 'All cars without drivers are wiping',
    complete = 'Vehicle wipe complete. Removed %s vehicles. Returned %s owned vehicles to garages.',
    alreadyRunning = 'A vehicle wipe is already running.',
    noPermission = 'You do not have permission to use this command.',
    reset = 'Car wipe status has been reset.'
}
