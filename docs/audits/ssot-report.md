# SSOT enforcement pass — 2026-05-06

Working-tree-driven SSOT cleanup for the Day-1 close-day flow on `main`.
Diff signal: the branch introduces `CloseDayConfirmationPanel`,
`EventBus.day_close_confirmation_requested(reason)` /
`EventBus.day_close_confirmed`, `ObjectiveDirector.can_close_day()` /
`ObjectiveDirector.get_close_blocked_reason()`, and the
`_loop_completed_today` flag — a single, content-aware close-day gate that
covers both "shelves never stocked" and "stocked but no sale yet" on every
day. The pre-existing per-screen "Day 1 + no first sale" `ConfirmationDialog`
in `HUD` and `MallOverview` was a strict subset of that new gate's
responsibility and now contradicts it.

## Changes made this pass

All edits in this section are working-tree changes (uncommitted, per the pass
contract — "Do not commit").

### 1. `game/scenes/ui/hud.gd` — soft-gate code paths removed

Removed all of:

- field `_confirm_dialog_focus_pushed: bool`
- `@onready var _close_day_confirm_dialog: ConfirmationDialog`
- `_wire_close_day_confirm_dialog()` call from `_ready`
- function `_is_day1_gate_active()`
- `_is_day1_gate_active`-driven branch in `_on_run_state_changed`
  (tooltip is now always cleared)
- `_is_day1_gate_active`-driven branch in `_on_close_day_pressed`
  (now always opens the close-day preview directly)
- function `_show_close_day_confirm()`
- function `_wire_close_day_confirm_dialog()`
- functions `_on_close_day_confirm_confirmed()` and
  `_on_close_day_confirm_canceled()`
- functions `_push_confirm_dialog_modal_focus()` and
  `_pop_confirm_dialog_modal_focus()`
- `_is_day1_gate_active`-driven branch in `_unhandled_input` (close_day
  action path)
- `_confirm_dialog_focus_pushed = false` reset in the test seam
- `_exit_tree()` body that re-popped the dialog's modal-focus frame

Net: ~120 lines removed from `hud.gd`. The HUD's close-day responsibility
now ends at "open the preview"; gating is the new SSOT's job.

### 2. `game/scenes/ui/hud.tscn` — dead `ConfirmationDialog` node removed

Removed the `[node name="CloseDayConfirmDialog" type="ConfirmationDialog"
parent="."]` node and its dialog-text properties.

### 3. `game/scenes/mall/mall_overview.gd` — soft-gate code paths removed

Removed:

- `@onready var _close_day_confirm_dialog: ConfirmationDialog`
- the `_close_day_confirm_dialog.confirmed.connect(...)` line in `_ready`
- the Day 1 + no-first-sale branch in `_on_day_close_pressed`
  (now unconditionally calls `_emit_day_close_requested`)
- function `_show_close_day_confirm()`

### 4. `game/scenes/mall/mall_overview.tscn` — dead `ConfirmationDialog` node removed

Removed the corresponding `[node name="CloseDayConfirmDialog" ...]` block.

### 5. Tests — covers for deleted behavior removed; covers for surviving behavior preserved

- `tests/gut/test_close_day_preview.gd` — three Day-1 soft-gate tests
  collapsed into one `test_pressing_close_day_opens_preview` that asserts
  the preview opens regardless of the first-sale flag. The preview's own
  confirm/cancel/empty-inventory/snapshot-callback tests are unchanged.
- `tests/gut/test_close_day_fp_modal_focus.gd` — three soft-gate
  modal-focus tests (`test_f4_in_fp_pushes_ctx_modal_when_soft_gate_fires`,
  `test_soft_gate_cancel_pops_ctx_modal`,
  `test_soft_gate_confirm_hands_modal_focus_to_preview`) collapsed into
  `test_close_day_press_pushes_preview_modal_focus`, which still verifies
  CTX_MODAL is pushed on press. `test_post_first_sale_close_day_pushes_
  preview_modal_focus` removed (now redundant with the simpler test).
  `test_cursor_release_signal_fires_on_soft_gate` renamed and rewritten as
  `test_cursor_release_signal_fires_on_close_day_press` to assert the
  same cursor-release contract without the soft-gate prerequisite. Header
  doc updated.
- `tests/gut/test_first_sale_chain.gd` — the three close-day soft-gate
  tests at the bottom of the file (`test_close_day_gate_active_on_day_1
  _without_first_sale`, `test_close_day_gate_releases_after_first_sale_
  flag_set`, `test_close_day_press_shows_soft_confirm_when_gate_active`)
  removed; the proceed-when-gate-released test simplified into
  `test_close_day_press_opens_preview_and_confirm_emits_request`. Header
  doc updated to reflect that the gate is no longer a HUD concern.
- `tests/gut/test_mall_overview.gd` — three soft-gate tests
  (`test_day_close_on_day1_before_first_sale_shows_confirm_dialog`,
  `test_day_close_confirm_dialog_close_anyway_emits_day_close_requested`,
  `test_day_close_confirm_dialog_stay_open_does_not_emit`,
  `test_day_close_passes_on_day1_after_first_sale`) collapsed into
  `test_day_close_press_emits_day_close_requested_unconditionally`.
- `tests/gut/test_day_summary_modal_focus.gd` — header doc updated to
  drop the `CloseDayConfirmDialog → CloseDayPreview → DaySummary` chain
  description in favor of the current `CloseDayPreview → DaySummary` plus
  optional `CloseDayConfirmationPanel` interleave. Test bodies unchanged.

### 6. Verification

Full project test runner (`bash tests/run_tests.sh`) executed end-to-end
after edits. GUT result: **5685 / 5685 tests passing**, including
`test_day_close_confirmation_gate.gd` (15 tests covering the new SSOT) and
all the rewritten soft-gate-replacement tests above. Pre-existing
ISSUE-239 content-data failures in `pocket_creatures_packs.json` /
tournaments config remain (not in scope — pre-date this pass and have no
SSOT relationship to the close-day flow).

## Final SSOT modules per domain

| Domain | Single owner |
|---|---|
| Player-initiated close-day request | `HUD._on_close_day_pressed` / `MallOverview._on_day_close_pressed` — both unconditionally emit through the close-day preview, which emits `EventBus.day_close_requested` |
| Loop-completion gating policy | `ObjectiveDirector.can_close_day()` and `ObjectiveDirector.get_close_blocked_reason()` (`game/autoload/objective_director.gd`) — content-aware ("shelves empty" vs "no sale yet") |
| Loop-completion confirmation prompt | `CloseDayConfirmationPanel` (`game/scripts/ui/close_day_confirmation_panel.gd`) — the only modal that consumes `EventBus.day_close_confirmation_requested` and answers with `EventBus.day_close_confirmed` |
| Day-close orchestration | `DayCycleController` (`game/scripts/systems/day_cycle_controller.gd`) — sole emitter of `EventBus.day_closed`, sole consumer of `day_close_requested` and `day_close_confirmed`, sole place that runs the gate before `_on_day_ended` |
| Modal CTX_MODAL focus contract | `ModalPanel` base class (`game/scripts/ui/modal_panel.gd`) — `CloseDayConfirmationPanel`, `MorningNotePanel`, and `InventoryPanel` all inherit it. The HUD's old per-instance push/pop pair is gone. |

Single-owner table for the rest of the runtime is unchanged from
`docs/architecture/ownership.md`.

## Risk log — intentionally retained

These items came up during the inventory pass but were **kept** with
justification.

- **Per-store legacy `ConfirmationDialog` callers in other panels** —
  `DifficultySelectionPanel`, `FixtureCatalogPanel`, `UpgradePanel`,
  `HagglePanel`, `TrendsPanel` still extend `CanvasLayer` /
  `PanelContainer` rather than `ModalPanel`. **Why kept:** out of scope —
  none of them participate in the close-day flow and the branch diff does
  not touch them; their relationship to the new `ModalPanel` SSOT is
  "haven't migrated yet," not "contradicts." Filed for a future pass when
  any one of them is actually changed.
- **`DaySummary` does not extend `ModalPanel`** — keeps its own
  `_focus_pushed` flag and `_push_modal_focus`/`_pop_modal_focus` pair.
  **Why kept:** DaySummary is shown by `DayCycleController` (an external
  driver), not by a self-contained `open()` button-click pattern, and its
  multiple dismiss paths (Continue, Mall Overview, Review Inventory) each
  need to release the frame. The `ModalPanel.open()` / `close()` shape
  doesn't fit cleanly here without forcing the controller to call
  `_panel.open()` instead of `show_summary(payload…)`. The contract that
  matters (single CTX_MODAL frame round-trips on every dismiss path) is
  covered by `tests/gut/test_day_summary_modal_focus.gd`.
- **`back_room_damaged_bin/Interactable` disabled in
  `retro_games.tscn`** — kept disabled with the existing inline comment.
  This is a forward-looking placeholder for the returns-review flow, not
  legacy dead code.
- **Old EH-06 doc cross-reference in `_open_close_day_preview`** — kept;
  the comment still describes the live "preview-missing" warning path,
  which is unchanged.
- **Two stale `.aidlc/research/...` markdown files mention
  `CloseDayConfirmDialog`** — kept; `.aidlc/` is a frozen research
  archive, not active docs (active docs boundary per
  `docs/contributing.md` is `README.md` + `docs/`). Editing the archive
  would falsify it.

## Sanity check — dangling references

After the edits:

```
$ grep -rn "_close_day_confirm_dialog\|_confirm_dialog_focus_pushed\|
   _show_close_day_confirm\|_is_day1_gate_active\|
   _wire_close_day_confirm_dialog\|CloseDayConfirmDialog\|
   _on_close_day_confirm_confirmed\|_on_close_day_confirm_canceled\|
   _push_confirm_dialog_modal_focus\|_pop_confirm_dialog_modal_focus" tests/ game/
(no matches)
```

Active docs (`docs/`, `README.md`) carry no references to the deleted
symbols. The only remaining mentions are in the `.aidlc/` research archive
(see Risk log) and historical entries in `tests/test_run.log`, which is
overwritten on every test run.

## Escalations

None. Both the act and justify decisions for in-scope findings were
self-contained.
