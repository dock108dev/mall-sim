# Mallcore Sim

Mallcore Sim is a Godot retail simulator about running stores in a 2000s mall.
The project is built with Godot/GDScript, uses JSON files for gameplay content,
and has automated GUT test coverage for systems, UI flows, and integrations.

## Current Project Shape

- Engine: Godot 4.x standard build, GDScript, Forward Plus renderer.
- Main scene: `res://game/scenes/bootstrap/boot.tscn`.
- Runtime world: `res://game/scenes/world/game_world.tscn`.
- Content source: JSON under `game/content/`, loaded at boot by
  `DataLoaderSingleton` and registered in `ContentRegistry`.
- Tests: GUT tests under `tests/`, `tests/gut/`, `tests/unit/`, and
  `game/tests/`.
- Exports: Windows, macOS, and Linux presets in `export_presets.cfg`.

## Run Locally

1. Install the standard, non-.NET Godot editor.
2. Open this repository by importing `project.godot`.
3. Let Godot import project assets.
4. Press F5, or run the project from the editor.

The boot scene loads all JSON content, validates the content registry, loads
settings, initializes audio, then transitions to the main menu.

## Run Tests

```bash
bash tests/run_tests.sh
```

The runner looks for Godot through `GODOT`, `GODOT_EXECUTABLE`, `godot` on
`PATH`, and common macOS install paths. When Godot is available, it imports
assets and runs GUT headlessly through `res://addons/gut/gut_cmdln.gd`.

## Deployment Basics

Export presets are checked into `export_presets.cfg` for:

- `Windows Desktop` -> `exports/windows/MallcoreSim.exe`
- `macOS` -> `exports/macos/MallcoreSim.zip`
- `Linux/X11` -> `exports/linux/MallcoreSim.x86_64`

The GitHub export workflow validates export configuration on version tags and
builds Windows and macOS artifacts. Built-in code signing is disabled in the
checked-in presets.

## Documentation

The active project docs are in `docs/`:

- [Docs Index](docs/index.md)
- [Setup](docs/setup.md)
- [Architecture](docs/architecture.md)
- [Content and Data](docs/content-data.md)
- [Testing](docs/testing.md)
- [Configuration and Deployment](docs/configuration-deployment.md)
- [Contributing](docs/contributing.md)
- [Docs Consolidation Audit](docs/audits/docs-consolidation.md)
