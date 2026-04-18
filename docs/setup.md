# Setup

## Requirements

- A standard Godot 4.x editor build (non-.NET).
- Bash for the helper scripts and test runner.
- No external package manager is required for gameplay code.

`project.godot` declares Godot `4.6` project features. The tagged export
workflow still installs Godot `4.3`, so local export verification should use
the engine version you plan to ship with.

## Open the project

1. Launch Godot.
2. Import `project.godot`.
3. Let Godot import assets.
4. Run the project from the editor.

The configured main scene is `res://game/scenes/bootstrap/boot.tscn`.

## Command-line helpers

### Import assets

Use the import helper on a fresh clone or before headless test/export work:

```bash
bash scripts/godot_import.sh
```

### Run the resolved Godot binary

Use the wrapper when you want the repo's Godot-resolution logic without
repeating it by hand:

```bash
bash scripts/godot_exec.sh --headless --path . --version
```

Both scripts resolve Godot in this order:

1. `GODOT`
2. `GODOT_EXECUTABLE`
3. `godot` on `PATH`
4. `/Applications/Godot.app/Contents/MacOS/Godot`
5. `$HOME/Applications/Godot.app/Contents/MacOS/Godot`

If needed:

```bash
export GODOT=/path/to/Godot
```

## Run tests

```bash
bash tests/run_tests.sh
```

The runner:

1. Resolves a Godot binary.
2. Imports project assets.
3. Runs GUT through `res://addons/gut/gut_cmdln.gd`.
4. Runs `res://game/tests/run_tests.gd` when that file exists.
5. Writes combined output to `tests/test_run.log`.
6. Runs shell validators matching `tests/validate_*.sh`.

## Repository layout

```text
addons/gut/          Checked-in GUT addon
game/autoload/       Autoload singletons from project.godot
game/content/        JSON content scanned at boot
game/resources/      Typed Resource classes populated from content
game/scenes/         Boot, menu, world, store, debug, and UI scenes
game/scripts/        Systems, controllers, and gameplay support scripts
tests/               Main GUT suite, integration/unit tests, shell validators
game/tests/          Additional GUT coverage included by .gutconfig.json
docs/                Active supporting project docs and audit notes
tools/               Local tooling and templates
```

Generated cache directories such as `.godot/` are editor/runtime artifacts, not
source content or project documentation.
