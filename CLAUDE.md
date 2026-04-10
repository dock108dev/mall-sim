# CLAUDE.md — AI Development Instructions

<!-- AIDLC Priority: 0. This file speaks directly to Claude during both
     planning and implementation. It's the "modder's guide" — tells the AI
     exactly how to work with this codebase. -->

## Project Identity

- **Name**: mallcore-sim
- **Engine**: Godot 4.3+ (GDScript, Forward Plus renderer)
- **Language**: GDScript (static typing required)
- **Package manager**: None — Godot editor manages all dependencies
- **Test command**: Run scenes directly in Godot editor (F5) or use GUT for unit tests
- **Lint command**: None — follow GDScript style conventions manually
- **Build command**: Open `project.godot` in Godot editor; export via Export menu

## Coding Standards

### Style

- Follow GDScript style conventions strictly (see docs/contributing.md)
- Max line length: 100 characters
- Imports: Use `preload()` for compile-time loading, `load()` only when path is dynamic
- Docstrings: `##` doc comments above classes, functions, and signals
- Static typing: Required on all variables, parameters, and return types

### File Organization

```
# Every GDScript file follows this structure:
1. ## Doc comment (one sentence describing the script's purpose)
2. class_name declaration (if needed)
3. extends declaration
4. Signals
5. Enums and constants
6. @export variables
7. @onready variables
8. Regular variables
9. _ready() and other Godot lifecycle callbacks
10. Public functions
11. Private helpers (prefix with _)
```

### Naming Conventions

| What                | Convention          | Example                       |
|--------------------|---------------------|-------------------------------|
| Files              | snake_case          | `store_controller.gd`         |
| Folders            | snake_case          | `game/scripts/`               |
| Classes            | PascalCase          | `StoreController`             |
| Functions/methods  | snake_case          | `get_item_by_id`              |
| Variables          | snake_case          | `current_health`              |
| Constants          | UPPER_SNAKE_CASE    | `MAX_INVENTORY_SIZE`          |
| Signals            | snake_case (past tense) | `item_sold`               |
| Enums              | PascalCase name, UPPER_SNAKE_CASE values | `enum State { IDLE, WALKING }` |
| Scenes             | snake_case          | `main_menu.tscn`              |

## Implementation Rules

### DO

- Use static typing on every variable, parameter, and return type
- Use signals and EventBus for cross-system communication
- Use `@export` for editor-configurable properties
- Use `@onready` with `$ChildName` for direct child references
- Use `preload()` for compile-time resource loading
- Keep scripts under 300 lines — delegate to sub-systems if larger
- Keep functions under 30 lines — extract helpers for complex logic
- Return early — avoid deep nesting, prefer guard clauses
- Use typed arrays: `Array[ItemDefinition]`, not untyped `Array`
- One responsibility per script — if it does two things, split it
- Prefer scene composition over inheritance where possible

### DO NOT

- Do NOT add comments that restate the code — only explain "why"
- Do NOT use `print()` for anything other than temporary debugging — use push_warning/push_error for diagnostics
- Do NOT use `get_node()` with long paths — use `@onready` or `@export` node references
- Do NOT use `await` in `_ready()` — use a separate `initialize()` method
- Do NOT directly reference other autoloads from autoloads — use EventBus signals
- Do NOT add GDScript addons/plugins without justification in the issue
- Do NOT modify files unrelated to the current issue
- Do NOT leave TODO/FIXME comments — create issues instead
- Do NOT use untyped variables or function signatures

## Testing Rules

### Approach

Godot does not have a built-in test framework. For logic-heavy scripts, use the GUT (Godot Unit Test) addon if added, or validate behavior through integration testing in-editor.

### What to Test

- Data loading and parsing (JSON content pipeline)
- Economy calculations (pricing, transactions, costs)
- State transitions (game states, day phases, store states)
- Signal emission (verify correct signals fire with correct data)

### What NOT to Test

- Godot engine internals (rendering, physics)
- Scene tree structure (validated by the editor)
- UI layout (visual verification in editor)

## Dependencies

### Required

| Dependency       | Purpose                          | Version   |
|-----------------|----------------------------------|-----------|
| Godot Engine    | Game engine, editor, and runtime | 4.3+      |

No external package manager is used. All game logic is written in GDScript. Content data is stored as JSON files under `game/content/`.

## Git Conventions

- Branch from `main` for all work
- Commit messages: `type: description` where type is feat/fix/refactor/test/docs
- One logical change per commit
- Never commit `.godot/` cache, `.import/` artifacts, or `.env` files

## Environment

### Required Environment Variables

None. The project runs entirely within the Godot editor with no external services.

### Development Setup

```bash
# 1. Install Godot 4.3+ (standard build, not .NET)
# 2. Clone the repository
git clone <repo-url> && cd mallcore-sim
# 3. Open in Godot
#    Launch Godot -> Import -> select project.godot
# 4. First open will import assets (may take a moment)
# 5. Press F5 to run the default scene
```
