# Mallcore Sim

Mallcore Sim is a Godot retail simulator about operating specialty stores in a
2000s-style mall. The project uses GDScript for gameplay code, JSON for game
content, GUT for automated tests, and checked-in export presets for local and
CI builds.

## Run Locally

1. Install the standard Godot editor build.
2. Import `project.godot`.
3. Let Godot import project assets.
4. Run the project with F5.

`project.godot` starts `res://game/scenes/bootstrap/boot.tscn`. Boot loads JSON
content from `game/content/`, validates `ContentRegistry`, loads settings from
`user://settings.cfg`, initializes audio, then transitions to the main menu.

## Run Tests

```bash
bash tests/run_tests.sh
```

The test runner resolves Godot from `GODOT`, `GODOT_EXECUTABLE`, `godot` on
`PATH`, or common macOS install paths, imports project assets, runs GUT
headlessly, and then runs any shell validators in `tests/validate_*.sh`.

## Deployment Basics

`export_presets.cfg` defines local export presets for:

- `Windows Desktop` -> `exports/windows/MallcoreSim.exe`
- `macOS` -> `exports/macos/MallcoreSim.zip`
- `Linux/X11` -> `exports/linux/MallcoreSim.x86_64`

Tagged GitHub releases validate export configuration and build Windows and macOS
artifacts. Linux has a checked-in preset for local export, but the current
release workflow does not publish a Linux artifact.

## Documentation

Active project docs live under `docs/`:

- [Docs Index](docs/index.md)
- [Setup](docs/setup.md)
- [Architecture](docs/architecture.md)
- [Content and Data](docs/content-data.md)
- [Testing](docs/testing.md)
- [Configuration and Deployment](docs/configuration-deployment.md)
- [Contributing](docs/contributing.md)
- [Docs Consolidation Audit](docs/audits/docs-consolidation.md)
