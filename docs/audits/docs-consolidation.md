# Docs Consolidation — 2026-05-05

**Scope:** documentation review and consolidation pass over `README.md`,
`docs/`, and `docs/audits/`. Goal: every doc statement verifiable from
the current code, configs, content, scenes, and CI workflows; nothing
else exists.

**Method:** read every file under `README.md`, `docs/`, and
`docs/audits/` in full; cross-check claims against `project.godot`,
`game/scripts/core/boot.gd`, `game/scenes/bootstrap/boot.gd`,
`game/scenes/world/game_world.gd`, the `[autoload]` roster, the new
autoload sources under `game/autoload/` and `game/scripts/systems/`,
the JSON content tree under `game/content/`, the resource definitions
under `game/resources/`, `game/scripts/core/save_manager.gd`,
`tests/run_tests.sh`, `.gutconfig.json`, `scripts/*.sh`, `.editorconfig`,
and the two CI workflows under `.github/workflows/`. No source code
edits.

---

## Doc-set boundary (re-confirmed)

- **Root:** `README.md` only as an active project doc. Customer-voice /
  vision files at root: `BRAINDUMP.md`, `LICENSE` — left untouched per
  pass rules.
- **Active project docs:** `docs/` (`index.md`, `setup.md`,
  `architecture.md`, `architecture/ownership.md`, `design.md`,
  `style/visual-grammar.md`, `content-data.md`, `testing.md`,
  `configuration-deployment.md`, `contributing.md`, `roadmap.md`).
- **Audit notes:** `docs/audits/` (`cleanup-report.md`,
  `error-handling-report.md`, `security-report.md`, `ssot-report.md`,
  dated `YYYY-MM-DD-audit.md` files for `2026-05-02`, `2026-05-03`,
  `2026-05-04`, `2026-05-05`, this `docs-consolidation.md`).

No stray markdown outside the boundary in the active doc set; markdown
under `.github/`, `.aidlc/`, `addons/`, `tools/`, and `planning/` is
configuration / templates / vendored material / tooling support and is
correctly excluded.

---

## Edits applied this pass

### `docs/architecture.md` — extend autoload roster from 31 to 41 entries

| Path | Change | Why |
|---|---|---|
| `docs/architecture.md` § "Autoloads" header prose | Updated "Three entries are scenes (`ObjectiveRail`, `InteractionPrompt`, `FailCard`)" → "Five entries are scenes (`ObjectiveRail`, `InteractionPrompt`, `MorningNotePanel`, `MiddayEventCard`, `FailCard`)". | `project.godot` `[autoload]` now contains 41 entries (lines 26–66), of which five are `.tscn` scenes. The old prose was correct at the prior pass (2026-05-04) but ten autoloads have since been added and two of those are scenes. |
| `docs/architecture.md` § "Autoloads" table | Added rows 29–41 covering `EmploymentSystem`, `PlatformSystem`, `StoreCustomizationSystem`, `ShiftSystem`, `ManagerRelationshipManager`, `MorningNotePanel`, `MiddayEventSystem`, `MiddayEventCard`, `HiddenThreadSystemSingleton`, `ReturnsSystem`. Renumbered the previously-final three rows (`FailCard`, `TutorialContextSystem`, `Day1ReadinessAudit`) to 37–39 to preserve `project.godot` load order. | These ten autoloads are declared in `project.godot:54-66` but were absent from the architecture table; the doc was bit-exact through entry 31 and then stopped. Each new row pulls a one-sentence responsibility from the leading docstring of its source file (or, for the two scene autoloads, from the script behind the scene): `game/autoload/employment_system.gd`, `game/scripts/systems/platform_system.gd`, `game/scripts/systems/store_customization_system.gd`, `game/scripts/systems/shift_system.gd`, `game/autoload/manager_relationship_manager.gd`, `game/scripts/ui/morning_note_panel.gd`, `game/scripts/systems/midday_event_system.gd`, `game/scripts/ui/midday_event_card.gd`, `game/autoload/hidden_thread_system.gd`, `game/autoload/returns_system.gd`. |

### `docs/content-data.md` — add `manager/` subdirectory and `platforms.json` root file

| Path | Change | Why |
|---|---|---|
| `docs/content-data.md` § "Current content layout" table | Added `game/content/manager/` row pointing at `manager_notes.json` and citing `ManagerRelationshipManager` as the consumer. | `game/content/manager/manager_notes.json` exists and is the data source the new `ManagerRelationshipManager` autoload reads on `day_started`. The subdirectory was added after the prior consolidation pass and the table did not list it. |
| `docs/content-data.md` § "Current content layout" root-file list | Added `platforms.json` (consumed by `PlatformSystem`). | `game/content/platforms.json` exists at the content root and is the data source for the new `PlatformSystem` autoload. Was absent from the bullet list. |

### `docs/configuration-deployment.md` — add `validate_originality.sh` to checked-in helper scripts

| Path | Change | Why |
|---|---|---|
| `docs/configuration-deployment.md` § "Checked-in integrations" helper-scripts bullet | Appended `validate_originality.sh` (with a one-line description: string-level trademark denylist over `game/content/`, `game/scenes/`, and `game/scripts/stores/`). | `scripts/validate_originality.sh` exists and the doc enumerated the other six scripts under `scripts/` but omitted this one. Description was sourced from the script's own header comment. |

---

## Statements removed as unverifiable

None this pass. Every statement that was wrong was wrong by *omission*
(missing autoloads, missing content paths, missing helper script);
no asserted statement contradicted the code.

---

## Verification notes (no edits required)

Each claim below was checked against current code, config, content, or
CI; no edit needed. Recorded so a future reviewer can re-run the matrix
without re-deriving it.

### `README.md`

- Entry scene `res://game/scenes/bootstrap/boot.tscn` →
  `project.godot:20`, scene file present.
- Boot loads content, validates the registry, loads `user://settings.cfg`,
  initializes audio, then opens the main menu →
  `game/scripts/core/boot.gd:18-66` runs `DataLoaderSingleton.load_all`,
  arc-unlocks/objectives schema validation, `ContentRegistry.is_ready`,
  the ≥5-store-id assertion, `Settings.load`, `AudioManager.initialize`,
  `GameManager.mark_boot_completed`, `EventBus.boot_completed.emit`,
  then `transition_to(State.MAIN_MENU)`.
- Test runner behavior, GUT discovery, `tests/test_run.log`,
  `tests/validate_*.sh` shell validators, and the three SSOT tripwires
  under `scripts/` → all matched in `tests/run_tests.sh`.
- Three export presets at the listed paths → matched in
  `export_presets.cfg` (`Windows Desktop`, `macOS`, `Linux/X11`).
- Tagged `v*` releases publish Windows/macOS/Linux → matched in
  `.github/workflows/export.yml`.
- Godot version: `project.godot:config/features=PackedStringArray("4.6", ...)`,
  `validate.yml:GODOT_VERSION="4.6.2-stable"`, `export.yml` passes
  `4.6.2` to `chickensoft-games/setup-godot@v2` (resolves to the
  `4.6.2-stable` release upstream). README's "4.6.2-stable" wording is
  truthful for both workflows in practical effect.

### `docs/index.md`

- Every doc it links exists in `docs/`, including the audit-report
  filenames it indexes.
- Boundary section ("README.md is the only active project doc at the
  repository root") matches actual repo layout.
- The dated-audit reference is generic ("dated `YYYY-MM-DD-audit.md`
  files"), so no edit is required when a new dated file (`2026-05-05`)
  appears.

### `docs/setup.md`

- Repository layout block reflects current top-level dirs.
- Godot resolution order in `scripts/godot_import.sh`,
  `scripts/godot_exec.sh`, and `tests/run_tests.sh:_resolve_godot_bin`
  matches the documented `GODOT` → `GODOT_EXECUTABLE` → `godot` →
  `/Applications/Godot.app/...` → `$HOME/Applications/Godot.app/...`
  precedence.
- Step 7 SSOT tripwires under `scripts/` — verified all three scripts
  present and executable.

### `docs/architecture.md` (post-edit)

- Boot Flow steps 1–7 — matched against `game/scripts/core/boot.gd`.
- Init tiers 1–5 — each `initialize_tier_N_*` body in
  `game/scenes/world/game_world.gd` was diff-walked; every system named
  in the table is initialized in the corresponding tier function in the
  documented order. `DayManager` is instantiated and added as a child in
  Tier 5 (`_day_manager = DayManager.new(); add_child(_day_manager)`).
- Autoload roster (post-edit: 41 entries, 5 scenes) — bit-exact against
  the `[autoload]` section of `project.godot:26-66`. Order, `*` prefix,
  and scene-vs-script categorization all match.
- `AudioEventHandler` is instantiated as a child node, not a registered
  autoload — matched against `audio_manager.gd:_setup_event_handler`
  (`add_child(_event_handler)`); also confirmed there is no
  `AudioEventHandler` entry in `[autoload]`.
- Signal-bus signal-prefix table — verified against signal declarations
  in `game/autoload/event_bus.gd`. `run_state_changed()` parameterless;
  `panel_opened`/`panel_closed` exist; UI 3D and 2D hover events flow
  through the `interactable_*` prefix.
- Scene Entry Points table — every `.tscn` referenced is present in
  `game/scenes/`. Store entry through `EventBus.enter_store_requested`
  → `game_world._on_hub_enter_store_requested` →
  `StoreDirector.enter_store` → `SceneRouter.route_to_path` matches the
  current control flow.
- Visual Systems table — every script and scene file listed exists.

### `docs/architecture/ownership.md`

- `SceneRouter` `_in_flight` flag, `tree_changed` + `process_frame`
  await sequence, `scene_ready` / `scene_failed` signals, and
  `AuditLog.pass_check(&"scene_change_ok", …)` / `fail_check` outputs —
  all matched in `game/autoload/scene_router.gd`.
- `StoreDirector` state machine `IDLE → REQUESTED → LOADING_SCENE →
  INSTANTIATING → VERIFYING → READY/FAILED` and `director_state_*`
  audit checkpoints — matched in `game/autoload/store_director.gd`.
- Per-store controllers named in row 2 — every file exists:
  `electronics_store_controller.gd`, `video_rental_store_controller.gd`,
  `pocket_creatures_store_controller.gd`,
  `sports_memorabilia_controller.gd`, `retro_games.gd`.
- `InputFocus` constants `CTX_MAIN_MENU`, `CTX_MALL_HUB`,
  `CTX_STORE_GAMEPLAY`, `CTX_MODAL` — matched in
  `game/autoload/input_focus.gd`.
- Cross-reference link to `../architecture.md` §"Autoloads" still
  resolves correctly.

### `docs/design.md`

- Card-based hub vs first-person store interior split — matched.
  `debug/walkable_mall=false` confirmed in `project.godot:[debug]`.
- Five-store roster table — display names and canonical IDs match
  `game/content/stores/store_definitions.json` exactly.
- `toggle_debug_camera` keybind = F1 — matched against
  `project.godot:[input]:toggle_debug_camera` (physical_keycode 4194332
  = `KEY_F1`).

### `docs/content-data.md` (post-edit)

- Loader pipeline (`_discover_json_files` → `_TYPE_ROUTES` lookup →
  `ContentParser.parse_*` → `ContentRegistry.register*` →
  `validate_all_references`) — matched against
  `game/autoload/data_loader.gd` and `game/autoload/content_registry.gd`.
- `MAX_JSON_FILE_BYTES = 1048576` (1 MiB) — matched in
  `data_loader.gd:7`.
- Content tree subdirectories listed all exist; `localization/` is
  empty as documented; root-level config JSON files all present
  (post-edit, including `manager/` and `platforms.json`).
- `_TYPE_ROUTES` buckets (15 `entries:<kind>`, 9 singleton/specialized,
  `ignore`) — matched against the dict literal at
  `data_loader.gd:19-53`.
- Canonical-ID regex `^[a-z][a-z0-9_]{0,63}$` and the `resolve()`
  normalization steps — verified in `content_registry.gd`.
- Scene-path constraints (`res://game/scenes/`, `.tscn`, store scenes
  under `res://game/scenes/stores/`) — matched against the registration
  guards in `content_registry.gd`.
- `validate_all_references()` checks — duplicate-id / alias-conflict,
  item `store_type`, store `starting_inventory`, scene
  `ResourceLoader.exists`, market/seasonal `target_store_types` and
  `affected_stores`, supplier and milestone refs — every assertion
  matched against the corresponding helper in `content_registry.gd`.
- Typed-resource table — every `class_name` listed exists under
  `game/resources/`.
- `DataLoaderSingleton` getters — every method listed in the
  "Runtime access" section exists in `data_loader.gd`.

### `docs/testing.md`

- `.gutconfig.json` — `dirs`, `prefix`, `suffix`, `should_exit`,
  `should_exit_on_success`, `pre_run_script` all match.
- `tests/run_tests.sh` step ordering matches the doc.
- CI jobs in `validate.yml`: `lint-docs`, `gut-tests`,
  `interaction-audit`, `content-originality`, `lint-gdscript` — all
  five jobs present, behavior matches the bullets.
- `interaction-audit` job uploads `docs/audits/` artifact, regenerated
  by `tests/audit_run.sh` (writes `docs/audits/${DATE_STAMP}-audit.md`;
  the new `2026-05-05-audit.md` was generated by exactly this path).
- Test layout block — `tests/gut/`, `tests/unit/`,
  `tests/integration/`, `game/tests/`, `tests/validate_*.sh` all
  present.

### `docs/configuration-deployment.md` (post-edit)

- Project config bullets all match `project.godot:17-22`.
- Input-action groups cited — every action listed is present in
  `[input]`.
- `debug/walkable_mall=false` default — matched in `[debug]`.
- `SaveManager` constants (`MAX_MANUAL_SLOTS = 3`,
  `MAX_SAVE_FILE_BYTES = 10485760`) and the `.tmp` →
  `DirAccess.rename_absolute` atomic-write pattern — all matched in
  `game/scripts/core/save_manager.gd`.
- Export-preset table (paths, x86_64, universal macOS, Linux x86_64,
  10.15 minimum, codesign disabled, embedded PCK, exclude filter
  contents) — matched against `export_presets.cfg`.
- `validate.yml` and `export.yml` job rosters — matched.

### `docs/contributing.md`

- `.editorconfig` formatting rules (tabs default, two spaces for MD /
  YAML / JSON, LF, UTF-8, final newlines) — matched against the
  checked-in `.editorconfig`.
- Naming conventions — match observed conventions in `game/`.

### `docs/roadmap.md`

- Phase 0.1 SSOT tripwire script names — all three checked-in under
  `scripts/`. The "Complete" callout is consistent with the tripwires
  being invoked by `tests/run_tests.sh`.
- Five-store roster claim matches `store_definitions.json`.
- "No real brands" rule is enforced by
  `.github/workflows/validate.yml:content-originality` and the local
  mirror `scripts/validate_originality.sh`.

### `docs/style/visual-grammar.md`

- `UIThemeConstants` constants — every named constant exists at
  `game/scripts/ui/ui_theme_constants.gd`.
- `STORE_ACCENTS` lookup keyed by store id exists with the documented
  per-store keys.
- Theme `.tres` files exist: `game/themes/mallcore_theme.tres`,
  `palette.tres`, and the `store_accent_*.tres` set.
- `tests/gut/test_palette_contrast.gd` exists.
- CRT shader `game/resources/shaders/crt_overlay.gdshader` exists.

### `docs/audits/` historical reports

- The four catalog files (`cleanup-report.md`,
  `error-handling-report.md`, `security-report.md`, `ssot-report.md`)
  are explicitly framed as point-in-time records by `index.md`. Their
  most recent pass headers date to `2026-05-04` and reflect state at
  pass-time.
- The dated `YYYY-MM-DD-audit.md` files (2026-05-02, 2026-05-03,
  2026-05-04, 2026-05-05) are the regenerated interaction-audit tables
  produced by `tests/audit_run.sh`. Each contains a generated-at
  timestamp matching its filename date.
- Per the doc-set boundary contract these are records of past audits,
  not currently-live claims, and are not edited by a docs-consolidation
  pass beyond detecting structural breaks. None were detected.

---

## Intentional gaps with rationale

- **No edits to `docs/audits/cleanup-report.md`,
  `error-handling-report.md`, `security-report.md`, `ssot-report.md`,
  or the dated `YYYY-MM-DD-audit.md` files.** These are point-in-time
  historical records (per the contract spelled out in
  `docs/index.md` §"Audit notes"). Touching them would falsify the
  snapshot they document.
- **No edits to `BRAINDUMP.md`.** Customer-voice file at root, called
  out as untouched in pass rules and in `docs/index.md` §"Boundary".
- **No edits to `docs/index.md`, `docs/setup.md`,
  `docs/architecture/ownership.md`, `docs/design.md`,
  `docs/testing.md`, `docs/contributing.md`, `docs/roadmap.md`,
  `docs/style/visual-grammar.md`, or `README.md`.** Every claim in
  these files was verified against current code, config, content,
  scenes, or CI workflows during this pass and found truthful. The
  verification matrix above lists every check performed.
- **`log_level: 1` in `.gutconfig.json` is not mentioned in
  `docs/testing.md`.** Intentional: the doc reads "uses ...", not
  "exhaustively lists ...". Adding it adds noise without changing
  behavior; the claim as written is true.
- **`.github/ISSUE_TEMPLATE/*.md` and
  `.github/pull_request_template.md`** are GitHub UI-templating
  config, not project documentation, and are correctly outside the
  `docs/` boundary as noted in `docs/index.md` §"Boundary".
- **No autoload responsibilities promoted to `docs/architecture/ownership.md`
  for the ten new entries.** The Ownership Matrix is scoped to the ten
  responsibilities that *enforce single-owner writes across multiple
  callers*; the new autoloads (employment, platforms, store
  customization, shifts, manager relationship, midday events, hidden
  thread, returns) own their internal state but are not yet contended
  by other systems on the write side. They are documented in the
  architecture autoload table; no Ownership-Matrix entry is required
  until a second writer appears.

---

## Escalations

None. All in-scope findings were either acted on (the three edits
listed above) or carry a concrete justification above. No
architectural decisions are pending.
