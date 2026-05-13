# Documentation Consolidation Pass — 2026-05-11

Working-tree-driven documentation review on `beta/strip-to-bones`. Goal: every
active-doc statement is verifiable from current code, config, or CI; nothing
else exists.

Scope: `README.md` plus everything under `docs/`. Out of scope by rule:
`BRAINDUMP.md` (customer voice) and the per-pass audit reports under
`docs/audits/` written by other passes (`cleanup-report.md`,
`error-handling-report.md`, `security-report.md`, `ssot-report.md`,
`YYYY-MM-DD-audit.md`).

The prior pass (2026-05-10, recorded below in earlier git history) deleted the
orphaned planning trees (`docs/production/`, `docs/archive/`,
`docs/design/`, four `docs/architecture/*` wave-1 docs) and rewrote
`docs/content-data.md` against the on-disk content tree. This pass is a
verification sweep over the surviving doc set against the current code.

## Summary

One verified drift surfaced: the **`ModalQueue` autoload** (declared at
`project.godot:52` between `InputFocus` and `ModalDimOverlay`, source at
`game/autoload/modal_queue.gd`) was missing from the
`docs/architecture.md` autoload table and unmentioned in the
`docs/architecture/ownership.md` modal-stack row. The autoload is real and
load-bearing — `game/autoload/scene_router.gd:85` and `:112` call
`ModalQueue.clear()` before every scene swap, and the `ModalPanel` base
class routes `CTX_MODAL` push/pop through `ModalQueue.request_open` and
`notify_closed`.

Two files updated. No deletions. No new files.

## Edits applied

### `docs/architecture.md` — autoload table row added

Inserted `ModalQueue` as row 27 between `InputFocus` (row 26) and
`ModalDimOverlay` (now row 28), matching the position in
`project.godot:[autoload]`. Subsequent row numbers shifted +1 (final row
count 43 → 44). The "Five entries are scenes" preamble is still accurate
(scene autoloads: `ObjectiveRail`, `InteractionPrompt`, `MorningNotePanel`,
`MiddayEventCard`, `FailCard`).

Row contents:

> `ModalQueue` | `game/autoload/modal_queue.gd` — priority-ordered FIFO that
> grants `CTX_MODAL` to one `ModalPanel` at a time; cleared by
> `SceneRouter` before every scene swap

Source: `project.godot:52`, `game/autoload/modal_queue.gd:1-50`,
`game/autoload/scene_router.gd:83-86,106-112`.

### `docs/architecture/ownership.md` — row 5 expanded

Row 5 ("Input focus / modal ownership") previously named only
`InputFocus` plus a generic "modal panels (push/pop on open/close)"
caller. Rewrote to:

- Spell out `ModalQueue` as the mediator that owns `CTX_MODAL` dispatch
  (priority enum `DAY_SUMMARY → VIC_NOTE → TUTORIAL → TOAST →
  PASSIVE_HUD` — verbatim from `modal_queue.gd:29-35`).
- Record `SceneRouter`'s `ModalQueue.clear()` call as part of the
  transition contract (so the modal stack cannot survive a scene swap).
- Move modal panels from "push/pop directly" to "route through
  `ModalQueue.request_open`" in the accepted-callers column.
- Add `ModalPanel`-bypass patterns to the forbidden column
  (`ModalQueue.notify_closed` / `cancel` called from non-panel code, or
  `CTX_MODAL` pushed outside `ModalQueue` dispatch).

Source: `game/autoload/modal_queue.gd:1-50`, `game/autoload/scene_router.gd:83-112`,
`game/autoload/input_focus.gd:18-21`.

## Statements verified, no edit needed

Spot-checked the following against the current working tree. All match.

- **`README.md`** — engine version `4.6.2`, entry scene path,
  `bash tests/run_tests.sh`, validator names
  (`validate_translations.sh`, `validate_single_store_ui.sh`,
  `validate_tutorial_single_source.sh`), export-preset paths, and `/docs`
  link list all match `project.godot`, `tests/run_tests.sh`, and
  `export_presets.cfg`.
- **`docs/index.md`** — every linked doc still exists; the Boundary
  section's claim that `README.md` is the only active root doc plus
  `BRAINDUMP.md` (out of scope) holds.
- **`docs/setup.md`** — Godot-binary resolution order (`GODOT`,
  `GODOT_EXECUTABLE`, `godot` on PATH, two macOS install paths) matches
  `tests/run_tests.sh:10-30` and `scripts/godot_exec.sh`.
  `bash scripts/godot_import.sh` exists. The `bash tests/run_tests.sh`
  step list matches.
- **`docs/architecture.md`** — boot flow steps 1-7 line up with
  `game/scripts/core/boot.gd::initialize()`; the wrapper at
  `game/scenes/bootstrap/boot.gd` exists (one-line
  `extends "res://game/scripts/core/boot.gd"`). GameWorld init tiers 1-5
  exist as `initialize_tier_1_data` …
  `initialize_tier_5_meta` at `game/scenes/world/game_world.gd:245,256,281,338,345`,
  with `finalize_system_wiring` at `:396`; tier 2 returns `bool` as
  documented. Scene-entry-point table paths all exist. The hub-mode
  description (`debug/walkable_mall=false`, `_setup_hub_mode`,
  `apply_pending_session_state` emits
  `EventBus.enter_store_requested(GameManager.DEFAULT_STARTING_STORE)`)
  matches `game/scenes/world/game_world.gd:1188-1226` and
  `game/autoload/game_manager.gd:11` (`DEFAULT_STARTING_STORE = &"retro_games"`).
  EventBus signal-prefix table (`store_`, `day_`, `customer_`, `inventory_`,
  etc.) and the `run_state_changed()` mirror match `event_bus.gd`.
- **`docs/architecture/ownership.md`** — all eight non-modal rows
  verified against source:
  - Row 1: `SceneRouter._in_flight`, `change_scene_to_file/_packed`,
    `tree_changed` + `process_frame` await, `scene_ready` / `scene_failed`
    all present in `game/autoload/scene_router.gd:28-146`.
  - Row 2: `StoreDirector.enter_store` state machine
    `IDLE → REQUESTED → LOADING_SCENE → INSTANTIATING → VERIFYING → READY`
    matches `game/autoload/store_director.gd:34-50,68-146`.
  - Row 3: per-store controller is `game/scripts/stores/retro_games.gd`
    extending `game/scripts/stores/store_controller.gd`.
  - Row 4: `CameraAuthority.request_current`, the `cameras` group, and
    `assert_single_active()` match `game/autoload/camera_authority.gd:27-88`.
  - Row 6: `GameState` autoload at `game/autoload/game_state.gd`.
  - Row 7: `HUD` is `game/scenes/ui/hud.gd`.
  - Row 8: `StoreRegistry` at `game/autoload/store_registry.gd`.
  - Row 9: `AuditLog.pass_check` / `fail_check` exist at
    `game/autoload/audit_log.gd:21+`.
  - Row 10: `EventBus` mirror-signal claim matches the live signal
    declarations in `event_bus.gd`.
- **`docs/design.md`** — Section 4 store-roster table has the single
  `retro_games` entry; `GameManager.DEFAULT_STARTING_STORE` is the
  canonical id. The visual anti-pattern list cross-references
  `BuildModeCamera`, `mat_outline_highlight.tres`, and
  `ui_theme_constants.gd` — all exist.
- **`docs/content-data.md`** — full `game/content/` tree (`audio_registry.json`,
  `beta/days/day_01.json`, `beta/days/day_02.json`,
  `beta/events/customer_events.json`, `beta/events/hidden_thread_events.json`,
  the 5 `customers/*.json`, `economy/{difficulty_config,pricing_config}.json`,
  `endings/ending_config.json`, `events/{ambient_moments,market_events,random_events}.json`,
  `fixtures.json`, `haggle_dialogue.json`, `items/retro_games.json`,
  `manager/manager_notes.json`, `meta/regulars_threads.json`,
  `objectives.json`, `onboarding/onboarding_config.json`, `platforms.json`,
  `progression/{arc_unlocks,milestone_definitions}.json`,
  `staff/staff_definitions.json`,
  `stores/{retro_games,store_definitions}.json` plus `stores/retro_games/grades.json`,
  `suppliers/supplier_catalog.json`, `tutorial_contexts.json`,
  `unlocks/unlocks.json`, `upgrades.json`) matches the doc tables.
  `_TYPE_ROUTES` `ignore` bucket in `game/autoload/data_loader.gd:47-62`
  matches the doc's `ignore` list verbatim. The empty `game/content/localization/`
  directory and the `MAX_JSON_FILE_BYTES = 1048576` cap (`data_loader.gd:7`)
  match. ContentRegistry ID regex matches `^[a-z][a-z0-9_]{0,63}$` in code.
- **`docs/testing.md`** — `tests/run_tests.sh` step list and the
  `.gutconfig.json` keys (`prefix`, `suffix`, `should_exit`,
  `should_exit_on_success`, `pre_run_script`) are accurate. The five CI
  jobs (`lint-docs`, `gut-tests`, `interaction-audit`,
  `content-originality`, `lint-gdscript`) all appear as `jobs:` entries
  in `.github/workflows/validate.yml`.
- **`docs/configuration-deployment.md`** — every input-action group is
  present in `project.godot:[input]`; `MAX_MANUAL_SLOTS = 3` and
  `MAX_SAVE_FILE_BYTES = 10485760` match
  `game/scripts/core/save_manager.gd`; the three export-preset paths
  (`exports/windows/MallcoreSim.exe`, `exports/macos/MallcoreSim.zip`,
  `exports/linux/MallcoreSim.x86_64`) match `export_presets.cfg`; the
  `4.6.2-stable` install line is in both workflows. The `Shelf Life`
  vs. `Mallcore Sim` naming dual-callout is honest about the
  `config/name` / preset disagreement in code.
- **`docs/contributing.md`** — `.editorconfig` rules, naming
  conventions, content-ID regex, and the `bash tests/run_tests.sh` entry
  point all check out.
- **`docs/retro_games_interactable_matrix.md`** — every numbered row's
  scene path resolves under `game/scenes/stores/retro_games.tscn` and
  every named handler exists on `game/scripts/stores/retro_games.gd`.
- **`docs/style/visual-grammar.md`** — `STORE_ACCENT_RETRO_GAMES`
  (`#E8A547`, `Color(0.910, 0.647, 0.278, 1.0)`), the four `FONT_SIZE_*`
  constants (`14`, `18`, `24`, `32`), and `DARK_PANEL_FILL`,
  `SEMANTIC_SUCCESS`, `SEMANTIC_INFO` are all present in
  `game/scripts/ui/ui_theme_constants.gd`. The dormant
  `store_accent_{electronics,pocket_creatures,sports_cards,video_rental}.tres`
  files are still on disk under `game/themes/` with no `STORE_ACCENT_*`
  constant reference, matching the doc.
- **`docs/beta/validation_checklist.md`** — interactable prompts, F10
  screenshot path pattern, and the customer-event id
  `day01_wrong_console_parent` (in
  `game/content/beta/events/customer_events.json`) all match.

## Statements removed as unverifiable

None this pass. The prior 2026-05-10 sweep removed the orphaned planning
trees; nothing new in the surviving doc set surfaced as drift beyond the
`ModalQueue` gap above.

## Intentional gaps

- **`config/name="Shelf Life"` vs. export preset
  `application/name="Mallcore Sim"`** — both names are recorded in
  `docs/configuration-deployment.md` rather than picking one. The strings
  genuinely disagree in code/config (`project.godot:17` vs.
  `export_presets.cfg` per-preset `application/name`). Reconciling them
  is a code-side decision that a docs pass cannot make.
- **`docs/audits/2026-05-05-audit.md` and `2026-05-06-audit.md`** — left
  untouched. These are interaction-audit table snapshots regenerated by
  `tests/audit_run.sh` / the `interaction-audit` CI job; hand-edits
  would race the next CI run.
- **`KNOWN_ORPHAN_SIGNALS` allowlist** in
  `tests/gut/test_eventbus_signal_compat.gd` remains the live receipt
  for intentional orphan signals in `event_bus.gd`. No replacement doc
  was written — the test plus the inline comments on `event_bus.gd` are
  the actual contract.
- **`MallHub` named in `ownership.md` rows 1 and 4 accepted-callers
  columns.** The script attached to `mall_hallway.tscn` is
  `class_name MallHallway` (not `MallHub`); the walkable variant is
  gated by `debug/walkable_mall=false` and not part of the shipping flow.
  The columns describe a conceptual responsibility ("the mall hub
  scene's controller") rather than a specific class name, and the
  walkable mall is dormant anyway. Left as-is to avoid implying the
  walkable variant is a live caller surface; if the variant is revived
  the column should be updated to `MallHallway` at the same time the
  caller wiring is added back.

## Escalations

None. Every finding was acted on (in-place edit) or recorded above under
"Intentional gaps" with the specific reason it was not actioned.
