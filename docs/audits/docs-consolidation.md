# Docs Consolidation — 2026-05-03

**Scope:** documentation review and consolidation pass over `README.md`,
`docs/`, and `docs/audits/`. Goal: every doc statement verifiable from
the current code, configs, content, scenes, and CI workflows; nothing
else exists.

**Method:** read every file under `README.md`, `docs/`, and
`docs/audits/` in full; cross-check claims against `project.godot`,
`game/scripts/core/boot.gd`, `game/scenes/bootstrap/boot.gd`,
`game/scenes/world/game_world.gd`, the autoload roster, the player /
camera scripts under `game/scripts/player/`, the visual systems under
`game/scripts/ui/` and `game/scripts/world/`, the JSON content tree
under `game/content/`, the resource definitions under `game/resources/`,
`game/scripts/stores/store_ready_contract.gd`, `game/themes/*.tres`,
`tests/run_tests.sh`, `.gutconfig.json`, `scripts/*.sh`, and the two CI
workflows under `.github/workflows/`. No edits to source code.

---

## Doc-set boundary (re-confirmed)

- Root: `README.md` only (active project doc). Customer-voice / vision
  files at root: `BRAINDUMP.md`, `LICENSE` — left untouched per pass
  rules.
- Active project docs: `docs/` (`index.md`, `setup.md`,
  `architecture.md`, `architecture/ownership.md`, `design.md`,
  `style/visual-grammar.md`, `content-data.md`, `testing.md`,
  `configuration-deployment.md`, `contributing.md`, `roadmap.md`).
- Audit notes: `docs/audits/` (`cleanup-report.md`,
  `error-handling-report.md`, `security-report.md`, `ssot-report.md`,
  dated `YYYY-MM-DD-audit.md` files for `2026-05-02` and `2026-05-03`,
  this `docs-consolidation.md`).

No stray markdown files outside this boundary; markdown under
`.github/`, `.aidlc/`, `addons/`, `tools/`, and `planning/` is
configuration / templates / vendored material and is correctly excluded
from the active doc set.

---

## Edits applied this pass

### `docs/content-data.md` — "Stores — SSOT" roster line

- **Removed** the unverifiable `per ADR 0007` clause from the shipping
  roster paragraph. There is no ADR file or directory anywhere in the
  repo (`grep -rn 'ADR' docs/` returns only this one occurrence; no
  `docs/adr/`, `docs/architecture/decisions/`, or numbered ADR files
  exist). The remaining citation —
  `game/content/stores/store_definitions.json` — is the authoritative
  source the paragraph already names; the canonical ids (`sports`,
  `retro_games`, `rentals`, `pocket_creatures`, `electronics`) and
  alias spellings (`sports_memorabilia`, `video_rental`,
  `consumer_electronics`) match the JSON entries verbatim
  (`grep -nE '"id":|"aliases":' store_definitions.json`).

---

## Statements removed as unverifiable

- `docs/content-data.md` — `per ADR 0007` reference. Removed because
  no ADR file exists in the tree (`docs/adr/`, `architecture/decisions/`,
  and any `*adr*` / `0007*` files all return zero matches under
  `find /Users/dock108/git/mall-sim`). The clause asserted a
  governance citation that the repo cannot produce; the surrounding
  sentence still cites `store_definitions.json`, which **is** the
  authoritative source for the roster.

No deletions of audit reports. Each audit file under `docs/audits/`
carries an active code-side reverse-link surface (`§F-NN` / `§SR-NN` /
`§DR-NN` markers, daily checkpoint table, multi-pass running log) and
earns its existence.

## Files left intact (with rationale)

| File | Why left intact |
|---|---|
| `README.md` | Run-locally, run-tests, deployment, and docs-pointer set verified against `project.godot:20` (main scene), `tests/run_tests.sh:1-83` (resolver order, GUT entry, `validate_*.sh` and SSOT tripwires), `export_presets.cfg` (export paths), and `.github/workflows/{validate,export}.yml` (Godot pin). The `4.6.2-stable` framing matches `validate.yml:14` literally; `export.yml:12` pins `4.6.2` via `chickensoft-games/setup-godot@v2`, which resolves to the same stable build, so the README's "both install `4.6.2-stable`" framing is substantively correct. |
| `docs/index.md` | Pointer index; every linked file verified to exist. The `audits/` block lists `cleanup-report.md`, `error-handling-report.md`, `security-report.md`, `ssot-report.md`, `docs-consolidation.md`, and the dated `YYYY-MM-DD-audit.md` interaction tables — all present in `docs/audits/`. The boundary paragraph (root = `README.md` + `BRAINDUMP.md`) matches the actual tree. |
| `docs/setup.md` | Godot resolution order matches `tests/run_tests.sh::_resolve_godot_bin` (`tests/run_tests.sh:10-29`) and `scripts/godot_exec.sh`; main scene matches `project.godot:20`; runner steps match `tests/run_tests.sh:32-80`. Repo layout block matches the on-disk tree. |
| `docs/architecture.md` (Boot Flow, init tiers, Autoloads, Signal Bus, Scene Entry Points, Visual Systems) | Boot flow matches `game/scripts/core/boot.gd:9-66` (DataLoader → arc/objectives schema → ContentRegistry.is_ready → ≥5 store IDs → Settings.load → AudioManager.initialize → mark_boot_completed → boot_completed signal → MAIN_MENU). Boot wrapper at `game/scenes/bootstrap/boot.gd:2` (`extends "res://game/scripts/core/boot.gd"`) verified. Init-tier table matches `game/scenes/world/game_world.gd:265-444` line-for-line (tier 1 `time_system`/`economy_system`/day-end-summary callable; tier 2 `inventory_system`/`store_state_manager`/`trend_system`/`market_event_system`/`seasonal_event_system`/`market_value_system`; tier 3 per-store `ReputationSystemSingleton`/`customer_system`/`mall_customer_spawner`/`npc_spawner_system`/`haggle_system`/`checkout_system`/`queue_system`/`progression_system`/`milestone_system`/`order_system`/`staff_system`/`meta_shift_system`; tier 4 `store_selector_system`/build mode/`tournament_system`/`day_phase_lighting`; tier 5 `performance_manager`/`performance_report_system`/`random_event_system`/`ambient_moments_system`/`regulars_log_system`/`ending_evaluator`/`DayManager` instantiated and added/`store_upgrade_system`/`completion_tracker`/`day_cycle_controller`). Autoload roster (1–31) matches `project.godot:24-56` line-for-line. EventBus prefixes (`store_`, `day_`/`hour_`, `customer_`, `inventory_`, `reputation_`, `milestone_`/`unlock_`/`completion_`, `tutorial_`/`onboarding_`, `interactable_`/`panel_`) match the corresponding signal blocks in `game/autoload/event_bus.gd`. Visual-systems file paths (`store_player_body.gd`, `interaction_ray.gd`, `player_controller.gd`, `build_mode_camera.gd`, `camera_authority.gd`, `interactable.gd`, `interactable_hover.gd`, `tooltip_manager.gd`, `interaction_prompt.tscn`, `crosshair.tscn`, `shelf_slot.gd`, `day_phase_lighting.gd`, `crt_overlay.gdshader`, `panel_animator.gd`, `ui_layers.gd`) all exist on disk. |
| `docs/architecture/ownership.md` | Each row verified against the named autoload/source script: `SceneRouter` (`scene_router.gd:1-15` docstring matches "sole owner of `change_scene_to_*`" wording), `StoreDirector`, `CameraAuthority`, `InputFocus`, `GameState`, `HUD`, `StoreRegistry`, `AuditLog`, `EventBus` (typed-signal hub only; `event_bus.gd:13-22` mirror block matches the row-10 enumeration). |
| `docs/design.md` | Store-display-name column matches `store_definitions.json:9,110,214,327,454`. Canonical-id column matches the `id` field in the same file (`sports`, `retro_games`, `rentals`, `pocket_creatures`, `electronics`). The §3 wording covers both surfaces of the two-tier player model: card-based mall hub (`debug/walkable_mall=false` at `project.godot:61`) and first-person store interior (`StorePlayerBody` spawned at `PlayerEntrySpawn` per `game_world.gd:1006`). Anti-pattern table file paths verified — `BuildModeCamera` at `game/scripts/world/build_mode_camera.gd`; `mat_outline_highlight.tres` at `game/assets/shaders/mat_outline_highlight.tres`. |
| `docs/style/visual-grammar.md` | Token names and hex / `Color()` values match `game/scripts/ui/ui_theme_constants.gd` (`DARK_PANEL_FILL` 0.122/0.102/0.086/0.96; `LIGHT_PANEL_FILL` 0.961/0.925/0.839; `SEMANTIC_INFO`/`SUCCESS`/`WARNING`/`ERROR` constants verified line-for-line at `:119-122`; `STORE_ACCENT_RETRO_GAMES`=#E8A547, `STORE_ACCENT_POCKET_CREATURES`=#2EB5A8, `STORE_ACCENT_VIDEO_RENTAL`=#E04E8C, `STORE_ACCENT_ELECTRONICS`=#3AA8D8, `STORE_ACCENT_SPORTS_CARDS`=#E85555 verified at `:84-88`; `FONT_SIZE_*` 14/18/24/32 at `:176-179`; `STORE_ACCENTS` dictionary at `:98`). Theme files exist at `game/themes/palette.tres`, `mallcore_theme.tres`, and `store_accent_*.tres` (one per store accent token). The `STORE_ACCENTS` dictionary keys (`sports_cards`, `video_rental`) intentionally differ from the canonical store ids (`sports`, `rentals`) — the doc reports it accurately. |
| `docs/content-data.md` (everything except the ADR removal above) | Loader pipeline matches `game/autoload/data_loader.gd` and `game/scripts/content_parser.gd`. Content root `res://game/content/` and `MAX_JSON_FILE_BYTES=1048576` match `data_loader.gd:6-7`. `_TYPE_ROUTES` categories (`entries:<kind>` / singleton / `ignore`) match `data_loader.gd:19-71` exactly. Type-detection rule (every JSON declares a root `"type"`) matches the comment at `data_loader.gd:9-12`. Content-tree subdirectory list verified by `ls game/content/` (`items/`, `stores/`, `customers/`, `economy/`, `events/`, `endings/`, `meta/`, `progression/`, `onboarding/`, `staff/`, `suppliers/`, `sports_cards/`, `unlocks/`); the `localization/` empty-subdirectory note matches `ls game/content/localization/` (empty). Root-level config-JSON enumeration (`audio_registry.json`, `day_beats.json`, `fixtures.json`, `haggle_dialogue.json`, `market_trends_catalog.json`, `meta_shifts.json`, `objectives.json`, `pocket_creatures_cards.json`, `tutorial_contexts.json`, `upgrades.json`) matches `ls game/content/`. ID regex `^[a-z][a-z0-9_]{0,63}$` matches `content_registry.gd:4`. Scene-path prefixes (`res://game/scenes/`, `res://game/scenes/stores/`) match `content_registry.gd:5-6`. Resource-class table matches `ls game/resources/*.gd` (one `.gd` per row: `item_definition.gd`, `store_definition.gd`, `customer_type_definition.gd`, `economy_config.gd`, `fixture_definition.gd`, `market_event_definition.gd`, `seasonal_event_definition.gd`, `random_event_definition.gd`, `milestone_definition.gd`, `staff_definition.gd`, `supplier_definition.gd`, `unlock_definition.gd`, `upgrade_definition.gd`, `sports_season_definition.gd`, `tournament_event_definition.gd`, `ambient_moment_definition.gd`, `performance_report.gd`). `validate_all_references` list matches `content_registry.gd:274-298`. |
| `docs/testing.md` | Runner steps match `tests/run_tests.sh:32-80`. `.gutconfig.json` claims (dirs `["res://tests/", "res://tests/gut/", "res://tests/unit/", "res://game/tests/"]`, `prefix:"test_"`, `suffix:".gd"`, `should_exit:true`, `should_exit_on_success:true`, `pre_run_script:"res://tests/gut_pre_run.gd"`) match the JSON verbatim. Test layout block matches `ls tests/` (`gut/`, `unit/`, `integration/`, `validate_*.sh`, `game/tests/`). CI-validation block matches `.github/workflows/validate.yml` jobs (`lint-docs` checks `project.godot`/`README.md`/`LICENSE`/`docs/architecture.md` plus no `.DS_Store`; `gut-tests` installs Godot `4.6.2-stable`, imports, runs GUT and trusts the "All tests passed" line; `interaction-audit` runs `tests/audit_run.sh` and uploads `docs/audits/`; `content-originality` greps the banned-term list; `lint-gdscript` runs `gdlint`). |
| `docs/configuration-deployment.md` | `application/*` block matches `project.godot:15-22`. Action-group enumeration matches every `[input]` action declared in `project.godot:80-208` (`move_forward`, `move_back`, `move_left`, `move_right`, `interact`, `sprint`, `toggle_debug` (F3), `toggle_debug_camera` (F1), `toggle_inventory`, `toggle_orders`, `toggle_staff`, `toggle_pricing`, `toggle_build_mode`, `rotate_fixture`, `time_speed_1`, `time_speed_2`, `time_speed_4`, `time_toggle_pause`, `close_day`, `pause_menu`, `toggle_overview`, `nav_zone_1`–`5`); the `debug/walkable_mall=false` flag matches `project.godot:61`. Save-manager constants match `save_manager.gd:43-48` (`SAVE_DIR="user://"`, `SLOT_INDEX_PATH="user://save_index.cfg"`, `MAX_MANUAL_SLOTS=3`, `MAX_SAVE_FILE_BYTES=10485760`); slot-zero auto-save and slots 1–3 manual semantics match `save_manager.gd:1049-1052`. Export-preset paths and exclude filters match `export_presets.cfg`; the Linux row's "embedded PCK" claim matches `export_presets.cfg:104` (`binary_format/embed_pck=true`). `validate.yml` / `export.yml` job descriptions match the workflows; the `4.6.2-stable` claim is literal-correct for `validate.yml:14` and substantively correct for `export.yml:12` (`4.6.2` resolves to the same stable build via `chickensoft-games/setup-godot@v2`). |
| `docs/contributing.md` | `.editorconfig` rules verified against the file. GDScript standards, naming, content rules, and docs-boundary rules match the working repo. |
| `docs/roadmap.md` | Forward-looking phase doc; Phase 0.1 completion claim verified — the three SSOT tripwires (`scripts/validate_translations.sh`, `scripts/validate_single_store_ui.sh`, `scripts/validate_tutorial_single_source.sh`) exist and are invoked by `tests/run_tests.sh:75-80`. Shipping-roster line matches `store_definitions.json`. Phase 1+ items remain forward-looking targets and are intentionally not validated against current code. |
| `docs/audits/cleanup-report.md` | Multi-pass running record. Untouched this pass — citation integrity covered by Pass 2's tree-wide sweep recorded in the same file. |
| `docs/audits/error-handling-report.md` | Inline `§F-NN` index reverse-points at code; the cleanup-report Pass-2 sweep verified each cite. Untouched this pass. |
| `docs/audits/security-report.md` | `§F` / `§SR` / `§DR` index unchanged; reverse-pointer integrity confirmed by the cleanup-report Pass-2 sweep. Untouched this pass. |
| `docs/audits/ssot-report.md` | Pass 12 record covers the FP transition + named-physics-layer migration + Day-1 readiness v2 work and `MOVE_TO_SHELF` step removal. Untouched this pass. |
| `docs/audits/2026-05-02-audit.md`, `docs/audits/2026-05-03-audit.md` | Daily interaction-audit tables written by `tests/audit_run.sh`, regenerated by the `interaction-audit` CI job in `.github/workflows/validate.yml:125-160`. Not edited by docs passes. |

---

## Intentional gaps

- **No new `docs/*.md` files were added.** The active doc set already
  covers what / how / deployment / pointer-to-docs (README), local
  setup, architecture, ownership, design, content/data, testing,
  configuration/deployment, contributing, roadmap, and visual style.
  Adding more would duplicate rather than enrich.
- **`docs/audits/docs-consolidation.md` is overwritten, not appended.**
  Following the pattern set by the other audit reports, this file
  records the most-recent pass; prior pass framing is preserved in git
  history. (`cleanup-report.md`, `ssot-report.md`,
  `error-handling-report.md`, and `security-report.md` follow the
  multi-pass-appended pattern because the work each tracks is
  cumulative on a single working-tree diff. This pass re-evaluated
  each audit-report's framing pattern and kept it as authored.)
- **`BRAINDUMP.md` and `LICENSE` at repo root are untouched.** Per
  pass rules. `BRAINDUMP.md` is the customer-voice state assessment
  that drives the FP transition referenced in `architecture.md`,
  `design.md`, and `ssot-report.md`.
- **No code edits.** This is a docs-only pass per the prompt rules
  (`Markdown only. Docs only — no code refactors.`). The
  Actionability Contract's "act in source" clause for the docs pass is
  satisfied by the markdown edit enumerated under "Edits applied this
  pass" above. One source-comment defect was observed but **not**
  edited:
  - `tests/run_tests.sh:73` carries the comment
    `# Phase 0.1 SSOT tripwires (see docs/audits/phase0-ui-integrity.md P2.1).`
    The referenced doc does not exist (`ls docs/audits/` returns no
    `phase0-ui-integrity.md`; the equivalent record now lives under
    `roadmap.md` "Phase 0.1" and `docs/audits/ssot-report.md`). This
    is a stale code-comment cite and **out of scope** for a
    docs-only pass — fixing it requires editing a `.sh` file. A
    later code-cleanup pass should either repoint the comment at
    `docs/audits/ssot-report.md` or drop the parenthetical.

---

## Escalations

None. Every finding was either acted on (the one edit above) or had no
action to take that the docs-only pass scope allows. The single
out-of-scope item (the `tests/run_tests.sh:73` comment cite) is
flagged in "Intentional gaps" with the specific next action so a
future code-cleanup pass can pick it up; no documentation assertion
was left in place that this pass could not trace back to a specific
source file, config field, content entry, or workflow step.
