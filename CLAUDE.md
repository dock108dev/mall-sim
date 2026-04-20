# Mallcore Sim — CLAUDE.md

## What this project is
A 2000s specialty-retail mall simulator in Godot 4.6.2 (GDScript). Five stores, each with a signature mechanic. Core loop: stock → price → sell → close day → read summary.

UI spine: **clickable management hub with ambient walkable flavor** (Mall Tycoon 2002 pattern). Store mechanics live in slide-out drawers over a single persistent mall-hub scene. No walkable store interiors, no player avatar.

## Tech stack
- **Engine:** Godot `4.6.2` — canonical. `project.godot` declares `4.6` features; CI (`validate.yml`, `export.yml`) pins `4.6.2`. Match locally.
- **Language:** GDScript.
- **Content:** JSON under `game/content/` only. Never duplicate to repo root.
- **Testing:** GUT (headless) + shell validators under `tests/` + headless interaction-audit runner.
- **Entry scene:** `res://game/scenes/bootstrap/boot.tscn`.
- **Persistent gameplay scene:** `res://game/scenes/mall/mall_hub.tscn`.

## Running locally
1. Install Godot 4.6.2.
2. Import `project.godot`.
3. Press F5.

## Running tests
```bash
bash tests/run_tests.sh        # GUT + content integrity
bash tests/audit_run.sh        # interaction-audit PASS/FAIL table
```
Test output → `tests/test_run.log`. The runner resolves Godot from `$GODOT`, `$GODOT_EXECUTABLE`, `godot` on PATH, or common macOS install paths. If `$GODOT`/`$GODOT_EXECUTABLE` is set but unresolvable, the runner fails loud — no silent skipping.

## Five stores
| Store | Controller | Signature mechanic |
|---|---|---|
| Retro Games | `RetroGamesController` | Refurbishment (Clean / Repair / Restore) |
| Pocket Creatures | `PocketCreaturesStoreController` | Pack opening + meta shifts + tournaments |
| Video Rental | `VideoRentalStoreController` | New-release premium + late fees |
| Electronics | `ElectronicsStoreController` | Warranty upsell + demo units |
| Sports Cards | `SportsMemorabiliaController` | Multi-tier grading (PSA-style 1–10) |

## Architecture rules (non-negotiable)
1. **5-tier init order** — Data → Core → Systems → Presentation → Boot. No tier-N ref to tier-(N+1) at init time.
2. **Signals as contract** — all cross-system communication via `EventBus`. Direct node refs between systems are banned.
3. **Single PriceResolver** — every price multiplier (difficulty, condition, authenticity, warranty, lifecycle, reputation, trend, seasonal, event, meta shift, variance) routes through `PriceResolver`. Nothing else computes final price.
4. **Content as data** — all content in JSON. Boot runs two-pass validation (parse+schema, then cross-reference); fails loud with the full error list.
5. **One controller per store** — parallel controllers are a structural bug. Delete duplicates.
6. **Hub + drawer** — no walkable store interiors. Mechanics live in drawers over the hub.
7. **All content original** — invented names, brands, franchises, characters. No trademarked IP, even as parody.

## Key directories
```
game/
  autoload/     # 16 singletons (tier-ordered)
  content/      # canonical JSON — single source of truth
  scenes/       # .tscn files (bootstrap, mall, ui, stores)
  scripts/      # GDScript source
tests/          # GUT runner, audit runner, shell validators
testdata/
  saves/        # versioned save fixtures (one per schema bump)
docs/
  research/     # completed research — do not re-request
  audits/       # generated per-commit audit tables
  decisions/    # written decisions for gate moments
  archive/      # retired scenes/scripts
exports/        # gitignored build output
```

## Design principles
1. **Finish before feature.** Implement or delete every stub. No visible placeholders.
2. **One path, one truth.** `game/content/` is the only content directory.
3. **Signals as contract.** See architecture rules.
4. **Transparent mechanics.** Price is fully traceable via `PriceResolver` audit output.
5. **Content as data.** No content embedded in `.gd`.
6. **Originality.** Invented IP only.

## Anti-patterns (do not introduce)
- Stub methods that return `false`/`null` without implementation
- Cross-system direct node references (use `EventBus`)
- Content type detection by heuristic (use explicit `type` field)
- Parallel controllers for the same store
- Price multipliers outside `PriceResolver`
- Duplicate milestone UI components (one `MilestoneCard` only)
- Content embedded in `.gd` files
- Walkable store interiors (contradicts hub + drawer)
- Real-world IP (Pokémon, Nintendo, Blockbuster, PSA, ESPN, etc.)

## Naming conventions
- Files: `snake_case.gd`, `snake_case.tscn`, `snake_case.json`
- Classes: `PascalCase` (matches filename)
- Signals: past-tense verb (`item_sold`, `day_closed`, `haggle_resolved`)
- Constants: `ALL_CAPS_SNAKE`
- JSON keys: `snake_case`
- IDs at runtime: `StringName` (`&"retro_games"`)

## Error handling
- **Content at boot:** fail loud with the full error list on `validation_error_screen.tscn`. Never silently skip bad content.
- **Runtime:** emit a failure signal, `push_warning`, degrade gracefully.
- **Save:** atomic temp-file swap; preserve existing save on read failure; migrations only run forward; never overwrite with corrupt state.

## Testing strategy
- Parameterized content-integrity tests over every JSON record (not over GDScript that reads them).
- Signal-chain integration tests using GUT `watch_signals`.
- Migration isolation: per-version fixture + unit test; one chain integration test.
- Interaction audit: `tests/audit_run.sh` → PASS/FAIL table in `docs/audits/`.
- Content-originality grep in CI against a banned-terms list.
- Do not test Godot engine internals or shader output.

## Research
Completed research lives in `docs/research/` (≈40 files). Do not re-request. Load a research doc before designing in that area.
