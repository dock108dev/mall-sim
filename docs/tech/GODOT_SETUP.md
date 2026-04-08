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
- Main scene: `res://game/scenes/bootstrap/boot.tscn`
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

These singletons are registered in `project.godot` under Project Settings > Autoload. **`project.godot` is the authoritative source for this list.**

| Name | Script Path | Purpose |
|------|------------|---------|
| `GameManager` | `res://game/autoload/game_manager.gd` | State machine, lifecycle |
| `AudioManager` | `res://game/autoload/audio_manager.gd` | SFX/music playback |
| `Settings` | `res://game/autoload/settings.gd` | User preferences |
| `EventBus` | `res://game/autoload/event_bus.gd` | Global signal broker |

Other systems (TimeSystem, EconomySystem, InventorySystem, CustomerSystem, ReputationSystem, DataLoader, SaveManager) are standalone class scripts in `game/scripts/`. They are instantiated by GameWorld or GameManager at runtime, not registered as autoloads. See `docs/architecture/SYSTEM_OVERVIEW.md` for full details.

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
  +-- game/                 # Everything Godot loads at runtime
  |    +-- autoload/        # Singleton scripts (GameManager, EventBus, etc.)
  |    +-- content/         # JSON data files (items, stores, economy)
  |    +-- resources/       # Custom Resource class definitions (.gd)
  |    +-- scenes/          # .tscn scene files
  |    |    +-- bootstrap/
  |    |    +-- ui/
  |    |    +-- world/
  |    |    +-- player/
  |    |    +-- stores/
  |    |    +-- debug/
  |    +-- scripts/         # GDScript files
  |    |    +-- core/       # Constants, SaveManager, InputHelper, Interactable
  |    |    +-- systems/    # EconomySystem, InventorySystem, TimeSystem, etc.
  |    |    +-- data/       # DataLoader
  |    |    +-- world/      # BuildMode
  |    |    +-- debug/      # DebugCommands
  |    +-- assets/          # Art, audio, fonts
  |    +-- tests/
  +-- docs/                 # Design and technical documentation
  +-- planning/             # Planning orchestrator (not shipped with game)
  +-- tools/                # Build scripts, data validators
  +-- reference/            # Art references, design mockups
```

## Common Gotchas

1. **Autoload order**: If you get null references at startup, check that autoloads are registered in the correct order. EventBus must load before any system that connects to its signals.

2. **JSON parse errors**: If DataLoader reports errors, check for trailing commas in JSON files. Godot's JSON parser is strict.

3. **Scene references**: If a scene fails to load, verify the path matches exactly (case-sensitive on all platforms).

4. **Import cache**: If assets look wrong after a git pull, delete the `.godot/imported/` directory and reopen the project to force a reimport.

5. **Resolution scaling**: If UI looks wrong, verify the stretch mode is set to `canvas_items` and aspect is `keep`. This ensures consistent layout across display sizes.

6. **GDScript formatting**: The project uses tabs for indentation (Godot default). Do not change this to spaces.

7. **Resource leaks**: When instancing scenes dynamically, always call `queue_free()` when removing them. Godot does not garbage collect scene tree nodes.
