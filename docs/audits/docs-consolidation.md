# Docs Consolidation — 2026-05-02

**Scope:** documentation review and consolidation pass over `README.md`,
`docs/`, and `docs/audits/`. Goal: every doc statement verifiable from the
current code, configs, content, scenes, and CI workflows; nothing else
exists.

**Method:** read every file under `README.md`, `docs/`, and `docs/audits/`
in full; cross-check claims against `project.godot`, `game/scripts/core/boot.gd`,
`tests/run_tests.sh`, `.gutconfig.json`, `.github/workflows/*.yml`,
`scripts/*.sh`, the autoload roster, the resolved `game/scenes/`,
`game/scripts/`, `game/content/`, `game/resources/`, and `game/themes/`
trees, and `game/content/stores/store_definitions.json`. Every code-shape
claim re-verified against the current tree. No edits to source code.

---

## Doc-set boundary (re-confirmed)

- Root: `README.md` only.
- Customer-voice / vision files at root: `BRAINDUMP.md`, `LICENSE` — left
  untouched per the pass rules.
- Active project docs: `docs/` (`setup.md`, `architecture.md`,
  `architecture/ownership.md`, `design.md`, `style/visual-grammar.md`,
  `content-data.md`, `testing.md`, `configuration-deployment.md`,
  `contributing.md`, `roadmap.md`, `index.md`).
- Audit notes: `docs/audits/` (`cleanup-report.md`, `error-handling-report.md`,
  `security-report.md`, `ssot-report.md`, dated `YYYY-MM-DD-audit.md`,
  this `docs-consolidation.md`).

No stray markdown files outside this boundary; `.github/`, `.aidlc/`,
`addons/`, `tools/`, `planning/` markdown is configuration / templates /
vendored material and is correctly excluded by `docs/index.md`.

---

## Edits applied this pass

### `docs/configuration-deployment.md`

- **Rewrote** the "Checked-in integrations" bullet that listed
  `validate_export_config.sh` as one of the SSOT tripwires invoked by
  `tests/run_tests.sh`. Verified against `tests/run_tests.sh:73-80`: the
  runner only invokes `validate_translations.sh`,
  `validate_single_store_ui.sh`, and `validate_tutorial_single_source.sh`.
  `scripts/validate_export_config.sh` exists in the tree and (per its
  own header at `scripts/validate_export_config.sh:3`) "mirrors the
  `.github/workflows/export.yml validate-export-config` job so the same
  checks can run locally without needing the Godot binary or export
  templates" — i.e., it is run independently, not by the test runner.
  The bullet now reflects that distinction.

### `docs/audits/cleanup-report.md`

- **Rewrote** the Pass-2 framing paragraph and one disposition row to
  acknowledge that the previously-deleted `docs-consolidation.md` has
  been re-created by this pass. The original Pass-2 statement
  ("only `2026-05-01-audit.md` and `docs-consolidation.md` are deleted")
  was a true point-in-time observation; after this pass the latter file
  is back, so the report now says it was absent **at the time of Pass 2**
  and notes the re-creation. The cite-restoration decisions Pass 2 made
  are unchanged — only the framing was updated.

### `docs/audits/ssot-report.md`

- **Rewrote** the Risk-log row that referred to "deleted reports
  (`security-report.md`, `ssot-report.md`, `docs-consolidation.md`,
  `cleanup-report.md` as prior pass names)" to remove the inaccurate
  "deleted" framing. Of those four filenames, three
  (`security-report.md`, `ssot-report.md`, `cleanup-report.md`) were
  never absent in this branch's working tree, and `docs-consolidation.md`
  has been re-created by this pass. The row's *intent* (preserve the
  provenance trail of prior pass names inside `error-handling-report.md`)
  is unchanged.
- **Rewrote** the Sanity-check row that asked "Any code citing the four
  deleted audit reports …?" to ask the same question without the
  false "deleted" premise. The result line ("None remaining in
  code/tests …") was already accurate and is preserved.

### `docs/audits/docs-consolidation.md` (this file)

- **Created** as the audit-trail of this pass.

---

## Statements removed as unverifiable

None. Every contested statement was instead **rewritten** to match the
current code/tree state. No claims in the active doc set
(`README.md`, `docs/*.md`, `docs/architecture/ownership.md`,
`docs/style/visual-grammar.md`) needed deletion: each was either
verified by direct inspection of the referenced source/config/content
file, or it described a forward-looking goal (in `docs/roadmap.md`)
that is explicitly framed as a phase target rather than a current
fact. The audit reports under `docs/audits/` are point-in-time records
and were left intact except for the small framing rewrites listed
above.

## Files left intact (with rationale)

| File | Why left intact |
|---|---|
| `README.md` | Run-locally / run-tests / deployment / docs-pointer set, all verified against `project.godot`, `tests/run_tests.sh`, `export_presets.cfg`, and `.github/workflows/`. |
| `docs/setup.md` | Verified: Godot resolution order matches `tests/run_tests.sh::_resolve_godot_bin` and `scripts/godot_exec.sh`; main scene matches `project.godot run/main_scene`; runner steps match `tests/run_tests.sh`. |
| `docs/architecture.md` | Autoload roster (1–31) matches `project.godot [autoload]` line-for-line. Boot flow matches `game/scripts/core/boot.gd`. Init-tier table matches `game/scenes/world/game_world.gd`. Visual-systems table matches `game/scripts/world/build_mode_camera.gd` (`class_name BuildModeCamera`), `game/autoload/camera_authority.gd`, `game/scripts/components/interactable.gd`, `game/scripts/ui/interactable_hover.gd`, `game/autoload/tooltip_manager.gd`, `game/scenes/ui/interaction_prompt.tscn`, `game/scripts/stores/shelf_slot.gd`, `game/scripts/world/day_phase_lighting.gd`, `game/resources/shaders/crt_overlay.gdshader`, `game/scripts/ui/panel_animator.gd`, `game/scripts/ui/ui_layers.gd`. |
| `docs/architecture/ownership.md` | Each row verified against the named autoload/source script: `SceneRouter`, `StoreDirector`, `CameraAuthority`, `InputFocus`, `GameState`, `HUD`, `StoreRegistry`, `AuditLog`, `EventBus`. |
| `docs/design.md` | Store-display-name table matches `game/content/stores/store_definitions.json:9,110,216,329,456`. Canonical-id column matches the `id` field in the same file. The "Management hub, not walkable world" rule is consistent with `project.godot debug/walkable_mall=false` and the in-store FP body (`game/scripts/player/store_player_body.gd`) being a separate, store-only system. Anti-pattern table claims (camera controllers, outline shader paths) match the visual-systems entries above. |
| `docs/style/visual-grammar.md` | Token names and hex/`Color()` values match `game/scripts/ui/ui_theme_constants.gd` (`DARK_PANEL_FILL`, `LIGHT_PANEL_FILL`, `SEMANTIC_*`, `STORE_ACCENT_*`, `STORE_ACCENTS`, `FONT_SIZE_*`). Theme files exist at `game/themes/palette.tres`, `mallcore_theme.tres`, and `store_accent_*.tres`. The `STORE_ACCENTS` dictionary keys (`sports_cards`, `video_rental`) intentionally differ from the canonical store ids (`sports`, `rentals`) — that is a code shape, not a doc bug, and the doc reports it accurately. |
| `docs/content-data.md` | Loader pipeline matches `game/autoload/data_loader.gd` and `game/scripts/content_parser.gd`. Type-route categories match `_TYPE_ROUTES`. Resource list matches `game/resources/*.gd`. Validation list matches `game/autoload/content_registry.gd::validate_all_references`. Roster lines (canonical / aliases) match `store_definitions.json`. |
| `docs/testing.md` | Runner steps match `tests/run_tests.sh`. `.gutconfig.json` claims (dirs, prefix, suffix, should_exit, pre-run script) match the JSON verbatim. CI-validation block matches `.github/workflows/validate.yml` jobs (`lint-docs`, `gut-tests`, `interaction-audit`, `content-originality`, `lint-gdscript`). |
| `docs/configuration-deployment.md` | After this pass's edit, every claim verified: `application/*` block, autoload pointer, save-paths block, `MAX_MANUAL_SLOTS=3` / `MAX_SAVE_FILE_BYTES=10485760` / `MAX_SLOT_INDEX_BYTES=65536` against `game/scripts/core/save_manager.gd:46-51`, export-preset paths against `export_presets.cfg`, and the `validate.yml` / `export.yml` job descriptions against the workflows. |
| `docs/contributing.md` | `.editorconfig` rules, GDScript standards, naming, content rules, and docs-boundary rules match the working repo. |
| `docs/roadmap.md` | Forward-looking phase doc; Phase 0.1 completion claim verified (the three SSOT tripwires exist and are invoked by `tests/run_tests.sh`); shipping-roster line matches `store_definitions.json`. Phase 3+ items remain forward-looking targets. |
| `docs/index.md` | Pointers correct; Audit-notes block matches the current `docs/audits/` directory contents. |
| `docs/audits/error-handling-report.md` | Inline `§F-NN` index reverse-points at code; the cleanup-report Pass-2 sweep verified each cite. Untouched this pass. |
| `docs/audits/security-report.md` | `§F` / `§SR` / `§DR` index unchanged; reverse-pointer integrity confirmed by the cleanup-report Pass-2 sweep. Untouched this pass. |
| `docs/audits/2026-05-02-audit.md` | Daily interaction-audit table written by `tests/audit_run.sh`, regenerated by the `interaction-audit` CI job. Not edited by docs passes. |

---

## Intentional gaps

- **No new `docs/*.md` files were added** beyond restoring this
  consolidation report. The active doc set already covers what / how /
  deployment / pointer-to-docs (README), local setup, architecture,
  ownership, design, content/data, testing, configuration/deployment,
  contributing, roadmap, and visual style. Adding more would duplicate
  rather than enrich.
- **No deletions of audit reports**. Each of `cleanup-report.md`,
  `error-handling-report.md`, `security-report.md`, `ssot-report.md`,
  and the dated `2026-05-02-audit.md` carries an active code-side
  reverse-link surface (`§F-NN` markers, daily checkpoint table) and
  earns its existence.
- **No rewrites of `BRAINDUMP.md`** — customer-voice file, explicitly
  out of scope.
- **No code edits**. This is a docs-only pass; the Actionability
  Contract's "act in source" clause is satisfied by the markdown edits
  enumerated above, which is the docs-pass form of acting.

---

## Escalations

None. Every finding was either acted on (the four edits above) or had
no action to take (everything else verified). No documentation
assertion was left in place that this pass could not trace back to a
specific source file, config field, content entry, or workflow step.
