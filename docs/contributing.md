# Contributing

## Scope discipline

Keep changes focused on the feature, bug, or documentation issue being handled.
Avoid unrelated refactors during narrow fixes.

## Formatting

`.editorconfig` is the checked-in source of truth:

- tabs for general source files
- two spaces for Markdown, YAML, and JSON
- LF line endings
- UTF-8
- final newlines

## GDScript standards

- Use static typing for variables, parameters, and return values.
- Prefer `preload()` for static paths and `load()` for dynamic paths.
- Use `@export` for editor-exposed settings.
- Use `@onready` for direct child references.
- Prefer guard clauses over deep nesting.
- Keep cross-system communication signal-driven through `EventBus` unless
  `GameWorld` is explicitly wiring concrete dependencies during initialization.
- Prefer `push_warning()` or `push_error()` over temporary `print()` debugging in
  committed code.

## Typical file organization

GDScript files commonly follow this order:

1. one-sentence `##` script doc comment
2. `class_name` when needed
3. `extends`
4. signals
5. enums and constants
6. `@export` variables
7. `@onready` variables
8. regular variables
9. lifecycle callbacks
10. public methods
11. private helpers prefixed with `_`

## Naming

| Item | Convention | Example |
| --- | --- | --- |
| files and folders | `snake_case` | `store_controller.gd` |
| classes | `PascalCase` | `StoreController` |
| functions and variables | `snake_case` | `get_item_by_id` |
| constants | `UPPER_SNAKE_CASE` | `MAX_SAVE_FILE_BYTES` |
| signals | `snake_case` | `item_sold` |
| scenes | `snake_case` | `main_menu.tscn` |

## Content changes

- Add gameplay content under `game/content/`.
- Use canonical IDs matching `^[a-z][a-z0-9_]{0,63}$`.
- Keep display names separate from IDs.
- Keep scene references under `res://game/scenes/`, and store scenes under
  `res://game/scenes/stores/`.
- Update tests when content changes affect loader behavior, catalogs, store
  setup, events, or save/load expectations.

## Testing expectations

Use the existing test entry point:

```bash
bash tests/run_tests.sh
```

Add or update tests when a change affects runtime logic, save/load behavior,
event contracts, or content-loading rules.

## Documentation rules

The active project docs boundary is:

- root: `README.md` only
- supporting docs: `docs/`
- audit/history notes: `docs/audits/`

When editing docs:

- validate claims against current scripts, scenes, configs, content, or
  workflows
- prefer consolidated docs over overlapping notes
- remove references to nonexistent files, outdated workflows, or deprecated
  behavior
- keep roadmap or planning language out of the active docs set unless it is
  clearly marked as future planning elsewhere
