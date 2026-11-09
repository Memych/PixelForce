# PixelForce - OoTMM Tracker

A comprehensive tracker for the **Ocarina of Time / Majora's Mask (OoTMM)** randomizer. Built with [Godot Engine](https://godotengine.org/), this tool helps players track locations, items, and progression during their randomizer playthroughs.

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

Automatically track game state by connecting to an emulator or randomizer daemon.

- **WebSocket** — connect to OoTMM daemon (default: `127.0.0.1:39278`)
- **TCP Memory Reader** — read game memory directly from emulator (port `13249`)
- **Auto-save** — progress is saved automatically
- **Event log** — real-time log of connection status and game events
- **Map switching** — automatically switches map region based on player location

## Installation

### From Release

1. Download the latest release from the [Releases](https://github.com/Memych/pixel-force-ootmm-tracker/releases) page
2. Extract the archive
3. Run `PixelForce_OoTMMTracker.exe`

### From Source

**Requirements:**
- [Godot 4.x](https://godotengine.org/download)

**Steps:**
1. Clone the repository:
   ```bash
   git clone https://github.com/Memych/pixel-force-ootmm-tracker.git
   cd pixel-force-ootmm-tracker
