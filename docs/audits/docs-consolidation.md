# Documentation Consolidation Pass — 2026-05-15

Working-tree-driven documentation review on `main`. The working tree carries
the active onboarding-pacing WIP (right-side beta panel, on-screen event log,
HUD money-delta pop, hint-overlay refresh, ObjectiveRail Day-1 visibility
tweaks, and the new `BetaHUD` autoload that owns the beta HUD panels for the
session lifetime). Goal: every active-doc statement is verifiable from current
code, config, or CI; nothing else exists.

Scope: `README.md` plus everything under `docs/`. Out of scope by rule:
`BRAINDUMP.md` (customer voice) and the per-pass audit reports under
`docs/audits/` written by other passes (`cleanup-report.md`,
`error-handling-report.md`, `security-report.md`, `ssot-report.md`,
`YYYY-MM-DD-audit.md` interaction-audit snapshots).

The prior pass (2026-05-13) removed three phantom-planning references
(`Phase 0` / `Phase 0.1` labels) from `docs/design.md`, `docs/setup.md`, and
`docs/testing.md`, and verified the 44-row autoload table against
`project.godot`. This pass re-verifies the doc set against the current working
tree and applies two corrections: a new autoload row for `BetaHUD` and a
hub-mode emitter clarification.

## Summary

This pass found one autoload drift (a new entry added since the prior pass)
and one imprecise hub-mode-emitter sentence in `docs/architecture.md`, and
corrected both. No other autoload, scene, script, content, workflow, or input
claim drifted relative to the working tree.

One file updated (`docs/architecture.md`); this report rewritten; no new
docs; no deletions.

## Edits applied

### `docs/architecture.md` — added `BetaHUD` autoload row (slot 33)

The `[autoload]` block in `project.godot` lines 26–70 now contains **45
entries**, not 44. The new entry is

```
BetaHUD="*res://game/autoload/beta_hud.gd"
```

at line 58 (slot 33), positioned between `BetaRunState` (slot 32) and
`EmploymentSystem` (now slot 34). `game/autoload/beta_hud.gd` is the
session-level owner of the beta HUD panels (`BetaRightPanel` and
`BetaEventLogPanel`): it spawns both once in `_ready`, holds them across day
transitions so the panel surfaces survive controller tear-downs, and exposes
`activate(day)` / `deactivate()` as session-level controls. The docstring
explicitly documents the load-order constraint
("must be registered after `EventBus`, `InputFocus`, and `BetaRunState`"),
which matches the slot order in `project.godot`.

Edit applied: inserted the `BetaHUD` row as new slot 33; shifted slots
33→34 (`EmploymentSystem`) through 44→45 (`HiddenThreadSystemSingleton`).
The "Five entries are scenes" preamble still holds — the five scene
autoloads (`ObjectiveRail`, `InteractionPrompt`, `MorningNotePanel`,
`MiddayEventCard`, `FailCard`) are unchanged; the script vs. scene count is
now 40 vs. 5.

### `docs/architecture.md` — corrected hub-mode emitter description

The Scene Entry Points section previously read:

> `GameWorld._setup_hub_mode` creates a `SceneTransition`,
> `apply_pending_session_state` emits
> `EventBus.enter_store_requested(GameManager.DEFAULT_STARTING_STORE)`, …

The actual emitter at `game/scenes/world/game_world.gd:1226` is
`_auto_enter_default_store_in_hub`, which `apply_pending_session_state`
calls only on the new-game branch (`:1203`). On the load-slot branch
(`:1191–:1199`) the function never emits `enter_store_requested` — it
instead defers to `save_manager.load_game(slot)` and falls through to the
notification/return-to-menu path on failure.

Rewrote the sentence to attribute the emit to
`_auto_enter_default_store_in_hub` and to mark it as the new-run branch.
The `docs/design.md` §3 paragraph already uses this exact attribution, so
this edit brings `architecture.md` into agreement with the design doc and
with the code.

## Statements verified, no edit needed

Spot-checked the following against the current working tree. All match. The
verification pulled `project.godot`, the autoload sources under
`game/autoload/` and `game/scripts/`, the gameplay scripts under
`game/scripts/`, the JSON content under `game/content/`, both GitHub Actions
workflows (`validate.yml`, `export.yml`), `tests/run_tests.sh`,
`scripts/run_godot_tests.sh`, `.gutconfig.json`, and `export_presets.cfg`.

- **`README.md`** — engine version `4.6.2`, entry scene
  `res://game/scenes/bootstrap/boot.tscn`, `bash tests/run_tests.sh`, the
  three SSOT-tripwire script names (`validate_translations.sh`,
  `validate_single_store_ui.sh`, `validate_tutorial_single_source.sh`), and
  the three export-preset paths
  (`exports/{windows,macos,linux}/MallcoreSim.{exe,zip,x86_64}`) all match
  `project.godot:9-21`, `tests/run_tests.sh`, `scripts/*.sh`, and
  `export_presets.cfg`. The `/docs` link list still resolves to existing
  files.
- **`docs/index.md`** — every linked doc still exists on disk
  (`setup.md`, `architecture.md`, `architecture/ownership.md`, `design.md`,
  `content-data.md`, `testing.md`, `configuration-deployment.md`,
  `contributing.md`, `retro_games_interactable_matrix.md`,
  `style/visual-grammar.md`, the seven `audits/*` files,
  `beta/validation_checklist.md`). The Boundary section's claim that
  `README.md` is the only active root doc plus `BRAINDUMP.md` (customer
  voice) holds — `ls *.md` at the root returns exactly those two plus
  `LICENSE` (not markdown).
- **`docs/setup.md`** — Godot-binary resolution order (`GODOT`,
  `GODOT_EXECUTABLE`, `godot` on `PATH`, two macOS install paths) matches
  `tests/run_tests.sh` and `scripts/godot_exec.sh`.
  `bash scripts/godot_import.sh` and `bash scripts/godot_exec.sh` both
  exist. The repository-layout block is accurate (no relocated trees).
- **`docs/architecture.md`** — after this pass's edits:
  - Boot-flow steps 1–7 still line up with `game/scripts/core/boot.gd`;
    `DataLoaderSingleton.load_all` → arc/objectives schema validation →
    `ContentRegistry.is_ready` → store-id non-empty → `Settings.load` /
    `AudioManager.initialize` → `mark_boot_completed` /
    `boot_completed.emit` → `transition_to(MAIN_MENU)` are all present.
    The wrapper at `game/scenes/bootstrap/boot.gd` is a one-line
    `extends "res://game/scripts/core/boot.gd"`.
  - GameWorld init tiers 1–5 exist as `initialize_tier_1_data` …
    `initialize_tier_5_meta` at
    `game/scenes/world/game_world.gd:245,256,281,338,345`, with
    `finalize_system_wiring` at `:396`; tier 2 returns `bool` as
    documented (`func initialize_tier_2_state() -> bool:` at `:256`).
  - The 45-row autoload table (post-edit) matches
    `project.godot:[autoload]` 1-for-1 in slot order.
  - Row 22 EventLog description (re-broadcasts each entry as
    `EventBus.event_logged(tag, message)` in every build; ring buffer +
    stdout debug-only) still matches
    `game/autoload/event_log.gd:234` (the broadcast emit) and the
    `event_logged(tag: String, message: String)` signal declared on
    `EventBus`.
  - Row 44 Day1ReadinessAudit (post-edit; was row 43 pre-edit) still
    matches `project.godot:69` and
    `game/autoload/day1_readiness_audit.gd`.
  - Scene-entry-point table paths all exist
    (`boot.tscn`, `main_menu.tscn`, `gameplay_shell.tscn`,
    `game_world.tscn`, `mall_hallway.tscn`, `storefront.tscn`,
    `retro_games.tscn`, `day_summary.tscn`, `hud.tscn`).
  - The corrected hub-mode description
    (`debug/walkable_mall=false`, `_setup_hub_mode`,
    `apply_pending_session_state` → `_auto_enter_default_store_in_hub`
    → `EventBus.enter_store_requested(GameManager.DEFAULT_STARTING_STORE)`)
    matches `game/scenes/world/game_world.gd:1188-1226` and
    `game/autoload/game_manager.gd:11`
    (`DEFAULT_STARTING_STORE = &"retro_games"`).
  - EventBus signal-prefix table (`store_`, `day_`/`hour_`, `customer_`,
    `inventory_`, `reputation_`, `milestone_`/`unlock_`/`completion_`,
    `tutorial_`/`onboarding_`, `interactable_`/`panel_`) and the
    `run_state_changed()` mirror still hold against `event_bus.gd`.
  - "Visual Systems" reuse table — every "Use this" target exists at the
    cited path (verified against `store_player_body.gd`,
    `interaction_ray.gd`, `player_controller.gd`, `build_mode_camera.gd`,
    `camera_authority.gd`, `interactable.gd`, `mat_outline_highlight.tres`,
    `interactable_hover.gd`, `tooltip_manager.gd`,
    `interaction_prompt.tscn`, `crosshair.tscn`, `shelf_slot.gd`,
    `day_phase_lighting.gd`, `crt_overlay.gdshader`, `panel_animator.gd`,
    `ui_layers.gd`).
- **`docs/architecture/ownership.md`** — all 10 rows still hold:
  - Row 1 (`SceneRouter`): `_in_flight`, `change_scene_to_file/_packed`,
    `tree_changed` + `process_frame` await, `scene_ready` /
    `scene_failed`, and the `AuditLog.pass_check`/`fail_check`
    instrumentation are all present in `game/autoload/scene_router.gd`.
    `ModalQueue.clear()` is called from the router before each swap.
  - Row 2 (`StoreDirector`): state machine
    `IDLE → REQUESTED → LOADING_SCENE → INSTANTIATING → VERIFYING → READY | FAILED`
    matches the `State` enum at
    `game/autoload/store_director.gd:34-41`.
  - Row 3 (per-store controller): `game/scripts/stores/retro_games.gd`
    extending `game/scripts/stores/store_controller.gd` is the surviving
    shipping store.
  - Row 4 (`CameraAuthority`): `request_current`, the `cameras` group,
    and `assert_single_active()` exist in
    `game/autoload/camera_authority.gd`.
  - Row 5 (`InputFocus` + `ModalQueue`): the four context constants
    (`CTX_MAIN_MENU = &"main_menu"`, `CTX_MALL_HUB = &"mall_hub"`,
    `CTX_STORE_GAMEPLAY = &"store_gameplay"`, `CTX_MODAL = &"modal"`)
    exist on `game/autoload/input_focus.gd`. The priority enum
    `DAY_SUMMARY → VIC_NOTE → TUTORIAL → TOAST → PASSIVE_HUD` lives at
    `game/autoload/modal_queue.gd:33-39`.
  - Row 6 (`GameState`), Row 7 (`HUD`), Row 8 (`StoreRegistry`),
    Row 9 (`AuditLog.pass_check`/`fail_check`), Row 10
    (`EventBus` mirror signals) all match their cited sources.
- **`docs/design.md`** — Section 4 store-roster table has the single
  `retro_games` row; `GameManager.DEFAULT_STARTING_STORE = &"retro_games"`
  is canonical at `game/autoload/game_manager.gd:11`. The §3 hub-mode
  description names `_auto_enter_default_store_in_hub` directly (the same
  emitter `architecture.md` now points to). The visual anti-pattern list
  cross-references `BuildModeCamera`, `mat_outline_highlight.tres`, and
  `ui_theme_constants.gd` — all exist.
- **`docs/content-data.md`** — every JSON path in the content-tree table
  exists under `game/content/` (35 files plus the empty
  `game/content/localization/` directory). The `_TYPE_ROUTES` `ignore`
  bucket in `game/autoload/data_loader.gd` matches the doc's `ignore`
  list. `MAX_JSON_FILE_BYTES = 1048576` (1 MiB) and
  `ContentRegistry.ID_PATTERN = ^[a-z][a-z0-9_]{0,63}$` still hold.
  `store_definitions.json` lists exactly one store (`retro_games`),
  matching the "Shipping roster" block.
- **`docs/testing.md`** — `tests/run_tests.sh` step list and the
  `.gutconfig.json` keys (`prefix: "test_"`, `suffix: ".gd"`,
  `should_exit: true`, `should_exit_on_success: true`,
  `pre_run_script: "res://tests/gut_pre_run.gd"`) match the on-disk
  config. The five CI jobs (`lint-docs`, `gut-tests`,
  `interaction-audit`, `content-originality`, `lint-gdscript`) all
  appear as `jobs:` entries in `.github/workflows/validate.yml`. The
  Godot install pin (`GODOT_VERSION: "4.6.2-stable"`) is at the workflow
  `env:` block.
- **`docs/configuration-deployment.md`** — every input-action group named
  in the doc is present in `project.godot:[input]`
  (`move_*`, `interact`, `quick_stock`, `toggle_debug`,
  `toggle_debug_camera`, `toggle_inventory`, `toggle_orders`,
  `toggle_staff`, `toggle_pricing`, `toggle_build_mode`, `rotate_fixture`,
  `time_speed_{1,2,4}`, `time_toggle_pause`, `close_day`, `pause_menu`,
  `toggle_overview`, `nav_zone_{1..5}`, `sprint`). `MAX_MANUAL_SLOTS = 3`
  and `MAX_SAVE_FILE_BYTES = 10485760` match
  `game/scripts/core/save_manager.gd`. The three export-preset paths
  match `export_presets.cfg`. The validate-workflow job list and the
  export workflow's preset validation, `chickensoft-games/setup-godot@v2`
  install, parallel Windows/macOS/Linux jobs, and final release step all
  match. The `Shelf Life` (config name) vs. `Mallcore Sim` (preset
  `application/name`) callout still reflects the actual string mismatch.
- **`docs/contributing.md`** — `.editorconfig` rules, naming
  conventions, content-ID regex (`^[a-z][a-z0-9_]{0,63}$`), and the
  `bash tests/run_tests.sh` entry point all check out.
- **`docs/retro_games_interactable_matrix.md`** — `interaction_mask = 16`,
  `ray_distance = 2.5 m`, the `InteractionArea` reparent on layer 16, and
  the shared `slot_collision` resource at `Vector3(0.3, 0.3, 0.3)` are
  still the documented contract. Every numbered row's scene path
  resolves under `game/scenes/stores/retro_games.tscn` and every named
  handler is on `game/scripts/stores/retro_games.gd`. The reserved
  `H-1`…`H-7` rows are still placeholders for the deferred hidden-thread
  audit pass and are explicitly marked as such; left untouched.
- **`docs/style/visual-grammar.md`** — `STORE_ACCENT_RETRO_GAMES`
  (`#E8A547`), the four `FONT_SIZE_*` constants, `DARK_PANEL_FILL`,
  `DARK_PANEL_BORDER`, `DARK_PANEL_TEXT`, `DARK_PANEL_TEXT_SECONDARY`,
  `LIGHT_PANEL_FILL`, `LIGHT_PANEL_TEXT`, and the four `SEMANTIC_*`
  colors all exist in `game/scripts/ui/ui_theme_constants.gd`. The
  dormant `store_accent_{electronics,pocket_creatures,sports_cards,
  video_rental}.tres` files are still on disk under `game/themes/` with
  no `STORE_ACCENT_*` constant reference, matching the "inactive until a
  second store is reintroduced" callout.
- **`docs/beta/validation_checklist.md`** — interactable prompts, F10
  screenshot path pattern, the customer-event id
  `day01_wrong_console_parent` (in
  `game/content/beta/events/customer_events.json`), and the
  `tests/gut/test_beta_day_one_critical_path.gd` smoke target all match.

## Statements removed as unverifiable

None this pass. The prior pass (2026-05-13) already removed the three
`Phase 0` / `Phase 0.1` phantom references; nothing of that shape is left in
the active doc set. The two edits applied above are corrections to
verifiable statements (a missing row and an imprecise emitter
attribution), not removals of unverifiable claims.

## Intentional gaps

- **`config/name="Shelf Life"` vs. export preset
  `application/name="Mallcore Sim"`** — both names remain documented in
  `docs/configuration-deployment.md`. The strings genuinely disagree in
  code/config (`project.godot:17` vs.
  `export_presets.cfg`). Reconciling them is a code-side decision that a
  docs pass cannot make.
- **Old beta panels (`beta_today_checklist.gd`,
  `beta_today_stats_panel.gd`)** — deleted in the WIP working tree. No
  active doc under `docs/` (excluding the audit reports rewritten by
  other passes) referenced either file, so no doc edit was required.
  The only references in the docs tree are in
  `docs/audits/cleanup-report.md`, `docs/audits/ssot-report.md`,
  `docs/audits/security-report.md`, and
  `docs/audits/error-handling-report.md`, which are out of scope by
  rule (each is rewritten by its own pass).
- **`docs/audits/2026-05-05-audit.md` and `2026-05-06-audit.md`** —
  left untouched. These are interaction-audit table snapshots
  regenerated by `tests/audit_run.sh` / the `interaction-audit` CI job;
  hand-edits would race the next CI run.
- **`MallHub` named in `docs/architecture/ownership.md` rows 1 and 4
  accepted-callers columns.** The script attached to `mall_hallway.tscn`
  is `class_name MallHallway` (not `MallHub`); the walkable variant is
  gated by `debug/walkable_mall=false` and not part of the shipping
  flow. The columns describe a conceptual responsibility ("the mall hub
  scene's controller") rather than a specific class name, and the
  walkable mall is dormant. Same disposition as prior passes: left as-is
  to avoid implying the walkable variant is a live caller surface; if
  the variant is revived the column should be updated to `MallHallway`
  at the same time the caller wiring is added back.
- **Audit reports under `docs/audits/`** (`cleanup-report.md`,
  `error-handling-report.md`, `security-report.md`, `ssot-report.md`)
  not re-verified line-by-line in this pass. Each has its own per-pass
  prompt that rewrites it; this docs pass would otherwise compete with
  those passes' rewrite contracts. Their internal references to source
  paths/lines drift relative to the WIP working tree, and that is the
  owning pass's surface to reconcile.

## Escalations

None. Every finding was acted on (in-place edit) or recorded above under
"Intentional gaps" with the specific reason it was not actioned.
