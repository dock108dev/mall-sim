# Docs Consolidation — 2026-05-03

**Scope:** documentation review and consolidation pass over `README.md`,
`docs/`, and `docs/audits/`. Goal: every doc statement verifiable from the
current code, configs, content, scenes, and CI workflows; nothing else
exists.

**Method:** read every file under `README.md`, `docs/`, and
`docs/audits/` in full; cross-check claims against `project.godot`,
`game/scripts/core/boot.gd`, `game/scenes/bootstrap/boot.gd`,
`game/scenes/world/game_world.gd`, the autoload roster, the player /
camera scripts under `game/scripts/player/`, the visual systems under
`game/scripts/ui/` and `game/scripts/world/`, the JSON content tree
under `game/content/`, the resource definitions under `game/resources/`,
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

### `docs/architecture.md` — Visual Systems table

- **Added** four rows that were missing after the in-progress
  first-person store-entry transition (verified against
  `game/scripts/player/store_player_body.gd` `class_name
  StorePlayerBody`, `game/scripts/player/interaction_ray.gd` parented to
  `PlayerController/StoreCamera` in `game/scenes/stores/retro_games.tscn:297`,
  `game/scripts/player/player_controller.gd` `class_name
  PlayerController` with `is_orthographic` debug overhead framing, and
  `game/scenes/ui/crosshair.tscn` `extends CanvasLayer`):

  - `StorePlayerBody` — first-person in-store player avatar with WASD,
    mouse-look, sprint, interact (spawned at `PlayerEntrySpawn` by
    `GameWorld._spawn_player_in_store` per `game_world.gd:1006`).
  - `InteractionRay` — eye-level interaction ray cast from the FP
    camera, parented to the `StoreCamera` node.
  - `PlayerController` (orbit) — debug-only overhead/orbit camera
    toggled by `toggle_debug_camera` (F1).
  - `Crosshair` — screen-center reticle CanvasLayer for the FP camera.

- **Reframed** the build-mode camera row from "Orbit / pan / zoom
  camera with Tween transitions" to "Build-mode orbit / pan / zoom
  camera with Tween transitions." Reason: the orbit role is now scoped
  to build mode plus the F1 debug overhead. The eye-level shopping
  camera is an embedded `Camera3D` on `StorePlayerBody`, not an orbit
  controller. Verified against `game/scripts/world/build_mode_camera.gd`.

### `docs/design.md` — non-negotiable §3

- **Rewrote** the "Management hub, not walkable world" rule. The
  previous wording — "player-controller movement is behind a debug flag
  only; the mall is navigated by clicking store cards" — predates the
  first-person in-store transition (see `BRAINDUMP.md` "Hard pivot
  required" / `docs/audits/ssot-report.md` Pass 2 "destructive cleanup
  against the working-tree diff that completes the first-person pivot").
  The new wording covers both surfaces:
  - **mall hub** is card-based via `mall_overview` and the walkable
    mall variant is gated by `debug/walkable_mall` (verified at
    `project.godot:61` `walkable_mall=false` and
    `game/scenes/world/game_world.gd:235` /
    `game/scenes/mall/mall_hub.gd:182`);
  - **store interior** is walked in first person via `StorePlayerBody`,
    with the orbit `PlayerController` retained as the F1
    `toggle_debug_camera` view only.

### `docs/configuration-deployment.md` — Input and runtime settings

- **Rewrote** the action-groups bullet list. Two issues with the
  previous list:
  1. It claimed "camera orbit, pan, and zoom" actions exist. They do
     not — `project.godot` defines no `orbit_*` / `pan_*` / `zoom_*`
     input actions, and the SSOT cleanup pass explicitly stripped them
     when the FP body landed (see `cleanup-report.md` Pass 3).
  2. It omitted action groups that **do** exist: `sprint`,
     `pause_menu`, `close_day`, `toggle_overview`, `toggle_debug_camera`
     (F1), and the five `nav_zone_N` shortcuts.
- The replacement enumerates every action-group present in
  `project.godot:80-208` and adds one sentence noting the
  `debug/walkable_mall` flag (default `false`).

### `docs/configuration-deployment.md` — Linux preset row

- **Tightened** the `Linux/X11` Notes cell from "Linux desktop preset
  checked in for local export use" to "Linux desktop preset, embedded
  PCK." Reason: `.github/workflows/export.yml` exports Linux as a
  first-class CI target alongside Windows and macOS — the "local export
  use" framing was misleading. Embedded PCK is verifiable from
  `export_presets.cfg:104` (`binary_format/embed_pck=true` on
  `[preset.2.options]`).

### `docs/index.md` — Audit notes block

- **Added** a one-line entry for `docs-consolidation.md`. The previous
  index listed `cleanup-report.md` as the trailing audit but omitted
  this consolidation report even though the file existed in the
  directory.

### `docs/audits/docs-consolidation.md` (this file)

- **Rewrote** as the audit-trail of this pass, replacing the prior
  2026-05-02 record. The previous record's edits were small framing
  rewrites; this pass's edits are larger (reflecting the FP transition
  in `architecture.md` / `design.md` / `configuration-deployment.md`),
  so a new pass record is warranted. The file remains a single
  most-recent record rather than appending; older pass framing is now
  in `git history` and in `cleanup-report.md` Pass 2 (which already
  cross-references the prior `docs-consolidation.md` framing).

---

## Statements removed as unverifiable

- `docs/configuration-deployment.md` — "camera orbit, pan, and zoom"
  action-group claim. Removed because no matching action exists in
  `project.godot` (`grep -E "orbit_|pan_|zoom_|camera_orbit|camera_pan|camera_zoom" project.godot` is empty).
- `docs/design.md` — the unqualified "player-controller movement is
  behind a debug flag only" claim. Removed because, post-FP-transition,
  the in-store body (`StorePlayerBody`) drives WASD + mouse-look in
  shipping configurations and the legacy orbit `PlayerController` is
  now the debug-only overhead view rather than the only player movement
  surface.

No deletions of audit reports. Each audit file under `docs/audits/`
carries an active code-side reverse-link surface (`§F-NN` / `§SR-NN` /
`§DR-NN` markers, daily checkpoint table, multi-pass running log) and
earns its existence.

## Files left intact (with rationale)

| File | Why left intact |
|---|---|
| `README.md` | Run-locally / run-tests / deployment / docs-pointer set, all verified against `project.godot`, `tests/run_tests.sh`, `export_presets.cfg`, and `.github/workflows/`. |
| `docs/setup.md` | Verified: Godot resolution order matches `tests/run_tests.sh::_resolve_godot_bin` (`tests/run_tests.sh:10-29`) and `scripts/godot_exec.sh`; main scene matches `project.godot:20`; runner steps match `tests/run_tests.sh:32-80`. |
| `docs/architecture.md` (Boot Flow, init tiers, Autoloads, Signal Bus, Scene Entry Points) | Boot flow matches `game/scripts/core/boot.gd:19-66` (DataLoader → arc/objectives schema → ContentRegistry.is_ready → ≥5 store IDs → Settings.load → AudioManager.initialize → mark_boot_completed → boot_completed signal → MAIN_MENU). Boot wrapper at `game/scenes/bootstrap/boot.gd:2` verified. Init-tier table matches `game/scenes/world/game_world.gd:265-440`. Autoload roster (1–31) matches `project.godot:24-56` line-for-line. EventBus prefixes (`store_`, `day_`, `customer_`, `inventory_`, `reputation_`, `milestone_`, `unlock_`, `completion_`, `tutorial_`, `onboarding_`, `interactable_`, `panel_`) match the corresponding signal blocks in `game/autoload/event_bus.gd`. The Visual-Systems table changes are listed above. |
| `docs/architecture/ownership.md` | Each row verified against the named autoload/source script: `SceneRouter`, `StoreDirector`, `CameraAuthority`, `InputFocus`, `GameState`, `HUD`, `StoreRegistry`, `AuditLog`, `EventBus`. |
| `docs/design.md` (everything except §3) | Store-display-name column matches `game/content/stores/store_definitions.json:9,110,216,329,456`. Canonical-id column matches the `id` field in the same file. Anti-pattern table claims (camera controllers, outline shader paths) match the visual-systems entries above. The §3 rewrite is described under "Edits applied this pass." |
| `docs/style/visual-grammar.md` | Token names and hex/`Color()` values match `game/scripts/ui/ui_theme_constants.gd` (`DARK_PANEL_FILL`, `LIGHT_PANEL_FILL`, `SEMANTIC_*`, `STORE_ACCENT_*`, `STORE_ACCENTS`, `FONT_SIZE_*`). Theme files exist at `game/themes/palette.tres`, `mallcore_theme.tres`, and `store_accent_*.tres`. The `STORE_ACCENTS` dictionary keys (`sports_cards`, `video_rental`) intentionally differ from the canonical store ids (`sports`, `rentals`) — the doc reports it accurately. |
| `docs/content-data.md` | Loader pipeline matches `game/autoload/data_loader.gd` and `game/scripts/content_parser.gd`. `_TYPE_ROUTES` categories (entries / singleton / ignore) match `game/autoload/data_loader.gd:19-71`. `MAX_JSON_FILE_BYTES = 1048576` matches `data_loader.gd:7`. Resource list matches `game/resources/*.gd` (20 files). Validation list matches `game/autoload/content_registry.gd::validate_all_references` at `:274-297` and helpers below. Roster line matches `store_definitions.json` (canonical `sports`/`retro_games`/`rentals`/`pocket_creatures`/`electronics` with documented aliases). |
| `docs/testing.md` | Runner steps match `tests/run_tests.sh`. `.gutconfig.json` claims (dirs, `prefix: "test_"`, `suffix: ".gd"`, `should_exit: true`, `should_exit_on_success: true`, `pre_run_script: "res://tests/gut_pre_run.gd"`) match the JSON verbatim. CI-validation block matches `.github/workflows/validate.yml` jobs (`lint-docs`, `gut-tests`, `interaction-audit`, `content-originality`, `lint-gdscript`). |
| `docs/configuration-deployment.md` (sections other than the two listed above) | After this pass's edits, every remaining claim verified: `application/*` block matches `project.godot:15-22`; save constants match `game/scripts/core/save_manager.gd:43-51` (`SAVE_DIR`, `SLOT_INDEX_PATH`, `MAX_MANUAL_SLOTS=3`, `MAX_SAVE_FILE_BYTES=10485760`); export-preset paths and exclude filters match `export_presets.cfg`; `validate.yml` / `export.yml` job descriptions match the workflows. |
| `docs/contributing.md` | `.editorconfig` rules, GDScript standards, naming, content rules, and docs-boundary rules match the working repo. |
| `docs/roadmap.md` | Forward-looking phase doc; Phase 0.1 completion claim verified (the three SSOT tripwires exist under `scripts/` and are invoked by `tests/run_tests.sh:75-80`); shipping-roster line matches `store_definitions.json`. Phase 1+ items remain forward-looking targets. |
| `docs/audits/cleanup-report.md` | Multi-pass running record. Pass 4 verification line ("4927 GUT tests, 0 failures") is point-in-time; later passes will append. Untouched this pass. |
| `docs/audits/error-handling-report.md` | Inline `§F-NN` index reverse-points at code; the cleanup-report Pass-2 sweep verified each cite. Untouched this pass. |
| `docs/audits/security-report.md` | `§F` / `§SR` / `§DR` index unchanged; reverse-pointer integrity confirmed by the cleanup-report Pass-2 sweep. Untouched this pass. |
| `docs/audits/ssot-report.md` | Pass 2 record covers the FP transition. Untouched this pass. |
| `docs/audits/2026-05-02-audit.md`, `docs/audits/2026-05-03-audit.md` | Daily interaction-audit tables written by `tests/audit_run.sh`, regenerated by the `interaction-audit` CI job in `.github/workflows/validate.yml`. Not edited by docs passes. |

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
  history. (`cleanup-report.md` follows a different pattern — multiple
  passes appended in one file — because the cleanup work itself is
  cumulative on a single working-tree diff. This pass re-evaluated each
  audit-report's framing pattern and kept it as authored.)
- **`BRAINDUMP.md` and `LICENSE` at repo root are untouched.** Per pass
  rules. `BRAINDUMP.md` is the customer-voice state assessment that
  drives the FP transition referenced above.
- **No code edits.** This is a docs-only pass; the Actionability
  Contract's "act in source" clause is satisfied by the markdown edits
  enumerated under "Edits applied this pass" above.

---

## Escalations

None. Every finding was either acted on (the six edits above) or had
no action to take (everything else verified). No documentation
assertion was left in place that this pass could not trace back to a
specific source file, config field, content entry, or workflow step.
