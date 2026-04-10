# Setup Guide

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

On first open, Godot will import all assets. This may take 30-60 seconds.

## Running the Game

1. Press F5 (or the Play button) to run from the main scene
2. The boot scene initializes, then transitions to the main menu
3. From the main menu, start a new game to enter gameplay

To run a specific scene for testing:
- Right-click any `.tscn` file in the FileSystem dock
- Select "Run This Scene" (or press F6 with the scene open)

---

## Project Settings

### Display
- Resolution: 1920x1080 (windowed), minimum 1280x720
- Stretch mode: `canvas_items`, aspect: `keep`
- Fullscreen: supported, toggled via settings
- V-Sync: enabled by default
- Target: 60 FPS

### Rendering
- Renderer: Forward+ (Vulkan)
- Anti-aliasing: MSAA 2x (3D)
- Shadows: medium quality directional + omni
- Post-processing: minimal (slight bloom on neon, subtle vignette)

### Main Scene
- `res://game/scenes/bootstrap/boot.tscn`

---

## Input Map

| Action | Default Key | Purpose |
|---|---|---|
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

Controls are rebindable through the in-game settings panel.

---

## Autoloads

Registered in `project.godot` (authoritative source):

| Name | Path | Purpose |
|---|---|---|
| `GameManager` | `game/autoload/game_manager.gd` | State machine, lifecycle |
| `AudioManager` | `game/autoload/audio_manager.gd` | SFX/music playback |
| `Settings` | `game/autoload/settings.gd` | User preferences |
| `EventBus` | `game/autoload/event_bus.gd` | Global signal broker |

All other systems (TimeSystem, EconomySystem, InventorySystem, etc.) are standalone class scripts in `game/scripts/systems/` instantiated by GameWorld at runtime. See `docs/architecture.md` for the full system list.

---

## Build Targets

### macOS (Primary)
- Universal binary (x86_64 + ARM64)
- Minimum: macOS 12 Monterey
- Distribution: `.app` inside `.dmg`
- Notarization required for distribution outside App Store

### Windows (Near-Term)
- x86_64, 64-bit only
- Minimum: Windows 10
- Distribution: zip with executable

### Linux
- Not actively targeted, but Godot supports it natively

### Minimum Hardware

| Component | Minimum | Recommended |
|---|---|---|
| CPU | Dual-core 2.0 GHz | Quad-core 2.5 GHz+ |
| RAM | 4 GB | 8 GB |
| GPU | Integrated (Intel UHD 620 / Apple M1) | Any dedicated GPU |
| Storage | 500 MB | 1 GB |
| Display | 1280x720 | 1920x1080 |

---

## Tech Stack

| Component | Choice | Rationale |
|---|---|---|
| Engine | Godot 4.3+ | Open source (MIT), no license fees, GDScript built-in |
| Language | GDScript | Static typing enforced, tight engine integration |
| Renderer | Forward+ (Vulkan) | Best quality for desktop, full lighting/shader support |
| Content | JSON | Human-readable, easy to diff, no external tooling |
| Save format | JSON | Debuggable, forward-compatible with versioned migrations |
| Audio | Godot built-in | AudioStreamPlayer pooling, bus-based mixing |

No external package manager. No networking. No external services.

---

## Common Gotchas

1. **Autoload order**: EventBus must load before any system that connects to its signals.
2. **JSON parse errors**: Godot's JSON parser is strict — no trailing commas.
3. **Scene references**: Paths are case-sensitive on all platforms.
4. **Import cache**: Delete `.godot/imported/` and reopen to force reimport after git pull issues.
5. **Stretch mode**: Must be `canvas_items` with aspect `keep` for consistent UI layout.
6. **Indentation**: The project uses tabs (Godot default). Do not change to spaces.
7. **Resource leaks**: Always call `queue_free()` when removing dynamically instanced scene nodes.

---

## Export Templates

1. Editor > Manage Export Templates > Download and Install
2. Define export presets in Project > Export (macOS Release, macOS Debug, Windows Release, Windows Debug)
3. Export via `godot --headless --export-release` for CI or Project > Export for manual builds
