# Docs Consolidation — 2026-05-01 (Pass 2)

Documentation accuracy pass over `README.md` and `docs/`. Every doc touched
or examined was re-verified against the current `project.godot`, autoload
sources, content tree, `tests/run_tests.sh`, `.github/workflows/{validate,
export}.yml`, `export_presets.cfg`, and `game/content/stores/store_definitions.json`.
No code or config was edited.

This pass continues from the earlier 2026-05-01 docs consolidation; that
pass's verification table is preserved at the bottom of this file under
**§ Prior pass — verification still valid** so a reader does not need to
re-read the prior history. Findings new to this pass are at the top.

## Working tree summary

- Edited: `docs/design.md` (store roster table — store names corrected to
  match `store_definitions.json`).
- Created: this file (overwriting the prior pass's report so the audit dir
  stays single-canonical-source per `docs/index.md`).
- No deletions, moves, or renames.
- Untouched and re-verified accurate against current code/config:
  `README.md`, `docs/index.md`, `docs/setup.md`, `docs/testing.md`,
  `docs/configuration-deployment.md`, `docs/architecture.md`,
  `docs/architecture/ownership.md`, `docs/content-data.md`,
  `docs/contributing.md`, `docs/roadmap.md`,
  `docs/style/visual-grammar.md`.
- Untouched by design (customer voice / point-in-time records, per the
  rules in this prompt): `BRAINDUMP.md` (root), `LICENSE`,
  `docs/audits/2026-05-01-audit.md`, `docs/audits/cleanup-report.md`,
  `docs/audits/error-handling-report.md`,
  `docs/audits/security-report.md`, `docs/audits/ssot-report.md`.

## Findings new to this pass

### `docs/design.md` §4 "Store roster" — display names did not match content

The table listed the five stores as **Retro Game Vault**, **Pocket
Creatures**, **Video Rental Depot**, **Digital Horizons**, **Stadium
Relics**. None of those strings appear anywhere in `game/content/`,
`game/scripts/`, or `BRAINDUMP.md`. The actual `name` fields in
`game/content/stores/store_definitions.json` are:

| Display name (JSON `name`) | Canonical id |
|---|---|
| Sports Memorabilia | `sports` |
| Retro Game Store | `retro_games` |
| Video Rental | `rentals` |
| PocketCreatures Card Shop | `pocket_creatures` |
| Consumer Electronics | `electronics` |

These also match the customer-voice listing in `BRAINDUMP.md:61-65` and
`BRAINDUMP.md:603-617`.

**Action:** rewrote the table to use the JSON display names, added a
canonical-id column, and prefaced the table with a one-line note pointing
at `store_definitions.json` as the source. The signature-mechanic
descriptions were preserved because they are accurate descriptions of the
store contracts in `game/scripts/stores/<store>_controller.gd` and the
roadmap's Phase 1 work items.

This was the only verifiability defect found in this pass.

## Verification — checks performed this pass

Every claim below was re-grepped against the current source after the
working tree's changes (`M` files in `git status`) had landed, so the prior
pass's verification table is not just transitively trusted.

- **Autoload roster** (31 entries) re-matched against `project.godot`
  `[autoload]` lines 26-56 — exact match including the three scene-typed
  autoloads (`ObjectiveRail`, `InteractionPrompt`, `FailCard`). The doc's
  note that `AudioEventHandler` is instantiated by `AudioManager` as a
  child rather than registered is verified by its absence from
  `project.godot` and presence at `game/autoload/audio_event_handler.gd`.
- **`StoreDirector` 6-state machine** re-verified against
  `game/autoload/store_director.gd:34-41` (`IDLE, REQUESTED, LOADING_SCENE,
  INSTANTIATING, VERIFYING, READY, FAILED`) — matches `docs/architecture/
  ownership.md` row 2.
- **`InputFocus` constants** re-verified against
  `game/autoload/input_focus.gd:16-19` (`CTX_STORE_GAMEPLAY`, `CTX_MALL_HUB`,
  `CTX_MODAL`, `CTX_MAIN_MENU`) — matches `docs/architecture/ownership.md`
  row 5.
- **Boot flow** re-matched against `game/scripts/core/boot.gd:18-66`:
  load_all → arc_unlocks schema → objectives schema → ContentRegistry
  ready → ≥5 store IDs → Settings.load → AudioManager.initialize →
  mark_boot_completed → boot_completed emit → MAIN_MENU transition.
  Matches `docs/architecture.md` §"Boot Flow" exactly.
- **GameWorld init tiers** re-matched against
  `game/scenes/world/game_world.gd:265-444`. Tier 1 data, Tier 2 state
  (returns false on hard failure — undocumented in the table but the doc's
  prose does not claim otherwise), Tier 3 operational including
  `meta_shift_system` last, Tier 4 world (`store_selector_system`,
  build mode, `tournament_system`, `day_phase_lighting`), Tier 5 meta
  including `DayManager` instantiated and added as a child here.
  `finalize_system_wiring` lives outside the tier list and is not claimed
  in the doc.
- **EventBus signals** referenced by name in `docs/architecture.md` and
  `docs/architecture/ownership.md` re-verified by grep against
  `game/autoload/event_bus.gd` — `store_ready` (line 13), `store_failed`
  (14), `run_state_changed` (51), `enter_store_requested` (80),
  `interactable_focused` (567), `panel_opened` (596), `panel_closed`
  (597) all present.
- **Save manager constants** re-verified against
  `game/scripts/core/save_manager.gd:36-48`: `MAX_MANUAL_SLOTS = 3`,
  `AUTO_SAVE_SLOT = 0`, `MAX_SAVE_FILE_BYTES = 10485760` (10 MiB),
  `SLOT_INDEX_PATH = "user://save_index.cfg"`,
  `SAVE_DIR = "user://"`, atomic `.tmp` write at line 1247-1248. Matches
  `docs/configuration-deployment.md` §"User data and persistence". The
  additional `BACKUP_DIR = "user://backups/"` constant (line 44) is *not*
  documented; see Intentional gaps.
- **DataLoader limits** re-verified at
  `game/autoload/data_loader.gd:7,19,160,196,238`: `MAX_JSON_FILE_BYTES =
  1048576`, `_TYPE_ROUTES` dict, `_discover_json_files` walks
  `res://game/content/`. Matches `docs/content-data.md` §"Loader pipeline".
- **CI validation jobs** re-matched against `.github/workflows/validate.yml`
  jobs `lint-docs`, `gut-tests`, `interaction-audit`,
  `content-originality`, `lint-gdscript`. The `interaction-audit` job
  uploads `docs/audits/` as an artifact (line `path: docs/audits/`) and
  invokes `tests/audit_run.sh` which writes `${DATE_STAMP}-audit.md` into
  `docs/audits/`. The existing wording in `docs/index.md`,
  `docs/testing.md`, and `docs/configuration-deployment.md` is accurate.
- **Export workflow** re-matched against `.github/workflows/export.yml`:
  preset-name check, x86_64 architecture check, codesign-disabled check,
  no absolute paths, no secrets, ETC2 ASTC import flag check. Matches
  `docs/configuration-deployment.md` §"Validation workflow" and
  §"Export workflow".
- **Export presets** re-matched against `export_presets.cfg`: Windows
  x86_64 PCK embedded, codesign disabled; macOS universal min 10.15
  codesign 0; Linux/X11 path `exports/linux/MallcoreSim.x86_64`. The
  `exclude_filter` is identical across the three presets and matches
  `docs/configuration-deployment.md` §"Export presets" line 73.
- **`.gutconfig.json`** dirs (`res://tests/`, `res://tests/gut/`,
  `res://tests/unit/`, `res://game/tests/`) plus `prefix: "test_"`,
  `suffix: ".gd"`, `should_exit: true`, `should_exit_on_success: true`,
  `pre_run_script: "res://tests/gut_pre_run.gd"` all match
  `docs/testing.md`. The `log_level: 1` field is not documented but is not
  a verifiability gap — it is GUT-internal noise control.
- **Tests directory layout** in `docs/setup.md` and `docs/testing.md`
  re-matched against `ls tests/`: `gut/`, `unit/`, `integration/`,
  `validate_*.sh`, `gut_pre_run.gd`, `audit_run.sh`. The
  `game/tests/run_tests.gd` file does not currently exist — the runner
  invokes it conditionally (`if [ -f ... ]`) and the docs use "when present"
  / "when that file exists", so this is consistent rather than stale.
- **Visual systems table** in `docs/architecture.md` §"Visual Systems"
  re-verified by `ls`: every file path present
  (`game/scripts/world/build_mode_camera.gd`,
  `game/scripts/components/interactable.gd`,
  `game/scripts/ui/interactable_hover.gd`,
  `game/autoload/tooltip_manager.gd`,
  `game/scenes/ui/interaction_prompt.tscn`,
  `game/scripts/stores/shelf_slot.gd`,
  `game/scripts/world/day_phase_lighting.gd`,
  `game/resources/shaders/crt_overlay.gdshader`,
  `game/scripts/ui/panel_animator.gd`,
  `game/scripts/ui/ui_layers.gd`).
- **Visual grammar tokens** in `docs/style/visual-grammar.md` re-verified
  against `game/scripts/ui/ui_theme_constants.gd:51,84-95,98-112,122,177`
  (`DARK_PANEL_FILL`, all five `STORE_ACCENT_*` and
  `STORE_ACCENT_INACTIVE_*`, `STORE_ACCENTS` lookup, `SEMANTIC_INFO`,
  `FONT_SIZE_BODY = 18`). Accent theme resources under `game/themes/`
  (`palette.tres`, `mallcore_theme.tres`, the five `store_accent_*.tres`)
  are present.
- **Content tree** re-matched against `ls game/content/`: items, stores,
  customers, economy, events, endings, meta, progression, onboarding,
  staff, suppliers, sports_cards, unlocks subdirs all present;
  `pocket_creatures/{creatures,packs}.json` and `retro_games/grades.json`
  subtrees present; root files (`audio_registry.json`, `day_beats.json`,
  `fixtures.json`, `haggle_dialogue.json`, `market_trends_catalog.json`,
  `meta_shifts.json`, `objectives.json`, `pocket_creatures_cards.json`,
  `tutorial_contexts.json`, `upgrades.json`) present;
  `localization/` subdir present and empty (matches doc).
- **Shipping store roster** re-verified against
  `store_definitions.json:5,109,212,329,456` — ids `sports`, `retro_games`,
  `rentals`, `pocket_creatures`, `electronics`. Aliases `sports_memorabilia`,
  `video_rental`, `consumer_electronics` declared. Matches
  `docs/content-data.md` §"Stores — SSOT".

## Statements removed as unverifiable

Only the four fictional store names in `docs/design.md` — see
**Findings new to this pass** above. Those names did not appear in any
code, content, or customer-voice file in the tree.

## Intentional gaps

- **`SaveManager.BACKUP_DIR = "user://backups/"` not added to
  `docs/configuration-deployment.md`.** It is a best-effort, pre-migration
  copy site (`save_manager.gd:1075-1117`); failure to write the backup
  intentionally does not block the migration. Documenting it would
  promote a recovery-side implementation detail to a public contract,
  which is exactly the inversion the prior pass avoided for
  `AuditLog.pass_check(&"boot_scene_ready", …)` in
  `docs/architecture.md` §"Boot Flow". The user-visible save contract is
  the four shipping slots and the 10 MiB read cap; the backup dir is
  load-bearing for migrations only.
- **`STORE_ACCENTS` Dictionary keys (`video_rental`, `sports_cards`) vs
  canonical store ids (`rentals`, `sports`).**
  `docs/style/visual-grammar.md` §"Store Accent Tokens" lists
  `video_rental` and `sports_cards` as the first-column "Store" entries.
  `video_rental` is a real alias for `rentals` (declared in
  `store_definitions.json:213-215`); `sports_cards` is **not** any
  canonical id or alias for the sports store (which has alias
  `sports_memorabilia`, not `sports_cards`). The documented table matches
  the constants that exist in `ui_theme_constants.gd` verbatim, so the
  doc is faithful to the code, but the lookup `STORE_ACCENTS.get("sports",
  …)` will miss the dict and return the default accent color. This is a
  runtime defect in `ui_theme_constants.gd`, not a documentation defect,
  and is out of scope for a docs-only pass. Filing as a runtime/visual
  bug is the correct next action — see Escalations.
- **`docs/audits/2026-05-01-audit.md` left as-is.** Regenerated by
  `tests/audit_run.sh` (locally and in CI's `interaction-audit` job),
  intentionally a snapshot. This pass corrects nothing in it.
- **`docs/audits/{cleanup,error-handling,security,ssot}-report.md` left
  as-is.** Each is a point-in-time audit record. Rewriting would lose the
  historical signal; deleting would break the cross-references in
  `docs/index.md` §"Audit notes".
- **`BRAINDUMP.md` left untouched.** Customer voice — out of scope for any
  documentation pass per the project rule embedded in
  `docs/contributing.md` and `docs/index.md`.
- **`tests/run_tests.sh:73` references `docs/audits/phase0-ui-integrity.md`
  in a comment.** That file does not exist. The reference is in shell
  source, not in documentation, so it is out of scope for this pass. The
  comment names the wrong audit file but does not break the runner — the
  three SSOT tripwires it precedes are still invoked correctly. Cleaning
  up the stale comment is a code edit and belongs in a code-quality pass.
- **Roadmap kept as-is.** `docs/roadmap.md` describes finalization phases.
  "Current state" (transaction loop end-to-end, two stores with real
  signature mechanics, three with scaffolded mechanics) is consistent
  with the controllers that exist under `game/scripts/stores/` and the
  open Phase 1 work items. Future-phase prose intentionally describes
  not-yet-shipped work — that is the doc's purpose, not a verifiability
  gap.
- **No reference docs collapsed or split.** The current layout
  (`README.md` at root + nine top-level docs in `docs/` + nested
  `architecture/ownership.md`, `style/visual-grammar.md`, and `audits/`)
  matches the structure rule in this prompt: README is lean, everything
  else lives under `docs/`. Nothing to merge or move.

## Escalations

- **`STORE_ACCENTS["sports_cards"]` runtime mismatch.**
  `game/scripts/ui/ui_theme_constants.gd:103` declares the accent under
  the key `"sports_cards"`, but the store's canonical id is `sports` and
  its only declared alias is `sports_memorabilia`. The store accent for
  Sports Memorabilia therefore never resolves through
  `get_store_accent(store_id)` (`ui_theme_constants.gd:235`). The fix is
  a single-character edit (`"sports_cards"` → `"sports"`) plus the same
  rename in `STORE_ACCENTS_INACTIVE`. The smallest concrete next action
  is to file or open an existing `.aidlc/issues/ISSUE-*.md` row against
  `ui_theme_constants.gd` for the runtime team — it is out of scope for
  this docs-only pass.

---

## § Prior pass — verification still valid

The earlier 2026-05-01 docs consolidation verified the items below. They
were re-checked this pass and remain accurate; they are kept here as a
single canonical record so a reader does not need to chase prior commits.

- README run-tests prose covers GUT + `tests/validate_*.sh` + the three
  Phase 0.1 SSOT tripwires under `scripts/`.
- `docs/index.md` audit-notes pointer uses a `YYYY-MM-DD-audit.md`
  pattern (no specific date hard-coded), names `tests/audit_run.sh` as
  the writer, and clarifies the CI artifact upload.
- `docs/setup.md` "Run tests" steps include the three SSOT tripwires.
- `docs/testing.md` enumerates the seven runner steps (resolve →
  import → GUT cmdln → optional `game/tests/run_tests.gd` → log →
  `tests/validate_*.sh` → SSOT tripwires) and the no-Godot fallback
  behavior.
- `docs/configuration-deployment.md` §"Checked-in integrations" enumerates
  the actual `scripts/` helpers (`godot_import.sh`, `godot_exec.sh`,
  `validate_translations.sh`, `validate_single_store_ui.sh`,
  `validate_tutorial_single_source.sh`, `validate_export_config.sh`).
- `docs/architecture.md` boot flow, GameWorld init tiers, autoload
  roster, signal bus prefix table, and visual systems table all match
  source.
- `docs/architecture/ownership.md` rows 1-10 match the autoload roster,
  the StoreDirector state machine, the InputFocus context constants, and
  the per-store controller list.
- `docs/content-data.md` matches `data_loader.gd`, the content tree, and
  the typed-resource set.
- `docs/style/visual-grammar.md` matches `ui_theme_constants.gd` and the
  theme resources under `game/themes/` (modulo the `STORE_ACCENTS` key
  mismatch escalated above).
- `docs/contributing.md` formatting, naming, and content rules match
  `.editorconfig`, `project.godot`, and `game/content/` layout.
- `docs/roadmap.md` Phase 0.1 marked complete reflects the three SSOT
  tripwire scripts that are checked in and wired into
  `tests/run_tests.sh`.
