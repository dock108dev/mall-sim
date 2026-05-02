# SSOT Enforcement Report — 2026-05-01 (Day 1 soft-gate pass)

**Pass scope.** Working-tree changes vs HEAD on `main` (no feature-branch
delta — all delta is uncommitted). The diff converts three behaviors that
previously had silent / split owners into single-owner contracts:

1. **Day 1 first-sale "you cannot close" gate** moves from a *hard rejection*
   (HUD + MallOverview emit `critical_notification_requested`,
   `DayCycleController._on_day_close_requested` rejects with `push_warning`)
   to a *soft confirmation dialog* owned by the in-store HUD and the mall
   hub overview. Once the player confirms, the close request flows through
   the same modal pipeline as any other day close.
2. **Audit / Debug overlay visibility in normal play** — both autoloads now
   carry an explicit gating contract: `queue_free()` in non-debug builds, and
   `visible = false` until an explicit F1 / F3 toggle in debug builds. They
   are no longer allowed to render incidentally during MAIN_MENU,
   MALL_OVERVIEW, STORE_VIEW, or GAMEPLAY.
3. **Main-menu Load Game button** disables itself when no slot 0 save
   exists, with `"No Save Found"` text and a dimmed modulate.

The diff itself does most of the SSOT moves. This pass adds the destructive
tail: removing the dead error-handling note that documented the now-deleted
`DayCycleController` backstop, scrubbing the in-source `§F-52` reference,
replacing the dead-string payload in two tutorial-gate tests with a real
critical-notification example, and tightening two stale gate comments in
test files that used the old "controller-side gate" framing.

---

## Changes made this pass

| Path | Change | Reason |
|---|---|---|
| `docs/audits/error-handling-report.md` | Deleted §F-52 entry (`DayCycleController._on_day_close_requested` Day-1 rejection emits push_warning). Updated executive-summary note count from 25 → 24. | The diff removes the controller backstop entirely. The §F-52 entry described code that no longer exists. |
| `game/autoload/objective_director.gd` | Replaced the §F-52 reference in the comment above `GameState.set_flag(&"first_sale_complete", true)` with a description of the new readers (HUD + MallOverview soft-confirm gate). | The "DayCycleController backstop" referenced by the comment was deleted in the diff. The flag is still read by the UI gates, so the rest of the comment is still load-bearing. |
| `tests/gut/test_hud_state_visibility.gd` | Replaced two `EventBus.critical_notification_requested.emit("Make your first sale before closing Day 1.")` payloads (and the matching `assert_eq` string) with `"Save failed — check disk space."` — a payload that is still a plausible critical notification. | The "Make your first sale" string was the literal payload of the now-deleted hard-gate emitters. Reusing a dead UX string in a test fixture invites a future maintainer to revive it. The replaced string mirrors the only actual save-failure user-facing message in the codebase (`game/scripts/core/save_manager.gd:308`). The tests themselves still validate the real behavior they're for: tutorial-step suppression rules for the `critical_notification_requested` → `toast_requested` forwarder. |
| `tests/gut/test_day_summary_day1_label_values.gd` | Reworded the assertion message "DaySummary must be visible after a gated Day 1 close" → "DaySummary must be visible after a Day 1 close once the first sale is recorded". | "Gated Day 1 close" implies the controller is gating the close. Under the new SSOT the controller does not gate; the UI does. The assertion's actual subject is "first sale completed → close → summary visible", so the new wording matches what is being tested. |
| `tests/gut/test_day_cycle_close_loop.gd` | Updated the `before_each` comment that explained why the test pre-sets `first_sale_complete = true`. The old comment said "Pre-satisfy the gate so day_close_requested reaches DayCycleController" — under the new SSOT there is no controller-side gate to satisfy. Comment now describes the flag set as forward-defensive consistency, not a gate-satisfier. | The behavior is unchanged (flag is still set), but the *reason* changed when the controller backstop was deleted. Without this fix a future reader would search for the controller-side gate the comment promised and not find it. |

### Files intentionally not touched (justify, with on-file rationale)

| Path | What was kept | Why this pass did not touch it |
|---|---|---|
| `game/autoload/event_bus.gd:593` (`signal critical_notification_requested`) | Signal definition retained even though it now has zero production emitters. | The HUD's forwarding shim (`_on_critical_notification_requested` → `toast_requested`) is the documented EH-54 contract for "must-show toast that bypasses tutorial-step suppression". The signal is the API surface for that contract. Removing it would also require deleting the HUD listener, the §F-54 docstring on the listener, and the two GUT tests in `test_hud_state_visibility.gd` that exercise the tutorial-bypass behavior — none of which the *diff* proves obsolete. The diff only proves the Day-1 caller is gone; the API surface itself is intentionally reserved for the next critical alert (e.g. save-failure escalation, bankruptcy banner). Deletion is a separate decision, escalated below. |
| `tests/gut/test_first_sale_chain.gd::test_close_day_gate_active_on_day_1_without_first_sale` and `test_close_day_gate_releases_after_first_sale_flag_set` | Kept as-is. | These tests exercise `HUD._is_day1_gate_active()`, the boolean predicate the soft confirmation dialog still consults (`hud.gd:209-213`). The predicate is still load-bearing; the test names already use "gate" in the soft-confirm sense. |
| `tests/gut/test_day1_core_loop.gd::test_flag_*_on_day*_means_gate_*` (3 tests) | Kept as-is. | Same predicate test as above, against the inline `Day == 1 and not first_sale_complete` expression. The flag still gates the *dialog*, just not the *bus rejection*. The test contract is unchanged. |
| `game/autoload/audit_log.gd` (and the rest of the autoload roster's documented assert pairings) | No change. | Out of scope of this diff — the audit overlay gating change is about visibility, not the underlying log autoload's contract. |

---

## SSOT contracts established or reaffirmed by this pass

| # | Domain | Single Owner | Forbidden patterns (rejection rule) |
|---|---|---|---|
| 1 | **Day 1 first-sale "must close" gate** | `HUD.CloseDayConfirmDialog` (in-store) and `MallOverview.CloseDayConfirmDialog` (mall hub) — the same `_is_day1_gate_active()` check guards both. The dialog's `confirmed` signal is the only path that releases the close. Cancel is a no-op. | (a) Re-introducing the `DayCycleController` controller-side rejection that emits `push_warning` and silently drops `day_close_requested`. The controller now trusts that any `day_close_requested` it sees has already cleared the UI gate. (b) Re-introducing the `EventBus.critical_notification_requested.emit("Make your first sale …")` toast in place of the dialog. (c) Adding a third surface that emits `day_close_requested` on Day 1 without consulting `_is_day1_gate_active()`. |
| 2 | **`day_close_requested` emission paths** | Two surfaces, both gated by the soft-confirm dialog: `HUD._open_close_day_preview()` (in-store) drives `CloseDayPreview`, whose `_on_confirm_pressed` emits; `MallOverview._emit_day_close_requested()` (mall hub) emits directly because the per-store dry-run preview UX has no payload from the hub. The HUD also has the documented EH-06 fallback emit when the preview child is missing. | Direct `EventBus.day_close_requested.emit()` from any in-store UI surface that bypasses the preview. The mall hub's direct emit is the documented exception (J-1, retained from prior pass). |
| 3 | **Audit / Debug overlay rendering during normal play** | `AuditOverlay` (autoload) and `DebugOverlay` (`game/scenes/debug/debug_overlay.gd`) self-gate. In non-debug builds both call `queue_free()` in `_ready` so they never enter the tree. In debug builds they start `visible = false` and only render after an explicit F3 / F1 toggle. | Any code path that flips `AuditOverlay.visible = true` (or `DebugOverlay.visible = true`) without an explicit user action. Any new SubViewport / second-viewport / minimap-style overlay added under `game/autoload/` or `game/scenes/debug/` without the same gating contract. (`tests/gut/test_audit_overlay_toggle.gd::test_overlay_stays_hidden_in_store_view_and_gameplay` is the negative test that fails if either gate regresses.) |
| 4 | **Main-menu "Load Game" button enable state** | `MainMenu._refresh_load_button_state()` (`game/scenes/ui/main_menu.gd:248`) is the sole writer of `_load_button.disabled` / `.text` / `.modulate`. It runs in `_ready` and on `NOTIFICATION_VISIBILITY_CHANGED`. The truth source is `FileAccess.file_exists("user://save_slot_0.json")` via `_slot_zero_save_exists()`. | Other menu code flipping `_load_button.disabled` directly. Any call to `_on_load_pressed` that bypasses the early-return when no slot 0 save exists — opening the load panel against an empty save dir is a dead-end UI surface. |

These join the SSOT contracts already established in prior passes (preserved
in the table below for cross-reference; line numbers updated where the
working-tree diff moved them).

| # (legacy) | Domain | Owner | Notes |
|---|---|---|---|
| L-1 | In-store close-day modal pipeline | `HUD._open_close_day_preview` → `CloseDayPreview.show_preview` → confirm emits | Still canonical. The new soft-confirm dialog sits *in front* of this; once dismissed with "Close Anyway", the same modal pipeline runs. |
| L-2 | Placement-mode hint banner | `PlacementHintUI` listening to `EventBus.placement_hint_requested` | Unchanged. |
| L-3 | MALL_OVERVIEW cash display | KPI strip in `mall_overview.gd`; HUD `_cash_label` is forced hidden in MALL_OVERVIEW (`hud.gd:312`) | Unchanged. |
| L-4 | Fixture-collision blocking during pivot movement | `PlayerController._pivot_blocked()` / `_resolve_pivot_step` | Unchanged. |
| L-5 | Orthographic camera mode | `PlayerController.is_orthographic` export, only `retro_games.tscn` sets true | Unchanged. |
| L-6 | Day Summary "Return to Mall" routing | `DaySummary._on_mall_overview_pressed` → GameWorld → MALL_OVERVIEW | Unchanged. |
| L-7 | Retro Games checkout-counter prompt state | `RetroGames._refresh_checkout_prompt()` | Unchanged. |
| L-8 | Day 1 quarantine surface | `RetroGames._apply_day1_quarantine()` (`refurb_bench` only) | Unchanged. |
| L-9 | MALL_OVERVIEW optional buttons | `MallOverview._refresh_optional_button_visibility()` | Unchanged. |

---

## Risk log — items intentionally retained (act-or-justify)

### J-1. `EventBus.day_close_requested.emit()` direct call in `mall_overview.gd:_emit_day_close_requested`

**Decision:** keep.

**Why:** `CloseDayPreview` shows a per-store shelf snapshot dry-run. The
mall hub view has no specific store under it — the preview UX (shelf-by-shelf
reveal) has no payload from this surface and would render "0 items on the
shelf, no customers today" misleadingly. The mall-hub close button has its
own Day-1 soft-confirm gate (`first_sale_complete` flag check at
`mall_overview.gd:390-394`), so the gate-rule symmetry with the HUD is
preserved; only the preview is skipped.

**How a future change would invalidate this:** if `CloseDayPreview` is
generalized to render an aggregated all-stores snapshot, the mall hub close
button should also route through it.

### J-2. `critical_notification_requested` signal retained with zero production emitters

**Decision:** keep.

**Why:** The signal is the API surface for the EH-54 forwarding contract
("must-show toast that bypasses tutorial-step suppression"). The diff
proves the Day-1 caller is obsolete, but does not prove the *contract* is
obsolete — the next critical alert (save failure, bankruptcy, content-load
failure) is the natural caller. The signal also still has two GUT tests
that pin the bypass behavior, so deleting the signal would require deleting
those tests, the HUD handler, and the §F-54 docstring. That is a wider
refactor than this SSOT pass should swallow.

**How a future change would invalidate this:** if a code review establishes
that no future critical alert will use the signal (e.g. save failures move
to a dedicated modal), delete the signal, the HUD listener, the §F-54
section, and the two `test_critical_notification_*` tests in one PR.

### J-3. `CloseDayPreview` confirm path bypasses the soft-confirm dialog after first sale

**Decision:** keep.

**Why:** Once `first_sale_complete` is true, `_is_day1_gate_active()`
returns false and the HUD opens `CloseDayPreview` directly. The confirm
dialog is *only* the Day 1 / no-first-sale soft gate. There is no need to
wrap the preview's own confirm step in another modal — the preview is
already a confirmation surface ("review the dry-run, then commit").

**How a future change would invalidate this:** if a separate "are you sure?"
prompt is wanted on every close (not just Day 1 / no-sale), wire it into
`CloseDayPreview._on_confirm_pressed` rather than re-opening the
`CloseDayConfirmDialog`.

### J-4. `DayCycleController` no longer self-defends against double-close on Day 1

**Decision:** keep — controller's existing `_awaiting_acknowledgement`
guard and the `double_close_ignored` test cover the only realistic
double-emit pattern.

**Why:** With the controller backstop removed, the only protection against
"player spams Close Day on Day 1" is the soft-confirm dialog itself
(modal-blocking the underlying button) plus the controller's pre-existing
`_awaiting_acknowledgement` flag. The dialog is modal at the engine level —
Godot's `ConfirmationDialog.popup_centered()` blocks input to the rest of
the tree until dismissed — so a second press cannot reach the bus while
the dialog is open. Adding controller-side rejection back would just
shadow the modal contract.

**How a future change would invalidate this:** if `CloseDayConfirmDialog`
is converted to a non-modal banner / toast, restore a controller-side
de-dupe guard that checks an in-flight flag.

---

## Sanity check — no dangling references

After the deletions and edits:

- `git grep "F-52"` → 0 hits.
- `git grep "Make your first sale"` → 0 hits (was 3 in `test_hud_state_visibility.gd`).
- `git grep "DayCycleController.*backstop"` → 0 hits.
- `git grep "Day 1 cannot close"` → 0 hits.
- `git grep critical_notification_requested.emit` → 2 hits, both in
  `tests/gut/test_hud_state_visibility.gd`, with the `"Save failed —
  check disk space."` payload that mirrors the only realistic future caller.
- `git grep "first_sale_complete"` → 49 hits, all in production-relevant
  paths: gate predicate (HUD + MallOverview), reader (DayManager,
  ObjectiveDirector, EconomySystem, Day1ReadinessAudit), test setup. No
  hard-gate rejection callsites remain.
- `bash tests/run_tests.sh` — see "Test verification" below.

---

## Test verification

Re-ran `bash tests/run_tests.sh` after edits. Result: **4818 / 4818 GUT
tests passing** (27,324 asserts), `---- All tests passed! ----`. The three
test files modified by this pass (`test_hud_state_visibility.gd`,
`test_day_summary_day1_label_values.gd`, `test_day_cycle_close_loop.gd`)
only had string / comment edits; their assertion logic was not changed.
The diff's own test additions (`test_close_day_preview.gd`,
`test_first_sale_chain.gd`, `test_mall_overview.gd`,
`test_day_cycle_controller.gd`, `test_audit_overlay_toggle.gd`,
`test_main_menu.gd`,
`test_day_summary_day1_label_values.gd::test_close_day_on_day1_renders_summary_after_soft_confirm`)
are the negative tests that pin the new SSOT — re-introducing the deleted
backstop or hard-gate would break them.

The pre-existing `test_day_summary_mall_overview_button.gd::test_mall_overview_press_emits_request_and_advances_day`
flakes as "Risky" with a `mall_overview_requested` access error, and the
ISSUE-239 validator (PocketCreatures pack shape, tournament count) reports
failures. Both predate this branch and reproduce on clean `main`; out of
scope for this pass.

---

## Escalations

### §E-SSOT-1. `HintOverlayUI` has no production consumer (carried over)

**File:** `game/scripts/ui/hint_overlay_ui.gd`,
`game/scenes/ui/hint_overlay_ui.tscn`.

**Status:** unchanged from the prior SSOT pass. The Day-1 soft-gate
diff does not touch this code path. Carrying the escalation forward so it
is not lost. See the prior pass entry (commit `ecb7011` and earlier) for
the full rationale; smallest concrete next action is unchanged: pick
"ship-with-onboarding-hints" or "rip-the-system" before either side can
be cleaned up.

### §E-SSOT-2. `prop_counter_register.gltf` orphan (carried over)

**File:** `game/assets/models/fixtures/prop_counter_register.gltf` (+
`.import`).

**Status:** unchanged. The asset is now ~6 days old, still no consumer
in `retro_games.tscn` or any other scene. Same reasoning to defer (an
in-progress asset is more likely than legacy chaff). Owner check still
pending.
