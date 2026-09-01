# NS Legacy Fuel — Dummy-Proof Configuration Guide

You should be able to configure the resource without opening any Lua file other than `config.lua`.

## 🚀 Quick setup (do this first)

Open `config.lua` and change only these sections if you need to:

| What you want to change | Where | What to edit |
|---|---|---|
| Framework | `Config.Framework` | `Name`, `Standalone` |
| Notifications | `Config.Notifications` | `Mode`, `Event` **or** `Resource`/`Export`/`Arguments` |
| Regular fuel price | `Config.Fuel` | `BasePricePerGallon` |
| Plus/Premium prices | `Config.Fuel.FuelTypes` | `priceOffset` |
| UI hide distance | `Config.Pump` | `FuelingUIDistance` |
| Hose/nozzle drop distance | `Config.Pump` | `HoseDropDistance` |
| Pump explosions | `Config.Pump.Explosions` | `Enabled` |
| Target system | `Config.Target` | `Resource` |
| Jerry cans | `Config.JerryCan` | `Enabled` |
| Gas-station map blips | `Config.Blips` | `Enabled` |

**After changing `config.lua`, restart `ns_legacyfuel`.**

---

## 🔔 Notifications — easiest explanation

The default uses the built-in GTA feed notification, so no notification resource is required. You can also connect your own notification script.

### Option A — notification event

Use this if your notification script tells you to run something like `TriggerEvent(...)`.

```lua
Notifications = {
    Mode = "builtin",
    Event = "gfx_hud:sendNotify",
    Icon = "fa-solid fa-bell",
    Color = "red",
    Duration = 5000,
}
```

### Option B — notification export

Use this if your notification script tells you to run something like:

```lua
exports["my_notify"]:Notify(message, color, duration)
```

Then configure:

```lua
Notifications = {
    Mode = "client_export",
    Resource = "my_notify",
    Export = "Notify",
    Arguments = { "message", "color", "duration" },
    Icon = "fa-solid fa-bell",
    Color = "red",
    Duration = 5000,
}
```

### Arguments

`Arguments` tells NS Legacy Fuel what order to send values to your export. Supported values are:

- `title`
- `message`
- `icon`
- `color`
- `duration`

For example, if your export is:

```lua
exports("Notify", function(title, message, duration)
    -- ...
end)
```

use:

```lua
Arguments = { "title", "message", "duration" }
```

**Do not put arbitrary words in `Arguments`.**

---

## ⛽ Fuel prices

The regular price is the base price:

```lua
BasePricePerGallon = 4.29
```

Each grade adds its own offset:

```lua
{
    grade = 91,
    name = "PLUS",
    priceOffset = 0.60,
},
```

With a $4.29 base, Plus becomes $4.89.

To make Premium $5.49, use `priceOffset = 1.20`.

**You normally do not edit `Config.Fuel.Types`.** It is built automatically from `FuelTypes`.

---

## 🪢 Nozzle and UI distances

### `HoseDropDistance`

```lua
HoseDropDistance = 6.0
```

At 6 meters from the pump, the hose/nozzle is considered pulled too far. This applies to both a player walking away with the nozzle and a vehicle driving away with it attached.

### `FuelingUIDistance`

```lua
FuelingUIDistance = 5.0
```

If the player walks farther than this from the pump, the UI hides. Fueling can continue if the nozzle is still attached correctly.

---

## 💥 Pump explosions

Explosions are **OFF by default**.

```lua
Explosions = {
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

**Safest setup:** keep `Enabled = false` and `PreventNativeExplosions = true`.

---

## 🛢️ Jerry cans

Turn the feature off entirely with:

```lua
JerryCan = {
    Enabled = false,
}
```

If enabled, the default item is `weapon_petrolcan`.

---

## 🗺️ Blips

Hide all gas-station map blips:

```lua
Blips = {
    Enabled = false,
}
```

---

## 🧪 Advanced settings

The following are intentionally documented but should normally stay at their defaults:

- Fuel consumption math
- Vehicle class multipliers
- Flow taper
- Pump attachment offsets
- Rope physics
- Animation flags
- Particle effects
- Vehicle model lists
- Spawned pump coordinates

If you change these, test the resource thoroughly before using the server in production.

---

## ❌ Common mistakes

### “I changed the config but nothing changed.”
Restart `ns_legacyfuel`.

### “My notification doesn't work.”
Check the notification resource name, export name, and argument order. Make sure the notification resource is started **before** NS Legacy Fuel.

### “I used `client_export` and it says Resource/Export is empty.”
Fill in both:

```lua
Resource = "your_notification_resource",
Export = "your_export_name",
```

### “I want $4.99 regular fuel.”
Set:

```lua
BasePricePerGallon = 4.99
```

### “I want Premium to be $5.99 while Regular is $4.99.”
Set Premium's `priceOffset` to `1.00`.

### “I don't want pumps exploding.”
Use:

```lua
Explosions = {
    Enabled = false,
    PreventNativeExplosions = true,
}
```

---

## LegacyFuel attribution

NS Legacy Fuel is a heavily modified derivative of **LegacyFuel by InZidiuZ**. See `NOTICE.md` and `LICENSE` for attribution and licensing information.
