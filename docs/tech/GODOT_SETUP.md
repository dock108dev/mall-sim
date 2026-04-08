# Godot Setup Guide

How to get mallcore-sim running locally for development.

---

## Prerequisites

- **Godot 4.3 or later** (standard build, not .NET). Download from https://godotengine.org/download
- **Git** for version control
- **macOS 12+ or Windows 10+** (Linux untested but should work)
- A text editor for JSON content files (VS Code recommended, with Godot GDScript extension)

## Getting Started

```bash
# Clone the repository
git clone <repo-url> mallcore-sim
cd mallcore-sim

# Open in Godot
# Option A: Double-click project.godot in Finder/Explorer
# Option B: Open Godot, click Import, navigate to the project folder
```

On first open, Godot will import all assets. This may take 30-60 seconds depending on asset volume.

## Project Settings to Verify

After opening the project, check these settings under Project > Project Settings:

### Display
- Window width: 1920
- Window height: 1080
- Resizable: On
- Mode: Windowed
- Stretch mode: canvas_items
- Stretch aspect: keep

### Rendering
- Renderer: Forward+ (default for desktop)
- Anti-aliasing: MSAA 2x (3D)
- V-Sync: Enabled

### Application
- Main scene: `res://scenes/boot/boot.tscn`
- Name: "mallcore-sim"

## Input Map

The following input actions should be defined in Project Settings > Input Map:

| Action | Default Key | Purpose |
|--------|------------|---------|
| `pause_toggle` | Space | Pause/resume time |
| `speed_1` | 1 | Normal speed |
| `speed_2` | 2 | Double speed |
| `speed_4` | 3 | Quad speed |
| `speed_pause` | 4 | Pause time |
| `toggle_inventory` | I | Open/close inventory panel |
| `toggle_pricing` | P | Open/close pricing panel |
| `toggle_catalog` | C | Open/close catalog |
| `toggle_management` | Tab | Switch view mode |
| `cancel` | Escape | Close panel / pause menu |
| `debug_overlay` | F1 | Toggle debug overlay |
| `zoom_in` | Scroll Up | Zoom camera in |
| `zoom_out` | Scroll Down | Zoom camera out |

## Autoload List

These singletons are registered under Project Settings > Autoload:

| Name | Script Path | Purpose |
|------|------------|---------|
| `EventBus` | `res://scripts/autoload/event_bus.gd` | Global signal broker |
| `GameManager` | `res://scripts/autoload/game_manager.gd` | State machine, lifecycle |
| `DataLoader` | `res://scripts/autoload/data_loader.gd` | JSON content registry |
| `EconomySystem` | `res://scripts/autoload/economy_system.gd` | Money and market values |
| `InventorySystem` | `res://scripts/autoload/inventory_system.gd` | Item tracking |
| `TimeSystem` | `res://scripts/autoload/time_system.gd` | Day cycle and clock |
| `ReputationSystem` | `res://scripts/autoload/reputation_system.gd` | Score and tier tracking |
| `SaveManager` | `res://scripts/autoload/save_manager.gd` | Save/load persistence |
| `TransitionManager` | `res://scripts/autoload/transition_manager.gd` | Scene transitions |

Order matters -- EventBus should be first, GameManager second, DataLoader third.

## Running the Game

1. Press F5 (or the Play button) to run from the main scene
2. The boot scene initializes, then transitions to the main menu
3. From the main menu, start a new game to enter gameplay

To run a specific scene for testing:
- Right-click any `.tscn` file in the FileSystem dock
- Select "Run This Scene" (or press F6 with the scene open)

## Directory Structure

```
mallcore-sim/
  +-- project.godot
  +-- content/            # JSON data files (items, stores, economy)
  +-- scenes/             # .tscn scene files
  |    +-- boot/
  |    +-- menu/
  |    +-- game/
  |    +-- stores/
  |    +-- characters/
  |    +-- ui/
  |    +-- debug/
  +-- scripts/            # .gd script files
  |    +-- autoload/      # Singleton systems
  |    +-- resources/     # Resource class definitions
  |    +-- ui/            # UI-specific scripts
  |    +-- store/         # Store-specific logic
  |    +-- customer/      # Customer AI
  +-- assets/             # Art, audio, fonts
  |    +-- models/
  |    +-- textures/
  |    +-- icons/
  |    +-- audio/
  |    +-- fonts/
  +-- docs/               # Design and technical documentation
```

## Common Gotchas

1. **Autoload order**: If you get null references at startup, check that autoloads are registered in the correct order. EventBus must load before any system that connects to its signals.

2. **JSON parse errors**: If DataLoader reports errors, check for trailing commas in JSON files. Godot's JSON parser is strict.

3. **Scene references**: If a scene fails to load, verify the path matches exactly (case-sensitive on all platforms).

4. **Import cache**: If assets look wrong after a git pull, delete the `.godot/imported/` directory and reopen the project to force a reimport.

5. **Resolution scaling**: If UI looks wrong, verify the stretch mode is set to `canvas_items` and aspect is `keep`. This ensures consistent layout across display sizes.

6. **GDScript formatting**: The project uses tabs for indentation (Godot default). Do not change this to spaces.

7. **Resource leaks**: When instancing scenes dynamically, always call `queue_free()` when removing them. Godot does not garbage collect scene tree nodes.
