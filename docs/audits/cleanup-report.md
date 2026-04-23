# Code Quality Cleanup Report

Date: 2026-04-22

## Scope

Cleanup pass over `game/autoload/`, `game/scripts/`, `game/scenes/`, and
`tests/`. Excluded: `addons/` (vendored GUT), generated files (`.import/`,
`.uid`). Repo must build cleanly; no behavioral changes.

This report supersedes the 2026-04-19 / 2026-04-21 cleanup report (whose
changes are already merged).

---

## Dead code removed

None. A full sweep of `game/` found:

- No commented-out code blocks.
- No stale `TODO`/`FIXME` markers in runtime code.
- No orphaned `print()` debug calls. Remaining `print()` usages are
  intentional instrumentation in `audit_log.gd`, `audit_overlay.gd`,
  `scene_router.gd`, `store_director.gd`, and `fail_card.gd` (runtime-audit
  pipeline that `tests/audit_run.sh` consumes).
- No unused imports (GDScript has no imports in the JS/Py sense; preloads
  spot-checked against references).

The prior cleanup pass already removed the two known dead items
(`AMBIENT_BUS` alias, `_apply_locale()` wrapper).

---

## Files refactored

None in this pass. See "Flagged for follow-up" below for large files that
are justified in place.

---

## Consistency changes made

None applied. Items considered and **deliberately not changed**:

- **Signal names with `_updated` suffix** (e.g., `inventory_updated`,
  `trend_updated`, `seasonal_multipliers_updated`, `objective_updated` in
  `game/autoload/event_bus.gd`). CLAUDE.md §2 requires past-tense signal
  names; `updated` is past-tense and conforms. Renaming to `_changed` for
  pure stylistic uniformity would be a broad cross-file rename with zero
  behavioral benefit and nonzero risk of missed references. **Not a
  violation — left as-is.**
- **Untyped signal-handler return types** (~15 `func _on_*(...)` without
  `-> void`). CLAUDE.md §2 requires typing for *new* code; these are
  pre-existing handlers and adding `-> void` is a cosmetic sweep that
  touches many files. **Flagged below, not applied.**
- **Hex-value comments alongside `Color(r,g,b)` floats** in
  `game/scenes/debug/accent_budget_overlay.gd`. The code uses floats (not
  hex literals), so the CLAUDE.md "no hex color literals" rule is satisfied.
  Comments are developer aids, not violations. **Left as-is.**

---

## Files still over 500 LOC

41 files exceed 500 lines. All top offenders are justified by system
scope; most already carry `# gdlint:disable=max-file-lines` with a
rationale. No splits recommended at this phase (see CLAUDE.md §8 rule 6:
audit/trace/wire only — no refactors for refactor's sake).

| File | LOC | Justification |
|---|---|---|
| `game/scripts/core/save_manager.gd` | 1324 | Serializes 40+ autoloads/systems; splitting fragments the single-save-source invariant. |
| `game/scenes/world/game_world.gd` | 1303 | Preload + instantiation hub for 40+ UI/scene nodes; central lifecycle. |
| `game/autoload/data_loader.gd` | 1102 | Parser dispatch for all content types; cohesive. |
| `game/scripts/content_parser.gd` | 942 | 11+ content-type parsers; extraction would require a parser-registry refactor out of scope. |
| `game/scripts/systems/customer_system.gd` | 888 | Customer AI state machine + spawn/pathing. |
| `game/scripts/systems/inventory_system.gd` | 848 | Per-store inventory + pricing + restock. |
| `game/autoload/settings.gd` | 770 | Settings load/save/apply for all categories. |
| `game/scripts/stores/video_rental_store_controller.gd` | 766 | Store-specific controller; domain-cohesive. |
| `game/scenes/ui/day_summary.gd` | 765 | Day-close UI aggregator. |

Remaining 32 files in the 500–750 LOC range are store controllers, panels,
and system coordinators — all single-responsibility at the domain level.

**Recommendation:** revisit after Phase 2 when the day-loop is
runtime-verified. Splitting before the golden path is stable risks
regressing ownership invariants (CLAUDE.md §8 rule 4).

---

## Duplicate utilities

None consolidated. The `is_open() -> bool` pattern appears across ~7 UI
panels (`inventory_panel.gd`, `save_load_panel.gd`, etc.) but each reads
panel-local state; extracting to a base class would add coupling without
reducing code.

---

## Flagged for follow-up

Items worth doing in a dedicated pass, but out of scope for a no-behavior
cleanup:

1. **Signal-handler return types**: add `-> void` to ~15 `_on_*` callbacks
   for CLAUDE.md §2 parity with new-code rules. Purely cosmetic, cross-file
   sweep. Safer as its own commit once branches quiesce.
2. **Large-file review post-Phase-2**: after day-loop verification, revisit
   `save_manager.gd`, `game_world.gd`, and `data_loader.gd` for logical
   split points (e.g., per-content-type parser modules).
3. **Signal naming convergence** (optional): if the team wants strict
   `_changed`/`_loaded`/`_finished` vocabulary, do one EventBus rename pass
   with a grep-verified reference update and a passing full test run.

---

## Verification

No source files were modified in this pass; repo build/test state is
unchanged from the start of the pass. No follow-up CI run required.
