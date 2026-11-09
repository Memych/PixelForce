# PixelForce - OoTMM Tracker

A comprehensive tracker for the **Ocarina of Time / Majora's Mask** ([OoTMM](https://github.com/OoTMM/OoTMM)) randomizer. Built with [Godot Engine](https://godotengine.org/), this tool helps players track locations, items, and progression during their randomizer playthroughs.

> [!IMPORTANT]
> This tracker is developed and tested against **build-dev** releases of the [OoTMM](https://github.com/OoTMM/OoTMM) randomizer — **not** stable tags (e.g. `v32`, `v33`). Location names, item lists, spoiler-log format and logic rules differ between build-dev and stable builds, so this tracker may misparse logs or misjudge reachability if your randomizer is not a matching build-dev version.

<img width="1538" height="928" alt="image" src="https://github.com/user-attachments/assets/e0c5a1f7-2e32-45a9-91b5-b052cdf0c551" />

<img width="1538" height="928" alt="image" src="https://github.com/user-attachments/assets/83962491-9169-4fa4-9041-4952fc2a4e9e" />

<img width="1538" height="928" alt="image" src="https://github.com/user-attachments/assets/70bc8855-195c-4a1e-8d78-17ecda875e36" />

<img width="1538" height="928" alt="image" src="https://github.com/user-attachments/assets/714aec7f-3072-4159-a7a4-2217b1620963" />

<img width="1538" height="928" alt="image" src="https://github.com/user-attachments/assets/f4b9f7ba-c451-4c78-bfe9-ba8221ddcabf" />

## Features

- 📍 **5500+ locations** tracked across both OoT and MM worlds
- 🗺️ **Interactive map** with region markers, entrances, and quick-jump navigation
- 🎒 **Item tracker** with progressive counters for equipment, bottles, songs, masks, keys, and tokens
- ⚙️ **Settings panel** mirroring OoTMM randomizer options
- 🤖 **AutoTracker** support via WebSocket and TCP memory reading
- 💾 **Save/Load** progress and spoiler log parsing
- 🌍 **Multi-world** support
- 🔍 **Advanced filters** (by world, game, checked status, reachability)

## Tabs Overview

### 📋 Locations

The main checklist view. Load a spoiler log (`OoTMM-Spoiler-*.txt`) to populate all locations with their randomized items.

- **Tree view** — locations grouped by region and sub-region
- **Checkboxes** — mark locations as visited; counters update automatically `[checked/available/total]`
- **Filters** — filter by World, Game (OoT/MM/Both), Checked status, Reachability (logic-based)
- **Search** — quick text search across all location names
- **Status bar** — shows total locations, checked count, and current mode (single/multi-world)
- **Color coding** — green for checked, red for unreachable, blue for available

### 🗺️ Map

Visual map of all regions from both games with interactive markers.

- **Region tree** — navigate to any region (Kokiri Forest, Clock Town, Water Temple, etc.)
- **Map images** — high-quality room/region maps loaded from `region_maps.json`
- **Markers** — location markers (chests, NPCs, etc.) and entrance markers (portals, doors)
- **Zoom & Pan** — mouse wheel to zoom, drag to pan
- **Quick Jump** — instant navigation to any entrance
- **Filters** — show/hide by status (unchecked, available, unreachable) and logic reachability
- **Counters** — each region shows `[collected/available/total]`

### 🎒 Items

Visual item tracker with progressive counters for all collectibles.

- **Equipment** — swords, shields, tunics, boots, tools (bow, hookshot, bombs, etc.)
- **Health & Magic** — heart containers, heart pieces, magic meter upgrades
- **Bottles** — track bottle contents (milk, fairies, bugs, fish, etc.)
- **Songs** — OoT and MM songs with progressive counters
- **Masks** — all transformation and regular masks
- **Keys** — dungeon keys, boss keys, silver rupees, skull tokens, stray fairies
- **Upgrades** — wallets, scales, strength, ammo upgrades
- **Color-coded panels** — each category has its own visual panel

### ⚙️ Settings

Configure randomizer settings to match your seed. Settings affect logic evaluation and item availability.

- **Categories** — Main, Shuffle, Events, Cross, Misc, Progressive, Extensions, Shared, Ageless, Age Requirements, World, Special Conditions, Tricks, Glitches, Shop Prices, Locations, Prices
- **Widgets** — checkboxes for boolean options, spinboxes for numeric values, enums for multi-choice
- **Examples** — Bombchu Behavior, Din's Fire in MM, Farore's Wind in MM, progressive wallets, etc.

### 🤖 AutoTracker

Automatically track game state by connecting to an emulator or randomizer daemon. The WebSocket daemon and multiplayer client are provided by the [OoTMM multiplayer](https://github.com/OoTMM/multiplayer) project.

- **WebSocket** — connect to OoTMM daemon (default: `127.0.0.1:39278`)
- **TCP Memory Reader** — read game memory directly from emulator (port `13249`)
- **Event log** — real-time log of connection status and game events
- **Map switching** — automatically switches map region based on player location

## Troubleshooting & Known Limitations

### ⚠️ Performance & Minor Lag
- **Initial Load & Filtering**: The tracker processes over 5,500 locations and evaluates complex logic graphs in real-time. You may experience brief freezes when loading a large spoiler log, switching map regions, or applying advanced filters (e.g., "Reachable"). This is expected behavior and depends on your system's CPU.
- **Rapid UI Updates**: Checking/unchecking locations in rapid succession might cause slight UI delays as counters and logic states recalculate across the entire graph.

### 🔌 AutoTracker Disconnects
- **Emulator State**: The TCP memory reader (default port `13249`) requires the emulator to be actively running. Pausing, closing, or crashing the emulator will immediately break the connection.
- **Daemon & Firewall**: The WebSocket connection (default port `39278`) relies on the OoTMM randomizer daemon. Ensure the daemon is running and that your firewall/antivirus is not blocking local loopback connections (`127.0.0.1`).
- **Memory Address Shifts**: Major updates to the emulator or the randomizer may change memory addresses, temporarily breaking the TCP reader until the tracker is updated.

### 🧠 Logic Inaccuracies
- **Version Mismatch**: The tracker's logic rules (`access_rules_*.json` and `logic_macros.gd`) and data files are synced to the current **build-dev** branch of OoTMM, not to stable releases (`v32`, `v33`, ...). Stable builds use different logic/data, so "Reachable"/"Unreachable" states and spoiler-log parsing can be inaccurate unless you're running a matching build-dev version.
- **Edge Cases**: Highly specific interactions involving multi-world item dependencies or obscure glitch combinations might not be perfectly mirrored in the tracker's logic evaluator.

### 📄 Spoiler Log Parsing
- Ensure your spoiler log is generated by a standard, compatible version of the OoTMM randomizer. Heavily modified or outdated spoiler log formats may fail to parse correctly, resulting in missing locations or items.

## Installation

### From Release

1. Download the latest release from the [Releases](https://github.com/Memych/PixelForce/releases) page
2. Extract the archive
3. Run `PixelForce_OoTMMTracker.exe`

### From Source

**Requirements:**
- [Godot 4.x](https://godotengine.org/download)

**Steps:**
1. Clone the repository:
   ```bash
   git clone https://github.com/Memych/PixelForce.git
   cd PixelForce

## Credits

- **OoTMM Randomizer** — [OoTMM/OoTMM](https://github.com/OoTMM/OoTMM)
- **OoTMM Multiplayer Client** (AutoTracker daemon) — [OoTMM/multiplayer](https://github.com/OoTMM/multiplayer)
- **Godot Engine** — [godotengine.org](https://godotengine.org/)
- **Fonts** — MegaMan10Regular, FOT-ChiaroStd-B
