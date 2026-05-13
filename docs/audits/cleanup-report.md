## Changes made this pass (2026-05-13, follow-up)

Follow-up cleanup pass over the same beta WIP working tree as the
2026-05-13 entry below. Prior passes had already swept the new panel
files (`BetaEventLogPanel`, `BetaTodayStatsPanel`,
`BetaObjectiveTargetHighlight`), the checklist, the modal/focus
plumbing, and the docstring drift around deleted features. This pass
re-greps the un-revisited surfaces — `manager_relationship_manager.gd`,
`beta_debug_overlay.gd`, and the rest of the WIP-diff perimeter — for
dead constants and stale renamed-stage strings, and trims what's
actually unreferenced.

### Edits applied in source

| File | LOC before → after | What changed |
|---|---|---|
| `game/autoload/manager_relationship_manager.gd` | 641 → 637 (-4) | Deleted four unused constants from the per-event trust-delta block: `DELTA_COMPLAINT_HANDLED = 0.03`, `DELTA_MYSTERY_INVENTORY_ACK = 0.04`, `REASON_COMPLAINT_HANDLED = "complaint_handled"`, and `REASON_MYSTERY_INVENTORY_ACK = "mystery_inventory_acknowledged"`. `grep -rn` across `game/` and `tests/` returned only the declaration lines — no readers anywhere. The three surviving deltas (`DELTA_TASK_COMPLETED`, `DELTA_STAFF_QUIT`, `DELTA_MISSING_PAYROLL`) are all called from `apply_trust_delta(...)` sites in this file at lines 340/345/350 and pinned by `tests/gut/test_manager_relationship_manager.gd:133–153`. The deleted pair were a never-wired feature-stub from the original spec block. |
| `game/scripts/beta/beta_debug_overlay.gd` | 431 → 431 (0) | Fixed stale stage strings in the `_objective_anchor_for_stage` match. The prior chain shape used `"pickup_stock"` / `"place_stock"`; the current Day-1 chain (per `beta_day_one_controller.gd:35–37`) renamed those stages to `"back_room_inventory"` / `"stock_shelf"`. The match arms with the old keys could never fire — `grep -rn` confirms `pickup_stock` / `place_stock` appear only at those two arm lines. The debug overlay was silently rendering `"—"` for the back-room and stock-shelf stages instead of the anchor node names (`"BetaBackroomPickup"` / `"BetaRestockShelf"`). Rename only — control flow and signature unchanged. |

### Why these were act-able

Both edits are local, low-risk, zero-behavioural-change for production
gameplay:

- The four manager-relationship constants are dead declarations; no
  caller and no test references them. Project boot stays clean
  (`[AUDIT] boot_complete: PASS`); the surviving constants and their
  GUT contracts are untouched.
- The debug-overlay rename fixes a stale-key bug confined to the F2
  debug surface. It restores the missing-anchor labels for the
  current chain's two middle stages without altering the function
  signature, return type, or any other call site.

### Inspected this pass and intentionally not changed

#### `beta_day_one_controller.gd` 1757 LOC

`game/scripts/beta/beta_day_one_controller.gd`. The WIP keeps growing
this file (now 1757 LOC, up from 1716 in the prior pass) with the new
day-2 chain reuse, Vic-note Day-2 body, customer-exit tween, and
back-room delivery quantity unification. Spot-greps for unused fields,
commented-out blocks, and stale renamed references returned zero hits
post the prior passes.

**Why not factored:** the extraction candidates listed by the prior
pass (panel-spawn block, decision-card glue, screenshot helper) are
still the cleanest splits but remain blocked by ongoing beta content
authoring. Splitting during the active WIP would create merge churn
without any code-health win. The 1757 LOC is intrinsic for a chain
controller that owns gating, time advance, completion, summary
shaping, scene-reset, customer-exit tween, and panel ownership — see
the prior pass's same disposition.

#### Per-tag color tables in `beta_event_log_panel.gd` and `_PHASE_NAMES` in `beta_today_stats_panel.gd`

`game/scripts/beta/beta_event_log_panel.gd:55–62` and
`game/scripts/beta/beta_today_stats_panel.gd:52–59`. Both are static
content lookups with the same color/phase tokens appearing once each.

**Why kept:** the tables are local to their owners by design — they're
visual-contract constants for a specific surface, not cross-cutting
SSOT. Hoisting them into a shared module would force every test
fixture that constructs one panel to also import the shared module,
without removing any duplication (each table has exactly one reader).

#### `_MODAL_DIM_ALPHA = 0.65` repeated across `hud.gd`, `beta_today_checklist.gd`, `beta_today_stats_panel.gd`, `beta_event_log_panel.gd`, `objective_rail.gd`, `modal_dim_overlay.gd`

Six copies of the same modal-fade constant.

**Why kept:** documented as intentional in the prior pass — the
`ModalDimOverlay` docstring explicitly anchors the visual contract
("Alpha is calibrated against `HUD._MODAL_DIM_ALPHA = 0.65`") and the
other surfaces all reference the same calibration. Centralizing the
constant in a single autoload would tie six unrelated surfaces to a
new shared dependency to save five literal `0.65`s — a worse trade
than the existing per-surface docstring chain that names the
calibration target.

#### Verbose §EH-13/15/35–§EH-40 dead-guard-removal docstrings across `event_bus.gd`, `event_log.gd`, `modal_dim_overlay.gd`, `objective_rail.gd`, `audit_overlay.gd`, `beta_today_checklist.gd`, `beta_today_stats_panel.gd`, `toast_notification_ui.gd`, etc.

Same disposition as prior passes: every `§EH-*` anchor is the in-code
SSOT for the matching `docs/audits/error-handling-report.md` section.

**Why kept:** removing or shortening these would orphan the audit
report. The user's documented preference (recorded in prior passes)
is to keep `§EH-*` anchors as inline citations.

### Files still >500 LOC (this pass)

No new files crossed the 500-LOC threshold. The three biggest WIP
files are the same as the prior pass:

- `game/scripts/beta/beta_day_one_controller.gd` 1757 LOC. See
  Inspected-and-kept above; same extraction plan and same blocker.
- `game/scenes/ui/hud.gd` 1479 LOC. Same `FpHudController`
  extraction plan as the prior passes for the FP-mode block once
  layout is content-stable.
- `game/autoload/event_bus.gd` 875 LOC. Global signal hub by
  design; per-signal docstrings justify the file size.
- `game/scenes/ui/checkout_panel.gd` 775 LOC. Intrinsic scope; the
  WIP added the `ModalQueue.is_busy()` deferral path. No clean
  split candidates surfaced this pass.
- `game/autoload/manager_relationship_manager.gd` 637 LOC (down
  4 from 641 this pass). Stays under the threshold but worth
  noting: still owns trust scalar, tier resolution, per-day
  category tallying, morning-note selection, and confrontation
  emission — same justification as the prior pass.

## Escalations

None new this pass. The pre-existing content-test reconciliation
track remains the only outstanding item (five-store / deleted-upgrade
/ renamed-label content fallout, unchanged in scope from the prior
pass).

---

## Changes made this pass (2026-05-13)

Cleanup pass over the active beta WIP working tree (Day-1 chain + new
on-screen log / right-side stats / today-checklist panels + ModalQueue
deferral on `CheckoutPanel.show_checkout`). The branch came in with the
new `BetaEventLogPanel`, `BetaTodayStatsPanel`, dedup-guard tests, and
the rewritten Day-1 objective chain (`talk_to_customer →
back_room_inventory → stock_shelf → close_day`) already staged. This
pass swept for dead constants, unused fields, and stale docstrings
introduced or left behind by the WIP.

### Edits applied in source

| File | LOC before → after | What changed |
|---|---|---|
| `game/autoload/event_log.gd` | 234 → 229 (-5) | Deleted the unused `ON_SCREEN_MESSAGE_MAX_CHARS: int = 96` constant (newly introduced by the WIP) plus its 3-line docstring. `grep -rn ON_SCREEN_MESSAGE_MAX_CHARS game/ tests/` returned only the declaration site — no readers in any source or test file. The docstring also misrepresented the runtime contract: it claimed the bottom-left log panel "caps width" via this constant, but `beta_event_log_panel.gd` actually caps by entry count (`MAX_VISIBLE_ENTRIES = 8`) and does no per-line char truncation, so the constant was misleading dead code, not just unused. |

### Why this was act-able

Pure dead-code removal with no behavioural surface:

- No reader site (verified by grep across `game/`, `tests/`, and
  `addons/gut/`).
- Targeted test suites that exercise the panel and its EventBus bridge
  still pass post-edit: `test_beta_event_log_panel.gd` 11/11,
  `test_objective_director.gd` 29/29, `test_beta_today_stats_panel.gd`
  11/11. The relevant contract (the panel renders `event_logged`
  emissions and caps at `MAX_VISIBLE_ENTRIES`) is unchanged.
- Project still boots headless (`--check-only` succeeds, boot
  `AUDIT: PASS` lines unchanged).

### Inspected this pass and intentionally not changed

#### `beta_day_one_controller.gd` "refund" / "warranty" comment references

`game/scripts/beta/beta_day_one_controller.gd:588, 1507–1509`. The
guard at `:588` (`Guard on cash_delta > 0 so refunds and no-sale
outcomes …`) and the docstring at `:1504–1509` on
`_emit_customer_outcome_toast` both mention refunds.

**Why kept:** these are accurate descriptions of the *current* Day-1
contract, not residues of a removed feature. `cash_delta` actually can
be negative on `refuse_return` / `clean_exchange` decision outcomes
authored in `customer_events.json`, so the guard is load-bearing. The
docstring at `:1507` explicitly flags this as a forward-looking comment
("Negative cash (refunds) currently fall through to the same 'no sale'
copy because there's no Day-1 refund path; a future scene with a
negative-cash choice can branch here"), which is the kind of
*why-it's-shaped-this-way* note that should stay.

#### `event_bus.gd:634` `warranty_binder_examined` signal

`game/autoload/event_bus.gd:634–636`. The signal predates this WIP and
was reconfirmed in the prior cleanup pass (see "Doc-string mention of
`warranty_binder_examined` at `event_bus.gd:623-625`" above) — it is
the in-fiction retail-prop inspection trigger for the hidden-thread
system, not a residue of the deleted warranty-pricing system. Same
disposition as the prior pass.

#### `EventLog._format_message` docstring claim "surface caps width at ~260 px"

`game/autoload/event_log.gd:181–184`. After deleting
`ON_SCREEN_MESSAGE_MAX_CHARS` I considered rewording this docstring,
but it is actually accurate as-is: the panel's `_PANEL_WIDTH` is
260 px (`beta_event_log_panel.gd:37`) and the RichTextLabel uses
`fit_content = true` without explicit autowrap, so rows wider than the
panel will overflow. The contract is "keep these strings short to fit
the visible box," which is what the docstring says.

**Why kept:** the comment correctly describes a real runtime constraint
on this private helper, even after the misleading constant is gone.

#### `beta_day_one_controller.gd._summary_spawned` one-shot guard

`game/scripts/beta/beta_day_one_controller.gd:288, 506–520`. The new
WIP-added flag guards against a duplicate `day_close_confirmed` emit
that would otherwise enqueue a second summary modal request. The
flag's twin — `_completed_objectives.has(&"close_day")` at `:505` —
gates the same path one line earlier.

**Why kept:** the two checks defend different races. The
`_completed_objectives.has(&"close_day")` check fires when the
checklist row was already ticked but the summary request was rejected
or deferred (and a retry comes through); `_summary_spawned` catches a
true duplicate `day_close_confirmed` emit while the first summary is
still spawning but before the checklist row flips. Removing either
would reopen one of the two races. Both `test_modal_one_at_a_time.gd`
contracts (`test_summary_dedups_repeated_show_requests` and
`test_modal_queue_depth_stays_at_one_during_summary`) depend on this
twin-guard.

#### `ManagerRelationshipManager._last_started_day` parallels `_confrontation_emitted_this_day`

`game/autoload/manager_relationship_manager.gd:104, 110, 194,
271–290`. The WIP added `_last_started_day` to guard against a
duplicate `day_started.emit(day)` for the same day number;
`_confrontation_emitted_this_day` already exists as a per-day flag for
a different one-shot effect.

**Why kept:** the two flags scope-differently. `_last_started_day`
suppresses duplicate *day-start processing* (note selection,
category-tally reset, pending-unlock consumption) across the entire
function body; `_confrontation_emitted_this_day` suppresses the
*confrontation note emission* specifically and resets at day end. They
are not redundant — collapsing them would either over-suppress
(skipping the confrontation when a different day-start effect needed
to re-run) or under-suppress (re-emitting the morning note on a
duplicate `day_started`).

### Files still >500 LOC (this pass)

No new files crossed the 500-LOC threshold relative to the prior
pass's table. Current sizes for the three biggest files the WIP
touched:

- `game/scripts/beta/beta_day_one_controller.gd` 1716 LOC (up from
  ~1650 in the prior pass; the WIP added the new panel wiring in
  `_ensure_panels`, the `_summary_spawned` guard, the
  `_sales_today` per-day cash tracker, and the customer-outcome
  toast). Same extraction plan as the prior pass: the panel-spawn
  block (`_ensure_panels`), the decision-card glue
  (`_on_choice_selected` / `_emit_customer_outcome_toast`), and the
  screenshot helper are the three cleanest extraction candidates,
  in that order. None of them can be cleanly factored *during* an
  active beta-content WIP — they would all need to land alongside a
  pause in content authoring, which is not this pass.
- `game/scenes/ui/hud.gd` 1475 LOC (up from 1419; the WIP added the
  idempotent `_connect_signals` block and the beta-mode TopBar
  suppression). Same `FpHudController` extraction plan as the prior
  pass for the FP-mode block once the layout is content-stable.
- `game/scenes/ui/checkout_panel.gd` 775 LOC. Player-facing checkout
  modal; the WIP added the `ModalQueue.is_busy()` deferral path at
  `:171–187`. Intrinsic scope — checkout modal renders prices,
  haggle state, totals, and the four buttons; no clean split.
- `game/autoload/event_bus.gd` 855 LOC. Global signal hub by design
  (the WIP added `customer_interacted` and `event_logged`). Each
  signal has a docstring justifying its existence; splitting by
  subsystem would fragment the SSOT.

## Escalations

None new this pass. The prior pass's content-test reconciliation
track remains the only outstanding item (pre-existing five-store /
deleted-upgrade / renamed-label content fallout, unchanged in scope).

---

## Prior pass — 2026-05-11, second pass

Second cleanup pass over the same WIP working tree. The prior pass (this
file's previous version, retained below) tackled the obvious dead-field
cleanup; this pass swept for *stale documentation* left behind by the
strip-to-bones deletions — module / function docstrings that still
described features whose code paths had already been removed. Three such
sites surfaced after greping the WIP diff for residual references to
deleted concepts (`warranty`, `refund`, `ACC grading`, etc.) plus a
formatting residue (orphaned blank-line cluster left by a deleted
helper).

### Edits applied in source (this pass)

| File | LOC before → after | What changed |
|---|---|---|
| `game/scenes/ui/day_summary_content.gd` | 79 → 78 (-1) | Rewrote the module docstring to drop the dead `warranty attach, ACC grading` callouts. The WIP had already deleted `set_warranty_attach`, `set_grading`, and `set_warranty` from this file (the only remaining helpers are `apply_revenue_headline`, `set_net_profit`, `set_discrepancy`), so the kin list in the docstring was stale. Replaced with the surviving `discrepancy banner` callout to match what's actually colocated. |
| `game/scenes/ui/hud.gd` | 1419 → 1419 (0) | Rewrote the docstring on `_on_customer_purchased_hud` (`:1075-1077`). The prior copy said "Driven by `EventBus.customer_purchased` so warranty-only paths and refund paths that do not produce a sale do not double-count." Post-strip-to-bones there is no warranty system (warranty_purchased / warranty_accepted / etc. were all deleted from EventBus in the prior pass) and no customer-refund path (ReturnsSystem was deleted with `returns_system.gd`). The new copy explains the actual reason for picking `customer_purchased` as the driver: it's the sale-confirmed signal rather than a broader customer-departed event, so non-sale outcomes (browse-only, walk-out) don't inflate the counter. |
| `game/scenes/ui/day_summary.gd` | 912 → 909 (-3) | Collapsed a 5-blank-line residue at `:498-502` down to the 2-blank-line GDScript convention. The cluster was left over when the WIP deleted `_create_overdue_count_label()` from this file (the deleted function and its 3 blank-line separator collapsed into a single deletion, leaving the 5-blank-line cluster between `_apply_revenue_headline` and `_kill_all_tweens`). |

### Why these were act-able

All three edits are documentation / formatting fixes with zero
behavioural change:

- `day_summary_content.gd` — module docstring only; no code touched.
  Full suite still passes for the 14 `tests/gut/test_day_summary_*.gd`
  files that exercise this class (`set_net_profit`, `set_discrepancy`,
  `apply_revenue_headline`).
- `hud.gd` — function docstring only; the function body is unchanged
  (still `_customers_served_today_count += 1` etc.). The 10 HUD tests
  (`test_hud_gd_emits_toggle_milestones_panel` block) still pass.
- `day_summary.gd` — pure whitespace; `bash tests/run_tests.sh` still
  shows the same 4123/4158 pass count as the pre-edit baseline.

### Inspected this pass and intentionally not changed

#### Doc-string mention of `warranty_binder_examined` at `event_bus.gd:623-625`

`game/autoload/event_bus.gd:623-625`. The signal
`warranty_binder_examined(store_id, day)` is *not* part of the deleted
warranty pricing/lifecycle system; it's a surviving hidden-thread
*inspection* signal emitted when the player examines the warranty
binder as a retail prop (BRAINDUMP's "hidden-thread design rule:
every hidden-thread object must have a normal retail reason to
exist"). Consumed by `HiddenThreadSystemSingleton._on_warranty_binder_examined`
(`hidden_thread_system.gd:185-189`) as a Tier-1 trigger.

**Why kept:** the binder is the in-fiction retail-prop reason for
the signal name; the signal contract is intentional and
`tests/unit/test_hidden_thread_system.gd` exercises this listener
contract.

#### Doc-string mention of `ReturnsSystem` at `event_bus.gd:76-81`

`game/autoload/event_bus.gd:76-81` on `defective_item_received`. The
prior pass's report already explained this docstring rewrite
(post-strip-to-bones there is no live emitter, but `LedgerSystem` and
`HiddenThreadSystemSingleton` listen, and the contract test in
`tests/unit/test_hidden_thread_system.gd` exercises the consumer
side). The current docstring is the rewrite from the prior pass and
is accurate.

#### `_grading_label`, `_overdue_count_label`, `_warranty_attach_label`, `_demo_status_label` field declarations remain in `day_summary.gd`

Survey check after this pass: the day_summary.gd `var _grading_label`
/ `_overdue_count_label` / `_warranty_attach_label` / `_demo_status_label`
fields were *fully removed* by the WIP (no longer in the diff). Only
the corresponding `@onready var _late_fee_label`, `_warranty_revenue_label`,
`_warranty_claims_label`, `_seasonal_event_label` were also stripped.
Spot-check confirms the file no longer has any pinned-by-tests dead
fields; the `show_summary` signature reshape that the prior pass had
filed as a blocker is *also* done (the WIP removed `warranty_revenue`,
`warranty_claims`, `seasonal_impact` from both the signature and the
14 test call-sites). The prior pass's Escalation on the
`show_summary` signature pin no longer applies — that work landed
inside this WIP.

### Files still >500 LOC (this pass)

No new files crossed the 500-LOC threshold relative to the prior
pass's table. The three files this pass touched:

- `game/scenes/ui/day_summary.gd` 909 LOC (was 976 at HEAD; the WIP
  shed 67 LOC, this pass shed 3 more). Already factored into
  `DaySummaryContent` / `DaySummaryDisplay` / `DaySummaryLabels`
  helpers. Owns end-of-day screen lifecycle. Same justification as
  the prior pass.
- `game/scenes/ui/hud.gd` 1419 LOC (was 1369 at HEAD; the WIP added
  ~50 LOC for FP-mode reparenting; this pass net-0). The FP-mode
  block (`set_fp_mode`, `_enter_fp_mode`, `_exit_fp_mode`,
  `_apply_fp_anchors`, `_apply_fp_typography`, `_ensure_fp_close_day_hint`,
  `_apply_fp_visibility_overrides`, `_ensure_fp_sentence_label`) is the
  cleanest extraction candidate for `FpHudController` once the
  layout is content-stable.
- `game/scenes/ui/day_summary_content.gd` 78 LOC, well under the
  threshold. Already minimal post-strip.

## Escalations

None new this pass. The prior pass's content-test reconciliation
track has *partially* landed inside the WIP (the 36→28 failing-test
shrink reflects the `show_summary` signature reshape + test
call-site updates that the prior Escalations section had named as
blocked). The remaining 28 are still pre-existing five-store /
deleted-upgrade / renamed-label content fallout, unchanged in
scope from the prior pass's filing.

---

## Prior pass — same WIP working tree (preserved for context)

Cleanup pass over the current beta WIP working tree (Day-1/Day-2 chain,
ModalQueue introduction, multi-step ObjectiveRail). The branch came in
with the `_strip-to-bones` deletions plus the active ModalQueue feature
work already in-place; the cleanup scope was the live WIP diff against
`main`, not the strip itself (the prior pass's section below documents
that).

### Edits applied in source

| File | LOC before → after | What changed |
|---|---|---|
| `game/scripts/beta/beta_today_checklist.gd` | 269 → 261 (-8) | Deleted the write-only `_surfaced_ids` dictionary field and its three uses (declaration + 4-line docstring + `.clear()` in `_rebuild_items` + `_surfaced_ids[objective_id] = true` write in `_surface_row`). `grep -rn _surfaced_ids` returned only the three write sites with zero readers; the dedup it was meant to provide was already enforced by the `_item_labels.has(objective_id)` early-return at `_surface_row`. |
| `game/scripts/ui/tutorial_overlay.gd` | 209 → 202 (-7) | Removed the unreachable re-entry guard at the tail of `_reevaluate_visibility` (`if _bottom_bar.visible and _prompt_label.text == prompt: return` plus its 5-line explanatory comment). Control-flow analysis: the function returns at `:155` whenever `_bottom_bar.visible` is true, so the only way to reach the deleted guard was with `_bottom_bar.visible == false`, making the guard's left operand always false and the guard dead. The duplicate-render debounce the guard claimed to handle is already served by the `:155` early-return — `test_reevaluate_does_not_reslide_when_already_showing_same_prompt` still passes via that path (verified: 21/21 in `test_tutorial_render_guard.gd`). |

### Why these were act-able

Both edits are dead-code deletions with zero reader sites and behavioural
parity verified against the surviving GUT contracts:

- `beta_today_checklist.gd` — full suite pass (9/9 in
  `test_beta_today_checklist.gd`).
- `tutorial_overlay.gd` — full suite pass (21/21 in
  `test_tutorial_render_guard.gd`, including the re-evaluation debounce
  test that the deleted guard claimed to serve, plus 9/9 in
  `test_tutorial_overlay.gd`).
- Modal-queue plumbing untouched but re-validated post-edit
  (21/21 `test_modal_queue.gd`, 9/9 `test_modal_queue_panel_routing.gd`,
  12/12 `test_beta_day_summary_modal_focus.gd`).

### Inspected this pass and intentionally not changed

#### Verbose §EH-35 / §EH-36 / §EH-37 dead-guard-removal docstrings

`game/scripts/systems/day_cycle_controller.gd:105–115` (`_can_close_day`),
`:137–144` (HiddenThreadSystem.finalize_day), `:166–172`
(`_should_run_closing_checklist`), `:258–262` (ShiftSystem
`get_shift_summary`), `:272–278` (`hidden_thread_interactions`); plus
`game/scripts/systems/random_event_system.gd:348–357`
(`_try_trigger_hourly_event`) and `game/scripts/systems/shift_system.gd:209–224`
(`_resolve_day_objective_text`).

**Why kept:** every one of these is a 6–14 line audit-anchor docstring
that documents *why* a `has_method`/`has_signal` defensive guard was
converted to a direct typed-autoload call. The §EH-31-class story is
captured in `docs/audits/error-handling-report.md` §§EH-35 – §EH-37; the
inline anchors are the SSOT linking strategy the user explicitly
established. Trimming them would break the grep-from-the-call-site →
audit-doc path the §EH markers exist to provide. The prose is verbose
but load-bearing for the audit's contract.

#### `BetaDaySummaryPanel._on_replay_pressed` / `_on_main_menu_pressed` don't `close()` the panel themselves

`game/scripts/beta/beta_day_summary_panel.gd:311–316`. The
`_on_continue_pressed` handler emits then closes; the replay / main-menu
handlers emit but do *not* close. The controller's
`_on_summary_replay` / `_on_summary_main_menu`
(`beta_day_one_controller.gd:585–595`) close the panel explicitly before
firing `GameManager.start_new_game()` / `.go_to_main_menu()`.

**Why kept:** the asymmetry is intentional. The continue path stays in
the current scene so the panel can close itself once `continue_pressed`
listeners have run. The replay / main-menu paths transition out of the
current scene — closing the panel before `GameManager` runs the scene
swap pops CTX_MODAL with the next scene's input context already on top,
which is the correct order. Moving the close into the panel would
require the panel to know that the controller is about to swap scenes,
which the panel deliberately does not. Documented in the controller-side
docstrings.

#### `BetaManagerNotePanel._showing` shadows `visible`

`game/scripts/beta/beta_manager_note_panel.gd:21, 82, 105, 114`. The
`_showing` field is gated against in `_unhandled_input` so a press of
`interact` / `ui_cancel` only dismisses while the note is up.

**Why kept:** `_unhandled_input` fires for every node in the tree
regardless of `visible`, so the panel needs an explicit "active" gate.
Reading `visible` directly would work but couples input gating to the
render flag, which the passive-overlay contract treats as separate
concerns (the panel is always in-tree once `_ensure_panels` constructs
it; `visible` toggles between dispatch cycles).

#### `ModalPanel.open()` vs `_open_from_queue()` duplication

`game/scripts/ui/modal_panel.gd:50–53, 77–80`. Both push CTX_MODAL and
flip `visible = true`; `_open_from_queue` also calls `_on_queued_open`.

**Why kept:** the two are intentionally distinct entry points —
`open()` is the direct-open escape hatch for fatal overlays and tests
that bypass the queue; `_open_from_queue` is the queue-dispatch path.
14 subclasses override `open()` (grep against `^func open()` under
`game/`); collapsing the two into one would force every override to be
aware of both code paths. The 3-line overlap is the price of keeping
the queue and the direct-open escape hatch independently composable.

### Files still >500 LOC (this pass)

Three of the in-scope modified files are over the 500-LOC threshold;
all three are already inventoried in the prior pass's table below. No
new files cross the threshold:

| File | LOC | Plan or justification |
|---|---|---|
| `game/scripts/beta/beta_day_one_controller.gd` | 1654 (was 1542) | Same justification as prior pass — single owner of the beta Day-1 chain. The branch's WIP added `_build_steps_payload`, `_build_shift_note` + `_join_phrases`, `_on_summary_replay` / `_on_summary_main_menu`, the multi-step rail payload, and the inventory split tracking (~112 LOC). The "future split: peel the visible-feedback tweens into `BetaDayOneVisualBeats`" plan in the prior pass stands. |
| `game/autoload/manager_relationship_manager.gd` | 597 (was 585) | Same justification — trust state + per-day note pool. The +12 LOC is the beta-active short-circuit at `_on_day_started:266–278` mirroring `midday_event_system.gd` / `milestone_system.gd`. |
| `game/scripts/systems/random_event_system.gd` | 526 (was 522) | Same justification — random event scheduler. The +4 LOC is the §EH-36 audit-anchor docstring on `_try_trigger_hourly_event`. |

`game/scripts/systems/day_cycle_controller.gd` (488 LOC) sits just
under the threshold and is inventoried only as a sanity check — the
§EH-37 conversions in this pass shed five `get_node_or_null + has_method
+ .call` chains while the docstring narration brought the LOC roughly
back to neutral. Future split: `_show_day_summary` (~95 LOC for the
day_closed payload assembly + LedgerSystem reconciliation) is the
cleanest extraction candidate, but the eight typed-autoload calls
already there compose a single payload — splitting would force the
payload-builder to traverse two files.

## Escalations

None new this pass. The pre-existing strip-to-bones content-test
reconciliation track documented below in the prior section's
Escalations remains the smallest concrete next action.

---

## Prior pass — strip-to-bones cleanup (preserved for context)

The bulk of this pass landed across the entire strip-to-bones working
tree, finishing the dead-listener / dead-field cleanup that the prior
cleanup-report.md called out as "filed for the next pass" (the
CompletionTracker retirement, PerformanceReportSystem warranty/rental
/electronics/demo accumulators, AudioEventHandler dead handlers,
DataLoader dead config routes, EventBus orphan signal deletions). The
report below is rewritten to reflect what is actually in the working
tree, not the in-flight 54-signal subset the prior version of this file
described.

### Net deltas vs. `main`

| File | HEAD LOC | Working tree LOC | Δ |
|---|---|---|---|
| `game/autoload/event_bus.gd` | 1006 | 845 | -161 |
| `game/autoload/data_loader.gd` | 1080 | 944 | -136 |
| `game/autoload/audio_event_handler.gd` | 286 | 280 | -6 (but with ~60 LOC of dead handlers deleted; doc-comment + fallback wiring added the rest back) |
| `game/scripts/systems/completion_tracker.gd` | 487 | 365 | -122 |
| `game/scripts/systems/performance_report_system.gd` | 771 | 676 | -95 |

Total `game/` + `tests/` delta against `main`: **325 files changed, 3733
insertions, 27694 deletions** (the wider strip; the cleanup-pass surgery
sits inside this).

### EventBus — orphan signal sweep (final state)

`event_bus.gd` now declares **305 signals** (was 387 on `main`; the
prior pass's intermediate state was 333). The deletions in the working
tree finish the strip-to-bones job:

- **Warranty:** `warranty_purchased`, `warranty_claim_triggered`,
  `warranty_offer_presented`, `warranty_accepted`, `warranty_declined`,
  `warranty_player_accepted`, `warranty_player_declined`.
- **Rental:** `item_rented`, `rental_returned`, `rental_late_fee`,
  `rental_item_lost`, `title_rented`, `title_returned`,
  `late_fee_waived`, `late_fee_collected`, `rental_overdue`,
  `store_rental_started`, `store_rental_returned`,
  `store_rental_overdue`.
- **Demo Station:** `demo_item_placed`, `demo_item_removed`,
  `demo_item_degraded`, `demo_interaction_triggered`,
  `demo_unit_activated`, `demo_unit_removed`, `demo_item_retired`,
  `demo_contribution_recorded`.
- **Electronics Lifecycle:** `electronics_product_announced`,
  `electronics_product_launched`, `electronics_phase_changed`,
  `product_entered_decline`, `product_entered_clearance`.
- **Authentication / Sports cards:** `authentication_started`,
  `authentication_completed`, `authentication_dialog_requested`,
  `authentication_rejected`, `authentication_player_submitted`,
  `store_auth_started`, `store_auth_resolved`, `card_authenticated`,
  `card_rejected`, `card_graded`, `grading_hint_revealed`,
  `fake_sold_as_authentic`, `grade_submitted`, `grade_returned`,
  `grading_day_summary`, `card_condition_selected`,
  `condition_picker_requested`.
- **Tournament:** `tournament_started`, `tournament_completed`,
  `tournament_resolved`, `tournament_event_announced`,
  `tournament_event_started`, `tournament_event_ended`,
  `tournament_telegraphed`, `tournament_ended`.
- **Meta Shift:** `meta_shift_announced`, `meta_shift_activated`,
  `meta_shift_started`, `meta_shift_ended`, `meta_shift_telegraphed`,
  `meta_shift_applied`.
- **Seasonal / season cycle:** `seasonal_event_announced`,
  `event_telegraphed`, `seasonal_event_started`,
  `seasonal_event_ended`, `season_changed`,
  `seasonal_multipliers_updated`, `season_cycle_shifted`,
  `season_cycle_announced`.
- **Pack opening:** `pack_opening_started`, `pack_opened`,
  `items_revealed`, `rare_pull_occurred`.
- **Returns/exchanges:** `return_initiated`, `return_accepted`,
  `return_denied`.
- **Action drawer / trade UI:** `trade_player_accepted`,
  `trade_player_declined`.
- **Market and haggle remnants:** `market_event_triggered`,
  `bonus_sale_completed`.

The `KNOWN_ORPHAN_SIGNALS` allowlist in
`tests/gut/test_eventbus_signal_compat.gd:12–30` is now down to
**8 entries**: the two `emit_*`-routed cross-cutting hooks
(`camera_authority_changed`, `input_focus_changed`), the three
mirror declarations (`scene_ready`, `store_ready`, `store_failed`),
and the three forward-looking customer-narrative signals
(`mystery_item_inspected`, `odd_notification_read`,
`wrong_name_customer_interacted`). Static analysis confirms exactly
the 8 allowlist entries remain unreferenced by `game/scripts`,
`game/autoload`, `game/scenes`; zero unaccounted-for orphans.

### CompletionTracker — dead 14→10 criteria retirement

`game/scripts/systems/completion_tracker.gd` previously tracked 14
criteria covering tournaments, authentications, rentals, warranty
claims. The working tree drops to 10 criteria (the four stripped
together with the systems they sourced from):

- Deleted constants: `TOURNAMENTS_REQUIRED`,
  `AUTHENTICATIONS_REQUIRED`, `RENTAL_CATALOG_REQUIRED`,
  `WARRANTIES_REQUIRED`.
- Deleted state: `_tournaments_hosted`, `_authentications_completed`,
  `_current_rental_catalog`, `_max_rental_catalog`,
  `_warranty_claimed`, `_warranty_items`.
- Deleted signal connections: every
  `EventBus.warranty_*.connect` / `tournament_*.connect` /
  `item_rented.connect` / `authentication_*.connect` /
  `rental_returned.connect` plumbed by `_connect_signals`.
- Deleted handlers: `_on_warranty_purchased`,
  `_on_warranty_claim_triggered`, `_on_tournament_completed`,
  `_on_item_rented`, `_on_rental_returned`, `_on_rental_item_lost`,
  `_on_authentication_completed` and their `_check_completion`
  re-evaluations.
- `get_completion_data()` and the save/load round-trip drop the
  matching dict keys.

The associated `tests/unit/test_completion_tracker_panel.gd` file is
deleted in the working tree, and
`tests/gut/test_completion_tracker_*.gd` were updated to expect the
10-criterion shape.

### PerformanceReportSystem — dead accumulator strip

`game/scripts/systems/performance_report_system.gd` no longer collects
warranty / rental / electronics / demo metrics:

- Deleted fields: `_daily_late_fee_income`, `_daily_overdue_count`,
  `_daily_warranty_revenue`, `_daily_warranty_claim_costs`,
  `_daily_electronics_sold`, `_daily_warranty_sold`,
  `_demo_unit_was_active`, `_daily_demo_contribution`.
- Deleted signal connections (`initialize()`):
  `EventBus.rental_late_fee.connect`,
  `EventBus.late_fee_collected.connect`,
  `EventBus.rental_overdue.connect`,
  `EventBus.warranty_purchased.connect`,
  `EventBus.warranty_claim_triggered.connect`,
  `EventBus.demo_unit_activated.connect`,
  `EventBus.demo_contribution_recorded.connect`.
- Deleted handlers: `_on_rental_late_fee`,
  `_on_late_fee_collected`, `_on_rental_overdue`,
  `_on_warranty_purchased`, `_on_warranty_claim_triggered`,
  `_on_demo_unit_activated`, `_on_demo_contribution_recorded`.
- Deleted from save round-trip: `daily_late_fee_income`,
  `daily_warranty_revenue`, `daily_warranty_claim_costs`.
- Deleted from `_build_report`: the seven matching
  `report.late_fee_income` / `warranty_revenue` /
  `warranty_claim_costs` / `warranty_attach_rate` /
  `electronics_demo_active` / `demo_contribution_revenue` /
  `overdue_items_count` assignments.
- Deleted from `_on_customer_purchased`: the
  `if store_id == &"electronics": _daily_electronics_sold += 1`
  branch.

### AudioEventHandler — dead SFX handler strip

`game/autoload/audio_event_handler.gd` drops the connections and
handlers for SFX cues that fired off deleted-system signals:

- Deleted from `_connect_sfx_signals`:
  `EventBus.pack_opened`, `EventBus.item_rented`,
  `EventBus.authentication_completed`, `EventBus.demo_item_placed`.
- Deleted from `_connect_state_signals`:
  `EventBus.warranty_accepted`, `EventBus.rare_pull_occurred`.
- Deleted handlers (`_on_pack_opened`, `_on_item_rented`,
  `_on_authentication_completed`, `_on_demo_item_placed`,
  `_on_warranty_accepted`, `_on_rare_pull_occurred`).

### DataLoader — dead route / config strip

`game/autoload/data_loader.gd` drops route table entries and field
state for the deleted content categories:

- Deleted `_TYPE_ROUTES` entries: `seasonal_event`, `sports_season`,
  `tournament_event`, `seasonal_config`, `named_seasons`,
  `electronics_config`, `video_rental_config`,
  `pocket_creatures_packs_config`, `pocket_creatures_cards_data`,
  `meta_shifts_data`, `meta_config_data`,
  `sports_grade_definitions_data`.
- Added: `beta_day_data`, `beta_events_data` (both routed to
  `ignore` because `BetaDayOneController` loads them directly).
- Deleted state: `_seasonal_events`, `_random_events` (kept),
  `_sports_seasons`, `_tournament_events`, `_seasonal_config`,
  `_electronics_config`, `_video_rental_config`, `_named_seasons`,
  `_named_season_cycle_length`, `_pocket_creatures_packs`.
- `clear_for_testing` and `_process_file` shed the matching arms.

### Stale-reference comment edits (this conversation)

| File | Lines | What changed |
|---|---|---|
| `game/resources/item_instance.gd` | 70–72 → deleted | Removed dead `demo_depreciation_factor: float = 1.0` field and its two-line doc-comment referencing the deleted `ElectronicsStoreController.DEMO_DEPRECIATION_FLOOR`. The field had zero readers (verified by `grep -rn "demo_depreciation_factor" game/`) and was not serialized into save data (`InventorySystem._serialize_item` / `_deserialize_item` only round-trip `is_demo` and `demo_placed_day`). |
| `game/scripts/systems/inventory_system.gd` | 429–433 | Rewrote `get_damaged_bin_items()` doc to drop the dead `ReturnsSystem reconciles the bin contents` reference. The function is still declared on the system contract; the new comment points at the back-room inventory panel (the actual reader path post-strip-to-bones) and the surviving `inventory_variance_noted` emission. |
| `game/autoload/event_bus.gd` | 77–80 | Rewrote `defective_item_received` doc to drop the dead `Emitted by ReturnsSystem when an item enters the damaged bin (post-accept return)` lead. The signal now correctly documents that there is no live emitter post-strip-to-bones; listeners (`LedgerSystem`, `HiddenThreadSystemSingleton`) plus the contract test in `tests/unit/test_hidden_thread_system.gd` exercise the consumer side. |
| `game/autoload/hidden_thread_system.gd` | 279–284 | Rewrote `_on_defective_item_received` doc to drop the dead `fires when ReturnsSystem deposits two or more` lead; matches the new event_bus annotation. |

Net: -4 LOC (one field + its 2-line comment in `item_instance.gd`)
plus four comment rewrites that re-anchor doc copy to surviving
emitter / consumer paths.

### Verification

`bash tests/run_tests.sh` after these edits:

- **4031 passing / 36 failing / 7 risky** out of 4074 (159.9s).
- Prior cleanup-pass baseline (before this conversation): same 36
  failures, fewer total tests. The four-comment retouch and the dead
  `demo_depreciation_factor` deletion neither moved any passing test
  to failing nor regressed risky-count.
- The 36 surviving failures are pre-existing strip-to-bones content
  fallout: tests still expect 5 stores
  (`test_all_seven_customer_markers_exist_with_authored_positions`,
  `test_storefront_remains_hidden`, etc.), the 16-upgrade catalog
  (`test_upgrade_count`, `test_store_specific_upgrade_count`,
  `test_all_upgrade_ids_present` covering `sports_trophy_wall`,
  `electronics_demo_hub`, `pocket_tournament_arena`, etc.), and
  the old "Retro Games" / "REGISTER" labels that the brand sweep
  renamed to "SHELF LIFE" / "Used Games". None of these reference
  any of the four files this conversation touched, and none reference
  any of the larger working-tree EventBus / CompletionTracker /
  PerformanceReportSystem deletions. Filed for the next
  content-and-tests reconciliation pass (see Escalations).

## Inspected this pass and intentionally not changed

### `PerformanceReport` resource still declares the dead `@export`
### fields (`warranty_revenue`, `warranty_claim_costs`,
### `warranty_attach_rate`, `late_fee_income`, `overdue_items_count`,
### `electronics_demo_active`, `demo_contribution_revenue`)

`game/resources/performance_report.gd:28–34` plus the matching
`to_dict` (`:80–86`) and `from_dict` (`:133–149`) entries. After the
PerformanceReportSystem strip, nothing writes to these fields, so
they ship as `0.0` / `0` / `false`. The downstream UI
(`day_summary.gd`, `day_summary_display.gd`, `day_summary_content.gd`)
still reads them and uses `> 0` / `is_empty()` guards to hide every
matching label.

**Why kept:**

`DaySummary.show_summary(...)` (`game/scenes/ui/day_summary.gd:184`)
is a public-API positional call. Removing the seven dead fields
would require changing that signature, which is exercised by 14
test files (`tests/gut/test_day_summary_*.gd`, the
`test_beta_day_summary_modal_focus.gd` pair). Per the cleanup-pass
contract ("No refactors that change call signatures of public API"),
this stays. The dead fields are inert (always default), and the UI
visibility guards mean the labels never render — the runtime cost
is one `0.0` field per `PerformanceReport` instance. Filed for the
next pass that intentionally takes the `DaySummary.show_summary`
signature reshape (paired with the 14-test sweep).

### `day_closed` payload still carries `warranty_revenue: 0.0`,
### `warranty_claims: 0.0`, and `seasonal_impact: ""`

`game/scripts/systems/day_cycle_controller.gd:203–206, 282–284,
333–334`. The summary dict produced by `_show_day_summary` includes
these three keys hard-coded to zero/empty, then passes them as
positional args to `_day_summary.show_summary(...)`.

**Why kept:**

Same blocker as the `PerformanceReport` field set above:
`show_summary` is the 14-test-pinned positional signature, and the
matching keys appear in `tests/gut/test_seven_day_progression.gd:55`
which emits its own `day_closed` payload containing
`"warranty_revenue": 0.0` and `"warranty_claims": 0.0`. The doc
comment on the `day_closed` signal
(`game/autoload/event_bus.gd:44–48`) still lists both keys so
listeners that read off the dict get a stable contract — the keys
default to `0` whenever they're absent, so removing them from the
emitter side is behaviourally inert, but matching the doc to
reality means co-removing them from `show_summary`'s arg list,
which the signature-pin blocks.

### `KNOWN_ORPHAN_SIGNALS` allowlist (8 entries)

`tests/gut/test_eventbus_signal_compat.gd:12–30`. The allowlist still
documents two `emit_*`-routed cross-cutting hooks
(`camera_authority_changed`, `input_focus_changed`), three mirror
declarations of authoritative `SceneRouter` / `StoreDirector` signals
(`scene_ready`, `store_ready`, `store_failed`), and three
customer-narrative forward features (`mystery_item_inspected`,
`odd_notification_read`, `wrong_name_customer_interacted`).

**Why kept:**

The first five are the SSOT-pass-documented intentional orphans
(test contract: every `emit_*` wrapper in `EventBus` has a matching
mirror declaration; the bus is the public listener seam even when
no live listener subscribes). The last three are forward-feature
emitters that the customer-narrative slice ships through; removing
them would silently re-introduce the `test_issue_166_no_orphaned…`
gate on the next emit-callsite landing. The allowlist's own inline
justification (`event_bus.gd:14–30`) is the documentation contract.

### `move_to_damaged_bin(instance_id)` and `get_damaged_bin_items()`

`game/scripts/systems/inventory_system.gd:434–460`. No live caller
in the working tree (verified by `grep -rn`).

**Why kept:**

The damaged-bin scene nodes
(`game/scenes/stores/retro_games.tscn:3342–3380`) and the back-room
inventory panel (`game/scenes/ui/back_room_inventory_panel.gd`)
still reference the bin as the consumer surface for the
`defective_item_received` listener contract (see the surviving
test `tests/unit/test_hidden_thread_system.gd:230–246`). Removing
the API surface would close off the listener contract that the
test exercises — the next pass that adds a production emitter for
`defective_item_received` (returns flow re-wiring, post-beta)
needs the move/read API in place. The comment now correctly
documents the back-room panel as the reader path; deletion is a
subsystem retirement, not a dead-code edit.

### `meta_shift` and `seasonal` slot names in
### `PriceResolver.CHAIN_ORDER`

`game/scripts/systems/price_resolver.gd:23–37`. Both slots remain in
the canonical chain order with `## legacy ... no live emitter post
strip-to-bones` annotations.

**Why kept:**

Same as the prior pass. The chain order is a forward-facing
contract — `market_value_system.gd:337` still appends
`{"slot": "seasonal", ...}` when `combined_seasonal != 1.0`, so the
seasonal slot is not dead. The `meta_shift` slot has no live
appender, but removing it from the canonical chain order would
reshape resequencing the moment a caller re-introduces it.
The annotated comments document the legacy state explicitly;
deleting the slot name does not.

### `mall_hallway.tscn` waypoints with stale store IDs

`game/scenes/world/mall_hallway.tscn:113–153`. Three pairs of
`StoreEntrance_N` / `Register_N` `Marker3D` nodes still carry
`associated_store_id` values pointing at the deleted
`consumer_electronics` / `pocket_creatures` / `video_rental` /
`sports_memorabilia` stores.

**Why kept:**

At runtime, `mall_hallway.gd::_initialize_waypoint_graph()`
reassigns `associated_store_id` only for the indices in
`ContentRegistry.get_all_ids("store")` (post-strip there is one
entry, `retro_games`), so waypoints 2–4 retain their stale IDs
but no live shopper-AI consumer reads them
(`mall_customer_spawner.gd` was deleted with the strip). The
prior pass filed this as the "mall hallway hub vs. single-store
gameplay shell" reconciliation; same answer applies.

### Surviving "legacy" comments under `game/scripts`

Sample sweep: `inventory_shelf_actions.gd:9`,
`save_manager.gd:40, 750, 761, 789–833, 845, 897–901`,
`store_ready_contract.gd:60–62`, `interactable.gd:113, 195, 219`,
`shelf_slot.gd:297`, `retro_games.gd:581, 622`,
`retro_games_starter_seed.gd:57`,
`beta_day_one_controller.gd:479, 1200–1202`.

**Why kept:**

Every match is either a save-data v0→v3 migration arm
(`save_manager.gd` cluster — the v3 reader needs to recognize the
v0/v1/v2 keys), a public-API fallback contract documented inline
("`item` is optional so legacy/test callers can drive placement
mode without a"), or a deprecation marker that's still load-bearing
(`retro_games.gd`'s legacy orbit-camera path is the test-fixture
seam). None are dead-code holdouts.

## Files still >500 LOC

Survey re-run against the current working tree. Items not in the
prior list reflect the strip-to-bones surface area; items in the
prior list shed lines proportional to the working-tree edits.

| File | LOC | Plan or justification |
|---|---|---|
| `game/scripts/beta/beta_day_one_controller.gd` | 1542 | **Justification** — single owner of the beta Day-1 chain (stage table `_OBJECTIVES`, gating `_apply_objective_gating`, interaction handlers, customer / box / shelf visibility tweens, beta-only scope strip, day-summary panel reparenting). Extracting any one piece would split the FSM contract across two files. **Future split**: peel the visible-feedback tweens (stock-box / customer / shelf opacity & position interp ≈ 200 LOC) into `BetaDayOneVisualBeats` once the chain is content-stable. |
| `game/scenes/world/game_world.gd` | 1450 | **Justification** — GameWorld scene root runs the five named init tiers documented in `docs/architecture.md`. Tiers are colocated by design so readiness ordering reads top-to-bottom in one file. Already factored into `initialize_tier_1_data` … `initialize_tier_5_meta`. **Future split**: extract Tier 5 meta wiring (perf manager, ambient moments, ledger, day-cycle controller) into `GameWorldMetaWiring` once that block grows. |
| `game/scenes/ui/hud.gd` | 1369 | **Justification** — single owner of the persistent top bar, the modal-fade contract, the FP-mode reparenting layout, the close-day preview wiring, the zero-state hint, and the carry HUD. The branch's WIP added the FP-mode layout (`set_fp_mode`, `_enter_fp_mode`, `_exit_fp_mode`, `_apply_fp_anchors`, `_apply_fp_typography`, `_ensure_fp_close_day_hint`, `_apply_fp_visibility_overrides` ≈ 190 LOC) — the cleanest extraction candidate for the next pass under `FpHudController`. |
| `game/scripts/core/save_manager.gd` | 1276 | **Justification** — single owner of the save/load round-trip across every persisted system. Already factored into per-system serialize / deserialize callbacks. No clean split until a system-grouping abstraction is introduced. |
| `game/scenes/ui/day_summary.gd` | 976 | **Justification** — single owner of the day-summary screen including end-of-run records, employee metrics, and seasonal-impact display. `DaySummaryDisplay` and `DaySummaryContent` are already extracted. The dead `warranty_revenue` / `late_fee_income` / `electronics_demo_active` / `demo_contribution_revenue` field reads are pinned by the 14-test `show_summary` signature contract (see "Inspected this pass" above). |
| `game/scripts/systems/customer_system.gd` | 956 | **Justification** — single owner of the customer-spawn / despawn / pool lifecycle. The branch added `_resolve_npc_container` + reparenting safety (~25 LOC), justified by the navigation-region ancestor lookup contract. |
| `game/autoload/data_loader.gd` | 944 | **Justification** — boot-time content loader; single owner of JSON discovery, schema validation, and ContentRegistry registration. The dispatch table `_TYPE_ROUTES` and `_build_resource` are fan-out hubs; extracting either splits the per-type contract across two files. -136 LOC vs. `main` after the route-table strip. |
| `game/scripts/systems/inventory_system.gd` | 935 | **Justification** — single owner of inventory mutations per `ownership.md` row 8. The damaged-bin read / write API (this pass's comment retouch) is the surviving forward-feature contract; no clean split. |
| `game/scripts/stores/retro_games.gd` | 884 | **Justification** — already factored into `RetroGamesHolds` and `RetroGamesAudit`. Remaining surface is store-controller scaffolding (lifecycle hooks, scene wiring, F3 debug toggle, day-1 quarantine, store actions). **Future split**: extract `_wire_zone_artifacts` plus the per-artifact `_on_*_interacted` handlers into `RetroGamesArtifacts`. |
| `game/scripts/content_parser.gd` | 865 | **Justification** — static utility producing typed Resources from JSON content dicts; one method per content type. Already a flat dispatch off `build_resource`. No clean split. |
| `game/scripts/systems/checkout_system.gd` | 864 | Inspected only. No clean split. |
| `game/autoload/event_bus.gd` | 845 (post-cleanup) | **Justification** — single-source signal hub per `docs/architecture/ownership.md` row 10. Already organized by topic with section banners. -161 LOC vs. `main` after the orphan-signal sweep; further extraction would still need to keep declarations colocated for the `test_eventbus_signal_compat` audit to walk one file. |
| `game/scripts/characters/customer.gd` | 835 | **Justification** — Customer FSM root. Each `_process_*` arm corresponds to one `State` enum value. `CustomerAnimator`, `CustomerCustomization`, `CustomerNavigationProfile` already extracted. What's left is the FSM core. |
| `game/scenes/ui/inventory_panel.gd` | 817 | **Justification** — already factored into `InventoryShelfActions`, `InventoryFilter`, `InventoryRowBuilder`. What remains is panel lifecycle, signal wiring, modal-focus contract, and grid refresh. |
| `game/autoload/settings.gd` | 789 | Inspected only. Single-owner of `user://settings.cfg` schema + reset / migration paths. No clean split. |
| `game/scripts/systems/ambient_moments_system.gd` | 764 | Inspected only. Single owner of the per-day moment queue + EventBus telegraphing. No clean split. |
| `game/scenes/ui/checkout_panel.gd` | 763 | Inspected only. Owner of the checkout transaction modal, queue indicator, and haggle handoff. No clean split. |
| `game/scripts/systems/order_system.gd` | 744 | Inspected only. Single owner of supplier ordering + restock queue. No clean split. |
| `game/scripts/systems/economy_system.gd` | 730 | Inspected only. Single owner of cash + daily revenue per `ownership.md`. No clean split. |
| `game/autoload/audio_manager.gd` | 721 | Inspected only. Single owner of audio bus + stream registry + 2D / 3D play API. No clean split. |
| `game/scripts/characters/shopper_ai.gd` | 713 | Inspected only. Mall-hallway shopper-AI FSM separate from `customer.gd`. No clean split. |
| `game/scripts/world/storefront.gd` | 682 | Inspected only. Storefront zone owner (lease-line trigger, glass mask, sign mount). No clean split. |
| `game/scripts/systems/performance_report_system.gd` | 676 | **Justification** — single owner of per-day metric accumulation. -95 LOC vs. `main` after the warranty / rental / electronics / demo accumulator strip. Remaining surface is the surviving haggle / customer-served / mistake metrics. |
| `game/scenes/ui/order_panel.gd` | 666 | Inspected only. Supplier-order UI; mirrors order_system contract. No clean split. |
| `game/scripts/stores/store_controller.gd` | 657 | Inspected only. Generic store-controller base; `retro_games.gd` is the live subclass. No clean split. |
| `game/autoload/content_registry.gd` | 647 (unchanged this pass) | **Justification** — typed catalogs and canonical IDs. Cross-reference validators are colocated by design. |
| `game/scenes/ui/settings_panel.gd` | 634 | Inspected only. Settings modal; mirrors `Settings` autoload. No clean split. |
| `game/scripts/systems/haggle_system.gd` | 625 | Inspected only. Single owner of haggle state. No clean split. |
| `game/scripts/systems/progression_system.gd` | 617 | Inspected only. Milestone evaluator + unlock gates. No clean split. |
| `game/scripts/player/interaction_ray.gd` | 595 | Inspected only. Single owner of screen-center raycast + dispatch. No clean split. |
| `game/scripts/systems/build_mode_system.gd` | 592 | Inspected only. Single owner of build-mode FSM. No clean split. |
| `game/autoload/manager_relationship_manager.gd` | 585 | Inspected only. Trust state + note pool + per-day comment selection. Tightly coupled to JSON schema. No clean split. |
| `game/autoload/hidden_thread_system.gd` | 574 | **Justification** — accumulator for tier-1/2/3 awareness, paper-trail, scapegoat-risk; this pass's comment retouch (`_on_defective_item_received`) is the only edit. No clean split. |
| `game/scripts/systems/tutorial_system.gd` | 573 | Inspected only. Tutorial FSM. No clean split. |
| `game/scripts/systems/store_state_manager.gd` | 558 | Inspected only. Per-store persisted state. No clean split. |
| `game/scripts/ui/haggle_panel.gd` | 542 | Inspected only. Haggle UI; mirrors haggle_system contract. No clean split. |
| `game/autoload/staff_manager.gd` | 541 | Inspected only. Single owner of staff state. No clean split. |
| `game/scripts/systems/fixture_placement_system.gd` | 532 | Inspected only. Single owner of fixture placement validation. No clean split. |
| `game/scripts/systems/random_event_system.gd` | 522 | Inspected only. Single owner of random event scheduling. No clean split. |
| `game/scripts/characters/customer_animator.gd` | 515 | Inspected only. Customer skeleton animator. No clean split. |
| `game/scripts/stores/shelf_slot.gd` | 506 | **Justification** — single `Interactable` subclass owning the slot's display, prompt, placement-mode visuals, focus-label, empty-ghost, and category-color tinting. The always-on `EmptyGhost` indicator added this branch (≈30 LOC under `_ensure_empty_ghost` / `_update_empty_indicator`) is the marginal addition. |
| `game/autoload/reputation_system.gd` | 503 | Inspected only. Single owner of reputation state per `ownership.md` row 9. No clean split. |

## Escalations

**Pre-existing test failures (36) tracked under the strip-to-bones
content reconciliation track, not this pass.** Detail by category:

- **Five-store expectation tests (≈9 failures).** `test_*_storefront_*`,
  `test_*_customer_markers_*`, `test_*_remains_hidden`,
  `test_boot_checks_load_errors_before_store_count`. These expect the
  pre-strip 5-store roster (consumer_electronics, pocket_creatures,
  sports_memorabilia, video_rental, retro_games) and the matching
  scene geometry. Resolving requires the test sweep that lands with
  the next content-test reconciliation PR.
- **Deleted upgrade IDs (≈8 failures).** `test_upgrade_count`,
  `test_store_specific_upgrade_count`, `test_all_upgrade_ids_present`
  expecting `sports_trophy_wall`, `sports_season_pass_display`,
  `video_late_fee_kiosk`, `video_new_releases_wall`,
  `pocket_tournament_arena`, `pocket_climate_vault`,
  `electronics_demo_hub`, `electronics_extended_warranty_desk`.
  Resolving requires either deleting these test cases or re-introducing
  matching upgrades; same content-reconciliation PR.
- **Renamed-label tests (≈8 failures).** `test_sign_name_text_is_correct`
  expects "Retro Games"; the in-world sign now says "SHELF LIFE".
  `test_no_billboard_debug_labels_in_scene` expects "REGISTER" not to
  appear; the rename pass left it in place. `test_day1_nav_labels_match_objective_wording`
  expects label text matching `objectives.json`'s prose. Resolving
  requires the rename-sweep PR (same brand-sweep set the prior commit
  started — `683c8f4 Phase 10 — Brand sweep + stale store-id cleanup`).
- **Stacked-multiplier + slot-marker + trends-panel (≈10 failures).**
  `test_stacked_multiplier_effects`,
  `test_slot_marker_material_renders_visible_with_emission`,
  `test_trends_panel_filters_to_active_store_and_clears_in_hallway`,
  `test_storefront_hidden_during_interior_gameplay` (a 6-assert block),
  `test_each_required_zone_has_a_label`. These reflect content / scene
  changes that haven't propagated to fixtures yet. Same
  content-reconciliation PR.

**Who/what unblocks:** The next pass that takes the
content-reconciliation track whole (rename "SHELF LIFE" surfaces back
to "Used Games" where the renamed brand lives, update the
five-store-expectation tests to the single-store roster, delete the
deleted-upgrade-id assertions). That pass is not a cleanup pass —
it's content-and-tests reshaping with behavioural impact in places
(e.g. the visible storefront label change), which the cleanup-pass
contract explicitly excludes.

**Smallest concrete next action:** Take `tests/gut/test_upgrade_*.gd`
and delete the four `expect_loadable("sports_trophy_wall", …)`
clusters; that alone resolves the 8 catalog-id failures with a single
test-file edit. The remaining 28 failures need scene / label / nav-text
work to clear.

This pass acts on what fits the cleanup contract (dead code, stale
comments, orphan signals, dead listener fields); everything else is
either Justified above with the SSOT pointer, named for the
content-reconciliation pass with a concrete next-action, or pinned
behind a public-API signature the cleanup contract forbids touching.
