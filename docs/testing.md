# Testing

Mallcore Sim uses the GUT addon checked into `addons/gut/`.

## Test Command

```bash
bash tests/run_tests.sh
```

The test runner:

1. Resolves Godot from `GODOT`, `GODOT_EXECUTABLE`, `godot` on `PATH`, or common
   macOS install paths.
2. Runs a headless import.
3. Runs GUT with `res://addons/gut/gut_cmdln.gd`.
4. Writes full output to `tests/test_run.log`.
5. Runs shell validation scripts matching `tests/validate_*.sh` when present.

## GUT Configuration

`.gutconfig.json` includes these directories:

- `res://tests/`
- `res://tests/gut/`
- `res://tests/unit/`
- `res://game/tests/`

Tests use the `test_*.gd` naming pattern and are configured to exit the process
after completion.

## Current Coverage Areas

The test suite currently includes coverage for:

- boot content loading and boot sequence
- content registry and data loader behavior
- economy, difficulty, checkout, haggling, pricing, and cash flow
- inventory, ordering, stock deduction, and restocking
- customer spawning, purchase decisions, NPCs, navigation, and UI indicators
- store state, store selection, store scenes, and storefront navigation
- build mode, fixture catalog, fixture placement, and build visuals
- time, day cycle, day summaries, wages, bankruptcy, and performance reports
- market, random, seasonal, trend, and sports season events
- staff hiring, morale, payroll, and quit behavior
- milestones, unlocks, upgrades, completion tracking, onboarding, and endings
- store-specific flows for sports memorabilia, retro games, video rental,
  pocket creatures, and consumer electronics
- save/load and slot metadata behavior
- audio, settings, camera, environment, tooltips, HUD, and UI panels

Use existing focused tests as examples before creating new fixtures or helper
patterns.

## When to Add Tests

Add or update tests when changing:

- content loading or JSON schema expectations
- event signal names or payload shapes
- save/load dictionary shape
- economy formulas or difficulty modifiers
- state ownership boundaries between systems
- store-specific mechanics
- UI controllers that emit gameplay events

Scene art, layout, and engine internals are normally verified in-editor unless a
script-level behavior can be asserted directly.

## CI Status

`.github/workflows/validate.yml` currently runs three jobs:

1. `lint-docs` checks for required files and common repository issues.
2. `gut-tests` installs Godot, imports the project, and runs GUT headlessly.
3. `lint-gdscript` runs non-blocking `gdlint`.

The `lint-docs` job still expects a root `CLAUDE.md` path even though the active
project documentation now lives in `README.md` and `docs/`. Treat that workflow
check as a current repo-configuration mismatch, not as part of the canonical
documentation structure.

`.github/workflows/export.yml` validates export presets and builds tagged
Windows and macOS release artifacts.
