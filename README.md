# Mallcore Sim

Mallcore Sim is a Godot retail simulator about running specialty stores in a
2000s-style mall. Gameplay code lives in GDScript, boot-time content is loaded
from JSON under `game/content/`, tests run through the checked-in GUT addon, and
export presets are versioned in the repository.

## Run locally

1. Install a standard Godot 4.x editor build.
2. Import `project.godot`.
3. Let Godot import project assets.
4. Run the project with F5.

The configured entry scene is `res://game/scenes/bootstrap/boot.tscn`. Boot
loads content, validates the registry, loads settings from `user://settings.cfg`,
initializes audio, and then opens the main menu.

## Run tests

```bash
bash tests/run_tests.sh
```

The test runner resolves Godot from `GODOT`, `GODOT_EXECUTABLE`, `godot` on
`PATH`, or common macOS install paths, imports assets, runs GUT headlessly,
runs `game/tests/run_tests.gd` when present, writes output to
`tests/test_run.log`, and then runs shell validators matching
`tests/validate_*.sh`.

## Deployment basics

`export_presets.cfg` defines checked-in local export presets for:

- `Windows Desktop` -> `exports/windows/MallcoreSim.exe`
- `macOS` -> `exports/macos/MallcoreSim.zip`
- `Linux/X11` -> `exports/linux/MallcoreSim.x86_64`

Tagged GitHub releases (`v*` tags) validate export configuration and publish
Windows, macOS, and Linux artifacts. The canonical engine version is Godot
`4.6.2`: `project.godot` declares `4.6` features and both the validate and
export CI workflows install `4.6.2-stable`. Run local builds and tests with
the same version.

## Documentation

Supporting project docs live under `docs/`:

- [Docs Index](docs/index.md)
- [Setup](docs/setup.md)
- [Architecture](docs/architecture.md)
- [Design](docs/design.md)
- [Content and Data](docs/content-data.md)
- [Testing](docs/testing.md)
- [Configuration and Deployment](docs/configuration-deployment.md)
- [Contributing](docs/contributing.md)
- [Roadmap](docs/roadmap.md)
