# Docs Consolidation — 2026-05-04

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
  dated `YYYY-MM-DD-audit.md` files for `2026-05-02`, `2026-05-03`, and
  `2026-05-04`, this `docs-consolidation.md`).

No stray markdown outside the boundary in the active doc set; markdown
under `.github/`, `.aidlc/`, `addons/`, `tools/`, and `planning/` is
configuration / templates / vendored material / tooling support and is
correctly excluded.

---

## Edits applied this pass

### `docs/content-data.md` — drop unverifiable `ISSUE-021` citation

| Path | Line | Change |
|---|---|---|
| `docs/content-data.md` | "Type detection" section (around line 72) | Removed the leading `Per ISSUE-021, ` citation. |

**Why:** `ISSUE-021` does not exist in the repository — the
`.aidlc/issues/` directory contains `ISSUE-001.md`..`ISSUE-019.md` plus
`VFIX-001.md`, with no `ISSUE-020`/`ISSUE-021`/etc. The cited issue
file is the source of truth for that ID space, so the citation is
unverifiable and the rule pointer dead-ends. The *behavior* the
sentence describes — every content JSON must declare a root `"type"`
field, no heuristic detection — is real and verified against
`game/autoload/data_loader.gd:_TYPE_ROUTES` and the route-resolution
logic in `_route_for_type` / `_process_file`. Only the dead citation
was removed; the rule and the rest of the section are intact.

---

## Statements removed as unverifiable

- `docs/content-data.md` — "Per ISSUE-021, ..." opener of the **Type
  detection** section. The cited issue file does not exist; the rule it
  introduced is preserved without the citation.

No other unverifiable statements were found in the active doc set.

---

## Verification notes (no edits required)

Each claim below was checked against current code, config, content, or
CI; no edit needed. Recorded here so a future reviewer can re-run the
matrix without re-deriving it.

### `README.md`

- Entry scene `res://game/scenes/bootstrap/boot.tscn` →
  `project.godot:run/main_scene`, matched in
  `game/scenes/bootstrap/boot.tscn`.
- Boot loads content, validates the registry, loads
  `user://settings.cfg`, initializes audio, opens the main menu →
  `game/scripts/core/boot.gd:initialize` runs
  `DataLoaderSingleton.load_all`, `arc_unlocks.json` and
  `objectives.json` schema validation, `ContentRegistry.is_ready`,
  `Settings.load`, `AudioManager.initialize`,
  `GameManager.mark_boot_completed`, `EventBus.boot_completed.emit`,
  then `transition_to(State.MAIN_MENU)`.
- Test runner behavior, GUT discovery, `tests/test_run.log`,
  `tests/validate_*.sh` shell validators, and the three SSOT
  tripwires under `scripts/` → all matched in `tests/run_tests.sh`.
- Three export presets at the listed paths → matched in
  `export_presets.cfg` (`Windows Desktop`, `macOS`, `Linux/X11`).
- Tagged `v*` releases publish Windows/macOS/Linux → matched in
  `.github/workflows/export.yml` (`release` job, `softprops/action-gh-release`).
- Godot version: `project.godot:config/features=PackedStringArray("4.6", ...)`,
  `validate.yml:GODOT_VERSION="4.6.2-stable"`, `export.yml:GODOT_VERSION="4.6.2"`
  (passed to `chickensoft-games/setup-godot@v2`, which resolves to the
  same 4.6.2 stable release). README's "4.6.2-stable" wording is
  truthful for both workflows in practical effect.

### `docs/index.md`

- Every doc it links exists in `docs/`, including the audit-report
  filenames it indexes.
- Boundary section ("README.md is the only active project doc at the
  repository root") matches actual repo layout.

### `docs/setup.md`

- Repository layout block reflects current top-level dirs
  (`addons/gut/`, `game/autoload/`, `game/content/`, `game/resources/`,
  `game/scenes/`, `game/scripts/`, `tests/`, `game/tests/`, `docs/`,
  `tools/`).
- Godot resolution order in `scripts/godot_import.sh`,
  `scripts/godot_exec.sh`, and `tests/run_tests.sh:_resolve_godot_bin`
  matches the documented `GODOT` → `GODOT_EXECUTABLE` → `godot` →
  `/Applications/Godot.app/...` → `$HOME/Applications/Godot.app/...`
  precedence.
- "Step 7: SSOT tripwires under `scripts/`" — verified all three
  scripts present and executable.

### `docs/architecture.md`

- Boot Flow steps 1–7 — all matched against `game/scripts/core/boot.gd`.
- Init tiers 1–5 — each `initialize_tier_N_*` body in
  `game/scenes/world/game_world.gd` was diff-walked; every system named
  in the table is initialized in the corresponding tier function in the
  documented order. `DayManager` is instantiated and added as a child
  in Tier 5 (`_day_manager = DayManager.new(); add_child(_day_manager);
  _day_manager.initialize(...)`).
- Autoload roster (31 entries, 3 scenes) — bit-exact against the
  `[autoload]` section of `project.godot`. Order, `*` prefix, and
  scene-vs-script categorization all match.
- `AudioEventHandler` is instantiated as a child node, not a registered
  autoload — matched against `audio_manager.gd:_setup_event_handler`
  (`add_child(_event_handler)`).
- Signal-bus signal-prefix table — verified against the signal
  declarations in `game/autoload/event_bus.gd`. `run_state_changed()`
  is parameterless; `panel_opened`/`panel_closed` exist; UI 3D and 2D
  hover events flow through the `interactable_*` prefix.
- Scene Entry Points table — every `.tscn` referenced is present in
  `game/scenes/`. Store entry through `EventBus.enter_store_requested`
  → `game_world._on_hub_enter_store_requested` →
  `StoreDirector.enter_store` → `SceneRouter.route_to_path` matches the
  current control flow.
- Visual Systems table — every script and scene file listed exists.
  `class_name` declarations verified for `StorePlayerBody`,
  `PlayerController`, `BuildModeCamera`, `DayPhaseLighting`,
  `Interactable`, `ShelfSlot`, `TooltipTrigger`, `UILayers`,
  `PanelAnimator`. `PanelAnimator.modal_open` / `slide_open` /
  `stagger_fade_in` static methods all present.

### `docs/architecture/ownership.md`

- `SceneRouter` `_in_flight` flag, `tree_changed` + `process_frame`
  await sequence, `scene_ready(target, payload)` /
  `scene_failed(target, reason)` signals, and the
  `AuditLog.pass_check(&"scene_change_ok", …)` / `fail_check` outputs —
  all matched in `game/autoload/scene_router.gd`.
- `StoreDirector` state machine `IDLE → REQUESTED → LOADING_SCENE →
  INSTANTIATING → VERIFYING → READY/FAILED` and `director_state_*`
  audit checkpoints — matched in `game/autoload/store_director.gd:State`
  and `_STATE_CHECKPOINTS`.
- Per-store controllers named in row 2 — every file path exists:
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
  `debug/walkable_mall=false` confirmed in `project.godot:[debug]`
  section.
- Five-store roster table — display names match
  `game/content/stores/store_definitions.json` `name` fields exactly:
  "Sports Memorabilia", "Retro Game Store", "Video Rental",
  "PocketCreatures Card Shop", "Consumer Electronics".
- Canonical IDs (`sports`, `retro_games`, `rentals`, `pocket_creatures`,
  `electronics`) match the `id` fields of those entries.
- `toggle_debug_camera` keybind = F1 — matched against
  `project.godot:[input]:toggle_debug_camera` (`physical_keycode`
  4194332 = `KEY_F1`).

### `docs/content-data.md`

- Loader pipeline (`_discover_json_files` → `_TYPE_ROUTES` lookup →
  `ContentParser.parse_*` → `ContentRegistry.register*` →
  `validate_all_references`) — matched against
  `game/autoload/data_loader.gd` and `game/autoload/content_registry.gd`.
- `MAX_JSON_FILE_BYTES = 1048576` (1 MiB) — matched in
  `data_loader.gd:7`.
- Content tree subdirectories listed all exist; `localization/` is
  empty as documented; `audio_registry.json`, `day_beats.json`,
  `fixtures.json`, `haggle_dialogue.json`, `market_trends_catalog.json`,
  `meta_shifts.json`, `objectives.json`, `pocket_creatures_cards.json`,
  `tutorial_contexts.json`, `upgrades.json` — all present at content
  root.
- `_TYPE_ROUTES` buckets (`entries:<kind>`, singleton/specialized,
  `ignore`) — matched against the `_TYPE_ROUTES` dict literal.
- Canonical-ID regex `^[a-z][a-z0-9_]{0,63}$` and the `resolve()`
  normalization steps — verified in
  `content_registry.gd` (`_RAW_ID_PATTERN` / `resolve`).
- Scene-path constraints (`res://game/scenes/`, `.tscn`, store scenes
  under `res://game/scenes/stores/`) — matched against the registration
  guards in `content_registry.gd`.
- `validate_all_references()` checks — duplicate-id /
  alias-conflict, item `store_type`, store `starting_inventory`, scene
  `ResourceLoader.exists`, market/seasonal `target_store_types` and
  `affected_stores`, supplier and milestone refs — every assertion
  matched against the corresponding helper in `content_registry.gd`.
- Typed-resource table — every `class_name` listed exists under
  `game/resources/` (`ItemDefinition`, `StoreDefinition`,
  `CustomerTypeDefinition`, `EconomyConfig`, `FixtureDefinition`,
  `MarketEventDefinition`, `SeasonalEventDefinition`,
  `RandomEventDefinition`, `MilestoneDefinition`, `StaffDefinition`,
  `SupplierDefinition`, `UnlockDefinition`, `UpgradeDefinition`,
  `SportsSeasonDefinition`, `TournamentEventDefinition`,
  `AmbientMomentDefinition`, `PerformanceReport`).
- Pocket-creatures pack-config note — matched against
  `data_loader.gd:_pocket_creatures_packs` (Array, populated under
  `pocket_creatures_packs_config` route, exposed via
  `get_pocket_creatures_packs()`).
- `DataLoaderSingleton` getters — every method listed in the
  "Runtime access" section exists in `data_loader.gd`.

### `docs/testing.md`

- `.gutconfig.json` — `dirs`, `prefix`, `suffix`, `should_exit`,
  `should_exit_on_success`, `pre_run_script` all match. `log_level: 1`
  is the only key not mentioned, which is fine — the doc says "uses",
  not "exhaustively lists".
- `tests/run_tests.sh` step ordering matches the doc.
- CI jobs in `validate.yml`: `lint-docs`, `gut-tests`,
  `interaction-audit`, `content-originality`, `lint-gdscript` — all
  five jobs present, behavior matches the bullets.
- `interaction-audit` job uploads `docs/audits/` artifact, regenerated
  by `tests/audit_run.sh` (writes
  `docs/audits/${DATE_STAMP}-audit.md`).
- Test layout block — `tests/gut/`, `tests/unit/`, `tests/integration/`,
  `game/tests/`, `tests/validate_*.sh` all present.

### `docs/configuration-deployment.md`

- Project config bullets all match `project.godot`.
- Input-action groups cited — every action listed
  (`move_forward/back/left/right`, `sprint`, `interact`,
  `toggle_debug`, `toggle_debug_camera`, `toggle_inventory`,
  `toggle_orders`, `toggle_staff`, `toggle_pricing`,
  `toggle_build_mode`, `rotate_fixture`, `time_speed_1/2/4`,
  `time_toggle_pause`, `close_day`, `pause_menu`, `toggle_overview`,
  `nav_zone_1`..`nav_zone_5`) is present in `[input]`.
- `debug/walkable_mall=false` default — matched in `[debug]`.
- `SaveManager` constants (`MAX_MANUAL_SLOTS = 3`,
  `MAX_SAVE_FILE_BYTES = 10485760`) and the `.tmp` →
  `DirAccess.rename_absolute` atomic-write pattern — all matched in
  `game/scripts/core/save_manager.gd`.
- Export-preset table (paths, x86_64, universal macOS, Linux x86_64,
  10.15 minimum, codesign disabled, embedded PCK, exclude filter
  contents) — matched against `export_presets.cfg`.
- `validate.yml` and `export.yml` job rosters — matched.
- "Both `validate.yml` and `export.yml` install Godot `4.6.2-stable`":
  validate.yml uses `GODOT_VERSION="4.6.2-stable"` directly;
  export.yml uses `chickensoft-games/setup-godot@v2` with version
  `4.6.2`, which the action resolves to the `4.6.2-stable` release on
  upstream. Net effect identical, so the doc's wording is truthful.

### `docs/contributing.md`

- `.editorconfig` formatting rules (tabs default, two spaces for MD /
  YAML / JSON, LF, UTF-8, final newlines) — matched against the
  checked-in `.editorconfig`.
- Naming conventions — match observed conventions in `game/`.

### `docs/roadmap.md`

- Phase 0.1 SSOT tripwire script names — all three checked-in under
  `scripts/`. The "Complete" callout for Phase 0.1 is consistent with
  the tripwires being invoked by `tests/run_tests.sh`.
- Five-store roster claim matches `store_definitions.json`.
- Cross-cutting "no real brands" rule is enforced by
  `.github/workflows/validate.yml:content-originality` (banned-term
  list) and `game/scripts/core/trademark_validator.gd`.

### `docs/style/visual-grammar.md`

- `UIThemeConstants` constants — every named constant exists at the
  documented file (`game/scripts/ui/ui_theme_constants.gd`) with the
  documented `Color()` value (spot-checked five accent colors and the
  four font-size constants).
- `STORE_ACCENTS` / `STORE_ACCENTS_INACTIVE` lookup dictionaries
  exist with the documented per-store keys.
- Theme `.tres` files exist: `game/themes/mallcore_theme.tres`,
  `palette.tres`, `dark_panel.tres`, `light_panel.tres`,
  `semantic.tres`, `store_accent_*.tres` for all five stores.
- `tests/gut/test_palette_contrast.gd` exists.
- CRT shader `game/resources/shaders/crt_overlay.gdshader` exists.

### `docs/audits/` historical reports

- The four catalog files (`cleanup-report.md`,
  `error-handling-report.md`, `security-report.md`, `ssot-report.md`)
  are explicitly framed as point-in-time records by `index.md`.
  Their `Latest pass` headers all date to `2026-05-04` (or the most
  recent pass referenced therein), so they reflect current state at
  pass-time. The dated `YYYY-MM-DD-audit.md` files (2026-05-02,
  2026-05-03, 2026-05-04) are the regenerated interaction-audit
  tables produced by `tests/audit_run.sh`.
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
  snapshot they document. Each report's `Latest pass` header dates to
  `2026-05-04` so they remain current as written.
- **No edits to `BRAINDUMP.md`.** Customer-voice file at root, called
  out as untouched in pass rules and in `docs/index.md` §"Boundary".
- **No edits to `docs/index.md`, `docs/setup.md`,
  `docs/architecture.md`, `docs/architecture/ownership.md`,
  `docs/design.md`, `docs/testing.md`,
  `docs/configuration-deployment.md`, `docs/contributing.md`,
  `docs/roadmap.md`, `docs/style/visual-grammar.md`, or `README.md`.**
  Every claim in these files was verified against current code,
  config, content, scenes, or CI workflows during this pass and found
  truthful. The verification matrix above lists every check performed.
- **`log_level: 1` in `.gutconfig.json` is not mentioned in
  `docs/testing.md`.** Intentional: the doc reads "uses ...", not
  "exhaustively lists ...". Adding it adds noise without changing
  behavior; the claim as written is true.
- **`.github/ISSUE_TEMPLATE/*.md` and
  `.github/pull_request_template.md`** are GitHub UI-templating
  config, not project documentation, and are correctly outside the
  `docs/` boundary as noted in `docs/index.md` §"Boundary".

---

## Escalations

None. All in-scope findings were either acted on (the single
`docs/content-data.md` ISSUE-021 citation removal) or carry a
concrete justification above. No architectural decisions are
pending.
