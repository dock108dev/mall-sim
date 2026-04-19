# Abend Handling Audit

Date: 2026-04-19  
Scope: `game/autoload/`, `game/scripts/core/`, `game/scripts/systems/`, `game/scripts/stores/`

---

## Executive Summary

The codebase has a broadly sound, layered error-handling strategy:

- **Boot errors** fail loud — `push_error` + visible error panel; content issues cannot be silently skipped.
- **Save/load errors** use a structured result dictionary (`ok`, `reason`, `data`) and always emit `EventBus.save_load_failed` so UI can respond.
- **Audio errors** use warn-once helpers to prevent log spam for missing assets.
- **Settings parse errors** fall back to safe defaults and log the fallback.
- **System-dependency errors** in autoloads log via `push_error` before returning false.

No broad try/catch-style swallowing exists (GDScript has no exception handling). No silent retry loops or circuit breakers were found — appropriate for a single-player desktop game. The dominant pattern is **"log and bail"** rather than silent swallow.

**Fixes applied this cycle (in-place):**
- **C1 (High, prior cycle):** `customer_system.gd` — missing `return` after null-scene error let initialization continue; fixed.
- **C2 (Medium, prior cycle):** `pack_opening_system.gd` — silent card-slot substitutions; warnings added.
- **C3 (Medium, this cycle):** `data_loader.gd` — unrecognized content type silently discarded; warning added.
- **C4 (Medium, this cycle):** `audio_manager.gd` — dead null guards removed; pool-saturation `_warn_once` added.
- **C5 (Medium, this cycle):** `checkout_system.gd` (autoload NPC path) — null `desired_item` logged.

---

## Findings Table

| # | File | Line(s) | Pattern | Severity | Status |
|---|------|---------|---------|----------|--------|
| H1 | `game/scripts/systems/customer_system.gd` | 98–102 | `push_error` with no `return` — execution continued into `_connect_signals()` with null `_shopper_scene` | **High** | Fixed (prior cycle) |
| M1 | `game/scripts/systems/pack_opening_system.gd` | 285–294 | Rare/energy-slot roll failures silently substituted a random common card | **Medium** | Fixed (prior cycle) |
| M2 | `game/scripts/systems/ending_evaluator.gd` | 419–423 | Wrong ending-count logged but execution continues with mismatched list | **Medium** | Open |
| M3 | `game/scenes/world/game_world.gd` | 1108–1125 | `_validate_load_state` logs errors but does not halt or degrade the session | **Medium** | Open |
| M4 | `game/autoload/data_loader.gd` | 239–240 | Unrecognized content file silently discarded (empty content type) | **Medium** | Fixed (this cycle) |
| M5 | `game/autoload/audio_manager.gd` | 78–79, 93–95 | Null guards on `_get_available_player()` are dead code; pool saturation steals silently | **Medium** | Fixed (this cycle) |
| M6 | `game/autoload/checkout_system.gd` | 32–35 | Customer with null `desired_item` emits `customer_left_mall` with no log | **Medium** | Fixed (this cycle) |
| L1 | `game/scripts/systems/secret_thread_system.gd` | 449–451 | `push_error("UnlockSystem not found")` has no `return`; `thread_completed` emitted without granting unlock | **Low** | Open |
| L2 | `game/scripts/systems/testing_system.gd` | 50 | `push_warning("already testing")` has no `return`; duplicate `start_test` can double-start | **Low** | Open |
| L3 | `game/autoload/difficulty_system.gd` | 210–211 | `_is_lower_tier` returns `false` silently when tier index is -1 — caller cannot distinguish "not lower" from "lookup failed" | **Low** | Open |
| L4 | `game/resources/supplier_definition.gd` | ~26 | `get_tier_data` returns `{}` for unknown tier with no log | **Low** | Open |
| L5 | `game/scripts/stores/store_selector_system.gd` | 119–364 | Twelve silent `return` guards on scene-graph lookups | **Low** | Open |
| L6 | `game/scripts/debug/debug_commands.gd` | 13, 17 | `add_cash()` and `set_time()` are stub no-ops — violate "finish before feature" | **Low** | Open |
| L7 | `game/autoload/data_loader.gd` | 237–238 | `personality_data` type intentionally discarded without explanation | **Low** | Note added (this cycle) |
| N1 | `game/autoload/settings.gd` | 165–171 | Parse failure falls back to defaults + push_warning | Note | Acceptable |
| N2 | `game/autoload/audio_event_handler.gd` | — | Null store_def falls back to hallway music | Note | Acceptable |
| N3 | `game/autoload/unlock_system.gd` | 62–65 | Unknown unlock IDs in save data discarded with push_warning | Note | Acceptable |
| N4 | `game/autoload/market_trend_system.gd` | — | Unknown category returns 1.0 neutral multiplier with push_error | Note | Acceptable |
| N5 | `game/autoload/difficulty_system.gd` | — | Unknown modifier returns 1.0 / false with push_error | Note | Acceptable |
| N6 | `game/scripts/characters/shopper_ai.gd` | — | Null waypoint / animation guards return silently | Note | Acceptable during transitions |
| N7 | `game/autoload/checkout_system.gd` | 27–28 | Duplicate-processing ID guard is silent | Note | Acceptable (idempotency) |
| N8 | `game/autoload/checkout_system.gd` | 42–58 | No-stock / over-budget / probability-fail emit `customer_left_mall` silently | Note | Acceptable (normal game events) |
| N9 | `game/scripts/core/save_manager.gd` | 987–990 | `_fail_load` always warns + emits `save_load_failed` signal | Note | Acceptable |
| N10 | `game/autoload/game_manager.gd` | 80–84 | Invalid state transitions warn and return false | Note | Acceptable |

---

## Detailed Findings

### H1 — `customer_system.gd`: Missing return after null-scene error (Fixed, prior cycle)

`push_error` was called for a missing `_shopper_scene` resource but execution fell through to `_connect_signals()`, which dereferenced the null and caused silent NPC spawn failures at runtime.

**Fix:** Added `return` after the `push_error`.

---

### M1 — `pack_opening_system.gd`: Silent card-slot substitution (Fixed, prior cycle)

Rare-slot and energy-slot roll failures silently substituted a random common card with no diagnostic. Misconfigured card pool JSON would produce wrong packs with no observable cause.

**Fix:** Added `push_warning` on both fallback branches.

---

### M2 — `ending_evaluator.gd`: Wrong ending count logged, execution continues (Open)

```gdscript
if _ending_definitions.size() != 13:
    push_error("EndingEvaluator: expected 13 endings, got %d" % ...)
# execution continues with the mismatched list
```

A wrong ending can trigger silently. The 13 is a hardcoded magic number that will break whenever endings are added or removed.

**Remediation:** Remove the magic-number guard; verify non-empty list and that all expected IDs from the registry are present. Consider a hard stop (or emit `content_load_failed`) rather than continuing.

---

### M3 — `game_world.gd`: Session validation logs but does not halt (Open)

`_validate_load_state` and `_validate_new_game_state` iterate errors and `push_error` each, but the session starts regardless of validation failures. A game can begin with an inconsistent state snapshot.

**Remediation:** Emit `EventBus.game_validation_failed` or degrade to an error panel when validation errors are present, consistent with boot's content-error handling.

---

### M4 — `data_loader.gd:239–240`: Unrecognized content type silently discarded (Fixed, this cycle)

```gdscript
if content_type.is_empty():
    return  # ← file silently skipped, no diagnostic
```

`_detect_type()` returns `""` when a JSON file's path doesn't match any known directory or filename pattern. A developer adding content to an unexpected directory gets zero feedback.

**Fix:** Replaced silent return with `push_warning("DataLoader: unrecognized content file, skipping: %s" % path)`.

---

### M5 — `audio_manager.gd:78–79, 93–95`: Dead null guards + silent pool saturation (Fixed, this cycle)

`_get_available_player()` never returns `null` — it falls through to a round-robin steal of an already-playing player when all 8 SFX slots are busy. The null guards in `play_sfx` and `_play_sfx_stream` are unreachable dead code, and pool saturation is completely unobservable.

**Fix:** Removed dead null guards; added `_warn_once("sfx_pool_full", ...)` inside `_get_available_player()` for the pool-exhaustion branch.

---

### M6 — `checkout_system.gd` (autoload): Null desired_item silently emits customer_left (Fixed, this cycle)

```gdscript
if not desired_item or not desired_item.definition:
    _processing_ids.erase(customer_id)
    EventBus.customer_left_mall.emit(npc, false)
    return false  # ← indistinguishable from normal game-state exit
```

`customer_left_mall(npc, false)` is also emitted for no-stock and over-budget exits. A null `desired_item` at checkout time represents an unexpected customer-AI state (customer spawned without a goal or definition load failed) that should be distinguishable from normal game events.

**Fix:** Added `push_warning("CheckoutSystem: customer %s has no desired item or definition" % customer_id)` before the return.

---

### L1 — `secret_thread_system.gd:449–451`: Missing return after unlock failure (Open)

```gdscript
if not UnlockSystemSingleton:
    push_error("SecretThreadSystem: UnlockSystem not found")
# falls through to emit thread_completed — thread marked complete without reward
```

A thread gets marked complete without granting its unlock. The player loses the reward silently.

**Remediation:** Add `return` after the `push_error`. Thread should remain in-progress; the error surfaces in the log.

---

### L2 — `testing_system.gd:50`: Missing return in duplicate-test guard (Open)

```gdscript
if _active_test_item != null:
    push_warning("TestingSystem: already testing '%s'" % ...)
    # no return — second start_test can double-start
```

**Remediation:** Add `return` after the `push_warning`.

---

### L3 — `difficulty_system.gd:210–211`: Ambiguous false from `_is_lower_tier` (Open)

`_is_lower_tier` returns `false` when either tier index is `-1` (unknown tier), indistinguishable from "tier is not lower". Callers cannot distinguish the failure case.

**Remediation:** Return a tri-state or emit a warning when either tier is unknown.

---

### L4 — `supplier_definition.gd`: Silent empty dict from `get_tier_data` (Open)

`get_tier_data` returns `{}` for unknown tiers without logging. Misconfigured supplier JSON is invisible at runtime.

**Remediation:** Add `push_warning` when tier is not found.

---

### L5 — `store_selector_system.gd:119–364`: Twelve silent scene-graph guards (Open)

Twelve consecutive unlogged `return` guards on scene-graph node lookups are legitimate during scene transitions but invisible if wiring is wrong at steady-state.

**Remediation:** Distinguish transition-time vs. steady-state guards; promote steady-state null guards to `push_warning`.

---

### L6 — `debug_commands.gd:13,17`: Stub no-ops in debug tooling (Open)

`add_cash()` and `set_time()` log "not yet wired" and do nothing. Silent no-ops in debug tooling make debugging harder. Violates "finish before feature" design principle.

**Remediation:** Implement or delete.

---

### L7 — `data_loader.gd:237–238`: `personality_data` silently discarded (Note added, this cycle)

```gdscript
if content_type == "personality_data":
    return  # intentional — loader for this type not yet implemented
```

Added inline comment so the intentional discard is visible to future developers. The content file should either be loaded or deleted.

---

## Categorization Summary

| Category | Count | Items |
|----------|-------|-------|
| Fixed in-place (prior cycle) | 2 | H1, M1 |
| Fixed in-place (this cycle) | 3 | M4, M5, M6 |
| Note added (this cycle) | 1 | L7 |
| Must fix — correctness | 2 | L1, L2 |
| Should fix — data integrity | 2 | M2, M3 |
| Should fix — observability | 3 | L3, L4, L5 |
| Stub methods to delete/implement | 1 | L6 |
| Acceptable as-is | 10 | N1–N10 |

---

## Remediation Plan

### P1 — Must fix (correctness)

**L1 — `secret_thread_system.gd`:** Add `return` after `push_error("UnlockSystem not found")` so `thread_completed` is not emitted without granting the unlock.

**L2 — `testing_system.gd`:** Add `return` after `push_warning("already testing")` to prevent double-start.

### P2 — Should fix (data integrity)

**M2 — `ending_evaluator.gd`:** Remove the `!= 13` magic-number check. Validate that `_ending_definitions` is non-empty and all expected IDs from the registry are present. Fail loud (emit `content_load_failed`) rather than continuing with a mismatched list.

**M3 — `game_world.gd`:** Emit `EventBus.game_validation_failed` or show an error panel when `_validate_load_state` or `_validate_new_game_state` finds errors, consistent with how boot handles content errors.

### P3 — Should fix (observability)

**L3 — `difficulty_system.gd`:** Return a tri-state or emit a warning when `_is_lower_tier` receives an unknown tier index.

**L4 — `supplier_definition.gd`:** Add `push_warning` in `get_tier_data` when the requested tier is absent.

**L5 — `store_selector_system.gd`:** Audit scene-graph guards; promote those that run at steady-state to `push_warning`.

**L6 — `debug_commands.gd`:** Implement `add_cash` and `set_time` or delete the file.

### P4 — Nice to have (defensive)

**M4 follow-up:** Confirm `personality_data` discard is intentional — delete `personalities.json` or implement the loader.

**`content_schema.gd`:** Audit all call sites of `validate()` to confirm the returned errors array is always checked and emitted; do not discard the return value silently.
