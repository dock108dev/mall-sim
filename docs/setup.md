# Setup

## Requirements

- Godot standard editor build, non-.NET.
- Bash for `tests/run_tests.sh`.
- No package manager is required for game runtime code.

`project.godot` declares Godot `4.6` features. The export workflow still uses
Godot `4.3`, so treat release exports as version-sensitive and verify them with
the engine version you intend to ship.

## Open the Project

1. Launch Godot.
2. Import `project.godot`.
3. Let Godot import assets.
4. Run the project from the editor.

The configured main scene is `res://game/scenes/bootstrap/boot.tscn`.

## Command-Line Import

Use the import helper when preparing a headless test or export environment:

```bash
bash scripts/godot_import.sh
```

If your Godot binary is not named `godot`, set one of these environment
variables before running scripts:

```bash
export GODOT=/path/to/Godot
export GODOT_EXECUTABLE=/path/to/Godot
```

## Command-Line Godot Wrapper

Use the generic wrapper when you need to run the resolved Godot binary directly:

```bash
bash scripts/godot_exec.sh --headless --path . --version
```

It uses the same resolution order as the import and test helpers.

## Run Tests

```bash
bash tests/run_tests.sh
```

The runner imports assets first, runs GUT headlessly through
`res://addons/gut/gut_cmdln.gd`, writes full output to `tests/test_run.log`,
and then runs shell validators under `tests/`.

## Project Layout

```text
addons/gut/          GUT test framework plugin
game/autoload/       global singleton scripts configured in project.godot
game/content/        JSON content loaded at boot
game/resources/      Resource classes created from content data
game/scenes/         boot, world, store, character, and UI scenes
game/scripts/        systems, store controllers, UI controllers, player, world
tests/               primary GUT test suite and shell test runner
game/tests/          additional GUT tests included by .gutconfig.json
tools/               local project tooling
```

Generated Godot cache directories such as `.godot/` are not source
documentation or game content.
