```markdown
# CLAUDE.md — Mallcore Sim (mall-sim)

## 1. Project Identity
- **Name**: Mallcore Sim (`mall-sim`)
- **Engine**: Godot 4.6 (Forward+ renderer)
- **Language**: GDScript (statically typed where possible)
- **Genre**: Retail / mall management sim, parody-storefront aesthetic (2000s mall culture)
- **Main scene**: `res://game/scenes/bootstrap/boot.tscn`
- **Repo layout**:
  - `game/` — runtime code, scenes, autoloads, content
  - `game/autoload/` — singletons (EventBus, GameManager, ContentRegistry, CameraManager, etc.)
  - `tests/` — GUT tests + per-issue `validate_issue_*.sh` audit scripts
  - `tools/`, `scripts/` — headless Godot helpers (`godot_exec.sh`, `godot_import.sh`)
  - `docs/research/` — design + technical research; **read before changing the relevant subsystem** (camera authority, scene lifecycle, GUT integration, store-ready contract, input/modal ownership, scene transition state machine, etc.)
  - `docs/audits/braindump.md` — current state assessment; treat as binding context.
  - `.aidlc/issues/` — issue specs (`ISSUE-NNN.md`).

## 2. Style
- GDScript, **statically typed**: `var x: int`, `func foo(a: String) -> void:`. No untyped `var` for new code.
- Indent: tabs (Godot default). Line length: ~100 cols soft.
- One class per file. Top of file order: `class_name`, `extends`, signals, enums, constants, exported vars, onready vars, lifecycle (`_ready`, `_process`, …), public methods, private methods (`_underscore`).
- Prefer `@onready var foo: Node = %Foo` with unique-name nodes over deep `$Path/To/Node` chains.
- Signals: past-tense names (`store_loaded`, `transition_finished`).
- **No silent failure.** Use `assert(...)`, `push_error(...)`, and visible debug states. A grey screen is the worst outcome — fail loudly. (See `docs/research/godot-runtime-assertion-patterns.md`.)
- No hex color literals in scenes/scripts — palette must come from theme. Enforced by `tests/validate_no_hex_colors.sh`.
- Linting rules are intentionally relaxed in some files via inline disables; do not re-enable globally without a reason.

## 3. Naming
- Files: `snake_case.gd` / `snake_case.tscn` / `snake_case.tres`.
- Classes (`class_name`): `PascalCase`, matching the file's purpose (e.g. `StoreController`, `CameraManager`).
- Autoload singleton names: `PascalCase` ending in `Manager`, `System`, `Registry`, or `Bus` (see `[autoload]` in `project.godot`). Singletons that overlap with class names use the `Singleton` suffix (`ReputationSystemSingleton`).
- Variables/functions: `snake_case`. Constants: `SCREAMING_SNAKE_CASE`. Private members: leading `_`.
- Scenes are grouped by domain under `game/scenes/<domain>/`. Tests mirror feature names: `test_<feature>.gd`.

## 4. Testing
- Framework: **GUT** (Godot Unit Test) under `addons/gut/`. Tests live in `tests/` (`test_*.gd`), with `tests/unit/` and `tests/integration/` subfolders.
- Run all tests: `tests/run_tests.sh` (wraps headless Godot via `scripts/godot_exec.sh`).
- Run audit scripts (per-issue runtime verification): `tests/audit_run.sh` — these MUST pass; any missing audit checkpoint line is treated as a failure.
- Per-issue validators: `tests/validate_issue_<NNN>.sh`. When closing an issue, add/update the matching script.
- CI: `.github/workflows/validate.yml` runs GUT + audit + validators. Trust GUT's summary line ("All tests passed") for pass/fail — headless Godot's exit code is unreliable due to engine cleanup quirks; do not "fix" CI by checking exit codes.
- New tests are **integration-first**: prove the runtime chain works end-to-end (boot → mall → store ready → interaction), not just that a class compiles. See `docs/research/godot-integration-testing-gut.md`.

## 5. Dependencies
- **Allowed**: vanilla Godot 4.6 + GUT (already vendored in `addons/gut/`).
- **Banned**: networked package managers, C# / .NET, GDExtension binaries, third-party addons not already in `addons/`.
- Adding an addon requires: vendoring it under `addons/<name>/`, updating `project.godot` plugin list, and a note in the PR explaining why a vanilla solution wasn't sufficient.
- No external runtime services. Game must run fully offline.

## 6. Git
- Branch from `main`. Branch names: `feat/<short>`, `fix/<short>`, `audit/<short>`, `issue-<NNN>-<short>`.
- Commit subject: imperative, ≤72 chars. Body explains *why*, references issue number when applicable. Recent style example: `Enhance audit logging in audit_overlay.gd to include pass status messages…`.
- One logical change per commit. No "WIP" commits on `main`.
- PRs must:
  - State which step(s) of the golden-path chain (Boot → Mall → Selection → Transition → Store Ready → Loop) are touched.
  - Include or update the relevant `validate_issue_*.sh` and any GUT tests.
  - Show CI green (`validate.yml`) before merge.

## 7. Dev Setup
1. Install Godot 4.6 (Forward+).
2. Clone: `git clone <repo>; cd mall-sim`.
3. First-time import (headless): `scripts/godot_import.sh` — generates `.import/` and `.uid` files.
4. Open in editor: `godot project.godot`, or run main scene: `scripts/godot_exec.sh --headless` (for CI-style runs).
5. Run tests locally: `tests/run_tests.sh`. Run a single audit: `tests/validate_issue_<NNN>.sh`.
6. Export presets live in `export_presets.cfg`; `.github/workflows/export.yml` handles release builds.

## 8. Important Rules (project-specific, non-negotiable)

These come from `docs/audits/braindump.md`. Violating them wastes the user's time.

1. **"Implemented" ≠ progress. "Verified in runtime" = progress.** Do not mark work done without a runtime check (GUT integration test, audit script, or a documented manual repro). If you can't test it, say so explicitly.
2. **Golden path is sacred**: `New Game → Mall → Click Store → Store Loads → Player Can Act`. Any change must keep this chain intact. Trace it in your PR description for non-trivial work.
3. **Store-Ready contract** (`docs/research/store-ready-contract-examples.md`): a store is ready ONLY if all of: store id resolved, real (not placeholder) scene loaded, store controller initialized, content instantiated, camera active and aimed at content, player controller present, input enabled (or intentionally disabled with UI explanation), no modal stealing focus, ≥1 visible interaction, objective text matches reality. No partial success — `enter_store(store_id) → READY or FAIL`.
4. **Single ownership**. For each responsibility (transition, store init, camera, input, "store ready" declaration, objective updates) there is exactly one owner. The canonical owner-per-responsibility map is `docs/architecture/ownership.md` — consult it before adding a writer to an already-owned surface. If you find split ownership, consolidate; do not add a third controller. See also `docs/research/camera-authority-patterns.md`, `docs/research/input-focus-modal-ownership.md`, `docs/research/scene-transition-state-machine.md`.
5. **Kill silent failures.** Missing scene/camera/player/content → `push_error` + visible failure UI + failing audit line. Never paper over with defaults that produce a grey screen.
6. **Do NOT during this phase**: add new features, add stores, add content, add narrative, polish UI beyond clarity, or "move forward" past a broken step. Audit / trace / wire / remove dead paths only.
7. **Autoload discipline**: don't add a new singleton without removing or justifying overlap with the existing ones in `project.godot`. Cross-system communication goes through `EventBus`, not direct singleton coupling, unless there's a clear ownership reason.
8. **Theme/colors**: no hex literals — use the theme. CI enforces this.
9. **CI behavior**: don't bypass GUT failures by editing exit-code logic. The "All tests passed" summary check is intentional — fix the test, not the check.
10. **Read the matching `docs/research/*.md`** before modifying camera, input/modal handling, scene transitions, GUT tests, store-ready logic, or storefront aesthetic. These encode prior decisions; don't rediscover them.
```