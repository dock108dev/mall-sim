# Code Quality Cleanup Report

Date: 2026-04-23

## Scope

Cleanup pass over `game/autoload/`, `game/scripts/`, `game/scenes/`, and
`tools/`. Excluded: `addons/` (vendored GUT), `tests/` fixtures, generated
files (`.import/`, `.uid`), and content JSON under `game/content/`.

This report supersedes the 2026-04-22 cleanup report. No behavioral changes
made; repo state preserved for the ~88 files of in-flight work currently
uncommitted on `main`.

---

## Dead code removed

None. A full sweep of `game/` and `tools/` found:

- No commented-out code blocks (3+ consecutive comment lines that parse as
  code).
- No unused `@export` vars. Spot-checks on `action_drawer.gd`,
  `difficulty_selection_panel.gd`, and `crt_overlay.gd` confirmed all are
  referenced.
- All `pass` stubs are intentional virtual hooks on base classes —
  `game/scripts/stores/store_controller.gd:105-118` defines the
  `_on_store_activated` / `_on_day_started` / `_on_customer_entered` override
  surface that subclassed store controllers fill in.
- No unused preloads detected.

## TODO / FIXME / HACK markers

Zero matches in `game/**/*.gd`. The 14 tech-debt markers flagged by the
audit all live in `tools/aidlc/tests/test_auditor.py` and
`tools/aidlc/aidlc/auditor.py` — they are **test fixtures and regex
literals** used by the auditor itself to detect these patterns in user
codebases. Not actionable.

## Outdated comments

None. Recent rename `GameState → RunState` (commit `a3b441b`) is internally
consistent:

- `game/autoload/game_manager.gd` retains `enum GameState` as an internal
  enum name — callers use `GameManager.GameState.*` qualified access.
- `game/autoload/game_state.gd`'s doc comment describes an "in-memory
  holder" and is accurate.
- No dangling references to the old autoload name found outside
  `GameManager`.

## Duplicate utilities

None. Only one `*_helper.gd` / `*_utils.gd` file exists
(`game/scripts/core/input_helper.gd`). No copy-paste candidates surfaced.

## Files refactored

None. No behavioral-risk edits made given the in-flight working tree.

---

## Files still over 500 LOC

The following files exceed 500 lines. Each is functionally cohesive (one
subsystem per file, consistent with the single-owner rule in
`docs/architecture/ownership.md`). Splitting any of them would cross
ownership boundaries, so they are **flagged for follow-up**, not
auto-refactored:

| LOC | File | Justification / follow-up note |
|----:|------|-----|
| 1341 | `game/scripts/core/save_manager.gd` | Owns save/load serialization for every system; extraction of per-system serializers requires coordinated design. Follow-up candidate. |
| 1328 | `game/scenes/world/game_world.gd` | Five-tier init orchestrator. Could split `_setup_ui` / `_setup_deferred_panels` / system wiring into mixins — flagged for follow-up. |
| 1073 | `game/autoload/data_loader.gd` | Sole caller of `ContentRegistry` writes; the per-type `_build_and_register_*` branches are the bulk. Extractable to a `content_parsers/` folder. Follow-up. |
| 973  | `game/scripts/stores/video_rental_store_controller.gd` | Large store controller (late-fee + refurb + rental loops). Parallel retro-games controller is comparable size. Store-specific, accept as-is until Phase 1 finishes per roadmap. |
| 945  | `game/scripts/content_parser.gd` | One `parse_*` per content type. Splitting would fragment the type-dispatch. Accept. |
| 888  | `game/scripts/systems/customer_system.gd` | Single-owner of customer lifecycle. Accept. |
| 864  | `game/scenes/ui/day_summary.gd` | UI layout + data aggregation. Consider extracting aggregation helper. Follow-up. |
| 848  | `game/scripts/systems/inventory_system.gd` | Single-owner inventory writes. Accept. |
| 770  | `game/autoload/settings.gd` | Settings persistence + apply. Accept. |
| 744  | `game/scripts/systems/order_system.gd` | Order lifecycle owner. Accept. |
| 727  | `game/autoload/audio_manager.gd` | Audio bus + bank + playback. Accept. |

No file in `tools/` exceeds 500 LOC.

## Consistency changes made

None. GDScript naming (snake_case funcs, PascalCase autoloads/classes),
signal-bus coupling, and autoload responsibilities already follow the
conventions documented in `CLAUDE.md` and `docs/architecture.md`.

---

## Conclusion

The repository is in a clean, maintainable state. The prior 2026-04-19 and
2026-04-22 cleanup passes have held — no regressions in dead code, stale
comments, or duplication. The only standing item is the set of 11 files
over 500 LOC listed above; four are flagged as reasonable extraction
candidates (`save_manager.gd`, `game_world.gd`, `data_loader.gd`,
`day_summary.gd`), the rest are single-owner subsystems whose size is
structural rather than accidental.

No files modified in this pass.
