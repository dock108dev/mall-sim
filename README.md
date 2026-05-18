# Shelf Life / Mallcore Sim

This repository is a Godot/GDScript retail sim. `project.godot` currently names
the running project `Shelf Life`, while the checked-in export presets still
produce `MallcoreSim` desktop artifacts. Boot-time content is loaded from JSON
under `game/content/`, tests use the checked-in GUT addon, and release exports
are driven by the versioned Godot export presets and GitHub Actions workflows.

## Run locally

1. Install a standard Godot 4.x editor build.
2. Import `project.godot`.
3. Let Godot import project assets.
4. Run the project with F5.

The configured entry scene is `res://game/scenes/bootstrap/boot.tscn`.

## Run tests

```bash
bash tests/run_tests.sh
```

The test runner resolves Godot from `GODOT`, `GODOT_EXECUTABLE`, `godot` on
`PATH`, or common macOS install paths, imports assets, runs GUT headlessly,
runs `game/tests/run_tests.gd` when present, writes output to
`tests/test_run.log`, and then runs shell validators matching
`tests/validate_*.sh` plus the SSOT tripwires under `scripts/`
(`validate_translations.sh`, `validate_single_store_ui.sh`,
`validate_tutorial_single_source.sh`).

## Deployment basics

`export_presets.cfg` defines checked-in local export presets for:

- `Windows Desktop` -> `exports/windows/MallcoreSim.exe`
- `macOS` -> `exports/macos/MallcoreSim.zip`
- `Linux/X11` -> `exports/linux/MallcoreSim.x86_64`

Tagged GitHub releases (`v*` tags) validate export configuration and publish
Windows, macOS, and Linux artifacts. `project.godot` declares Godot `4.6`
features; CI uses Godot 4.6.2 builds (`4.6.2-stable` in validation and
`4.6.2` in the export workflow). Use Godot 4.6.2 locally for parity.

## Documentation

Supporting project docs live under `docs/`:

- [Docs Index](docs/index.md)
- [Setup](docs/setup.md)
- [Architecture](docs/architecture.md)
- [Content and Data](docs/content-data.md)
- [Testing](docs/testing.md)
- [Configuration and Deployment](docs/configuration-deployment.md)
- [Visual Grammar](docs/style/visual-grammar.md)
