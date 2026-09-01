# NS Legacy Fuel

A realistic, multiplayer-friendly fuel system for FiveM with physical pump nozzles, configurable fuel grades, jerry cans, server-side transactions, hose distance behavior, dropped-nozzle recovery, and optional gas-pump explosions.

> **LegacyFuel credit:** This project is a heavily modified derivative of [InZidiuZ/LegacyFuel](https://github.com/InZidiuZ/LegacyFuel). LegacyFuel is the original project this resource is based on. Please keep the original attribution and GPL-3.0 license with every redistribution.

## Highlights

- Physical gas-pump nozzle pickup, vehicle insertion, removal and return
- Hose/nozzle drop when a player or vehicle travels beyond the configured distance
- Dropped nozzle outline only within the configured pickup/drop distance
- Fueling continues while the player walks away; UI follows the configured UI distance
- Final tank level, gallons and total remain correct when a tank reaches 100%
- Regular, Plus and Premium fuel grades with configurable pricing
- Realistic fuel-flow taper near a full tank
- Server-authoritative pump locks and fuel payment calculation
- Disconnect and stale-lock cleanup
- Configurable transaction sanity checks
- Optional gas-pump vehicle-impact / player-kick explosions
- Native GTA pump explosion protection
- Configurable jerry-can fueling, purchase and refill behavior
- ox_target integration
- NUI dispenser interface
- Client exports for vehicle fuel and fueling-session integrations
- Adaptive client loops for lower idle resource usage

## Requirements

- FiveM / FXServer
- `ox_target`
- ESX by default (`Config.Framework.Standalone = false`)
- `ox_inventory` is optional for enhanced jerry-can metadata synchronization
- Your notification resource can be configured through `Config.Notifications.Event`

The ESX dependency is intentionally not hard-coded into `fxmanifest.lua`, so standalone mode can be used without ESX. When standalone mode is disabled, ESX must be started before this resource.

## Compatibility

- FiveM / FXServer
- ESX Legacy when framework mode is enabled
- ox_target
- ox_inventory is optional but recommended when using persistent jerry-can metadata
- Custom notification events/exports through `config.lua`

The resource is intentionally not tied to a specific notification resource.

## Installation

1. Download or clone this repository.
2. Put the `ns_legacyfuel` folder inside your server's resources directory.
3. Start `ox_target` before this resource.
4. If using ESX, start `es_extended` before this resource.
5. Add:

```cfg
ensure ox_target
ensure ns_legacyfuel
```

6. Configure `config.lua`.
7. Restart `ns_legacyfuel`.

FiveM resources use `fxmanifest.lua` to declare their scripts, metadata and dependencies.

## Configuration

All normal server-owner settings are in `config.lua`.

### Fuel pricing

```lua
Config.Fuel.BasePricePerGallon = 4.29
```

Fuel grades use offsets from the base price:

```lua
{
    grade = 93,
    name = "PREMIUM",
    description = "Premium unleaded",
    priceOffset = 1.10,
}
```

### Hose / UI distances

```lua
Config.Pump.HoseDropDistance = 6.0
Config.Pump.FuelingUIDistance = 5.0
```

The same hose distance controls when a held nozzle or a vehicle-mounted nozzle breaks away. The dropped-nozzle outline also uses this distance.

### Pump explosions

Disabled by default:

```lua
Config.Pump.Explosions = {
    Enabled = false,
    AllowVehicleImpact = true,
    AllowPlayerKick = true,
    VehicleMinSpeed = 4.0,
    VehicleImpactRadius = 2.25,
    PlayerKickRadius = 1.65,
    Cooldown = 15,
    RespawnAfter = 300,
    ExplosionType = 2,
    ExplosionDamageScale = 1.0,
    ExplosionCameraShake = 1.0,
    ExplosionAudible = true,
    ExplosionInvisible = false,
    DeletePumpAfterExplosion = false,
    DestroyedPumpInteractionDisabled = true,
    PreventNativeExplosions = true,
}
```

If `Enabled = false`, the resource does not intentionally trigger pump explosions. `PreventNativeExplosions = true` also prevents normal GTA pump damage from bypassing the configured behavior.

### Transaction protection

Fuel transactions are calculated server-side from the recorded starting fuel level, selected grade and reported final fuel level. The server also limits the maximum gallons per session and applies a dispenser-rate sanity check.

For testing/economy balancing:

```lua
Config.Logging.Enabled = true
```

This writes completed fuel transactions to the server console.

## Public exports

FiveM supports client/server exports for resource-to-resource integrations.

### `GetFuel(vehicle)`

Returns the vehicle fuel level from `0.0` to `100.0`.

```lua
local fuel = exports.ns_legacyfuel:GetFuel(vehicle)
```

### `SetFuel(vehicle, value)`

Sets vehicle fuel, clamped to `0.0` through `100.0`.

```lua
exports.ns_legacyfuel:SetFuel(vehicle, 75.0)
```

### `IsFueling()`

Returns `true` while the player is actively fueling with a pump nozzle or jerry can.

```lua
if exports.ns_legacyfuel:IsFueling() then
    print("Player is fueling")
end
```

### `GetCurrentPump()`

Returns the current pump entity and pump coordinates when a nozzle is active.

```lua
local pump, coords = exports.ns_legacyfuel:GetCurrentPump()
```

### `GetFuelSession()`

Returns a read-only snapshot of the active fueling session, or `nil` when inactive.

```lua
local session = exports.ns_legacyfuel:GetFuelSession()

if session then
    print(session.type)           -- "pump" or "jerrycan"
    print(session.fuelCurrent)    -- current vehicle fuel
    print(session.gallons)        -- gallons pumped so far
    print(session.pricePerGallon)
end
```

The original `GetFuel(vehicle)` and `SetFuel(vehicle, value)` globals are also retained for compatibility with older LegacyFuel-style integrations.

## Resource structure

```text
ns_legacyfuel/
├── config.lua
├── fxmanifest.lua
├── LICENSE
├── NOTICE.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── client/
│   ├── main.lua
│   ├── shared.lua
│   ├── fuel.lua
│   ├── nozzle.lua
│   ├── jerrycan.lua
│   └── targets.lua
├── server/
│   └── main.lua
├── docs/
│   ├── CONFIG.md
│   ├── EXPORTS.md
│   └── TEST_PLAN.md
└── ui/
    ├── index.html
    ├── script.js
    ├── style.css
    ├── background.png
    └── digital-counter-7.ttf
```

## Release / testing

Before a public release, run the full test plan in `docs/TEST_PLAN.md`. In particular, test multiple players at different pumps, disconnect/reconnect cleanup, 100% fuel completion, hose break behavior, dropped nozzle recovery, payment correctness, and the explosion toggle.

## Performance

The resource uses adaptive waits for idle vs active interactions and avoids continuously running high-frequency pump/nozzle logic when no interaction is taking place. For server testing, use FiveM's `resmon 1` and test with several players active at multiple stations.

## Credits and license

**Original project:** [LegacyFuel by InZidiuZ](https://github.com/InZidiuZ/LegacyFuel)

LegacyFuel is licensed under **GNU GPL-3.0**. This project retains the GPL license and attribution because it is based on that project. See `LICENSE` and `NOTICE.md`.

You may distribute GPL software for a fee, but recipients must retain the rights required by the GPL, including access to the corresponding source. Do not market this repository as closed-source/proprietary software while retaining the GPL-covered LegacyFuel-derived code.

## Disclaimer

This resource is provided without warranty. Test it on a development server before deploying it to a production economy.


## Security model

Fuel grades, pump ownership, transaction limits, dispenser-rate checks, pump proximity, and payments are validated server-side. Jerry-can refill/purchase operations are also server-authoritative. The client is treated as untrusted input.

## Release testing

Before publishing a release, run [`docs/TEST_PLAN.md`](docs/TEST_PLAN.md) on a development server and test both ESX and ox_inventory paths used by your deployment.


## License

This project is distributed under the GNU GPL-3.0 because it is a modified derivative of LegacyFuel. See [`LICENSE`](LICENSE) and [`NOTICE.md`](NOTICE.md).

Commercial closed-source/escrow redistribution of this LegacyFuel-derived code is not permitted by this project.
