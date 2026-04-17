# Setup

## Requirements

- Godot standard build, non-.NET.
- Bash for `tests/run_tests.sh`.
- No package manager is required for game runtime code.

The project currently declares Godot `4.6` features in `project.godot`. The
export workflow installs Godot `4.3`, so verify local exports with the engine
version used by your release target before cutting a tagged build.

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

## Run Tests

```bash
bash tests/run_tests.sh
```

The runner imports assets first, then runs GUT tests headlessly. Output is
written to `tests/test_run.log`, while the terminal shows the summarized GUT
result lines.

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
