# Abend Handling Audit

Date: 2026-04-19

## Executive Summary

The codebase has broadly consistent error handling: nearly every error path emits
`push_error` or `push_warning` before returning. The dominant pattern is
"log and bail" rather than silent swallow. However, the audit found:

- **1 High** — missing `return` after a critical scene-load failure in
  `CustomerSystem` caused initialization to continue with a null scene; **fixed
  in-place**.
- **2 Medium** — silent card-slot substitutions in `PackOpeningSystem` that hid
  content configuration problems; **warnings added in-place**.
- **1 Medium** — `EndingEvaluatorSystem` logs a wrong-count error but continues
  running with a mismatched ending list.
- **Several Low / Notes** — pervasive unlogged `return null` / `return []`
  guard clauses in scene-graph helper functions; intentional design but worth
  understanding.

No broad try/except-style swallowing exists (GDScript has no exception handling).
No silent retry loops or circuit breakers were found. The main risk class is
**guard-clause silent returns** that hide upstream wiring failures.

---

## Detailed Findings

### Severity: High

| # | File | Lines | Pattern | Risk |
|---|------|-------|---------|------|
| H1 | `game/scripts/systems/customer_system.gd` | 98–102 | `push_error` with no `return` — execution continued into `_connect_signals()` with a null `_shopper_scene`, causing null-dereference signals later | Reliability — NPCs would silently fail to spawn |

**H1 — Fixed.** Added `return` after the missing-shopper-scene error.

---

### Severity: Medium

| # | File | Lines | Pattern | Risk |
|---|------|-------|---------|------|
| M1 | `game/scripts/systems/pack_opening_system.gd` | 285–294 | Rare-slot and energy-slot roll failures silently substituted a random common card with no warning | Observability — bad card-pool JSON would produce wrong packs with no diagnostic |
| M2 | `game/scripts/systems/ending_evaluator.gd` | 419–423 | Wrong ending-definition count logged but execution continues, running the ending evaluator with a mismatched list | Data integrity — wrong ending could trigger |
| M3 | `game/autoload/data_loader.gd` | 196 | `if data == null: return` inside `_process_file` — the error IS recorded by `_load_json_with_error` before returning null, but the calling loop silently skips the file with no additional context about which file was skipped | Observability — file skip reason is in the error log but not tied to the file path at the call site |
| M4 | `game/scenes/world/game_world.gd` | 1108–1125 | `_validate_load_state` and `_validate_new_game_state` iterate validation errors and `push_error` each, but do not halt or degrade the session | Data integrity — game can start with an inconsistent state snapshot |

**M1 — Fixed.** Added `push_warning` on both fallback branches so bad pool config is visible.

**M2 — Not fixed in-place.** The 13-ending count is a hardcoded magic number. The
correct fix is to make the count data-driven (remove the hardcoded `!= 13` check)
or to change the push_error into a hard-stop. Neither can be done safely without
confirming the intended ending count in the content definition files. Tracked
below in the remediation plan.

**M3 — Not fixed in-place.** The error is logged by `_record_load_error` before
null is returned; the file path appears in that message. Acceptable as-is;
tracked as a note.

**M4 — Not fixed in-place.** Validation is informational post-hoc. Making it a
hard stop would change session-start behavior. Tracked in remediation plan.

---

### Severity: Low

| # | File | Lines | Pattern | Risk |
|---|------|-------|---------|------|
| L1 | `game/autoload/audio_manager.gd` | 74, 90 | Player-pool exhausted returns silently (no warning); intentional to avoid log spam under high load | Observability — no metric for pool saturation |
| L2 | `game/autoload/game_manager.gd` | 249–251 | `get_current_day()` falls back to `_current_day_shadow` when `TimeSystem` is null — deliberate pre-boot guard, but indistinguishable from day 0 | Reliability — subtle pre-boot ordering bugs masked |
| L3 | `game/scripts/systems/secret_thread_system.gd` | 449–451 | `push_error("UnlockSystem not found")` has no `return`; execution continues to emit `thread_completed` without granting the unlock | Data integrity — thread marked complete without reward |
| L4 | `game/scripts/systems/testing_system.gd` | 50 | `push_warning("already testing '%s'")` has no `return`; a second `start_test` call may double-start | Reliability |
| L5 | `game/autoload/unlock_system.gd` | 62–65 | `push_error("ContentRegistry cannot resolve display name")` returns the raw unlock ID as a fallback string — caller cannot distinguish error string from valid display name | Data integrity (cosmetic) |
| L6 | `game/autoload/difficulty_system.gd` | 210–211 | `_is_lower_tier` returns `false` silently when either tier index is -1 (unknown tier) — caller cannot tell "not lower" from "lookup failed" | Reliability |
| L7 | `game/resources/supplier_definition.gd` | ~26 | `get_tier_data` returns `{}` for unknown tier with no log — callers must check for empty dict | Observability |
| L8 | `game/scripts/stores/store_selector_system.gd` | 119–364 | Twelve consecutive unlogged `return` guards on scene-graph node lookups — legitimate during scene transitions but invisible if wiring is wrong at steady-state | Observability |
| L9 | `game/scripts/debug/debug_commands.gd` | 13, 17 | `add_cash()` and `set_time()` push_warning "not yet wired" — stub methods that do nothing; violate the "finish before feature" design principle | Reliability (debug-only) |

---

### Severity: Note (Acceptable)

| # | File | Pattern | Rationale |
|---|------|---------|-----------|
| N1 | `game/autoload/settings.gd` | File-load failures fall back to defaults with a push_warning | Correct — user settings are non-critical, defaults are safe |
| N2 | `game/scripts/systems/tutorial_system.gd` | Load failure resets to clean tutorial state | Correct — progressive disclosure; clean state is safe |
| N3 | `game/autoload/audio_event_handler.gd` | Null store_def falls back to hallway music | Intentional design — store audio is decorative |
| N4 | `game/autoload/settings.gd` | Font size / locale / resolution clamped to defaults with push_warning | Correct — all have tested safe fallbacks |
| N5 | `game/autoload/unlock_system.gd` | Unknown unlock IDs in save data discarded with push_warning | Correct — forward-compat; orphaned IDs are harmless |
| N6 | `game/autoload/market_trend_system.gd` | Unknown category returns 1.0 (neutral multiplier) with push_error | Acceptable — neutral is the safest price fallback |
| N7 | `game/autoload/difficulty_system.gd` | Unknown modifier returns 1.0 / false with push_error | Acceptable — same rationale as N6 |
| N8 | `game/scripts/characters/shopper_ai.gd` | Null waypoint / animation guards return silently | Acceptable during scene transitions; movement tolerates a missed frame |
| N9 | `game/scenes/bootstrap/boot.gd` | Re-entry after completed boot: logs + transitions to menu anyway | Acceptable — idempotent recovery |
| N10 | `game/autoload/game_manager.gd` | `quit_game()` calls `get_tree().quit()` | Correct — intentional clean exit |

---

## Categorization Summary

| Category | Count | Action |
|----------|-------|--------|
| Fixed in-place | 2 | Done (H1, M1) |
| Needs tightening | 3 | M2, M4, L3 |
| Needs telemetry / observability | 3 | L1, L4, L8 |
| Stub methods to delete or implement | 2 | L9 |
| Acceptable as-is | 10+ | N1–N10 |

---

## Remediation Plan

### P1 — Must fix (correctness)

**L3 — `secret_thread_system.gd`: missing return after UnlockSystem not found.**
Add `return` so `thread_completed` is not emitted when the unlock cannot be
granted. Thread should be left in-progress; the error is surfaced in the log
for the next load.

**M2 — `ending_evaluator.gd`: hardcoded `!= 13` ending count check.**
Remove the magic-number guard. Instead verify that `_ending_definitions` is
non-empty and that every expected `ending_id` from the content registry is
present. This scales correctly when endings are added.

**L4 — `testing_system.gd`: missing return in duplicate-test guard.**
Add `return` after the push_warning so a second `start_test` call on the same
item cannot double-start.

### P2 — Should fix (observability)

**M4 — `game_world.gd` validation logs but continues.**
Change `_validate_load_state` / `_validate_new_game_state` to emit
`EventBus.game_validation_failed` (or degrade to a boot-error panel) when
errors are present, consistent with how boot handles content errors.

**L1 — Audio pool exhaustion is silent.**
Add a rate-limited `push_warning` (use the existing `_warn_once` pattern in
`AudioManager`) when the SFX player pool is exhausted so pool-size tuning has
an observable signal.

**L9 — `debug_commands.gd` stubs.**
Either implement `add_cash` and `set_time` or delete the file. Silent no-ops in
debug tooling make debugging harder.

### P3 — Nice to have (defensive)

**L6 — `difficulty_system.gd` `_is_lower_tier` ambiguous return.**
Return a tri-state or emit a warning when either tier is unknown so callers can
distinguish "not lower" from "lookup failed".

**L7 — `supplier_definition.gd` `get_tier_data`.**
Add a `push_warning` when tier is not found so misconfigured supplier JSON is
visible at runtime rather than requiring callers to defensively check for empty
dicts.

**L8 — `store_selector_system.gd` silent scene-graph guards.**
Promote null returns that occur after steady-state initialization (as opposed to
those during scene transitions) to `push_warning` so wiring failures at
load-time are observable.
