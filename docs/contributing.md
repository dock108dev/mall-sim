# Contributing

## Scope Discipline

Keep changes focused on the feature, bug, or documentation issue being handled.
Do not refactor unrelated systems while making a narrow fix.

## GDScript Standards

- Use static typing for variables, parameters, and return values.
- Prefer `preload()` when the path is static; use `load()` only for dynamic
  paths.
- Use `@export` for editor-configurable values.
- Use `@onready` for direct child references.
- Prefer guard clauses over deeply nested logic.
- Keep cross-system communication signal-driven through `EventBus` unless
  `GameWorld` is explicitly injecting a dependency during initialization.
- Do not add temporary `print()` diagnostics to committed code; use
  `push_warning()` or `push_error()` for meaningful diagnostics.

## File Organization

GDScript files generally follow this order:

1. one-sentence `##` script doc comment
2. `class_name` when needed
3. `extends`
4. signals
5. enums and constants
6. `@export` variables
7. `@onready` variables
8. regular variables
9. Godot lifecycle callbacks
10. public functions
11. private helpers prefixed with `_`

## Naming

| Item | Convention | Example |
| --- | --- | --- |
| files/folders | `snake_case` | `store_controller.gd` |
| classes | `PascalCase` | `StoreController` |
| functions/variables | `snake_case` | `get_item_by_id` |
| constants | `UPPER_SNAKE_CASE` | `MAX_SAVE_FILE_BYTES` |
| signals | `snake_case` | `item_sold` |
| scenes | `snake_case` | `main_menu.tscn` |

## Content Changes

- Add gameplay content under `game/content/`.
- Use canonical IDs that match `^[a-z][a-z0-9_]{0,63}$`.
- Keep display names separate from IDs.
- Verify new scene paths exist if content references them.
- Add or update tests when content changes affect loader behavior, catalog
  coverage, store setup, event behavior, or save/load expectations.

## Documentation Changes

The root should only contain `README.md` as active project documentation.
Supporting project docs belong under `docs/`.

When editing docs:

- Validate claims against current scripts, scenes, configs, or content files.
- Prefer fewer consolidated docs over many overlapping notes.
- Remove speculative roadmap language unless it is clearly marked as future
  planning.
- Do not document nonexistent files, old workflows, or deprecated systems.
