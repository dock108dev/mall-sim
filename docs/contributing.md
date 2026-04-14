# Contributing

## Code Conventions

### Naming

- **Files and folders:** `snake_case` — `player_controller.gd`, `item_definition.gd`
- **Classes:** `PascalCase` — `class_name PlayerController`, `class_name ItemDefinition`
- **Variables and functions:** `snake_case` — `var current_health: int`, `func take_damage(amount: int) -> void`
- **Constants:** `UPPER_SNAKE_CASE` — `const MAX_INVENTORY_SIZE: int = 64`
- **Signals:** `snake_case`, past tense — `signal item_sold(item: ItemInstance)`
- **Enums:** `PascalCase` name, `UPPER_SNAKE_CASE` values — `enum State { IDLE, WALKING, INTERACTING }`

### GDScript Style

- **Always use static typing.** Every variable, parameter, and return type must be typed.
  ```gdscript
  # Good
  var price: float = 0.0
  func calculate_total(items: Array[ItemInstance]) -> float:

  # Bad
  var price = 0.0
  func calculate_total(items):
  ```
- **One responsibility per script.** A script does one thing. If it is doing two things, split it.
- **No monolithic managers.** If a manager script is growing past 300 lines, it needs to delegate to sub-systems.
- **Prefer signals over direct references.** Use EventBus for cross-system communication. Use direct signals for parent-child within the same scene.
- **No `get_node()` with long paths.** Use `@onready` with `$ChildName` for direct children, or `@export` node references set in the editor.
- **No `await` in `_ready()`.** If you need async initialization, use a separate `initialize()` method called after the scene is fully loaded.

### File Organization

- One class per file (with rare exceptions for small inner classes)
- File name matches class name in snake_case: `class_name StoreController` -> `store_controller.gd`
- Group related scripts in subdirectories under `game/scripts/`

## Scene and Resource Conventions

- Scene files (`.tscn`) go in `game/scenes/` organized by feature area
- Custom Resources (`.tres`) go in `game/resources/`
- Resource class scripts go in `game/resources/` alongside their `.tres` files
- Autoload scripts go in `game/autoload/`
- Content JSON files go in `game/content/` with subdirectories per domain

## Branch Naming

```
feature/short-description    — new functionality
fix/short-description        — bug fix
refactor/short-description   — code restructuring without behavior change
docs/short-description       — documentation only
```

Examples: `feature/customer-pathfinding`, `fix/inventory-drag-offset`, `refactor/store-controller-split`

## Commit Messages

Format: `type: description` where type is `feat`, `fix`, `refactor`, `test`, or `docs`.

Use imperative mood, lowercase, no period. First line under 72 characters.

```
feat: add customer browsing state machine
fix: item tooltip position on ultrawide displays
refactor: extract shelf placement into sub-system
docs: update architecture diagram
```

If more context is needed, add a blank line then a body paragraph.

## Pull Request Process

1. Create a branch from `main` using the naming convention above
2. Make your changes — keep the diff focused on one feature or fix
3. Test in the Godot editor: run the game, verify your change works, check for errors in the output panel
4. Push your branch and open a PR against `main`
5. PR description should include: what changed, why, and how to test it
6. Wait for review before merging

## What Not to Do

- **No dead scaffolding.** Do not commit empty scripts, placeholder scenes, or stub functions that say `# TODO`. If you are not implementing it in this PR, do not add the file.
- **No premature optimization.** Write clear code first. Profile before optimizing.
- **No asset imports without discussion.** Do not add 3D models, textures, or audio files without discussing format, size, and licensing first.
- **No changes to autoload registration** without discussing in an issue first.
- **No `print()` statements in committed code.** Use `push_warning()` or `push_error()` for diagnostics.
- **No hardcoded magic numbers.** Use constants or config values.
- **No direct file system paths.** Use `res://` and `user://` prefixes for all file access within Godot.

## Release Builds

Export presets for Windows Desktop, macOS, and Linux/X11 are configured in `export_presets.cfg` at the project root. Each preset embeds the PCK into the executable (single-file mode) and excludes development-only paths (`.aidlc/`, `docs/`, `tests/`, `*.md`, `*.txt`, `.gitignore`, `.gutconfig.json`).

### Prerequisites

1. Install [Godot 4.3+](https://godotengine.org/download) standard build (not .NET).
2. Download export templates via **Editor → Manage Export Templates** and install the matching version.
3. For signed macOS builds: provide a Developer ID certificate in Keychain and set `codesign/identity` in the macOS preset. For unsigned local testing, leave the identity blank.
4. For signed Windows builds: provide an authenticode certificate and set `codesign/identity` in the Windows preset. For unsigned builds, set `codesign/enable=false`.

### Export Steps

1. Open the project in the Godot editor.
2. Go to **Project → Export**.
3. Select the target preset (Windows Desktop, macOS, or Linux/X11).
4. Click **Export Project** (not **Export PCK/ZIP**).
5. Choose the output path matching the preset default (`exports/<platform>/`) or a custom path.
6. Confirm the export completes with no errors in the output panel.

### Validation on a Clean Machine

After exporting, validate the binary on a machine with no Godot editor installed:

1. Copy only the exported binary (`.exe`, `.app` bundle, or `.x86_64`) to the clean machine — no project files.
2. Run the binary.
3. Confirm the game launches to `boot.tscn` without missing resource errors in the OS console.
4. Advance past the boot screen to verify autoloads initialize correctly.

### Version String

The application version is sourced from **ProjectSettings → application/config/version** (`project.godot`). Update this value before tagging a release. The version propagates automatically to all three export presets via the `application/version` and `application/file_version` preset options.
