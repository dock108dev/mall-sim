## Changes made this pass

This pass ran on top of an in-flight working-tree refactor that already
constitutes a substantial cleanup of the close-day flow, modal-focus
contract, error-handling discipline, and hidden-thread interactable layer.
That refactor is documented in three sibling reports:

- `docs/audits/ssot-report.md` — close-day SSOT consolidation (HUD /
  MallOverview soft-gate dialogs collapsed into `CloseDayConfirmationPanel`
  + `EventBus.day_close_confirmation_requested` / `day_close_confirmed`
  + `ObjectiveDirector.can_close_day()`).
- `docs/audits/error-handling-report.md` — `push_warning` → `push_error`
  escalations on Day-1 critical-path content authoring regressions.
- `docs/audits/security-report.md` — bbcode escape on the boot error label,
  read-time clamps on hand-editable cfg fields, length caps on
  save-derived id strings.

This cleanup pass therefore had a narrow remaining surface: the
SSOT/error-handling/security passes already removed the four legacy
`CloseDayConfirmDialog` nodes, the duplicated soft-gate code paths in
HUD/MallOverview, and the per-panel `_focus_pushed` / `_push_modal_focus`
/ `_pop_modal_focus` / `_reset_for_tests` quartet (now inherited from the
new `ModalPanel` base class).

What this pass added in-place:

### Consistency edits

| File | Lines | What changed |
|---|---|---|
| `game/autoload/audio_event_handler.gd` | 178–182 | Added a 3-line intent comment to `_on_store_exited` so its empty `pass` body matches the documented-empty pattern of its sibling `_on_store_entered`. The handler is intentionally a claim point — hallway transitions are driven by `_on_storefront_exited` and `_on_active_store_changed`, not by `store_exited` — but only the entered side documented this. |

No other in-scope cleanup edits were made by this pass. The findings table
below documents what was inspected and intentionally not changed.

## Inspected and intentionally not changed

### EventBus Phase 1 mirrors and `emit_*` wrappers

`signal store_ready` / `store_failed` / `scene_ready` /
`input_focus_changed` / `camera_authority_changed` and their five
`emit_*` wrappers (`game/autoload/event_bus.gd:13–22, 975–992`) have no
production listeners — `SceneRouter`, `StoreDirector`, `InputFocus`, and
`CameraAuthority` own these signals directly and listeners (e.g.
`InventoryPanel`, `MallHub`) hook the owners, not the bus.

**Why kept:**

1. `tests/unit/test_event_bus.gd` exercises every wrapper and asserts the
   declared arity (ISSUE-022 contract).
2. `event_bus.gd:9–12` documents these as Phase 1 mirrors specifically so
   "other systems can listen through the bus without reaching into owners
   directly" — the contract is intentional, even though no production
   listener has subscribed yet.
3. `tests/gut/test_eventbus_signal_compat.gd` allowlists exactly these
   five mirrors as `KNOWN_ORPHAN_SIGNALS` with documented reasons (lines
   16–23). Removing them would require coordinated edits to that
   allowlist plus the unit-test file.

This is justify-not-act: the public-API surface and its tests are the
SSOT, not the live listener count.

### `morning_note_panel.gd extends ModalPanel`

The prior pass flagged this for action. `MorningNotePanel.open()` and
`close()` deliberately do **not** call `super.open()` /
`super.close()`, never invoke `_push_modal_focus` /
`_pop_modal_focus`, and the class docstring states "intentionally does
NOT claim CTX_MODAL on InputFocus". The inheritance is hollow.

**Why kept this pass:**

`docs/audits/ssot-report.md` (this branch's SSOT pass) explicitly
declares `MorningNotePanel` as a `ModalPanel` subclass for the
"single owner of CTX_MODAL contract" SSOT (table row 5):
"`CloseDayConfirmationPanel`, `MorningNotePanel`, and
`InventoryPanel` all inherit it." Backing the inheritance out would
contradict the SSOT pass's own table. Reverting would also strip a
forward-looking lifecycle hook surface (subclasses that *do* want
`super.open()` get a single override point). Acting on this would
require a coordinated edit to the SSOT report — out of scope for this
narrower cleanup pass.

### `EmploymentSystem.TRUST_DELTA_MANAGER_CONFRONTATION` /
`REASON_MANAGER_CONFRONTATION`

Public constants on `game/autoload/employment_system.gd:40, 45` are
referenced only by `tests/gut/test_employment_system.gd` —
no production caller fires the manager-confrontation reason yet.

**Why kept:**

These constants are part of the autoload's documented public API surface
and are exercised by a contract test
(`test_manager_confrontation_decrement_via_apply_trust_delta`). Removing
them would require deleting a passing test that pins the behavior and
would force the eventual confrontation handler to reintroduce both. The
"public API exists ahead of its first caller" pattern is consistent with
how `apply_trust_delta`'s other reason families landed.

### `EventBus.queue_advanced` listeners

`queue_advanced` is emitted from `queue_system.gd` and
`checkout_system.gd` (5 emitters total) but has no production listener;
only test files connect.

**Why kept:**

The signal still drives the test-only contract that `RegisterInteractable`
and the queue subsystems share. Removing the signal would require
rewriting those tests against direct system polling, which would be a
test-architecture change unrelated to cleanup.

### `EventBus.manager_warning_note_requested`

Emitted from `shift_system.gd:233, 237` with no production listener.
The handler comment at `shift_system.gd:230–232` reads "ISSUE-005 will
own the manager note panel; until then this is a forward signal so the
panel can wire up at request time." Verified that ISSUE-005's
`MorningNotePanel` consumes the *different* signal `manager_note_shown`,
so this comment is still accurate — the wiring hasn't happened.

**Why kept:**

The forward-reference comment is current — not stale — and the signal
remains the documented integration point for the future wiring.

## Files still >500 LOC

Carried forward from the prior pass with no new changes. Each entry
names a concrete extraction the next pass could perform, or a
justification for the current size.

| File | LOC | Plan or justification |
|---|---|---|
| `game/scenes/world/game_world.gd` | ~1665 | **Justification** — GameWorld scene root runs the five named init tiers documented in `docs/architecture.md`. Tiers are colocated by design so the readiness ordering reads top-to-bottom in one file. Already factored into `initialize_tier_1_data` … `initialize_tier_5_meta`. **Future split**: extract Tier 5 meta wiring (perf manager, ambient moments, ledger, day cycle controller) into `GameWorldMetaWiring` once that block grows. |
| `game/autoload/event_bus.gd` | ~1000 | **Justification** — single-source signal hub per `docs/architecture/ownership.md` row 10. Already organized by topic with section banners. **Future split**: extract `emit_*` wrappers + day-end summary helper into a sibling `EventBusHelpers` autoload — the only non-signal-declaration lines. |
| `game/scenes/ui/inventory_panel.gd` | ~931 | **Justification** — already factored into `InventoryShelfActions`, `InventoryFilter`, `InventoryRowBuilder`. The `ModalPanel` extraction in this branch already removed five duplicated focus-bookkeeping methods (~30 LOC) without touching the rest. What remains is the panel lifecycle, signal wiring, modal-focus contract, and grid refresh. |
| `game/scripts/stores/retro_games.gd` | ~870 | **Justification** — already factored into `RetroGamesHolds` and `RetroGamesAudit`. The branch's SSOT pass removed the dead `_refresh_checkout_prompt` block (~70 LOC). Remaining surface is store-controller scaffolding (lifecycle hooks, scene wiring, F3 debug toggle, day-1 quarantine, store actions). **Future split**: extract `_wire_zone_artifacts` plus the per-artifact `_on_*_interacted` handlers into `RetroGamesArtifacts` once the new hidden-thread artifact set adds enough handler bulk to push that block past ~150 LOC. |
| `game/scripts/characters/customer.gd` | ~887 | **Justification** — Customer FSM root. Each `_process_*` arm corresponds to one `State` enum value. `CustomerAnimator`, `CustomerCustomization`, `CustomerNavigationProfile` already extracted. What's left is the FSM core. |
| `game/scripts/stores/shelf_slot.gd` | ~545 | **Justification** — single `Interactable` subclass owning the slot's display, prompt, placement-mode visuals, focus-label, empty-ghost, and category-color tinting. Just past the 500 cutoff. The new always-on `EmptyGhost` indicator added in this branch (≈30 LOC under `_ensure_empty_ghost` / `_update_empty_indicator`) is the marginal addition. |
| `game/scripts/systems/customer_system.gd` | ~980 | **Justification** — single owner of the customer-spawn / despawn / pool lifecycle. The branch's parent-resolution work added `_resolve_npc_container` + reparenting safety (~25 LOC), justified by the navigation-region ancestor lookup contract. |
| `game/scripts/systems/checkout_system.gd` | ~996 | Inspected only — under the 1000-LOC bar. No action. |
| `game/scripts/systems/inventory_system.gd` | ~935 | Inspected only — single owner of inventory mutations per `ownership.md` row 8. No clean split. |
| `game/scripts/systems/day_cycle_controller.gd` | ~526 | Listed because the branch's confirmation-gate path lifted it past 500. The new `_on_day_close_confirmed` / `_can_close_day` / `_resolve_close_blocked_reason` block is ~40 LOC and is the SSOT pass's intentional centralization. No action. |

## Verification

- `bash tests/run_tests.sh` was run end-to-end on the working tree.
  GUT result: **5569 passing / 14 failing / 31 risky** out of 5614
  collected. All shell validators pass:
  `validate_translations.sh`, `validate_single_store_ui.sh`,
  `validate_tutorial_single_source.sh`, plus the SSOT and Issue-009
  / Issue-023 sub-validators.
- The 14 failing tests cluster in three new test files added by the
  in-flight WIP (`test_day_close_confirmation_gate.gd`,
  `test_hud_zero_state_hint.gd`,
  `test_register_interactable.gd`,
  `test_hidden_thread_interactables.gd`,
  `test_eventbus_signal_compat.gd`) and all involve scenes/signals
  introduced by the SSOT pass that have not yet finished wiring. They
  predate this pass — the only edit this pass made was the 3-line
  comment in `audio_event_handler.gd`, which does not touch any of
  the failing test files.

## Escalations

None. The single in-scope edit is acted on; everything else is
explicitly justified above with a pointer to the SSOT / public-API /
test contract that pins the current shape.
