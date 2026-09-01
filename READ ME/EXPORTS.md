# Exports

## Client exports

### GetFuel

```lua
local fuel = exports.ns_legacyfuel:GetFuel(vehicle)
```
Returns `number` from `0.0` to `100.0`.

### SetFuel

```lua
exports.ns_legacyfuel:SetFuel(vehicle, 75.0)
```
Sets the vehicle fuel level. Values are clamped to `0.0`-`100.0`.

### IsFueling

```lua
local active = exports.ns_legacyfuel:IsFueling()
```
Returns `true` while pump or jerry-can fueling is active.

### GetCurrentPump

```lua
local pump, coords = exports.ns_legacyfuel:GetCurrentPump()
```
Returns the current pump entity and coordinates, or `nil, nil` if there is no active nozzle/pump.

### GetFuelSession

```lua
local session = exports.ns_legacyfuel:GetFuelSession()
```
Returns `nil` when inactive. Otherwise returns:

```lua
{
    active = true,
    type = "pump" or "jerrycan",
    vehicle = vehicleEntity,
    fuelStart = number,
    fuelCurrent = number,
    gallons = number,
    grade = string,
    name = string,
    pricePerGallon = number,
    pumpCoords = vector3,
}
```

## Compatibility globals

`GetFuel(vehicle)` and `SetFuel(vehicle, value)` remain available as globals for older LegacyFuel-style integrations.

The original LegacyFuel project exposes `GetFuel` and `SetFuel` as its primary integration exports; this resource keeps those concepts compatible while adding the additional exports above. See the original project for attribution and history.
