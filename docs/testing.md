# Testing

Mallcore Sim uses the checked-in GUT addon plus a set of shell validators under
`tests/`.

## Main test command

```bash
bash tests/run_tests.sh
```

`tests/run_tests.sh` currently does the following:

1. Resolves Godot from `GODOT`, `GODOT_EXECUTABLE`, `godot` on `PATH`, or common
   macOS install paths.
2. Runs a headless import.
3. Runs GUT with `res://addons/gut/gut_cmdln.gd`.
4. Runs `res://game/tests/run_tests.gd` when that file exists.
5. Writes the combined output stream to `tests/test_run.log`.
6. Runs every shell validator matching `tests/validate_*.sh`.

## GUT configuration

`.gutconfig.json` currently points GUT at:

- `res://tests/`
- `res://tests/gut/`
- `res://tests/unit/`
- `res://game/tests/`

The current config also uses:

- `prefix: "test_"`
- `suffix: ".gd"`
- `should_exit: true`
- `should_exit_on_success: true`
- `pre_run_script: "res://tests/gut_pre_run.gd"`

## Test layout

```text
tests/gut/          Broad gameplay and scene-oriented GUT coverage
tests/unit/         Narrow unit-style GUT coverage
tests/integration/  Integration-style test scripts under the main tests tree
game/tests/         Additional GUT tests invoked directly and included in .gutconfig
tests/validate_*.sh Shell validators for legacy issue- and structure-level checks
```

## Current coverage areas

The checked-in tests currently cover:

- boot flow, content loading, and content registry rules
- time, economy, difficulty, checkout, haggling, pricing, and reporting
- inventory, ordering, suppliers, stock, and save/load behavior
- store state, store transitions, hallway/storefront flow, and build mode
- customer spawning, NPC systems, queueing, and purchase flow
- milestones, unlocks, upgrades, completion, onboarding, and endings
- store-specific mechanics for sports memorabilia, retro games, video rental,
  pocket creatures, and consumer electronics
- settings, audio, camera, environment, tooltips, and UI panels

## When changes should come with tests

Add or update coverage when changing:

- content-loading rules or JSON schema expectations
- event names or payload shapes on `EventBus`
- save/load dictionary shape or migration behavior
- economy formulas or difficulty modifiers
- cross-system ownership boundaries
- store-specific mechanics or controller wiring
- UI scripts that emit gameplay events or depend on system state

## CI validation

`.github/workflows/validate.yml` currently runs three jobs:

1. `lint-docs` - required-file and repository-shape checks
2. `gut-tests` - Godot install, import, and headless GUT execution
3. `lint-gdscript` - non-blocking `gdlint` via `gdtoolkit`

Two current workflow quirks matter for documentation:

1. `lint-docs` still expects a root `CLAUDE.md` file even though the active
   project docs set is `README.md` plus `docs/`.
2. `gut-tests` installs Godot `4.6.2-stable`, while the tagged export workflow
   still uses Godot `4.3`.

Tagged release exports are handled separately by `.github/workflows/export.yml`.
