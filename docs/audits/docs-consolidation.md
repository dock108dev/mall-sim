---
date: 2026-04-28
pass: docs-consolidation
scope: README.md and all markdown under docs/
---

# Docs Consolidation — 2026-04-28

Full accuracy pass across the active documentation set. Every claim was
verified against source code, `project.godot`, CI workflows, and content
files before being accepted or corrected.

The previous pass note (2026-04-27) is superseded by this entry.

---

## Files changed

### docs/architecture.md

**Autoload roster: missing 31st entry.** `project.godot` registers
`Day1ReadinessAudit="*res://game/autoload/day1_readiness_audit.gd"` as the
last autoload (line 56). The roster table topped out at row 30
(`TutorialContextSystem`). Added row 31 describing the autoload's role: it
subscribes to `StoreDirector.store_ready` and emits
`AuditLog.pass_check(&"day1_playable_ready", …)` /
`fail_check(&"day1_playable_failed", …)` based on an eight-condition Day 1
playable composite.

**GameWorld init Tier 5: missing system.**
`game/scenes/world/game_world.gd:410-412` instantiates `DayManager`
(`_day_manager = DayManager.new()` then `add_child(_day_manager)`) inside
`initialize_tier_5_meta`, between `ending_evaluator.initialize()` and
`store_upgrade_system.initialize(...)`. The Tier 5 row had not listed
`DayManager`. Added it to the system list.

**Signal Bus Model: invented `tooltip_` prefix.** The "Signal name
conventions" table claimed `tooltip_` was a prefix in `event_bus.gd`. A
grep for `^signal tooltip_` returns no matches; tooltip surfaces are
managed by `TooltipManager` directly, not via EventBus signals. Removed
`tooltip_` from the row and tightened the `interactable_` / `panel_`
description (the only `panel_*` signals are `panel_opened` and
`panel_closed`).

### docs/architecture/ownership.md

**Row 1 (Scene load): wrong owner of the state machine.** The row
attributed an `IDLE → REQUESTED → LOADING → INSTANTIATING → VERIFYING →
READY/FAILED` state machine to `SceneRouter`. `game/autoload/scene_router.gd`
has no such state machine — it tracks `_in_flight: bool`, awaits
`tree_changed` + one `process_frame` after the engine queues the swap, then
emits `scene_ready(target, payload)` plus an `AuditLog` pass/fail. Rewrote
the row to describe the actual SceneRouter behavior. The named state
machine is `StoreDirector`'s and was moved to row 2 (see below).

**Row 2 (Store lifecycle): underspecified; absorbs the relocated state
machine.** The actual `StoreDirector` enum is
`IDLE → REQUESTED → LOADING_SCENE → INSTANTIATING → VERIFYING →
READY/FAILED` (note: `LOADING_SCENE`, not `LOADING`). Each transition
emits a `director_state_*` `AuditLog` checkpoint. Row 2 also previously
omitted the `set_scene_injector` seam (`game/autoload/store_director.gd`
class docstring lines 22–29) that lets a host scene like GameWorld inject
the store under `StoreContainer` instead of going through SceneRouter for
a full viewport swap. Both added. `Day1ReadinessAudit` added to the
readers column to reflect the new autoload.

**Row 10 (Cross-system eventing): wrong `scene_ready` mirror signature.**
`event_bus.gd:15` declares `signal scene_ready(scene_name: StringName)` —
single argument. The full `scene_ready(target: StringName, payload:
Dictionary)` lives on `SceneRouter`. The matrix had described the
EventBus mirror with both arguments. Corrected to single-arg, with a
parenthetical noting where the two-arg form lives.

### docs/content-data.md

**Type detection: stale four-step heuristic.** Per ISSUE-021, `DataLoader`
now requires every content JSON to declare a root `"type"` field; the
loader looks the value up in `_TYPE_ROUTES` and fails the file with a
load error on missing or unknown types. The class docstring at
`game/autoload/data_loader.gd:9-12` is explicit: "no heuristic detection
via filename or directory is permitted." The doc still described an
order-of-detection that fell back to file basenames and directory names
(steps 2–4). Replaced the four-step list with the actual `_TYPE_ROUTES`
mechanism and broke routes into the three documented buckets
(`entries:<kind>`, singleton/specialized, `ignore`).

**`game/content/meta/`: secret-thread file does not exist.** The content
layout table claimed "Secret thread data and regulars thread data" under
`game/content/meta/`. A `find` for `*secret*` JSON returns nothing;
`game/content/meta/` contains only `regulars_threads.json`. Updated the
row and the matching bullet under "Non-resource content."

**Validation list incomplete.** `ContentRegistry.validate_all_references()`
covers more than the doc claimed: in addition to item `store_type`,
store `starting_inventory`, and scene-path existence, it also collects
duplicate-id and alias-conflict errors recorded during registration
(`_validate_entry_cross_refs` calls `_validate_event_store_refs`,
`_validate_seasonal_event_store_refs`, `_validate_supplier_refs`, and
`_validate_milestone_refs`). Added all four cross-ref categories plus the
duplicate/alias bullet.

**Runtime access getters: missing `get_all_unlocks()`.** The function
exists at `data_loader.gd:1042` but was absent from the listed public
getter surface. Added.

**Loader pipeline diagram: outdated `_detect_type()` step.** Replaced
`DataLoaderSingleton._detect_type()` with `dict["type"] looked up in
DataLoader._TYPE_ROUTES` to match the actual code path.

### docs/index.md

**Stale "latest interaction audit" date.** Listed `2026-04-27-audit.md`
as latest; `docs/audits/2026-04-28-audit.md` now exists (timestamp inside
the file: `2026-04-28T12:15:37Z`). Updated. Also added
`security-report.md` to the code-quality audits bullet, since it sits in
`docs/audits/` alongside the other reports.

---

## Files reviewed and accepted without change

All claims verified against source code.

| File | Verification scope |
| --- | --- |
| `README.md` | Entry scene, test command, export presets, Godot version, docs pointer |
| `docs/setup.md` | Godot version, helper script names and paths, test runner steps, repo layout |
| `docs/architecture.md` (remainder) | Boot sequence steps 1–7 against `game/scripts/core/boot.gd:18-66`, init-tier function names against `game_world.gd:261-391`, autoload rows 1–30 against `project.godot:24-55`, scene entry points against filesystem, `run_state_changed` mirror against `event_bus.gd:51`, visual systems table against file existence |
| `docs/architecture/ownership.md` (rows 3–9) | Row contents verified against the named autoload sources (`input_focus.gd`, `camera_authority.gd`, `game_state.gd`, etc.) |
| `docs/content-data.md` (remainder) | Loader pipeline ordering, content subdirectory listing against `game/content/`, canonical ID pattern (`^[a-z][a-z0-9_]{0,63}$` at `content_registry.gd:4`), `_normalize` behavior at `content_registry.gd:460-469`, scene-path constraints, SSOT declaration, typed resource table |
| `docs/testing.md` | `.gutconfig.json` fields, test directory layout, CI job list against `validate.yml` (`setup_gut_env.gd` seeding is an implementation detail not worth surfacing in the doc) |
| `docs/configuration-deployment.md` | `project.godot` settings, save-manager constants, export preset table (`export_presets.cfg` exclude_filter matches the documented exclusion list), CI workflow job lists |
| `docs/contributing.md` | Naming conventions, GDScript standards, `.editorconfig`-driven formatting rules, documentation rules |
| `docs/design.md` | Non-negotiables, store roster, progression model, out-of-scope list, visual anti-patterns |
| `docs/roadmap.md` | Phase descriptions, Phase 0.1 completion note (the three SSOT tripwire scripts exist under `scripts/` and are invoked from `tests/run_tests.sh:74-80`) |
| `docs/style/visual-grammar.md` | Color tokens against `UIThemeConstants` (`STORE_ACCENT_*`, `SEMANTIC_*`, `DARK_PANEL_*`, `LIGHT_PANEL_*`, `FONT_SIZE_*`), store accent hex values, `STORE_ACCENT_INACTIVE_*` constants, theme/palette resource paths |

---

## Statements removed because unverifiable

None. Every change above either replaced a wrong claim with the verified
one or added a missing fact — no claims were dropped for being merely
unprovable.

---

## Intentional doc gaps left for future work

### `docs/research/` still does not exist

Carried over from the 2026-04-27 pass: `docs/architecture/ownership.md`
no longer references `docs/research/*.md`, and that directory has not
been created. The underlying research notes still live in
`.aidlc/research/` (outside the active docs boundary). Promoting them
into `docs/research/` requires a decision that is outside this pass'
scope. **Smallest concrete next action:** pick one research note,
re-validate it against current code, and write it to
`docs/research/<topic>.md`.

### Per-checkpoint Day 1 readiness conditions are listed in code, not docs

`Day1ReadinessAudit` checks eight conditions
(`game/autoload/day1_readiness_audit.gd:65-103`): `active_store_id`,
`camera_source`, `input_focus`, `fixture_count`, `stockable_shelf_slots`,
`backroom_count`, `first_sale_complete`, `objective_active`. The
architecture doc only names the autoload and its pass/fail checkpoint
strings; it does not enumerate the eight conditions. The class docstring
in `day1_readiness_audit.gd` already covers this, and the existing
`CLAUDE.md` "Day 1 Quarantine" table covers the related per-system Day 1
behavior. **Justification:** the source-of-truth is the code's
constants; duplicating the list into `architecture.md` would double the
maintenance surface. If Day 1 readiness becomes a player-facing concept
that non-engineers need to look up, escalate to a dedicated doc page.

### `tools/interaction_audit.md` is a frozen 2026-04-21 snapshot

The file lives in `tools/` (outside the active docs boundary defined in
`docs/index.md`) and is dated `2026-04-21`. It still references
`docs/research/vertical-slice-store-selection.md`, which does not exist,
and describes a signal chain (`StoreSelectorSystem.enter_store()`,
`mall_hub.gd:38`) from before `StoreDirector` became the sole entry
point. Per the documentation boundary, files under `tools/` are tooling
support rather than active docs, so this pass leaves it untouched.
**Escalation candidate:** if the team wants the audit kept current, it
should move into `docs/` (and be regenerated on each AIDLC run); if it
is a historical artifact, it should be deleted.

---

## Escalations

### `AIDLC_FUTURES.md` at the repository root

The file is auto-generated by AIDLC ("Auto-generated by AIDLC
finalization on 2026-04-28") and points to `ARCHITECTURE.md`,
`DESIGN.md`, and `ROADMAP.md` at the repository root, none of which
exist (the actual files are `docs/architecture.md`, `docs/design.md`,
and `docs/roadmap.md`). The contributing rules say only `README.md` and
customer-voice files belong at root, and the active docs boundary in
`docs/index.md` reinforces that.

Editing the file by hand is futile because the next AIDLC run will
overwrite it. **Who unblocks:** whoever owns the AIDLC project template
(`tools/aidlc/project_template/`). **Smallest concrete next action:**
update the template's `AIDLC_FUTURES.md` generator to either (a) write
into `docs/audits/aidlc-futures.md` instead of root, or (b) point at the
real `docs/*` paths. Until that happens, this docs pass leaves the file
in place.

### Godot version string mismatch between CI workflows

`.github/workflows/validate.yml` sets `GODOT_VERSION: "4.6.2-stable"` and
downloads from the GitHub release tag literally; `.github/workflows/export.yml`
sets `GODOT_VERSION: "4.6.2"` and feeds it to
`chickensoft-games/setup-godot@v2`, which resolves the same stable
build. Functionally equivalent, but `docs/configuration-deployment.md`
and `README.md` both say "Both `validate.yml` and `export.yml` install
Godot `4.6.2-stable`", which is literally true only of `validate.yml`.
**Who unblocks:** anyone touching CI — the right fix is to align both
workflows on the same string. **Smallest concrete next action:** change
`export.yml` line 12 to `GODOT_VERSION: "4.6.2-stable"` (the chickensoft
action accepts either form), then this docs claim becomes literally
correct without a doc edit. Left untouched here because the rules
forbid code refactors during a docs pass.
