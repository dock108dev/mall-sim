# Mallcore Sim — CLAUDE.md

## What this project is
A 2000s specialty-retail mall simulator in Godot 4.x (GDScript). Players run five stores, each with a signature mechanic. Core loop: stock → price → sell → close day → read summary. Three layers: deep retail sim, nostalgia/narrative piece, polished indie game.

## Tech stack
- **Engine:** Godot 4.x (project declares 4.6 features; CI export workflow uses 4.3 — verify the version you ship)
- **Language:** GDScript
- **Content:** JSON under `game/content/` (canonical; never duplicate to repo root)
- **Testing:** GUT addon (headless) + shell validators under `tests/`
- **Entry scene:** `res://game/scenes/bootstrap/boot.tscn`

## Running locally
1. Install a standard Godot 4.x editor build.
2. Import `project.godot`.
3. Press F5.

## Running tests
```bash
bash tests/run_tests.sh
```
Output → `tests/test_run.log`. The script resolves Godot from `$GODOT`, `$GODOT_EXECUTABLE`, `godot` on PATH, or common macOS install paths.

## Five stores
| Store | Signature mechanic |
|---|---|
| Retro Games | Refurbishment quality assessment |
| Pocket Creatures | Pack opening + meta shifts + tournaments |
| Video Rental | Late-fee / new-release cycle (currently stubbed) |
| Electronics | Warranty upsell + demo units (currently stubbed) |
| Sports Cards | Authentication + grading (currently binary, not a mechanic) |

## Architecture rules (non-negotiable)
1. **5-tier init order** — autoloads fire in a fixed sequence; never initialize out of order or skip tiers.
2. **Signals as contract** — systems communicate via signals only; no direct cross-system references.
3. **Single PriceResolver** — every price multiplier (base, season, reputation, event, haggle) routes through `PriceResolver`; nothing calculates price outside it.
4. **Content as data** — all game content lives in JSON; boot validates the registry and fails loud on bad content.
5. **One controller per store** — each store has exactly one controller class; delete duplicates.

## Key directories
```
game/
  content/      # JSON content — canonical source of truth
  scenes/       # Godot scene files (.tscn)
  scripts/      # GDScript source (.gd)
  tests/        # GUT test scripts
tests/          # Shell test runner and validators
docs/           # Project documentation
  research/     # Research docs (do not re-request completed research)
exports/        # Build output (gitignored build artifacts)
```

## Design principles
1. **Finish before feature** — implement or delete every stub; never ship visible placeholders.
2. **One path, one truth** — no duplicate content roots; `game/content/` is the only content directory.
3. **Signals as contract** — see architecture rules above.
4. **Transparent mechanics** — the price model must be fully traceable via `PriceResolver` audit output.
5. **Content as data** — no content embedded in GDScript.

## Anti-patterns (do not introduce)
- Stub methods that return `false` or `null` without implementation
- Cross-system direct references (use signals)
- Content type detection by heuristic (use explicit `type` field in JSON)
- Parallel controllers for the same store
- Price multipliers outside `PriceResolver`
- Duplicate milestone UI components (collapse to one)
- Content embedded in `.gd` files

## Naming conventions
- Files: `snake_case.gd`, `snake_case.tscn`, `snake_case.json`
- Classes: `PascalCase` (matches filename)
- Signals: past-tense verb (`item_sold`, `day_closed`, `haggle_resolved`)
- Constants: `ALL_CAPS_SNAKE`
- JSON keys: `snake_case`

## Error handling by class
- **Content errors at boot:** fail loud — crash with a clear error message; never silently skip bad content.
- **Runtime errors:** emit a failure signal, log the error, degrade gracefully if possible.
- **Save errors:** preserve existing data; migrate forward only; never overwrite with corrupt state.

## Testing strategy
- Parameterized content integrity tests over every JSON file (not over GDScript that reads them)
- Signal-chain integration tests for transaction flow
- Migration isolation tests for each save version bump
- Do not test framework internals or Godot engine behavior
