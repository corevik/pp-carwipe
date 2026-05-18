# pp_carwipe

Automatic txAdmin-style vehicle wipe system for FiveM/QBX/Qbox/QBCore servers.

This is the reverted version that **does not save or overwrite vehicle customizations/mods**. It only:

- Sends txAdmin-style announcements.
- Wipes vehicles with no driver every configured interval.
- Sets owned vehicles back into the garage database.
- Deletes world vehicles after returning owned vehicle plates to the garage.
- Supports manual admin wipe commands.

## Dependencies

Required:

- `oxmysql`
- txAdmin client resources available on the server for the txAdmin announcement event:
  - `txcl:showAnnouncement`

Framework:

- Standalone for wipe logic.
- Designed for QBX/Qbox/QBCore-style `player_vehicles` tables.

## Install

1. Put the folder in your resources directory:

```text
resources/[standalone]/pp_carwipe
```

2. Add this to your `server.cfg`:

```cfg
ensure oxmysql
ensure pp_carwipe

add_ace group.admin pp_carwipe.admin allow
```

3. Restart your server, or run:

```text
restart pp_carwipe
```

## Commands

Instant manual wipe:

```text
/carwipe
```

Countdown manual wipe:

```text
/carwipe 5
```

Emergency reset command:

```text
/carwipereset
```

## Permissions

The manual commands require this ACE permission:

```cfg
add_ace group.admin pp_carwipe.admin allow
```

If your admins are not in `group.admin`, add the ACE to your actual admin group.

## Auto wipe config

In `config.lua`:

```lua
Config.AutoWipe = {
    enabled = true,
    intervalMinutes = 30,
    warningTimes = {
        30,
        5
    }
}
```

Default behavior:

- Announces at 30 minutes.
- Announces at 5 minutes.
- Wipes at the end of the 30-minute cycle.

## Garage/database behavior

The script returns owned vehicles to the garage by updating the owned vehicle row:

```sql
state = 1
```

Default DB config:

```lua
Config.Database = {
    enabled = true,
    table = 'player_vehicles',
    plateColumn = 'plate',
    garageColumn = 'garage',
    stateColumn = 'state',
    storedValue = 1,
    updateGarage = false,
    defaultGarage = 'legionsquare'
}
```

QBX/QBCore usually uses:

```text
0 = out
1 = in garage
2 = impound
```

## Important customization note

This reverted version intentionally does **not** update:

```sql
player_vehicles.mods
```

That means the car wipe will not touch normal GTA customizations, NOS, V12, engine swaps, or mechanic-script custom data.

Your mechanic script should be responsible for saving customizations to the database when upgrades are installed or when the vehicle is stored.

## Passenger behavior

Default:

```lua
onlyProtectDriver = true
```

This means:

- Vehicle with a driver = safe
- Vehicle with no driver = wiped
- Vehicle with only passengers = wiped

To protect vehicles if anyone is inside, change it to:

```lua
onlyProtectDriver = false
```

## Ignoring emergency vehicles

You can ignore by plate prefix:

```lua
ignoredPlatePrefixes = {
    'POL',
    'EMS',
}
```

Or by model:

```lua
ignoredModels = {
    [`police`] = true,
    [`ambulance`] = true,
}
```

## Troubleshooting

### `/carwipe` says already running

Use:

```text
/carwipereset
```

### Owned cars delete but do not return to garage

Check your `player_vehicles` table and make sure the columns match `config.lua`:

```sql
SHOW COLUMNS FROM player_vehicles;
```

The common QBX/QBCore columns are:

```text
plate
state
garage
```

### txAdmin announcement does not show

Make sure your server has txAdmin client resources running. This script uses:

```lua
TriggerClientEvent('txcl:showAnnouncement', -1, message, author)
```

## File list

```text
pp_carwipe/
├── fxmanifest.lua
├── config.lua
├── server.lua
├── client.lua
└── README.md
```ALTER TABLE `player_vehicles`
ADD COLUMN IF NOT EXISTS `state` INT(11) NOT NULL DEFAULT 1;
ALTER TABLE `player_vehicles`
ADD COLUMN IF NOT EXISTS `garage` VARCHAR(50) NOT NULL DEFAULT 'legionsquare';
UPDATE `player_vehicles`
SET `state` = 1
WHERE `state` = 0;

