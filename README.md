# ⛽ NS Legacy Fuel

### A realistic multiplayer fuel system for FiveM

**NS Legacy Fuel** brings a more immersive gas-station experience to FiveM while keeping the simplicity and compatibility of the original LegacyFuel system.

Physically grab the pump nozzle, insert it into your vehicle, select your fuel grade, and fill up. Walk too far from the pump and the hose can disconnect. Drop the nozzle and come back for it. Use a jerry can when you're stuck on the side of the road.

Built with **multiplayer synchronization, server-side transaction validation, configurable fuel behavior, and LegacyFuel-compatible exports.**

---

## 📸 Preview

![NS Legacy Fuel](https://i.imgur.com/Icu4bGx.png)

![NS Legacy Fuel](https://i.imgur.com/G44zYNm.png)

---

# ✨ Features

### ⛽ Physical Fuel Pump Nozzles

* Pick up the nozzle directly from the pump
* Insert the nozzle into your vehicle
* Return the nozzle when finished
* Physical nozzle synchronization between players

### 🛢️ Realistic Hose Behavior

* Hose/nozzle disconnects when pulled beyond the configured distance
* Dropped nozzles can be recovered
* Configurable interaction and fueling distances
* Realistic pump-to-vehicle fueling interaction

### 🔥 Multiple Fuel Grades

* **Regular**
* **Plus**
* **Premium**
* Fully configurable fuel pricing

### 💳 Server-Side Fuel Transactions

* Fuel cost is calculated server-side
* Transaction sanity checks
* Pump locking
* Stale/disconnected player cleanup
* Helps prevent client-side fuel/payment manipulation

### 🧯 Optional Gas Pump Explosions

* Vehicle impacts
* Players kicking/hitting the pump
* Configurable damage
* Configurable explosion radius
* Configurable cooldown
* Configurable pump respawn behavior
* Native GTA pump explosions can be prevented

### 🪣 Jerry Cans

* Purchase and refill behavior
* Configurable capacity
* Fuel vehicles using a jerry can
* Persistent jerry-can metadata support with `ox_inventory`

### 🎯 ox_target Support

Fully supports **ox_target** for interacting with pumps and fuel-related features.

### 🖥️ NUI Fuel Dispenser

* Select fuel grade
* View fuel information
* Real-time fueling information
* Clean and modern interface

### 🔌 LegacyFuel Compatibility

Designed to make switching from LegacyFuel easier.

Compatible functionality includes:

* `GetFuel`
* `SetFuel`
* LegacyFuel-style integrations

Existing scripts using LegacyFuel-style fuel exports/functions can continue to work with minimal changes.

### ⚡ Performance Focused

* Adaptive client loops
* Reduced idle processing
* Optimized interaction checks
* Designed with multiplayer servers in mind

---

# 🎥 Showcase

### Full Fueling Process

> 🎬 https://youtu.be/f1WERhijviE

---

# ⚙️ Requirements

* **FiveM / FXServer**
* **ox_target**
* **ESX Legacy** *(when framework mode is enabled)*
* **ox_inventory** *(optional, recommended for persistent jerry-can metadata)*

### Standalone

**Standalone mode is supported.**

---

# 📦 Installation

### 1. Download

Download or clone `ns_legacyfuel` into your server's `resources` folder.

### 2. Start Dependencies

Make sure `ox_target` is started before `ns_legacyfuel`.

If using ESX, make sure `es_extended` is started as well.

### 3. Add to `server.cfg`

```cfg
ensure ox_target
ensure ns_legacyfuel
```

### 4. Configure

Open:

```text
config.lua
```

and configure the resource to your server's needs.

### 5. Restart

Restart the resource or your server.

---

# 🔧 Configuration

Almost everything server owners need to change is located in `config.lua`.

You can configure:

* Fuel prices
* Fuel grades
* Fuel consumption
* Pump interaction distances
* Hose distance
* Fueling UI distance
* Jerry cans
* Pump explosions
* Notifications
* Framework settings
* Transaction limits
* Logging
* Vehicle behavior
* Fueling behavior

---

# 🔌 Exports

## Get Fuel

```lua
exports.ns_legacyfuel:GetFuel(vehicle)
```

## Set Fuel

```lua
exports.ns_legacyfuel:SetFuel(vehicle, 75.0)
```

## Check Fueling

```lua
if exports.ns_legacyfuel:IsFueling() then
    print("Player is fueling")
end
```

Additional exports are available for accessing the current pump and active fueling session.

See the documentation for the complete export list.

---

# 🧪 Multiplayer & Security

NS Legacy Fuel was designed with multiplayer servers in mind.

Fuel transactions are validated **server-side** using the recorded starting fuel level, selected fuel grade, and reported final fuel level.

The server also applies configurable limits and sanity checks to fuel sessions.

Additional protections include:

* Server-side transaction validation
* Pump locking
* Fuel session validation
* Stale session cleanup
* Player disconnect cleanup
* Configurable transaction limits

The goal is to prevent the client from being able to freely manipulate fuel costs or transaction values.

---

# 📚 Documentation

* **Configuration:** `docs/CONFIG.md`
* **Exports:** `docs/EXPORTS.md`
* **Testing:** `docs/TEST_PLAN.md`

---

# 🛠️ Development

Found a bug or have an idea?

Feel free to open an **Issue** or submit a **Pull Request**.

When reporting a bug, please include:

* FiveM artifact/build
* Framework
* Other fuel-related resources
* Steps to reproduce
* Client/server console errors
* Relevant configuration

---

# 🙏 Credits

NS Legacy Fuel is a heavily modified derivative of **LegacyFuel by InZidiuZ**.

Original project:

**InZidiuZ/LegacyFuel**

Please retain the original attribution and **GPL-3.0 license** when redistributing.

---

# 📄 License

This project is licensed under the **GNU General Public License v3.0**.

See `LICENSE` for more information.
