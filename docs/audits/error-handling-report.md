## Changes made this pass

This pass continues the prior pass's posture (see prior changes table below).
Two additional `push_warning` sites were escalated to `push_error` because
their own docstrings claimed CI catches the regression — but `push_warning`
does not match CI's `^ERROR:` stderr grep
(`.github/workflows/validate.yml`), so the documented CI safety net was
broken. One site previously slated for escalation was kept at `push_warning`
because a test asserts the graceful-degradation fallback on purpose.

### This pass (2026-05-06 / §EH-09 – §EH-11)

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/scenes/ui/hud.gd` | 314–325 | `_open_close_day_preview` `CloseDayPreview child missing` escalated `push_warning` → `push_error`. Method docstring already promised CI would catch the wiring regression; only the severity was wrong. See §EH-09. |
| `game/scripts/systems/customer_system.gd` | 345–362 | `despawn_customer` null-payload + non-Customer cast guards escalated `push_warning` → `push_error`. Both branches are caller-bug invariants (typed signal handler, no test fixtures pass null/wrong-type). New block comment cites §EH-11. |
| `game/scenes/ui/inventory_panel.gd` | 349–365 | Empty-`store_id` warning kept at `push_warning` and the comment now records *why* it is not escalated: `test_inventory_panel.gd::test_refresh_with_empty_store_id_falls_back_safely` asserts the graceful "No active store" fallback, so an escalation would fail CI on a test that exercises the contract on purpose. See §EH-10. |

No behavior change beyond severity / comment text. Functions still return on
the bad branch with the same fallback; the only effect is that the two
escalated sites now fail CI's stderr scan when a real wiring regression
occurs, while the deliberately-tested fallback at §EH-10 stays diagnosable
without breaking its test.

### Prior pass (preserved)

Severity escalations from `push_warning` → `push_error` so the CI gut-tests
stderr scan fails the build when these conditions occur, instead of letting
the project ship with a silently-degraded Day-1 critical path or a malformed
UI/world contract:

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/autoload/objective_director.gd` | 95–132 | Three load-time content-validation warnings (non-Dictionary step, non-Array `steps`, Day-1 step-count mismatch) escalated to `push_error`. Comments updated to cite §1 of this report. |
| `game/autoload/objective_director.gd` | 137–151 | `pre_step` non-Dictionary warning escalated to `push_error`. |
| `game/scenes/world/game_world.gd` | 1080–1102 | `PlayerEntrySpawn.bounds_min` / `bounds_max` wrong-type warnings escalated to `push_error`. Method-level comment updated to cite §2. |
| `game/scenes/ui/inventory_panel.gd` | 533–546 | `_on_remove_from_shelf` non-shelf row-builder regression warning escalated to `push_error`. Comment updated to cite §3. |
| `game/scripts/components/register_interactable.gd` | 75–90 | `_fire_quick_sale` "customer at register without desired item" warning escalated to `push_error`. New comment cites §4. |

No behavior change beyond severity: in every case the function still returns
on the bad branch and still applies the same fallback (default footprint,
queue rejection, ignored click, fall-back rail copy). The only effect is that
the regression now fails CI's stderr scan instead of being silently downgraded
to a warning the operator would never see.

## Executive summary

- **Scope (this pass)**: 31 production files in the working tree (21 modified + 10 newly added under `game/`); tests excluded. The prior pass covered 15 files.
- **Findings inventoried (this pass)**: ~110 distinct error-handling sites across silent guards, warning vs. error severity, `has_method` / `has_signal` dynamic-call seams, and unchecked `signal.connect()` calls. The bulk overlap with the prior inventory; the new files (the 8 component interactables, `modal_panel.gd`, `close_day_confirmation_panel.gd`) added ~20 sites of the standard Interactable enabled/can_interact guard pattern plus the new ModalPanel push/pop contract.
- **Acted this pass (in source)**: 3 severity changes — 2 escalations (`hud.gd` CloseDayPreview missing, `customer_system.gd` despawn null/wrong-type) and 1 explicit downgrade-with-justification (`inventory_panel.gd` empty store_id, where a test asserts the warning-level fallback).
- **Acted prior passes (preserved)**: 5 severity escalations across 4 subsystems (objective_director, game_world bounds, inventory_panel remove handler, register_interactable FSM).
- **Justified this pass (in source)**: All 8 new component interactables follow the standard `Interactable.interact` contract (`if not enabled or not can_interact(by): return`); the base-class doc covers the silent-return semantics, so per-site annotations were not added. The new `ModalPanel` already self-documents its push/pop/cleanup `push_error` paths in its own header.
- **Posture verdict**: Acceptable. The repo's existing convention — `push_error` on owner-contract violations and `push_warning` on optional/test-seam paths — is consistently applied. The newly-added subsystems (component interactables, modal panel, close-day confirmation) follow the convention without introducing new silent-swallow patterns. After this pass, every Day-1-critical content/UI/state contract violation surfaces at the CI level, and the one place where a docstring promised CI-level surfacing without backing it with `push_error` (HUD CloseDayPreview missing) is now consistent.

| Severity | Count | Action taken |
|---|---|---|
| Critical | 0 | n/a |
| High | 7 | 5 prior-pass escalations preserved (§§1–4); 2 new escalations this pass (§§EH-09 / EH-11) |
| Medium | 1 | 1 explicit-downgrade with test-rationale comment (§EH-10) |
| Low | ~14 | Justified in code (existing §F-XX markers retained / extended) |
| Note | ~30 | Unchecked `signal.connect()` calls — see §5 |

## §1 — ObjectiveDirector content validation (HIGH)

`game/autoload/objective_director.gd` parses `res://game/content/objectives.json` at autoload time and feeds the Day-1 step chain that drives the entire first-time-player tutorial rail.

Pre-pass severity: `push_warning` for four content-authoring regressions:

1. Non-Dictionary entry inside `steps` (line 105 pre-pass)
2. Non-Array `steps` field (line 113 pre-pass)
3. Day 1 `steps` count != `DAY1_STEP_COUNT` (line 124 pre-pass)
4. Non-Dictionary `pre_step` field (line 145 pre-pass)

Risk lens: **reliability**. Each of these conditions silently disables the Day-1 step chain (`_day1_steps_available()` returns false) or, in the `pre_step` case, leaves the rail blank between `day_started` and the first `manager_note_dismissed`. The rail is the player's only on-screen tutorial guide on Day 1. A typo in `objectives.json` would have shipped a broken first-day experience whose only signal was a `WARNING:` line that no CI job parsed.

Action: escalated all four sites to `push_error`. The CI `gut-tests` job greps `^ERROR:` on stderr and fails the build on unrecognized push_error output (`.github/workflows/validate.yml` lines ~118–135). The default fallback (rail falls back to pre-sale / post-sale text) is preserved so production never crashes — but a regression now fails CI rather than shipping. No test exercises these malformed-input paths, so the change does not destabilize the existing suite.

## §2 — GameWorld player-bounds metadata (HIGH)

`game/scenes/world/game_world.gd::_apply_marker_bounds_override` (lines 1086–1102 post-pass) reads `bounds_min` / `bounds_max` metadata from the `PlayerEntrySpawn` marker on each store scene to clamp the walking player's reachable footprint.

Pre-pass severity: `push_warning` per side when the metadata key was present but the value was not a `Vector3`.

Risk lens: **data integrity / safety**. The method comment already documented the consequence: *"Falling silently through to the default footprint can let the player walk through walls in a store whose interior is smaller than the default bounds."* This is a content-authoring bug with player-visible exploit potential (clipping into geometry, escaping into out-of-bounds rendering). The author had already escalated from a fully silent fallback to a warning; this pass takes it the rest of the way to an error so CI catches the regression at build time.

Action: both `push_warning` calls escalated to `push_error`. The default footprint is still applied so the store remains playable. `null` (key absent) remains the documented opt-out and stays silent. No test passes wrong-type bounds metadata, so this is safe against the existing suite.

## §3 — InventoryPanel row-builder UI invariant (HIGH)

`game/scenes/ui/inventory_panel.gd::_on_remove_from_shelf` (lines 529–546 post-pass) is the click handler for the per-row Remove button. The button is gated upstream by `inventory_row_builder.add_remove_button`, which only attaches it when `item.current_location.begins_with("shelf:")`.

Pre-pass severity: `push_warning` when the handler ran for a non-shelf item.

Risk lens: **observability / data integrity**. Reaching this branch means the row-builder gating regressed and a click was offered for an item that lives in the backroom (or worse, has empty/malformed location). The handler refused to do anything, so a player would see "no response on click" — a well-known frustration vector and an extremely hard-to-diagnose production bug if it ever shipped.

Action: escalated to `push_error`. `test_inventory_panel.gd` exercises the normal shelf-removal flow with `current_location = "shelf:..."`, so the new error path is never hit by the test suite. A row-builder regression that re-introduced the bad gating would now fail CI immediately.

## §4 — RegisterInteractable Customer-FSM invariant (HIGH)

`game/scripts/components/register_interactable.gd::_fire_quick_sale` (lines 75–90 post-pass) handles the Day-1 single-press checkout. By the time it runs, `_pending_customer` has been set from `EventBus.customer_ready_to_purchase`, which the Customer FSM only emits when `_desired_item` is resolved.

Pre-pass severity: `push_warning` when the arrived customer had no desired item / definition.

Risk lens: **reliability**. This is a Customer-FSM invariant break: a customer cannot legitimately reach the register without a desired item under the documented protocol. A warning here would have allowed a broken FSM transition to ship as a "queue rejection" UX bug rather than the systemic state-machine fault it actually is.

Action: escalated to `push_error`. The fallback (`customer.reject_from_queue()`) is preserved so the queue self-recovers. The existing test suite always builds the customer with a valid `_desired_item`, so the new error path is never exercised by tests.

## §5 — Unchecked `signal.connect()` calls (NOTE)

Across the in-scope files, ~30 `signal.connect(...)` calls do not capture or check the returned error code. Examples: `event_bus.gd:919`, `objective_director.gd:55–67`, `interaction_ray.gd:44–46`, `interaction_prompt.gd:42–49`, `day_cycle_controller.gd:43–47`.

Risk lens: **observability**. In Godot 4, `Signal.connect()` returns `OK` on success and an error code on duplicate / invalid target / disconnected receiver. The idiomatic project pattern (consistent across the autoload roster) is to call `.connect()` without capturing the result, relying on `is_connected()` guards in the few places where double-connect is plausible (e.g. `close_day_confirmation_panel.gd:30`, `interaction_ray.gd:215`).

Decision: **justify, do not act**. Wrapping every `connect()` in a checked path would invert the project's idiom and add ~50 nearly-identical guard branches. The signal infrastructure (`EventBus` autoload) is itself authored once and well-tested, so the connect-time failure modes that warrant per-call hardening are already covered by the `is_connected` guards at the rare double-subscribe sites. Recommend revisiting only if a future incident traces back to a missing connection.

## §6 — Test-seam silent returns (LOW)

The following silent-return patterns are documented test seams and are kept as-is. Each carries an existing `§F-XX` reference at the call site that this pass leaves intact:

- `objective_director.gd:316–319` (§F-98) — Day-1 step state-machine race-guard.
- `objective_director.gd:336–338` (§F-99) — `tree == null` test seam mirrors §F-44 / §F-54.
- `game_world.gd:858–862` (§F-55) — silent return on GAME_OVER is intentional.
- `game_world.gd:872–875` (§F-105) — same GAME_OVER terminal-state guard.
- `game_world.gd:980–983` (§F-39) — `as Node3D` cast guard.
- `game_world.gd:1110–1114` (§F-46) — silent return when no `PlayerController` child exists.
- `game_world.gd:1195–1201` (§F-90) — Tier-2 init pattern for `store_state_manager`.
- `inventory_panel.gd:389–391` (§F-104) — null `_filter_row` test seam.
- `inventory_panel.gd:574–577` (§F-104) — null `SceneTree` test seam.
- `inventory_panel.gd:586–595` (§F-96) — empty `slot_id` rejection.
- `interaction_ray.gd:299` (§F-53) — dead-prompt audit reference.
- `interaction_ray.gd:359–366` (§F-108) — debug-build telemetry gate.
- `interaction_prompt.gd:131–137` (§F-44) — null-`InputFocus` test seam.
- `morning_note_panel.gd:138–143` / `:156–159` (§F-136) — `GameState` / autoload fallback.
- `day_cycle_controller.gd:141–145` and `:148–152` — `ObjectiveDirector` autoload fail-open documented in the function header (lines 137–140).

These all share the same shape: production runtime always provides the system being checked; bare-Node unit-test fixtures hit the silent path; the fallback (default value, no-op, generic copy) is the documented behavior.

## §7 — `has_method` dynamic-call seams (LOW)

Seven sites (`inventory_panel.gd:761`, `game_world.gd:149`, `day_cycle_controller.gd:145/152/186`, `morning_note_panel.gd:157`, `register_interactable.gd:102`) call `obj.has_method(...)` before `obj.call(...)`. These are deliberate decoupling between autoload and scene scripts — the typed import would create a circular dependency between the autoload roster and the scene tree.

Decision: **justify, do not act**. The pattern is consistent across the codebase and the call sites are stable; signature drift would be caught by GDScript's parser at edit time on the implementing class. No hardening warranted.

## §8 — `input_focus.gd` stack-depth leak (NOTE)

`game/autoload/input_focus.gd:127–133` warns (rather than errors) when the post-transition stack depth is greater than 1 — an upstream scene leaked a `push_context` without matching `pop`. The function header explicitly justifies this:

> A depth >1 post-transition means the prior scene leaked a push and is reported as a non-fatal warning so the leaking call site can be found.

The case for keeping a warning: the topmost frame still gates input correctly, so gameplay continues. Empty stack is the fatal case (`_fail` calls `push_error` + AuditLog.fail_check + ErrorBanner). Depth=1 is healthy; depth>1 is "diagnose me." The current split between fail (empty) and warn (over-deep) is correct.

Decision: **justify, do not act**. Keep the warning; the existing `MAX_STACK_DEPTH=8` assert in `push_context` is the hard cap.

## §EH-09 — HUD CloseDayPreview missing (HIGH)

`game/scenes/ui/hud.gd::_open_close_day_preview` (lines 318–326 post-pass) is
the click handler for the in-store HUD's "Close Day" button. The intended path
opens the `CloseDayPreview` modal so the player can review the day before
committing; the modal owns the `EventBus.day_close_requested` emit. The
fallback path emits the signal directly (the day still closes) but the modal
is gone.

Pre-pass: the function docstring already read *"the wiring regression is
logged so CI catches it"* — but the call used `push_warning`, which the CI
stderr scan in `.github/workflows/validate.yml` (`grep "^ERROR:"`) does not
match. The promised CI safety net was inert.

Risk lens: **reliability / observability**. `hud.tscn` ships with a
`CloseDayPreview` child; reaching the fallback means the scene was
edited without the modal. The day-close still works, but the player loses
the dry-run preview UX entirely — a silent UX regression that this pass
escalates to a CI failure.

Action: escalated `push_warning` → `push_error` and updated the docstring
to reference this section. No tests exercise the missing-preview path
(verified via grep: `_open_close_day_preview`, `CloseDayPreview child
missing`, `HUD._close_day_preview` — zero hits in `tests/`).

## §EH-10 — InventoryPanel empty store_id (MEDIUM, justified-not-acted)

`game/scenes/ui/inventory_panel.gd::_refresh_grid` (lines 349–365 post-pass)
is the panel-refresh entry point. The Day-1 contract (ISSUE-001) wires
`active_store_changed` so by the time the panel can be opened, GameManager
has an active store. Hitting the empty-`store_id` branch is a regression of
that wiring.

The docstring at this site reads similarly to §EH-09 — *"surface it loudly
so it shows up in CI rather than silently degrading to an empty panel"* —
which on initial read suggests a `push_error` escalation. **However**,
`tests/gut/test_inventory_panel.gd::test_refresh_with_empty_store_id_falls_back_safely`
deliberately sets `panel.store_id = ""` and asserts the graceful "No active
store" fallback rendering. Escalating to `push_error` would fail CI on a
test that exercises the contract on purpose.

Action: **kept at `push_warning`**, updated the comment to (a) name the
test that exercises this branch, (b) explain why escalation is incorrect,
and (c) cite this section. The docstring's "shows up in CI" wording now
accurately means "appears in CI logs as a warning, not as a build failure."

## §EH-11 — CustomerSystem despawn caller-bug invariants (HIGH)

`game/scripts/systems/customer_system.gd::despawn_customer` (lines 345–362
post-pass) is the sole path that removes a customer from `_active_customers`
and increments `_leave_counts`. Its two upfront guards — `customer_node ==
null` and the `as Customer` cast — are caller-bug invariants. The function
is wired through `_on_customer_despawn_requested(customer: Customer)` (a
typed signal handler) and through internal timeout-cleanup paths that all
hold typed `Customer` references. No test fixture passes `null` or a non-
`Customer` node (verified: zero hits for `despawn_customer(null` or non-
`Customer` despawn calls under `tests/`).

Pre-pass: both guards used `push_warning` and silently returned. A real
caller bug would have:
1. Skipped the `_active_customers.erase(customer)` accounting → leaked
   reference, biased `get_active_customer_count`.
2. Skipped `_increment_leave_count` → undercounted day-summary "failed
   customer" buckets.
3. Skipped the `customer_left` signal → downstream subscribers
   (reputation, performance reports) lose an event.

Risk lens: **reliability / data integrity**. Not security or auth, but a
silent count drift that would show up only as "the day-summary numbers
look off" — exactly the hard-to-diagnose production bug class this audit
targets.

Action: replaced both `push_warning` calls with `push_error` and added a
shared block comment at the function head citing this section. The fallback
behavior (silent return) is preserved so the customer state machine self-
recovers; only the diagnostic level changes.

## Escalations

None. All findings were either acted on (§§1–4, §§EH-09 / EH-11),
explicitly justified-not-escalated with test-bound rationale (§EH-10), or
justified at the call site (§§5–8).
