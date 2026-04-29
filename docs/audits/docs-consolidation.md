---
date: 2026-04-28
pass: docs-consolidation
scope: README.md and all markdown under docs/, plus tools/interaction_audit.md
---

# Docs Consolidation — 2026-04-28 (follow-up pass)

Second accuracy pass on 2026-04-28, after the working-tree changes that
deleted the root `AIDLC_FUTURES.md` and `CLAUDE.md` files. Every claim in
the active docs set was re-verified against `project.godot`, the autoload
sources under `game/autoload/`, the boot script (`game/scripts/core/boot.gd`),
the GameWorld init tiers (`game/scenes/world/game_world.gd`), the CI
workflows under `.github/workflows/`, the GUT config, and the JSON content
under `game/content/`.

The earlier pass note (also dated 2026-04-28, written before the root-doc
deletions) is superseded by this entry.

---

## Files added

None.

## Files deleted

### `tools/interaction_audit.md`

A 2026-04-21 Phase 0 audit table that:

- Sat outside the active docs boundary (`docs/index.md` defines `docs/`
  and `README.md` as the active set; `tools/` is tooling support).
- Cited `docs/research/vertical-slice-store-selection.md` as a supporting
  document. That file does not exist (commit `2ec01ab` removed the
  entire `docs/research/` tree on a previous cleanup).
- Documented a stale signal chain (`StoreSelectorSystem.enter_store()`
  via `mall_hub.gd:38`). The current entry point is `StoreDirector.enter_store`
  (`game/autoload/store_director.gd`); the architecture and ownership
  docs already record this.
- Closed with a single concrete recommendation: change
  `DEFAULT_STARTING_STORE` from `&"sports"` to `&"retro_games"`. That
  change is already in the code at `game/autoload/game_manager.gd:11`
  (`const DEFAULT_STARTING_STORE: StringName = &"retro_games"`). The
  audit's only forward-looking statement has been acted on.

The file's pass/fail step-by-step was a snapshot — the corresponding
checkpoint set is now produced live by `AuditOverlay` on every CI run and
written to `docs/audits/2026-04-29-audit.md` (and the matching
`tests/audit_run.sh` job). Keeping a frozen markdown copy of the same
table alongside the daily-regenerated one was pure duplication.

## Files consolidated

None — no overlap between active docs warranted a merge this pass.

---

## Files changed in place

### `docs/index.md`

**Stale "latest interaction audit" date.** The "Audit notes" bullet listed
`2026-04-28-audit.md` as the latest interaction audit; `docs/audits/`
already contains `2026-04-29-audit.md` (timestamp inside the file:
`2026-04-29T01:37:41Z`). Updated the bullet to point at the
2026-04-29 file.

---

## Files reviewed and accepted without change

Re-verified against current source. All claims hold.

| File | Verification scope (this pass) |
| --- | --- |
| `README.md` | Entry scene `res://game/scenes/bootstrap/boot.tscn` (`project.godot:20`); test command and the listed runner steps against `tests/run_tests.sh`; export preset paths against `export_presets.cfg`; Godot `4.6.2-stable` install in both `validate.yml` and `export.yml`; pointer set under `Documentation`. |
| `docs/architecture.md` | Boot sequence steps 1–7 against `game/scripts/core/boot.gd:18-66`. GameWorld init tiers 1–5 (`initialize_tier_1_data` through `initialize_tier_5_meta`) at `game_world.gd:265, 276, 304, 371, 395`. Autoload table rows 1–31 against `project.godot:24-56` (31 entries, ending with `Day1ReadinessAudit`). `GameManager.State` enum (MAIN_MENU, GAMEPLAY, PAUSED, GAME_OVER, LOADING, DAY_SUMMARY, BUILD, MALL_OVERVIEW, STORE_VIEW) at `game_manager.gd:5-9`. `AudioEventHandler` instantiated as a child of `AudioManager` at `audio_manager.gd:47`, not registered as autoload. Visual systems table — every named class/resource exists at the cited path. |
| `docs/architecture/ownership.md` | `SceneRouter` `_in_flight` flag, `tree_changed` + `process_frame` await, and `scene_ready(target, payload)` / `scene_failed(target, reason)` emission at `game/autoload/scene_router.gd`. `StoreDirector` state machine `IDLE → REQUESTED → LOADING_SCENE → INSTANTIATING → VERIFYING → READY/FAILED` and `set_scene_injector` seam at `store_director.gd:34-52, 156`. `InputFocus` constants (`CTX_MAIN_MENU`, `CTX_MALL_HUB`, `CTX_STORE_GAMEPLAY`, `CTX_MODAL`) at `input_focus.gd:16-19`. `StoreRegistry.resolve(id)` fail-loud at `store_registry.gd:44-50`. `AuditLog.pass_check` / `fail_check` signatures at `audit_log.gd:21, 39`. EventBus mirror signals (`store_ready`, `store_failed`, `scene_ready` single-arg, `run_state_changed`, `input_focus_changed`, `camera_authority_changed`) at `event_bus.gd:13-22`. |
| `docs/design.md` | Five-store roster, signature mechanics, non-negotiables, out-of-scope list, visual anti-patterns table. |
| `docs/content-data.md` | `_discover_json_files()` at `data_loader.gd:196`. `MAX_JSON_FILE_BYTES = 1048576` at `data_loader.gd:7`. ID regex `^[a-z][a-z0-9_]{0,63}$` at `content_registry.gd:4`. `ContentRegistry.resolve` normalization at `content_registry.gd:33-52`. Scene-path constraints (`res://game/scenes/`, store scenes under `.../stores/`) at `content_registry.gd:5-6`. `validate_all_references()` at `content_registry.gd:274`. `get_all_store_ids()` at `content_registry.gd:233`. `_seed_from_content_registry` at `store_registry.gd:92`. The five shipping store IDs (`sports`, `retro_games`, `rentals`, `pocket_creatures`, `electronics`) are the only top-level ids in `game/content/stores/store_definitions.json`. The full `_TYPE_ROUTES` bucket list (`entries:<kind>`, singleton/specialized configs, `ignore`) at `data_loader.gd:19-71`. All 23 listed `get_all_*` / `get_*_config` getters exist on `DataLoaderSingleton`. |
| `docs/testing.md` | `.gutconfig.json` directories, `pre_run_script` path, prefix/suffix/exit fields. Test layout dirs (`tests/gut/`, `tests/unit/`, `tests/integration/`, `game/tests/`, `tests/validate_*.sh`) all present. `validate.yml` jobs `lint-docs`, `gut-tests`, `interaction-audit`, `content-originality`, `lint-gdscript` at the cited line numbers. |
| `docs/configuration-deployment.md` | Application name and version (`Mallcore Sim`, `0.1.0`) at `project.godot:17, 19`. SaveManager `MAX_MANUAL_SLOTS = 3` and `MAX_SAVE_FILE_BYTES = 10485760` at `save_manager.gd`. Atomic-write `.tmp` rename behavior. `chickensoft-games/setup-godot@v2` invocation in `export.yml`. The export-preset table matches `export_presets.cfg` exactly. |
| `docs/contributing.md` | `.editorconfig` rules, GDScript ordering convention, naming table, content path rules. |
| `docs/roadmap.md` | The three SSOT tripwire scripts (`validate_translations.sh`, `validate_single_store_ui.sh`, `validate_tutorial_single_source.sh`) exist under `scripts/` and are invoked from `tests/run_tests.sh:73-80`. Five-store roster matches `store_definitions.json`. |
| `docs/style/visual-grammar.md` | Every constant named in the doc (`DARK_PANEL_*`, `LIGHT_PANEL_*`, `SEMANTIC_*`, `STORE_ACCENT_*`, `STORE_ACCENT_INACTIVE_*`, `STORE_ACCENTS`, `RARITY_COLORS_CB`, `FONT_SIZE_*`) exists in `game/scripts/ui/ui_theme_constants.gd`. `game/themes/palette.tres`, `mallcore_theme.tres`, and the five `store_accent_*.tres` resources all exist. `tests/gut/test_palette_contrast.gd` exists. |
| `docs/setup.md` | `scripts/godot_import.sh` and `scripts/godot_exec.sh` exist. The five-step Godot binary resolution order matches `tests/run_tests.sh:11-16`. Test runner steps and repository layout match the filesystem. |

---

## Statements removed because unverifiable

None this pass. Earlier passes had already pruned the last set of
unverifiable claims; nothing new was found that fit the bar.

---

## Intentional doc gaps left for future work

### `docs/research/` still does not exist

Carried forward from the previous pass. No active doc references
`docs/research/*.md` after the deletion of `tools/interaction_audit.md`.
Underlying research notes still live in `.aidlc/research/` (outside the
active docs boundary). **Justification:** promoting any of those notes
into `docs/research/` requires a content decision (which note is still
true, who owns its maintenance) that is outside a docs-accuracy pass.
**Smallest concrete next action if revived:** pick one note, re-validate
it against the current code path, and write it to
`docs/research/<topic>.md`.

### Per-checkpoint Day 1 readiness conditions are listed in code, not docs

`Day1ReadinessAudit` checks eight conditions
(`game/autoload/day1_readiness_audit.gd:65-103`): `active_store_id`,
`camera_source`, `input_focus`, `fixture_count`, `stockable_shelf_slots`,
`backroom_count`, `first_sale_complete`, `objective_active`. The
architecture doc names the autoload and its pass/fail checkpoint strings
but does not enumerate the eight conditions. **Justification:** the
class docstring at `day1_readiness_audit.gd` already documents the
conditions in the code. Duplicating the list into `architecture.md`
would double the maintenance surface for a contract that lives in code.
If Day 1 readiness ever becomes a player-facing concept that
non-engineers need to look up, escalate to a dedicated doc page.

### `scripts/validate_export_config.sh` is undocumented

The script exists and mirrors the inline `validate-export-config` job in
`.github/workflows/export.yml` (preset names, x86_64, no hardcoded
identity, no absolute paths, ETC2 ASTC import). It is not invoked from
`tests/run_tests.sh`. **Justification:** this is a doc gap, not a doc
error. Adding it to `docs/configuration-deployment.md` is a useful
enhancement but is feature work, not consolidation. **Smallest concrete
next action if added:** mention it under "Local export" as the
single-command preflight that matches CI.

---

## Escalations

### Godot version-string mismatch between CI workflows

`.github/workflows/validate.yml` sets `GODOT_VERSION: "4.6.2-stable"`;
`.github/workflows/export.yml` sets `GODOT_VERSION: "4.6.2"` and feeds it
to `chickensoft-games/setup-godot@v2`, which resolves the same stable
build. Functionally equivalent. The README and
`docs/configuration-deployment.md` both say "Both `validate.yml` and
`export.yml` install Godot `4.6.2-stable`," which is literally true for
`validate.yml` and effectively true (via the action's resolution) for
`export.yml`. **Who unblocks:** anyone touching CI. **Smallest concrete
next action:** change `export.yml:12` to `GODOT_VERSION: "4.6.2-stable"`
so the docs claim becomes literal. Left untouched here because this pass
is docs-only and the wording is already accurate at the level of "what
gets installed."

### Previous `AIDLC_FUTURES.md` escalation

Resolved. The file no longer exists at the repository root (working-tree
deletion captured by `docs/audits/ssot-report.md` and
`docs/audits/cleanup-report.md`). Re-flagging this would only matter if a
future AIDLC run regenerates the file at the root; if it does, the
template generator under `tools/aidlc/project_template/` is the place to
fix, not the docs.
