# Documentation Consolidation Pass — 2026-05-13

Working-tree-driven documentation review on `main` (working tree carries the
beta strip-to-bones WIP plus the multi-step ObjectiveRail / ModalQueue
feature work). Goal: every active-doc statement is verifiable from current
code, config, or CI; nothing else exists.

Scope: `README.md` plus everything under `docs/`. Out of scope by rule:
`BRAINDUMP.md` (customer voice) and the per-pass audit reports under
`docs/audits/` written by other passes (`cleanup-report.md`,
`error-handling-report.md`, `security-report.md`, `ssot-report.md`,
`YYYY-MM-DD-audit.md` interaction-audit snapshots).

The prior pass (2026-05-11, recorded in earlier git history) added the
`ModalQueue` autoload row to `docs/architecture.md` and rewrote
`docs/architecture/ownership.md` row 5 to spell out the modal dispatch
contract. This pass is a verification sweep against the current code with
the WIP applied, plus a small phantom-reference cleanup.

## Summary

This pass found three small phantom-planning references in active docs and
removed them. No autoload, scene, script, content, workflow, or input claim
in the surviving doc set drifted relative to the working tree.

Three files updated, no new docs, no deletions.

## Edits applied

### `docs/design.md` — dropped `(Phase 0 exit criterion)` parenthetical

Section 5 ("Progression model") had the constraint:

> **Constraint:** no new mechanics ship until the existing store's signature
> mechanic has a working end-to-end loop (Phase 0 exit criterion).

Removed the trailing `(Phase 0 exit criterion)` clause. Rationale: there is
no `Phase 0` planning doc anywhere in the active doc set
(`grep -r "Phase 0" docs/` only matches `docs/design.md` itself; `BRAINDUMP.md`
likewise has zero hits); the parenthetical pointed to a planning artifact
that does not exist on disk. The constraint sentence still states the
actual rule, which is the verifiable claim.

### `docs/design.md` — rephrased "Phase 0 exit criteria" out-of-scope bullet

Section 6 ("Out of scope for 1.0") had:

> - New mechanics before Phase 0 exit criteria are cleared

Rewrote to:

> - New mechanics before the shipping store's signature loop is end-to-end

Same rationale as above — the rule is the same, but it now stands on a
fact (the shipping store's signature loop end-to-end status) instead of a
named planning phase that has no anchor doc.

### `docs/setup.md` and `docs/testing.md` — dropped `Phase 0.1` SSOT-tripwire label

Both docs described `tests/run_tests.sh`'s final step as:

> Runs the Phase 0.1 SSOT tripwires under `scripts/`
> (`validate_translations.sh`, `validate_single_store_ui.sh`,
> `validate_tutorial_single_source.sh`).

Removed `Phase 0.1` (kept the rest verbatim). The script names are concrete
and verifiable; the `Phase 0.1` label originally pointed at
`docs/audits/phase0-ui-integrity.md`, which the 2026-05-10 pass removed when
it deleted the orphaned planning trees. The label is the only remaining
artifact of that doc and is not anchored anywhere readers can follow it.
The reference inside `tests/run_tests.sh:73` (a comment) is code, not docs,
and is out of scope for this pass.

## Statements verified, no edit needed

Spot-checked the following against the current working tree. All match. The
verification pulled `project.godot`, the autoload sources under
`game/autoload/`, the gameplay scripts under `game/scripts/`, the JSON
content under `game/content/`, both GitHub Actions workflows
(`validate.yml`, `export.yml`), `tests/run_tests.sh`,
`scripts/run_godot_tests.sh`, and `export_presets.cfg`.

- **`README.md`** — engine version `4.6.2`, entry scene path
  `res://game/scenes/bootstrap/boot.tscn`, `bash tests/run_tests.sh`,
  validator names (`validate_translations.sh`, `validate_single_store_ui.sh`,
  `validate_tutorial_single_source.sh`), the three export-preset paths
  (`exports/{windows,macos,linux}/MallcoreSim.{exe,zip,x86_64}`), and the
  `/docs` link list all match `project.godot:9-21`,
  `tests/run_tests.sh:1-83`, and `export_presets.cfg`.
- **`docs/index.md`** — every linked doc still exists on disk
  (`setup.md`, `architecture.md`, `architecture/ownership.md`, `design.md`,
  `content-data.md`, `testing.md`, `configuration-deployment.md`,
  `contributing.md`, `retro_games_interactable_matrix.md`,
  `style/visual-grammar.md`, the seven `audits/*` files). The Boundary
  section's claim that `README.md` is the only active root doc plus
  `BRAINDUMP.md` (customer voice) holds — `ls *.md` at the root returns
  exactly those two plus `LICENSE` (not markdown).
- **`docs/setup.md`** — Godot-binary resolution order (`GODOT`,
  `GODOT_EXECUTABLE`, `godot` on `PATH`, two macOS install paths) matches
  `tests/run_tests.sh:10-30` and `scripts/godot_exec.sh`.
  `bash scripts/godot_import.sh` and `bash scripts/godot_exec.sh` both
  exist. The repository-layout block is accurate (no relocated trees).
- **`docs/architecture.md`** — boot flow steps 1-7 line up with
  `game/scripts/core/boot.gd`; the wrapper at
  `game/scenes/bootstrap/boot.gd` is a one-line
  `extends "res://game/scripts/core/boot.gd"`. GameWorld init tiers 1-5
  exist as `initialize_tier_1_data` … `initialize_tier_5_meta` at
  `game/scenes/world/game_world.gd:245,256,281,338,345`, with
  `finalize_system_wiring` at `:396`; tier 2 returns `bool` as documented
  (`func initialize_tier_2_state() -> bool:` at `:256`, branches to
  `return false` at `:261` and `return true` at `:277`).
  - The 44-row autoload table matches `project.godot:[autoload]` 1-for-1
    in slot order. Five entries are scenes (`ObjectiveRail`,
    `InteractionPrompt`, `MorningNotePanel`, `MiddayEventCard`,
    `FailCard`); the other 39 are scripts. The scene-vs-script split
    sentence in the table preamble holds.
  - Row 22 EventLog description (re-broadcasts each entry as
    `EventBus.event_logged(tag, message)` in every build for the
    player-facing on-screen log surface; ring buffer + stdout debug-only)
    matches `game/autoload/event_log.gd:216` (the broadcast call) and the
    `event_logged(tag: String, message: String)` signal declared at
    `game/autoload/event_bus.gd:503`.
  - Row 43 Day1ReadinessAudit matches `project.godot:68` and
    `game/autoload/day1_readiness_audit.gd`.
  - Scene-entry-point table paths all exist
    (`boot.tscn`, `main_menu.tscn`, `gameplay_shell.tscn`,
    `game_world.tscn`, `mall_hallway.tscn`, `storefront.tscn`,
    `retro_games.tscn`, `day_summary.tscn`, `hud.tscn`).
  - The hub-mode description (`debug/walkable_mall=false`,
    `_setup_hub_mode`, `apply_pending_session_state` emits
    `EventBus.enter_store_requested(GameManager.DEFAULT_STARTING_STORE)`)
    still matches `game/scenes/world/game_world.gd` and
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
    `ModalQueue.clear()` is called from the router at `:85`.
  - Row 2 (`StoreDirector`): state machine
    `IDLE → REQUESTED → LOADING_SCENE → INSTANTIATING → VERIFYING → READY`
    matches the `State` enum at
    `game/autoload/store_director.gd:34-42`.
  - Row 3 (per-store controller): `game/scripts/stores/retro_games.gd`
    extending `game/scripts/stores/store_controller.gd` is the surviving
    shipping store.
  - Row 4 (`CameraAuthority`): `request_current`, the `cameras` group,
    and `assert_single_active()` exist in
    `game/autoload/camera_authority.gd`.
  - Row 5 (`InputFocus` + `ModalQueue`): the four context constants
    (`CTX_MAIN_MENU = &"main_menu"`, `CTX_MALL_HUB = &"mall_hub"`,
    `CTX_STORE_GAMEPLAY = &"store_gameplay"`, `CTX_MODAL = &"modal"`)
    exist at `game/autoload/input_focus.gd:18-21`. The priority enum
    `DAY_SUMMARY → VIC_NOTE → TUTORIAL → TOAST → PASSIVE_HUD` lives at
    `game/autoload/modal_queue.gd:33-39`.
  - Row 6 (`GameState`), Row 7 (`HUD`), Row 8 (`StoreRegistry`),
    Row 9 (`AuditLog.pass_check`/`fail_check`), Row 10
    (`EventBus` mirror signals) all match their cited sources.
- **`docs/design.md`** — Section 4 store-roster table has the single
  `retro_games` row; `GameManager.DEFAULT_STARTING_STORE = &"retro_games"`
  is canonical. The visual anti-pattern list cross-references
  `BuildModeCamera`, `mat_outline_highlight.tres`, and
  `ui_theme_constants.gd` — all exist. After this pass's edits, no
  reference to a non-existent `Phase 0` planning phase remains.
- **`docs/content-data.md`** — every JSON path in the content-tree table
  exists under `game/content/` (24 files plus the empty
  `game/content/localization/` directory and the populated
  `game/assets/localization/` directory). The `_TYPE_ROUTES` `ignore`
  bucket in `game/autoload/data_loader.gd:19-63` matches the doc's
  `ignore` list. `MAX_JSON_FILE_BYTES = 1048576` (1 MiB) at
  `data_loader.gd:7` matches. `ContentRegistry.ID_PATTERN` is
  `^[a-z][a-z0-9_]{0,63}$` at `content_registry.gd:4`.
  `store_definitions.json` lists exactly one store (`retro_games`),
  matching the "Shipping roster" block.
- **`docs/testing.md`** — `tests/run_tests.sh` step list and the
  `.gutconfig.json` keys (`prefix: "test_"`, `suffix: ".gd"`,
  `should_exit: true`, `should_exit_on_success: true`,
  `pre_run_script: "res://tests/gut_pre_run.gd"`) are accurate. The five
  CI jobs (`lint-docs`, `gut-tests`, `interaction-audit`,
  `content-originality`, `lint-gdscript`) all appear as `jobs:` entries
  in `.github/workflows/validate.yml`. The Godot install pin
  (`GODOT_VERSION: "4.6.2-stable"`) is at the workflow `env:` block.
- **`docs/configuration-deployment.md`** — every input-action group named
  in the doc is present in `project.godot:[input]`
  (`move_*`, `interact`, `quick_stock`, `toggle_debug`,
  `toggle_debug_camera`, `toggle_inventory`, `toggle_orders`,
  `toggle_staff`, `toggle_pricing`, `toggle_build_mode`,
  `rotate_fixture`, `time_speed_{1,2,4}`, `time_toggle_pause`,
  `close_day`, `pause_menu`, `toggle_overview`, `nav_zone_{1..5}`,
  `sprint`).
  `MAX_MANUAL_SLOTS = 3` and `MAX_SAVE_FILE_BYTES = 10485760` match
  `game/scripts/core/save_manager.gd:46,48`; the atomic `.tmp` write is
  in `_write_save_file_atomic()`. The three export-preset paths
  (`exports/windows/MallcoreSim.exe`, `exports/macos/MallcoreSim.zip`,
  `exports/linux/MallcoreSim.x86_64`) match `export_presets.cfg`. The
  exclude-filter list (`.aidlc/*,docs/*,tests/*,game/tests/*,
  addons/gut/*,game/addons/gut/*,.godot/*,*.md,*.txt,.gitignore,
  .gutconfig.json`) is identical across all three presets, matching the
  doc's "All current presets exclude …" line.
  The validate workflow's `lint-docs`, `gut-tests`, `interaction-audit`,
  `content-originality`, `lint-gdscript` jobs match. The export
  workflow's preset validation, `chickensoft-games/setup-godot@v2`
  install, parallel Windows/macOS/Linux jobs, and final
  `softprops/action-gh-release@v3` release step match. The artifact
  filenames (`mallcore-sim-{windows,macos,linux}.{zip,zip,tar.gz}`) match
  the workflow's upload steps. The `Shelf Life` (config name) vs.
  `Mallcore Sim` (preset `application/name`) callout reflects the actual
  string mismatch in `project.godot:17` and `export_presets.cfg`.
- **`docs/contributing.md`** — `.editorconfig` rules, naming
  conventions, content-ID regex (`^[a-z][a-z0-9_]{0,63}$`), and the
  `bash tests/run_tests.sh` entry point all check out.
- **`docs/retro_games_interactable_matrix.md`** — the InteractionRay
  cast (`interaction_mask = 16`, `ray_distance = 2.5 m`), the
  `InteractionArea` reparent on layer 16, and the shared
  `slot_collision` resource at `Vector3(0.3, 0.3, 0.3)` are still the
  documented contract. Every numbered row's scene path resolves under
  `game/scenes/stores/retro_games.tscn` and every named handler is on
  `game/scripts/stores/retro_games.gd`. The reserved `H-1`…`H-7` rows
  are still placeholders for the deferred hidden-thread audit pass and
  are explicitly marked as such; left untouched.
- **`docs/style/visual-grammar.md`** — `STORE_ACCENT_RETRO_GAMES`
  (`#E8A547`, `Color(0.910, 0.647, 0.278, 1.0)`), the four `FONT_SIZE_*`
  constants (`14`, `18`, `24`, `32`), `DARK_PANEL_FILL`,
  `DARK_PANEL_BORDER`, `DARK_PANEL_TEXT`, `DARK_PANEL_TEXT_SECONDARY`,
  `LIGHT_PANEL_FILL`, `LIGHT_PANEL_TEXT`, and the four `SEMANTIC_*`
  colors (`SUCCESS`, `WARNING`, `ERROR`, `INFO`) all exist in
  `game/scripts/ui/ui_theme_constants.gd:51-105`. The "Interactable
  States" table token names (`panel_raised`, `panel_surface`,
  `accent_interact`, `accent_warning`, `text_muted`, `text_primary`)
  resolve to the `Palette/colors/*` keys in
  `game/themes/game_theme.tres:272-278`, so both naming axes (Constants
  vs. Theme palette) are real. The dormant
  `store_accent_{electronics,pocket_creatures,sports_cards,video_rental}.tres`
  files are still on disk under `game/themes/` with no `STORE_ACCENT_*`
  constant reference, matching the "inactive until a second store is
  reintroduced" callout.
- **`docs/beta/validation_checklist.md`** — interactable prompts, F10
  screenshot path pattern, the customer-event id
  `day01_wrong_console_parent` (in
  `game/content/beta/events/customer_events.json`), and the
  `tests/gut/test_beta_day_one_critical_path.gd` smoke target all match.

## Statements removed as unverifiable

- The `(Phase 0 exit criterion)` parenthetical in `docs/design.md`
  Section 5 — no `Phase 0` doc exists in `docs/` and `BRAINDUMP.md`
  does not name a `Phase 0`.
- "Phase 0 exit criteria" in `docs/design.md` Section 6 — same reason.
- "Phase 0.1 SSOT tripwires" labeling in `docs/setup.md` step 7 and
  `docs/testing.md` step 7 — the original anchor doc
  (`docs/audits/phase0-ui-integrity.md`) was deleted in the 2026-05-10
  consolidation pass; the label has been an orphan since.

The verifiable substance of all three sentences was preserved (the
end-to-end-loop constraint and the three concrete tripwire script names
respectively).

## Intentional gaps

- **`config/name="Shelf Life"` vs. export preset
  `application/name="Mallcore Sim"`** — both names remain documented in
  `docs/configuration-deployment.md`. The strings genuinely disagree in
  code/config (`project.godot:17` vs.
  `export_presets.cfg:24,31,69`). Reconciling them is a code-side
  decision that a docs pass cannot make.
- **`docs/audits/2026-05-05-audit.md` and `2026-05-06-audit.md`** —
  left untouched. These are interaction-audit table snapshots regenerated
  by `tests/audit_run.sh` / the `interaction-audit` CI job; hand-edits
  would race the next CI run.
- **`MallHub` named in `docs/architecture/ownership.md` rows 1 and 4
  accepted-callers columns.** The script attached to `mall_hallway.tscn`
  is `class_name MallHallway` (not `MallHub`); the walkable variant is
  gated by `debug/walkable_mall=false` and not part of the shipping
  flow. The columns describe a conceptual responsibility ("the mall hub
  scene's controller") rather than a specific class name, and the
  walkable mall is dormant. Same disposition as the prior pass: left
  as-is to avoid implying the walkable variant is a live caller surface;
  if the variant is revived the column should be updated to
  `MallHallway` at the same time the caller wiring is added back.
- **Audit reports under `docs/audits/`** (`cleanup-report.md`,
  `error-handling-report.md`, `security-report.md`, `ssot-report.md`)
  not re-verified line-by-line in this pass. Each has its own per-pass
  prompt that rewrites it; this docs pass would otherwise compete with
  those passes' rewrite contracts. Their internal references to source
  paths/lines may have drifted relative to the WIP working tree (e.g.
  `cleanup-report.md` records `hud.gd` at 1419 LOC but the file is now
  1479 LOC after the working-tree's FP-mode block), and that is the
  cleanup-report pass's surface to reconcile, not this pass's.

## Escalations

None. Every finding was acted on (in-place edit) or recorded above under
"Intentional gaps" with the specific reason it was not actioned.
