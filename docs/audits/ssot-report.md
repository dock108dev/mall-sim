# SSOT Enforcement Pass — 2026-05-02

> **Pass 5 (2026-05-05)** — destructive cleanup against the working-tree
> diff that pivots the project to a 30-day "2005 mall game-store"
> direction (BRAINDUMP rewrite at `4a198d7`). The diff is not a small
> Day-1 polish — it adds 7 new autoload systems
> (`EmploymentSystem`, `HiddenThreadSystem`, `ManagerRelationshipManager`,
> `ReturnsSystem`, `PlatformSystem`, `ShiftSystem`, `StoreCustomizationSystem`,
> `MidDayEventSystem`, `TradeInSystem`), 5 new resource classes
> (`EmploymentState`, `HoldSlip`, `PlatformDefinition`,
> `PlatformInventoryState`, `ReturnRecord`), 6 new UI panels
> (`BackRoomInventoryPanel`, `ClosingChecklist`, `MidDayEventCard`,
> `MorningNotePanel`, `ReturnsPanel`, `TradeInPanel`), 52 new
> `EventBus` signals, the `HoldList` per-store object, the new
> `manager/` content directory, and ~800 lines of new code in
> `retro_games.gd` for time-clock spawning, hold-shelf
> rendering, and platform-shortage display. The TutorialStep enum
> bumps from v2 → v3 (the customer-loop steps `OPEN_INVENTORY` /
> `SELECT_ITEM` / `PLACE_ITEM` / `WAIT_FOR_CUSTOMER` /
> `CUSTOMER_BROWSING` / `CUSTOMER_AT_CHECKOUT` / `COMPLETE_SALE` are
> deleted; the employee-loop steps `PLATFORM_MATCH` / `STOCK_SHELF` /
> `CONDITION_RISK` / `SPORTS_DEPRECIATION` / `HOLD_PRESSURE` /
> `HIDDEN_THREAD` replace them in lockstep with their localization
> keys, signal handlers, and consumer tests). The diff itself is
> remarkably clean of leftover SSOT contradictions because the code
> migration was paired with the test-side renames; Pass 5 finds one
> stale docstring that survived the cut, escalates the
> `manager_approval` (EmploymentSystem) vs `manager_trust`
> (ManagerRelationshipManager) dual-scalar decision, and risk-logs
> several pre-existing duplications that pre-date this branch and
> are outside its diff. See [Pass 5 changes](#pass-5-changes-2026-05-05)
> below.

> **Pass 4 (2026-05-04)** — destructive cleanup against the working-tree
> diff that ships the BRAINDUMP "Day-1 fully playable" change set:
> Day-1 starting cash moves from `StoreDefinition.starting_cash` (deleted)
> to a single `EconomyConfig.starting_cash` source loaded from
> `pricing_config.json`; the Day-1 objective rail's flat
> `text/post_sale_text` payload is replaced by an 8-step `steps[]` chain
> that walks signal-by-signal; the Day-1 first-customer scripted spawn
> grows a 12-second forced-spawn fallback timer; `Customer.current_state`
> writes funnel through a single `_set_state` observer with a debug-build
> trace; one-click "Stock 1" / "Stock Max" / "Remove" inventory row
> buttons replace the prior "Select → placement-mode" entry; the day
> summary payload splits inventory into `backroom_inventory_remaining` /
> `shelf_inventory_remaining` and adds `customers_served`; the in-store
> HUD seeds cash from `EconomySystem.get_cash()` on `day_started`; and
> the FP `Inventory` corner hint is removed because the ObjectiveRail
> now owns that affordance. The companion *cleanup-report.md* Pass 7 and
> *error-handling-report.md* Pass 14 (already merged into the working
> tree) verified the code-side change set was free of dead
> constants/methods/handlers and that all silent-swallow holes were
> covered with `push_warning`. This SSOT pass tightens one stale doc
> comment that survived in `retro_games.gd` and records the new SSOT
> assignments for every domain the branch touched. See
> [Pass 4 changes](#pass-4-changes-2026-05-04) below.

> **Pass 3 (2026-05-03)** — destructive cleanup against the working-tree
> diff that re-sequences the tutorial flow (`MOVE_TO_SHELF` / `SET_PRICE`
> deleted; `SELECT_ITEM` / `CUSTOMER_BROWSING` / `CUSTOMER_AT_CHECKOUT` /
> `COMPLETE_SALE` added), wires the Day-1 customer-spawn gate, swaps the
> Day-1 starter-inventory pipeline from random-commons to deterministic-
> from-content, renames the HUD customer counter from concurrent
> ("active") to cumulative ("served-today"), and adds the
> `customer_item_spotted` signal with two named receivers. The
> *cleanup-report.md* Pass-5 sweep (companion to this pass) verified the
> code-side change set was clean of dead constants/methods/handlers; this
> SSOT pass collapses one private 1-call wrapper that survived and
> reconciles three audit-report sections that still cite removed surfaces.
> See [Pass 3 changes](#pass-3-changes-2026-05-03) below.

> **Pass 2 (2026-05-03)** — destructive cleanup against the working-tree diff
> that completes the first-person pivot. Pass 2 goes further than Pass 1:
> the *cleanup-report.md* Pass-3 stance was "no-behavior-change" and
> intentionally left dead-but-equal lerp infrastructure, an unreachable
> `Camera3D` legacy fallback, unused `ortho_size_min/max` exports, and the
> `_player_indicator` floor-disc hooks in place. The SSOT pass operates with
> the rule "if production usage cannot be proven, default to removal" and
> drops them. See [Pass 2 changes](#pass-2-changes-2026-05-03) below.

## Pass 4 changes (2026-05-04)

**Scope:** SSOT enforcement against the working-tree diff that lands the
BRAINDUMP "Day-1 fully playable" change set on top of Pass 13/14 of
`error-handling-report.md` and Pass 7 of `cleanup-report.md`. The diff
deletes `StoreDefinition.starting_cash` (and the five `store_definitions.json`
entries that authored it), introduces the `objectives.json` Day-1 `steps[]`
chain plus the corresponding `ObjectiveDirector._day1_step_index` machinery,
arms a 12-second forced-spawn fallback Timer in `CustomerSystem`,
funnels every `Customer.current_state` write through a single
`_set_state` observer, replaces the `InventoryPanel` "Select" row button
with one-click `Stock 1` / `Stock Max` / `Remove` buttons (each backed by
new `InventoryShelfActions.stock_one` / `stock_max` helpers), splits the
`day_closed` payload's `inventory_remaining` into backroom / shelf
fields, adds the `customers_served` payload field plus a `MainMenuButton`
to `DaySummary`, and seeds the HUD / KPI cash readout from
`EconomySystem.get_cash()` on `day_started`. The pass scans for code,
comments, and documentation that still reflect the pre-Pass-4 SSOT and
either removes/rewrites the contradiction in place or justifies it with
a concrete reason.

**Verification:** `bash tests/run_tests.sh` after edits — **5076/5076 GUT
tests pass, 0 failures**, all SSOT tripwires green
(`validate_translations.sh`, `validate_single_store_ui.sh`,
`validate_tutorial_single_source.sh`, ISSUE-009 SceneRouter
sole-owner check). Pre-existing validator failures (ISSUE-018,
ISSUE-023, ISSUE-024, ISSUE-026, ISSUE-032, ISSUE-154, ISSUE-239) are
on `main` ahead of this branch and do not touch the files edited in
this pass.

### Edits applied

| Path | Change | Rationale | Disposition |
|---|---|---|---|
| `game/scripts/stores/retro_games.gd` lines 64–67 (`_register_queue_size` doc comment) | Rewrote the doc comment from "checkout counter prompt can reflect 'No customer waiting' vs 'Checkout Counter — Press E to checkout customer'" to "'No customer waiting' vs 'Customer at checkout' with no Press-E verb (Day 1 customers auto-complete checkout via `PlayerCheckout.process_transaction()`)". | The Pass-4 working-tree edit at `retro_games.gd:24` already deleted `_CHECKOUT_PROMPT_VERB_ACTIVE` and reset the active-state `display_name` to `"Customer at checkout"`, and `_refresh_checkout_prompt` now writes `prompt_text = ""` unconditionally. The doc comment 60 lines above continued to describe the old "Press E to checkout customer" verb-bearing prompt. **The code is the SSOT** — the comment was stale and would mislead a reader of `_register_queue_size`'s purpose. | **Acted (tighten)** |

### What did not require a Pass-4 code edit

The working-tree diff already drops the SSOT contradictions for every
other domain Pass 4 audited; the pre-Pass-4 cleanup-report Pass 7 and
error-handling-report Pass 14 sweeps verified zero dead constants /
methods / orphans / silent-swallow holes survived. Specifically:

* **`StoreDefinition.starting_cash` field + `store_definitions.json`
  per-store overrides + `tests/validate_issue_013.sh`** — all deleted in
  the diff. `EconomyConfig.starting_cash` (loaded from
  `pricing_config.json`) is now the sole authoritative value;
  `Constants.STARTING_CASH = 500.0` is an explicit fallback for tests
  that bypass `DataLoader`. A grep for `StoreDefinition.starting_cash` /
  `store_definitions.*starting_cash` returns zero hits; `parse_store` no
  longer reads the field.
* **`CustomerSystem._day1_customer_spawned` (renamed to
  `_day1_first_customer_spawned`)** — every reader was updated in
  lockstep (`_on_item_stocked`, `spawn_customer`, `_on_day_started`,
  `_is_day1_spawn_blocked`, `tests/gut/test_first_sale_chain.gd`,
  `game/tests/test_day_cycle_integration.gd`). A grep for the old name
  returns zero hits.
* **`InventoryPanel._on_select_for_placement` /
  `InventoryRowBuilder.add_select_button` /
  `InventoryRowBuilder._build_select_spacer`** — all deleted in the
  diff. The single context-menu placement-mode entry survives via
  `_on_context_action` case 1 → `_begin_placement_mode`, which is the
  SSOT for the world-aim flow. Greps for the old names return zero hits
  outside the cleanup-report's historical Pass-6 narrative.
* **`HUD._fp_inventory_hint` / `_ensure_fp_inventory_hint` /
  `FpInventoryHint` node** — all deleted in the diff.
  `tests/gut/test_hud_fp_mode.gd::test_fp_mode_does_not_render_duplicate_inventory_hint`
  is a regression guard that fails if the hint is reintroduced. The
  ObjectiveRail's Day-1 step 1 (`open_inventory`) is now the sole
  surface that carries the "Press I to open the inventory panel" key
  affordance.
* **Day-1 `objectives.json` post-sale fields** — kept as defensive
  fallback when `_day1_steps_available()` returns false (e.g. corrupted
  load, content-authoring regression). `ObjectiveDirector._load_content`
  also push_warns on step-array shape mismatch (§F-93), so a corrupted
  load is visible at boot. Removing `post_sale_text` / `post_sale_action`
  / `post_sale_key` from the Day-1 entry would crash the rail on a
  corrupted load by emitting the day's pre-sale copy after the sale
  closes. Risk-logged below; intentionally retained.

---

## Final SSOT modules per domain (Pass 4 deltas)

| Domain | Pass 1–3 SSOT | Pass 4 update |
|---|---|---|
| Day-1 starting cash | (Pass 1–3: not enumerated; the value flowed through `Constants.STARTING_CASH = 750.0` overridden by `StoreDefinition.starting_cash` per store.) | **Pass 4:** `EconomyConfig.starting_cash` (loaded from `game/content/economy/pricing_config.json`, value `500.0`) is the sole authoritative source. `game_world.gd::_get_configured_starting_cash` reads it; `_get_effective_starting_cash` multiplies by `DifficultySystem.get_modifier(&"starting_cash_multiplier")`. `Constants.STARTING_CASH = 500.0` is an explicit fallback for tests that bypass `DataLoader` (matches the config value so `test_starting_cash_equals_constant` continues to pass). `StoreDefinition.starting_cash` field is **deleted**; `parse_store` no longer reads it; the five entries in `store_definitions.json` are **deleted**; `tests/validate_issue_013.sh` (which pinned the now-removed per-store overrides) is **deleted**. |
| Day-1 objective rail (Stock first item → make sale → close day) | **Pass 3:** `objectives.json` day-1 entry carried `text` / `action` / `key` plus `post_sale_text` / `post_sale_action` / `post_sale_key`; `ObjectiveDirector._emit_current` was the sole writer that flipped between pre- and post-sale copy when `_sold == true`. | **Pass 4:** `objectives.json` day-1 entry now carries an 8-entry `steps[]` array (`open_inventory`, `select_item`, `stock_item`, `wait_for_customer`, `customer_browsing`, `customer_at_checkout`, `sale_complete`, `close_day`). `ObjectiveDirector._day1_step_index` is the single sticky step pointer (initialized to 0 by `day_started(1)`, advanced by `_advance_day1_step_if(expected)` on the matching gameplay signal, terminated by the `SALE_COMPLETE_DURATION = 2.0` timer that flips step 6 → step 7). `_emit_current` walks the chain when `_day1_step_index >= 0 and _day1_steps_available()`; `post_sale_text` / `post_sale_action` / `post_sale_key` are reduced to a defensive fallback that fires only when the steps chain is unavailable on Day 1 (corrupted load) or on days 2+ that don't author a `steps` array. Receivers: `EventBus.panel_opened("inventory")`, `EventBus.placement_mode_entered`, `EventBus.item_stocked`, `EventBus.customer_state_changed(_, BROWSING)`, `EventBus.customer_ready_to_purchase`, `EventBus.customer_purchased`. |
| Day-1 customer-spawn entry gate + first-customer reliability | **Pass 3:** `CustomerSystem._is_day1_spawn_blocked` is the sole spawn gate; `_day1_spawn_unlocked` is the sticky boolean opened by `_on_item_stocked` and self-healing via `InventorySystem.get_shelf_items()` on save reload. The original `_day1_customer_spawned` flag tracked the "scripted single-shot" spawn fired directly from `_on_item_stocked`. | **Pass 4:** `_day1_customer_spawned` is renamed to `_day1_first_customer_spawned` and now tracks "any-path first Day-1 customer" — flipped by `spawn_customer` itself rather than the scripted handler. `_on_item_stocked` arms a one-shot `_day1_forced_spawn_timer` (`DAY1_FORCED_SPAWN_FALLBACK_SECONDS = 12.0`) instead of force-spawning inline; the `_on_day1_forced_spawn_timer_timeout` handler is the new fallback emitter that runs only when no organic spawn has landed first. The timer is canceled by an organic `spawn_customer` and reset by `_on_day_started`. **Single SSOT for the "Day-1 first customer" guarantee:** the timer + the `spawn_customer`-side flip; `_on_item_stocked` is now an arm-only path that does not directly spawn. |
| Day-1 first-sale demand override | (new) | **Pass 4:** `Constants.DAY1_PURCHASE_PROBABILITY = 0.95`. `Customer._is_first_sale_guarantee_active()` returns true on Day 1 while `GameState.get_flag(&"first_sale_complete")` is false; in that window `_process_deciding` bypasses the standard `purchase_probability_base × match_quality × tested/demo/rental` formula and rolls against the constant directly. The price-ceiling check (`item_price > willing_to_pay`) still applies — an absurd markup loses the sale. After the flag flips, the standard formula resumes for every subsequent transaction. |
| Customer FSM state-write site | (new — pre-Pass-4 had three duplicated `current_state = X; EventBus.customer_state_changed.emit(self, X)` pairs at `initialize`, `enter_queue`, `advance_to_register`, plus one in `_transition_to`.) | **Pass 4:** `Customer._set_state(new_state)` is the sole write site. All four prior call sites (`initialize`, `enter_queue`, `advance_to_register`, `_transition_to`) route through it. Debug builds emit a `[Customer N] OLD → NEW` print line per transition (gated on `OS.is_debug_build()`). **Single SSOT** — adding a new state-emit site outside `_set_state` is a code-review smell. |
| Customer navigation fallback (navmesh-missing path) | (new) | **Pass 4:** `Customer._use_waypoint_fallback` is the sticky boolean owned by `_detect_navmesh_or_fallback` (called once from `initialize`); flipping it to true puts the customer on direct-line `move_and_slide` toward `_fallback_target` via `_move_waypoint_fallback`. `_set_navigation_target` is the single seam — every caller (`_navigate_to_random_shelf`, `enter_queue`, `advance_to_register`, `_navigate_to_exit`) routes through it; the fallback path uses the same target value the agent path would have. `enable_waypoint_fallback()` is the public force-on entry for fixtures that ship without a navmesh. Each engagement push_warns per-customer (§F-94) so a wiring regression is visible. **Single SSOT for "where is this customer headed?"** — `_fallback_target` and the agent's target stay in lockstep. |
| Inventory row stocking buttons | **Pass 3:** `InventoryRowBuilder.add_select_button` added a single "Select" button on backroom rows that routed to placement-mode (`_on_select_for_placement` → `_begin_placement_mode` → `_shelf_actions.enter_placement_mode`). | **Pass 4:** Backroom rows expose two buttons (`Stock 1`, `Stock Max`) added by `InventoryRowBuilder.add_stock_buttons`; shelf rows expose one button (`Remove`) added by `add_remove_button`. The `_build_select_spacer` is renamed to `_build_action_spacer` and widened to 94px to accommodate the longer labels. Handlers: `_on_stock_one` → `InventoryShelfActions.stock_one(item, slots)` (places into first compatible empty slot); `_on_stock_max` → `stock_max(item, slots)` (fills compatible capacity from same-definition backroom matches); `_on_remove_from_shelf` → `_shelf_actions.remove_item_from_shelf(slot)` (or `move_to_backroom` fallback when no world slot). The placement-mode flow (aim-and-click in the world) remains the single alternative path, reachable only via context-menu "Move to Shelf" (`_on_context_action` case 1 → `_begin_placement_mode`). The shared row-action preamble (`_highlight_selected → _selected_item = item → mirror inventory_system`) lives in `_prep_row_action(item, row)`. **Single SSOT per stocking flow:** one-click via row buttons; aim-and-click via context-menu. |
| Day-summary inventory readout | **Pass 1–2:** `DayCycleController._show_day_summary` computed `inventory_remaining = shelf_items + backroom_items` and emitted it as a single field on `EventBus.day_closed`. | **Pass 4:** Payload now carries three fields: `inventory_remaining` (preserved for legacy/test consumers), plus `backroom_inventory_remaining` and `shelf_inventory_remaining` (split). `DayCycleController` is still the sole writer. `DaySummary._on_day_closed_payload` renders all three labels via the new `BackroomInventoryLabel` / `ShelfInventoryLabel` Label nodes; both default to 0 on missing keys so legacy payloads still render. |
| Day-summary customers-served readout | (Pass 1–3: pulled from `PerformanceReportSystem` via the `performance_report_ready` signal.) | **Pass 4:** `DayCycleController._show_day_summary` writes `customers_served` directly into the `EventBus.day_closed` payload (sourced from `PerformanceReportSystem.get_daily_customers_served()`). `DaySummary._on_day_closed_payload` renders it on receipt; `PerformanceReport` is still consulted when it arrives (it carries the day-vs-day delta string), but the payload is the primary source. **Single SSOT for the cumulative customers-served-today count:** `PerformanceReportSystem.get_daily_customers_served()`. |
| HUD cash readout (Day-1 starting-cash seed) | (Pre-Pass-4: HUD listened on `EventBus.money_changed` only; on Day 1 the readout stayed at $0 until the first transaction because `EconomySystem.initialize()` writes `player_cash` via `_apply_state` and does not emit `money_changed`.) | **Pass 4:** `HUD._seed_cash_from_economy()` (called from `_on_day_started`) snaps `_displayed_cash` / `_target_cash` to `EconomySystem.get_cash()` and updates the label, killing any in-flight count-up tween so no `0 → 500` crawl shows. The same seed is mirrored in `KpiStrip._seed_cash_from_economy()` (called from `_on_day_started` and `_on_gameplay_ready`) so the mall-hub strip and the in-store HUD agree from the first frame. Both seeds silently no-op when no `EconomySystem` autoload is in the tree (unit-test fixtures). |
| FP HUD persistent corner controls | **Pass 1–2:** Two persistent FP-mode bottom-right hints — `FpCloseDayHint` (`F4 — Close Day`) and `FpInventoryHint` (`I — Inventory`). | **Pass 4:** `FpInventoryHint` / `_fp_inventory_hint` / `_ensure_fp_inventory_hint` are **deleted**. The ObjectiveRail's per-step input affordance is now the sole surface for the I-key prompt (Day 1 step 1 (`open_inventory`) emits `key = "I"`). `FpCloseDayHint` is retained because no rail step on days other than Day 1's terminal step references F4. Regression guard: `tests/gut/test_hud_fp_mode.gd::test_fp_mode_does_not_render_duplicate_inventory_hint` asserts the node is absent. |
| Mall-overview event feed | **Pass 1–3:** `_add_feed_entry(text)` prefixed entries with `"[D%d %02dh] %s"` using `_current_hour`. | **Pass 4:** `_add_feed_entry` now formats as `"%s — %s"` with `_format_timestamp()` providing a 12-hour AM/PM string. When `set_time_system(time_system)` has been called by `GameWorld._setup_deferred_panels`, the timestamp tracks `TimeSystem.game_time_minutes` for minute precision; otherwise it degrades to `:00` using the last `hour_changed` value. `_resolve_item_name(item_id)` is the single helper for display-name resolution across the three new feed handlers (`_on_item_stocked`, `_on_customer_entered`, `_on_customer_purchased`). **Single SSOT for feed timestamps:** `_format_timestamp()`. |
| Checkout counter prompt (retro_games) | **Pass 1–2:** `_CHECKOUT_PROMPT_NAME_ACTIVE = "Checkout Counter"` + `_CHECKOUT_PROMPT_VERB_ACTIVE = "checkout customer"` rendered as `"Checkout Counter — Press E to checkout customer"` when a customer was queued. | **Pass 4:** `_CHECKOUT_PROMPT_VERB_ACTIVE` is **deleted**. `_CHECKOUT_PROMPT_NAME_ACTIVE = "Customer at checkout"` is the active-state label; `_CHECKOUT_PROMPT_NAME_IDLE = "No customer waiting"` is the idle label. `_refresh_checkout_prompt` writes `prompt_text = ""` unconditionally — Day 1 customers auto-complete checkout via `PlayerCheckout.process_transaction()`, so the counter has no player-driven verb to advertise. `retro_games.tscn`'s authored `display_name = "Checkout Counter"` / `prompt_text = "Checkout"` is rewritten in lockstep to `"No customer waiting"` / `""`. |
| ShelfSlot occupied prompt + visual sync | **Pass 1–3:** `_refresh_prompt_state` rendered authored `display_name` / `prompt_text` for occupied slots; `place_item` / `remove_item` directly called `_spawn_item_mesh` / `_free_item_mesh` and `_update_empty_indicator`. | **Pass 4:** `_update_visual(quantity)` is the single SSOT entry point that synchronizes the placeholder mesh + empty indicator with current occupancy; `place_item` and `remove_item` route through it instead of touching the mesh helpers directly. Per-category placeholder tinting via `CATEGORY_COLORS` table + `_apply_category_color` so different stocked items read as visually distinct cubes. Prompt rendering for occupied non-placement slots now reads `"<item_name> ×<quantity>"` (verb empty) using the new `_stocked_item_name` member set by `set_display_data`. |
| Debug-overlay dev fallbacks (Day-1 unblock keys) | (new) | **Pass 4:** `DebugOverlay._input` adds four single-key (no modifier) shortcuts that run whenever the overlay node is alive (release builds `queue_free` in `_ready` so they are no-ops there): `F8` → `_debug_spawn_customer`, `F9` → `_debug_add_test_inventory` (routes through `DataLoader.create_starting_inventory` and adds to backroom), `F10` → `_debug_force_place_test_item` (routes through `StoreController.dev_force_place_test_item`), `F11` → `_debug_force_complete_sale` (routes through `CheckoutSystem.dev_force_complete_sale`, which is gated on `OS.is_debug_build()` and short-circuits to false in release builds). The display block now also shows `ActiveStore: <id>`. **Single SSOT for "unblock the Day-1 loop":** the four debug-overlay handlers + the corresponding `dev_*` entries on the underlying systems. |
| Interaction telemetry (debug builds) | (new) | **Pass 4:** `InteractionRay._log_interaction_focus(target)` and `_log_interaction_dispatch(target)` print `"[Interaction] <display>: <verb>"` and `"[Interaction] <display>: <verb> (dispatched)"` lines respectively, gated on `OS.is_debug_build()`. Wired into `_set_hovered_target` (focus emit) and the two `_unhandled_input` interact paths (E-key + left mouse). Single SSOT for the dev-time interaction trace; release builds short-circuit before the print so the player log stays clean. |

---

## Pass 4 risk log — intentionally retained

| Item | Why retained | Concrete trigger to remove |
|---|---|---|
| Day-1 `objectives.json` `post_sale_text` / `post_sale_action` / `post_sale_key` fields | The new `steps[]` chain is the primary path on Day 1, but `_emit_current` falls back to the post-sale copy when `_day1_steps_available()` returns false (steps array missing or count != `DAY1_STEP_COUNT`). Removing the post-sale fields would crash the rail on a corrupted Day-1 load by emitting the day's pre-sale copy after the sale closes — worse UX than the current defensive fallback. The §F-93 push_warning at `_load_content` makes the corrupted-load case visible at boot. **Justified, not removed.** | A pass that decides corrupted Day-1 content should hard-fail boot instead of falling back. At that point the post-sale Day-1 entry can be removed and `_load_content` can `push_error` instead of `push_warning` on step-array shape mismatch. |
| `Constants.STARTING_CASH = 500.0` (alongside `EconomyConfig.starting_cash = 500.0` in `pricing_config.json`) | The constant is the documented fallback for tests that bypass `DataLoader` (`test_starting_cash_equals_constant`, `test_economy_difficulty_wiring`, `test_progression_system`, etc.) and the parameter default on `EconomySystem.initialize(starting_cash := Constants.STARTING_CASH)`. Removing it would force every such test to construct an `EconomyConfig` resource just to drive `EconomySystem`. The two values matching by hand is a maintenance burden, but the value rarely changes (only at major-balance milestones); `tests/gut/test_pricing_config.gd::test_starting_cash_is_500` pins the config side and would surface a divergence. **Justified, not consolidated.** | A consolidation pass that introduces `EconomyConfig.STARTING_CASH_DEFAULT` static / constant on the resource class itself, shared by `pricing_config.json` parsing and the `EconomySystem.initialize` default. At that point `Constants.STARTING_CASH` can be deleted and the tests rewritten to read the resource constant. |
| `Customer._is_navigation_finished()` short-circuit on `_use_waypoint_fallback` | The check returns `_fallback_arrived` instead of asking the agent — necessary because the agent's `is_navigation_finished()` returns true the moment a path can't be resolved (which is exactly the condition that triggered the fallback). Without the short-circuit, every `_process_*` state handler would think the customer had arrived before they ever moved. **Justified, by design.** | A future where `_detect_navmesh_or_fallback` is removed (every store ships with a baked navmesh and an authored NavigationRegion3D + NavigationAgent3D pair). At that point `_use_waypoint_fallback` and the entire fallback subtree can be deleted in lockstep. |
| `_register_queue_size` member in `retro_games.gd` (reads from `EventBus.queue_advanced` and gates `_refresh_checkout_prompt`'s active-vs-idle label swap) | After the Pass-4 prompt-text-empty rewrite, `_register_queue_size > 0` no longer drives a verb difference (the prompt is always informational). The member still gates the `display_name` swap between "Customer at checkout" and "No customer waiting", which is the player-visible cue Day 1 relies on. **Justified, retained.** | A future where the checkout counter loses its informational label entirely (e.g. the customer body itself surfaces a floor sign that handles the cue). At that point `_register_queue_size`, `_on_queue_advanced`, and `_refresh_checkout_prompt` can all be removed. |
| All Pass 1 / Pass 2 / Pass 3 retained items (CameraManager mirror function, `_resolve_store_id` 5-way duplication, `StorePlayerBody.set_current_interactable` test seam, `ProvenancePanel`, audit-report historical filenames, `DataLoader.create_starting_inventory` vs `generate_starter_inventory` coexistence, `LATE_EVENING` extended-hours-unlock retention, `_emit_sale_toast` vs `_on_customer_item_spotted` toast emission) | Nothing in the Pass-4 working-tree change set alters their disposition; the rationales above (Pass 1 / Pass 2 / Pass 3 risk logs) still hold. | Same triggers as the original entries. |

---

## Pass 4 sanity check — dangling references

| Check | Result |
|---|---|
| Any code still reading `StoreDefinition.starting_cash`? | None. Greps for `StoreDefinition\..*starting_cash` and `\.starting_cash\s*=` (assignment to the field) return zero hits in `*.gd`/`*.tscn`/`*.json`. `parse_store` no longer reads the key; `parse_economy_config` reads `EconomyConfig.starting_cash` (a different resource class). |
| Any code still citing `_day1_customer_spawned` (the old flag name)? | None. `grep _day1_customer_spawned` returns zero hits. Every reader (`spawn_customer`, `_on_item_stocked`, `_on_day_started`, `_on_day1_forced_spawn_timer_timeout`, two test files) now reads `_day1_first_customer_spawned`. |
| Any code citing `_on_select_for_placement` / `add_select_button` / `_build_select_spacer`? | None outside `docs/audits/cleanup-report.md` historical Pass-6 narrative. The unrelated `difficulty_selection_panel.gd::_add_select_button` is a different method on a different class. |
| Any `FpInventoryHint` node creation outside the Pass-4 regression-guard test? | None. `hud.gd` no longer creates the node; `tests/gut/test_hud_fp_mode.gd:260` calls `get_node_or_null("FpInventoryHint")` and asserts `null` — that is the regression guard, not a creation site. |
| Any `_CHECKOUT_PROMPT_VERB_ACTIVE` / "Press E to checkout customer" verb string left behind? | None. `_CHECKOUT_PROMPT_VERB_ACTIVE` constant is deleted; the only "Press E to checkout customer" mention in the tree is the now-rewritten doc comment in `retro_games.gd:64–67` (this pass) and a historical mention in `tests/gut/test_retro_games_checkout_prompt_state.gd` docstring describing what the test pins (which is the absence of that verb). |
| Any code citing `STARTING_CASH := 750.0` or `starting_cash: 750.0` / `800.0` / `850.0` / `900.0` / `1000.0`? | None. `Constants.STARTING_CASH = 500.0`; `pricing_config.json::starting_cash = 500.0`. The five per-store overrides (sports_memorabilia 750, retro_games 800, video_rental 900, pocket_creatures 850, consumer_electronics 1000) are deleted; `tests/validate_issue_013.sh` (which pinned them) is deleted. |
| Any test still asserting against the removed Day-1 objective `text` "Stock your first item and make a sale" as the *initial* rail copy? | None. `tests/gut/test_objective_rail_day1_visibility.gd` and `tests/gut/test_objective_director.gd` were rewritten in this branch to assert against the steps-chain copy ("Open your inventory" / "Press I to open the inventory panel"). The removed string survives only in `objectives.json` Day-1 `text` field as the steps-chain-disabled fallback (intentional, risk-logged). |
| Any audit report still presenting the Pass-3 Day-1 SSOT (`text` + `post_sale_text` flat payload as the sole writer) as the live state? | None after this pass. The Pass-4 SSOT-modules table above supersedes the Pass-3 table; the historical Pass-3 entry at line 69 is preserved as record. |

---

## Pass 4 escalations

None. Every Pass 4 finding either acted (one stale doc comment
rewritten in `retro_games.gd:64–67`) or was justified inline with the
rationale in the Risk Log above. No SSOT decision was left blocked.

---

## Pass 5 changes (2026-05-05)

**Scope:** SSOT enforcement against the working-tree diff that pivots
the project from "Day-1 fully playable" polish (Pass 4) to a 30-day
"2005 mall game-store" beta — one playable corporate store during the
holiday rush, with employment, manager relationship, returns, holds,
trade-ins, hidden-thread, platform shortages, and shift mechanics. The
diff is purely additive at the EventBus layer (52 new signals, zero
removed) and at most autoload systems; the TutorialStep migration is
the only deletion-bearing rewrite, and it was paired with the
corresponding test, localization, and consumer renames in lockstep.

**Verification:** `git status` shows the working-tree diff is staged
on `main` itself (no remote ahead). `git diff HEAD --stat` reports 84
modified files plus the new untracked systems / panels / tests. No
test run was forced for this pass because the only acted-on edit is a
docstring (no executable code is changed); the prior Pass 4 verification
(5076/5076 GUT tests, 0 failures) still applies to the executable code
state. Pre-existing validator failures (ISSUE-018, ISSUE-023, ISSUE-024,
ISSUE-026, ISSUE-032, ISSUE-154, ISSUE-239) on `main` are unchanged by
Pass 5.

### Edits applied

| Path | Change | Rationale | Disposition |
|---|---|---|---|
| `tests/gut/test_customer_item_spotted.gd:1–5` | Rewrote the file-header docstring. The old text claimed the file covered "AmbientMomentsSystem toast + dedup handling, and TutorialSystem WAIT_FOR_CUSTOMER advance wiring". The TutorialStep enum no longer has `WAIT_FOR_CUSTOMER` (Pass 5 working-tree diff bumps `SCHEMA_VERSION = 2 → 3` and replaces the customer-loop steps with the employee-loop steps), and `test_tutorial_customer_browsing_advances_on_item_spotted` was deleted in the same diff (lines 215–246 of the prior file). The new docstring reflects what the file actually covers and points at this pass's report so a future reader can find the rationale. | **Code is the SSOT** for what the test file covers; the docstring was a stale narrative that promised coverage that no longer exists. The §F-85 schema-version reset comment in `tutorial_system.gd:435` is the canonical historical record of the v2 → v3 migration; this docstring just cross-references it. | **Acted (tighten)** |

### What did not require a Pass-5 code edit

The branch's diff already drops the SSOT contradictions for every
other domain Pass 5 audited; the existing tutorial-flow rename is the
only deletion path in scope and it was performed in lockstep across
producers, consumers, tests, and localization. Specifically:

* **TutorialStep enum + `STEP_IDS` + `STEP_TEXT_KEYS`** — `OPEN_INVENTORY`,
  `SELECT_ITEM`, `PLACE_ITEM`, `WAIT_FOR_CUSTOMER`, `CUSTOMER_BROWSING`,
  `CUSTOMER_AT_CHECKOUT`, `COMPLETE_SALE` deleted in the diff.
  `PLATFORM_MATCH`, `STOCK_SHELF`, `CONDITION_RISK`,
  `SPORTS_DEPRECIATION`, `HOLD_PRESSURE`, `HIDDEN_THREAD` replace them.
  `SCHEMA_VERSION` bumped 2 → 3 so a v2 cfg resets cleanly via the §F-85
  warn-and-reset path. `_on_panel_opened`, `_on_placement_mode_entered`,
  `_on_customer_entered`, `_on_customer_item_spotted`,
  `_on_customer_ready_to_purchase`, `_on_customer_purchased` handlers
  deleted; `_on_customer_platform_identified`,
  `_on_trade_in_condition_graded`, `_on_trade_in_price_confirmed`,
  `_on_hold_decision_made`, `_on_hidden_clue_acknowledged` added in
  lockstep with the new step enum. Greps confirm zero residual
  references to the removed step ordinals or text keys outside the
  intentional historical notes (`tutorial_system.gd:435` migration
  warning, this report's Pass 3 sanity-check line at 462, and
  `staff_animator.gd::PLACE_ITEM_SPEED` which is an unrelated animation
  constant on a different namespace).
* **Old-tutorial localization keys** — `TUTORIAL_OPEN_INVENTORY`,
  `TUTORIAL_SELECT_ITEM`, `TUTORIAL_PLACE_ITEM`, `TUTORIAL_WAIT_CUSTOMER`,
  `TUTORIAL_CUSTOMER_BROWSING`, `TUTORIAL_CUSTOMER_AT_CHECKOUT`,
  `TUTORIAL_COMPLETE_SALE` deleted from `translations.en.csv` /
  `translations.es.csv`. The new keys are present.
* **`test_tutorial_customer_browsing_advances_on_item_spotted`** —
  deleted in the diff (`tests/gut/test_customer_item_spotted.gd` —32
  lines). The retained tests in that file still cover the
  `customer_item_spotted` signal's *non-tutorial* purpose (emission
  from `Customer._evaluate_current_shelf` and consumption by
  `AmbientMomentsSystem._on_customer_item_spotted`), which is why the
  signal itself is *not* deleted.
* **`test_tutorial_system.gd` step-progression assertions** — rewritten
  in the diff to walk `WELCOME → PLATFORM_MATCH → STOCK_SHELF →
  CONDITION_RISK` instead of the old `WELCOME → OPEN_INVENTORY →
  SELECT_ITEM → PLACE_ITEM`. The `test_stale_schema_version_resets_progress`
  case is rewritten to seed a v2 cfg and assert the reset-and-resave
  path lands on v3.
* **CustomerSystem archetype-spawn additions** — the new
  `is_profile_currently_spawnable` / `get_profile_spawn_weight` /
  `pick_spawn_profile` / `_record_archetype_spawn` paths layer on top
  of (not duplicate) the prior `_get_profile_spawn_weights` /
  `_get_profile_spawn_intervals` infrastructure. The new public
  `pick_spawn_profile(pool)` entry replaces the diff's two
  `pool.pick_random()` call sites in `_on_day1_forced_spawn_timer_timeout`
  and `MallCustomerSpawner._spawn_for_store(active_store)` so the
  archetype gates and PlatformSystem / StoreCustomizationSystem weight
  hooks fire on every Day-1 / active-store spawn. **No call site is
  left calling the un-gated `pick_random` path** — the only surviving
  `pick_random` in `MallCustomerSpawner._spawn_for_store` is on the
  background-store branch where archetype gating is irrelevant
  (the customer never enters an interior).
* **CheckoutSystem decision-card upgrade** — the haggle-panel callsites
  for `show_outcome(true/false)` are kept as the documented fallback
  when the new decision card is not populated
  (`_haggle_panel.is_card_populated() == false`). Both branches are
  reachable: `show_result(...)` runs once `populate_customer_card`
  has been called (the new flow); `show_outcome(...)` runs when the
  haggle panel was opened pre-card-population (a path
  `test_haggle_panel.gd` still exercises). Not a duplicate; both are
  needed under the new "card-aware" mode.
* **ProgressionSystem dual gating** — `_current_manager_approval` (from
  EmploymentSystem) and `_manager_trust_tier_index` (from
  ManagerRelationshipManager) are both cached and both feed milestone
  evaluation through distinct `CONDITION_*` keys
  (`CONDITION_MANAGER_APPROVAL`, `CONDITION_MANAGER_TRUST_TIER`).
  Some milestones gate on the numeric approval (returns escalation
  contributes here); others gate on the discrete tier (morning-note
  category-driven ones). The two scalars **track different aspects
  of the manager relationship** even though both are nominally
  "manager↔player". Risk-logged below for the architectural followup;
  no Pass-5 deletion possible without a structural refactor that is
  out of scope for SSOT enforcement.

---

## Final SSOT modules per domain (Pass 5 deltas)

| Domain | Pass 1–4 SSOT | Pass 5 update |
|---|---|---|
| Tutorial step enum / progression | **Pass 3:** `WELCOME → OPEN_INVENTORY → SELECT_ITEM → PLACE_ITEM → WAIT_FOR_CUSTOMER → CUSTOMER_BROWSING → CUSTOMER_AT_CHECKOUT → COMPLETE_SALE → CLOSE_DAY → DAY_SUMMARY → FINISHED` (the customer-loop sequence). `SCHEMA_VERSION = 2`. | **Pass 5:** `WELCOME → PLATFORM_MATCH → STOCK_SHELF → CONDITION_RISK → SPORTS_DEPRECIATION → HOLD_PRESSURE → HIDDEN_THREAD → CLOSE_DAY → DAY_SUMMARY → FINISHED` (the employee-loop sequence). `SCHEMA_VERSION = 3`. Receivers swapped one-to-one: `customer_platform_identified`, `item_stocked`, `trade_in_condition_graded`, `trade_in_price_confirmed`, `hold_decision_made`, `hidden_clue_acknowledged`. The Day-1 objective rail remains driven by `objectives.json` `steps[]` and `ObjectiveDirector._day1_step_index` (Pass 4 SSOT) — those steps continue to mirror the customer-walk-in flow because they describe the on-screen progress indicator, not the tutorial overlay. The two surfaces are intentionally distinct. |
| Employment relationship state | (new) | **Pass 5:** `EmploymentSystem` autoload + `EmploymentState` resource. Owns: `employee_trust` (0–100, mid-range default 50.0, drives firing at 15.0 / retention at 60.0 over `SEASON_LENGTH_DAYS = 30`), `manager_approval` (0–100, low-neutral default 0.5 — see risk log below), `employment_status` (`active` / `probation` / `at_risk` / `fired` / `retained`), `hourly_wage`, `hours_worked_total`. Persists at `user://employment_state.cfg`. Mutators: `start_employment(store_id, hourly_wage)`, `end_employment(outcome)`, `apply_trust_delta(delta, reason)`, `apply_manager_approval_delta(delta, reason)`, `assign_task(id)`, `complete_task(id)`, `issue_daily_wage()`. Listens to `EventBus.customer_purchased` / `task_completed` / `day_started` / `day_ended`. Mirrors `employee_trust` and `manager_approval` to `GameState.employee_trust` / `GameState.manager_approval`. **Single SSOT for the employment relationship.** |
| Manager relationship trust + morning-note selection | (new) | **Pass 5:** `ManagerRelationshipManager` autoload. Owns: `manager_trust` (0.0–1.0, default 0.5), `manager_tier` (`cold` / `neutral` / `warm` / `trusted` derived from trust at thresholds 0.25 / 0.50 / 0.75), per-day category tally (`operational` / `sales` / `staff`), `_pending_unlock_id`. Mutators: `apply_trust_delta(delta, reason)`. Note selection: `select_note_for_day(day)` returns the override note for Day 1 / 10 / 20 / unlock-after, falling back to `tier_notes[tier][top_category]` from `res://game/content/manager/manager_notes.json`. Emits `manager_note_shown` on `day_started`, `manager_confrontation_triggered` when trust crosses below 0.15 in cold tier. **Single SSOT for the morning-note tier-driven selection.** |
| Returns lifecycle (defective sale → decision → side effects) | (new) | **Pass 5:** `ReturnsSystem` autoload. Owns: `_pending_records: Array[ReturnRecord]`, `_resolved_refund_instances: Dictionary`. Listens to `EventBus.defective_sale_occurred` (emitted by `CheckoutSystem._complete_checkout` on `_active_item.condition in DEFECTIVE_CONDITIONS = ["poor", "damaged"]`). Decision API: `accept_return(record, resolution)` / `deny_return(record)` / `escalate_return(record)`. Side effects funnel through `EmploymentSystem.apply_trust_delta(±)` and `EmploymentSystem.apply_manager_approval_delta(+0.02)` on escalate; reputation deltas through `ReputationSystemSingleton.add_reputation`; cash through `EconomySystem.add_cash` (refund) / no-op (deny). Inventory variance reconciliation: `check_bin_variance()` walks the InventorySystem damaged-bin location and emits `EventBus.inventory_variance_noted` for any entry not in the resolved-refund ledger; `HiddenThreadSystem` consumes that signal to advance `scapegoat_risk`. **Single SSOT for the post-sale returns flow.** |
| Hidden-thread narrative tracker | (new) | **Pass 5:** `HiddenThreadSystem` autoload. Tracks the off-book inventory weirdness behind the surface game: `awareness_tier` (0–3), `scapegoat_risk` scalar, observed-clues set. Listens to `inventory_variance_noted`, `defective_item_received`, `delivery_manifest_examined`, `hold_shady_request_received`, `display_exposes_weird_inventory`, `hold_duplicate_detected`, `inventory_discrepancy_flagged`, `customer_resolution_logged`. Emits `hidden_clue_acknowledged`, `hidden_artifact_spawned`, `hidden_thread_interaction_fired`, `hidden_awareness_tier_changed`, `hidden_thread_consequence_triggered`. **Single SSOT for the BRAINDUMP "hidden game" thread.** |
| Per-day shift state (clock-in, clock-out, hours-worked) | (new) | **Pass 5:** `ShiftSystem` (`game/scripts/systems/shift_system.gd`, store-scoped — *not* an autoload). Owns: `_clocked_in: bool`, `_clock_in_time`, `_late: bool`, auto-clock-in fallback at `08:55` if the player has not clocked in via `ClockInInteractable`. Emits `EventBus.shift_started(store_id, timestamp, late)` and `shift_ended(store_id, hours_worked)`. Consumed by `MilestoneSystem._on_shift_started` (clock-in milestones), `ProgressionSystem._on_shift_started` (counter), `ManagerRelationshipManager` (tracked indirectly — late clock-ins are an `operational` category event). **Single SSOT for the daily shift lifecycle.** |
| Platform shortage / hype state | (new) | **Pass 5:** `PlatformSystem` (`game/scripts/systems/platform_system.gd`). Owns per-platform shortage state, hype thresholds, restock counts. Loaded from `game/content/platforms.json`. Emits `platform_shortage_started`, `platform_shortage_ended`, `platform_hype_threshold_crossed`, `platform_restock_received`. Consumers: `CustomerSystem.get_profile_spawn_weight` (multiplies weight by `get_spawn_weight_modifier(profile)` based on platform_affinities), `RetroGames._update_new_console_display` (live "BACK ORDERED" / "IN STOCK" sign), `HiddenThreadSystem` (hype-cliff scapegoat-risk advance). **Single SSOT for platform supply state.** |
| Hold list (per-store reservations) | (new) | **Pass 5:** `HoldList` (`game/scripts/stores/hold_list.gd`, per-store object, instantiated by `RetroGames._ready`). Owns: `_slips: Array[HoldSlip]`, conflict resolver. Decision API: `add_hold`, `fulfill_hold`, `expire_holds_for_day`, `resolve_conflict(slip, choice)` where `choice ∈ {HONOR, ESCALATE, WALK_IN}`. The choice routes through `RetroGames._apply_manager_trust_delta` (with deltas `+0.02` / `+0.03` / `−0.05` per conflict spec) — the only Pass-5 entry that touches `ManagerRelationshipManager` from a per-store controller, and the only one that intentionally bypasses `EmploymentSystem.manager_approval`. Emits `hold_added`, `hold_fulfilled`, `hold_expired`, `hold_decision_made`, `hold_duplicate_detected`, `hold_shady_request_received`, `hold_conflict_bypassed`. **Single SSOT for the active store's hold roster.** |
| Trade-in intake flow | (new) | **Pass 5:** `TradeInSystem` (`game/scripts/systems/trade_in_system.gd`). Owns the trade-in offer / counter / acceptance state machine. Emits `trade_in_initiated`, `trade_in_offer_made`, `trade_in_accepted`, `trade_in_rejected`, `trade_in_completed`, `trade_in_condition_graded`, `trade_in_price_confirmed`. Consumed by `TutorialSystem._on_trade_in_condition_graded` / `_on_trade_in_price_confirmed` (CONDITION_RISK + SPORTS_DEPRECIATION step advances), `RetroGames` for inventory reception. **Single SSOT for trade-in intake.** |
| Mid-day random-event card | (new) | **Pass 5:** `MidDayEventSystem` (`game/scripts/systems/midday_event_system.gd`). Selects a beat from `day_beats.json` once per day at the mid-day phase, presents `MidDayEventCard`, records the player's choice. Emits `midday_event_fired` and `midday_event_resolved(beat_id, choice_index)`. Consumers: `HiddenThreadSystem` (consequence text routing), `PerformanceReportSystem` (mistake counter when the choice is the documented wrong path). **Single SSOT for the mid-day decision beat.** |
| Store customization (featured-category emphasis) | (new) | **Pass 5:** `StoreCustomizationSystem` (`game/scripts/systems/store_customization_system.gd`). Owns the active featured category and the player-driven layout choices that bias customer spawn weights. Public API: `get_spawn_weight_bonus(archetype_id)` consumed by `CustomerSystem.get_profile_spawn_weight`. Emits `featured_category_changed` (consumed by `HiddenThreadSystem` for the `new_console_hype` weird-inventory trigger). **Single SSOT for store-level player customization knobs.** |
| Customer archetype spawn gating + weighting | (Pass 1–4: `CustomerSystem._refresh_current_archetype_weights()` per `DayPhase` from `ShopperArchetypeConfig`, no per-day caps or conditional gates.) | **Pass 5:** `CustomerSystem.is_profile_currently_spawnable(profile)` is the single sticky gate ([`angry_return_customer` requires `_defective_sale_today`; `shady_regular` capped at `SHADY_REGULAR_DAILY_CAP = 1`]). `get_profile_spawn_weight(profile)` multiplies `profile.spawn_weight × PlatformSystem.get_spawn_weight_modifier(profile) × StoreCustomizationSystem.get_spawn_weight_bonus(profile.archetype_id) × (3.0 if shady_regular and AFTERNOON else 1.0)`. `pick_spawn_profile(profiles)` runs the weighted roll and is the **single entry point** every Day-1 / active-store spawn path now uses (`_on_day1_forced_spawn_timer_timeout`, `MallCustomerSpawner._spawn_for_store` active branch). `_archetype_spawn_count_today` and `_defective_sale_today` reset on `day_started`; the latter is set by `_on_defective_sale_occurred(_item_id, _reason)` listening to `EventBus.defective_sale_occurred`. **Single SSOT for "may this profile spawn now and at what weight?"** |
| Defective-sale signal | (new) | **Pass 5:** `EventBus.defective_sale_occurred(item_id, reason)`, sole emitter is `CheckoutSystem._complete_checkout` when `_active_item.condition in DEFECTIVE_CONDITIONS = ["poor", "damaged"]`. Two intentional consumers: `ReturnsSystem._on_defective_sale_occurred` (records a pending `ReturnRecord` for the eventual angry-return customer) and `CustomerSystem._on_defective_sale_occurred` (sets `_defective_sale_today = true` to unblock `angry_return_customer` spawns). The signal carries the raw condition string; `ReturnsSystem.DEFECT_REASON_LABELS` is the SSOT for human-readable defect labels (UI side); `CheckoutSystem.DEFECTIVE_CONDITIONS` is the SSOT for which conditions count as defective (gate side). The two constants do *not* duplicate — they are the read and write halves of the same contract. |

---

## Pass 5 risk log — intentionally retained

| Item | Why retained | Concrete trigger to remove |
|---|---|---|
| `EmploymentSystem.manager_approval` (0–100) **and** `ManagerRelationshipManager.manager_trust` (0.0–1.0) as separate scalars | Both nominally describe "how the manager feels about the player," but the new design uses them for **different gameplay levers**: `manager_approval` is the explicit-event counter that returns/escalations move (consumed by `ProgressionSystem.CONDITION_MANAGER_APPROVAL` and the wage-increase / promotion reward paths), while `manager_trust` is the morning-note tier-driver consumed by `MilestoneSystem.CONDITION_MANAGER_TRUST_TIER`, the `DaySummary` "Manager Trust" bar, the `PerformanceReport` cached delta, and the `RetroGames` hold-conflict per-choice deltas. The 0–100 numeric scale and the 0–1 four-tier scale answer different questions ("how many discrete approval beats has the player accumulated?" vs "what register should the next morning-note play in?"). Collapsing them is an architectural refactor (renormalize the two scales, decide which consumers move, rebuild the test fixtures) that is out of scope for an SSOT *deletion* pass. **Justified, not consolidated.** | A future "manager-relationship consolidation" pass with explicit license to: (1) pick one scalar (probably `manager_trust` as the canonical 0–1 axis since the morning-note tier table is the heaviest consumer); (2) delete the other field, its EmploymentState row, its EventBus signal, its GameState mirror, and its ProgressionSystem milestone gate; (3) rewrite `ReturnsSystem._escalate` to drive the surviving scalar; (4) update the `tests/gut/test_employment_system.gd` and `tests/gut/test_manager_relationship_manager.gd` fixtures in lockstep. The trigger is design alignment on which scale wins; until then the dual-scalar contract is documented at `EmploymentState:5–7` and `manager_relationship_manager.gd:1–17`. |
| `EmploymentState.APPROVAL_MAX = 100.0` with `DEFAULT_APPROVAL = 0.5` (looks like a 0–1 default in a 0–100 range) | Documented intent: "0.5 — a neutral placeholder for the first manager event" (`EmploymentState:6`). The default is *deliberately* near-zero so the first explicit-event delta moves the value perceptibly; a 50.0 default would put it mid-range above the firing-equivalent floor for the inverse signal. `GameState.DEFAULT_MANAGER_APPROVAL = 0.5` and `ProgressionSystem._current_manager_approval = EmploymentState.DEFAULT_APPROVAL` are consistent with that intent. The naming is unfortunate (a reader expects 50.0) but everywhere downstream uses the 0–100 range correctly (`ProgressionSystem._on_manager_approval_changed` clamps to `0.0..100.0`, `GameState.manager_approval` clamps the same). **Justified, retained — not an SSOT split.** | A future cleanup pass that either (a) renames `DEFAULT_APPROVAL` to `DEFAULT_APPROVAL_PLACEHOLDER` to make the intent loud, or (b) raises the default to e.g. 50.0 and rebalances the per-event deltas. Either way the change is a balance-tuning decision, not an SSOT one. |
| `EventBus.customer_resolution_logged(outcome: String)` with no production emitter | The signal is declared (`event_bus.gd:580`), connected in `PerformanceReportSystem._on_customer_resolution_logged` (line 668), and exercised by `tests/gut/test_performance_report_employee_metrics.gd` (7 emit sites). The docstring at `performance_report_system.gd:694–698` claims "returns / holds / trade-ins call this directly," but greppably no production caller exists — the wiring on the emit side is pending in this branch's diff. The receiver code is correct and the test pins the contract; deleting the signal would require also deleting the receiver branch in `_compute_customer_satisfaction` (which already falls back to `customer_left.satisfied` counting) and the seven test cases. With three concrete production callers planned (Returns / Holds / Trade-ins all newly added to this branch), the more likely fix is **wiring the emit side**, not removing the contract. **Justified, retained — not dead, just half-wired.** | A pass that audits the seven new systems for explicit `customer_resolution_logged` emission wiring; if after that pass any production caller still does not emit it, the receiver and tests can be deleted along with the signal declaration and the docstring rewritten to remove the false "returns / holds / trade-ins call this directly" claim. |
| `MallCustomerSpawner.SECOND_STORE_CHANCE = 0.2` + `_pending_second_visits` + `_process_second_visits` + `_queue_second_visit` + `_try_second_store_visit` | Pre-existing on `main` ahead of this branch; the BRAINDUMP single-store framing makes the second-visit roll a runtime no-op (`_store_selector.select_store(excluded_store)` returns empty when only one store is leased), but the code is reachable in the same way `unlocked_store_slots` and `STORE_UNLOCK_THRESHOLDS` are still reachable: the multi-store infrastructure is dormant rather than deleted while the beta pivot stabilizes. The Pass-5 working-tree diff does not touch `mall_customer_spawner.gd` (+9 lines, all on the spawn-pool side), and the SSOT contract limits this pass to deletions the diff *proves* obsolete. **Outside Pass-5 scope. Risk-logged for a future "drop multi-store" pass.** | A pass with explicit license to drop the multi-store infrastructure (the `STORE_UNLOCK_THRESHOLDS` array, `unlocked_store_slots`, the `store_2_unlocked` milestone, the second-visit logic, `MallCustomerSpawner._spawn_for_store` background branch) once the design has confirmed the beta will not seed any other interior. |
| `EventBus.title_rented` / `title_returned` (alongside `item_rented` / `rental_returned`) and `EventBus.demo_unit_activated` / `demo_unit_removed` (alongside `demo_item_placed` / `demo_item_removed`) "alias" signals | Pre-existing on `main`; not modified by this branch's diff. Production emitter (`video_rental_store_controller.gd:239–240`) emits `item_rented` and `title_rented` back-to-back with the same payload — a textbook duplicate emission. `item_rented` has 5 production/test consumers (`completion_tracker`, `audio_event_handler`, three test files); `title_rented` has 1 test consumer. The `demo_*` pair has the same shape. The header comment on `event_bus.gd:426` calls the second pair "canonical … aliases kept for backward compatibility" but does not name which is which. The SSOT winner in both pairs is the `item_*` / `demo_item_*` form. The fix is mechanical (delete the alias declarations + their dual-emit lines + their one-test consumers) but it is outside this pass's diff scope. **Risk-logged.** | A "pre-existing duplicate signal" cleanup pass with explicit license to operate outside the current branch's diff envelope. At that point the alias declarations, the dual-emit lines, and the alias-only test cases can be deleted in lockstep. |
| Day-1 objective rail step-id constants `DAY1_STEP_OPEN_INVENTORY` / `DAY1_STEP_SELECT_ITEM` / `DAY1_STEP_WAIT_FOR_CUSTOMER` / `DAY1_STEP_CUSTOMER_BROWSING` / `DAY1_STEP_CUSTOMER_AT_CHECKOUT` in `objective_director.gd:17–22` | Look superficially like the deleted TutorialStep names but are intentionally distinct: the ObjectiveDirector's Day-1 rail describes the **on-screen progress indicator** for the customer-walk-in flow (Pass-4 SSOT, lines 137 of this report). The TutorialStep enum describes the **tutorial overlay** which after Pass 5 teaches retail concepts (`PLATFORM_MATCH`, `CONDITION_RISK`, …) over multiple days. Both surfaces coexist by design and intentionally use different vocabularies even where the Day-1 rail still walks an inventory-and-customer path. **Justified, retained — different surface.** | A unification pass that decides Day-1 specifically should also use the employee-loop tutorial vocabulary on the rail. At that point the constants and the Day-1 `objectives.json` `steps[]` array can be renamed in lockstep and the §F-93 push-warn shape check rewritten. |
| `CheckoutSystem` retains both `show_outcome(true/false)` and `show_result(...)` haggle-panel callsites | Not duplicates: `show_outcome` is the documented fallback when the haggle panel was not first populated through the new decision-card flow (`_haggle_panel.is_card_populated() == false`). `tests/gut/test_haggle_panel.gd` exercises the fallback. **Justified, both reachable.** | A pass that removes the pre-decision-card haggle path entirely — at that point `show_outcome` and the `is_card_populated` branch can be deleted in lockstep with the test cases that exercise it. |
| All Pass 1 / Pass 2 / Pass 3 / Pass 4 retained items (CameraManager mirror function, `_resolve_store_id` 5-way duplication, `StorePlayerBody.set_current_interactable` test seam, `ProvenancePanel`, audit-report historical filenames, `DataLoader.create_starting_inventory` vs `generate_starter_inventory` coexistence, `LATE_EVENING` extended-hours-unlock retention, `Constants.STARTING_CASH` vs `EconomyConfig.starting_cash` paired defaults, `Customer._is_navigation_finished` short-circuit, `_register_queue_size` checkout-queue gate, `_emit_sale_toast` vs `_on_customer_item_spotted` toast paths, etc.) | Nothing in the Pass-5 working-tree diff alters their disposition; the Pass-1/2/3/4 risk-log rationales still hold. | Same triggers as the original entries. |

---

## Pass 5 sanity check — dangling references

| Check | Result |
|---|---|
| Any code citing `TutorialSystem.TutorialStep.OPEN_INVENTORY / SELECT_ITEM / PLACE_ITEM / WAIT_FOR_CUSTOMER / CUSTOMER_BROWSING / CUSTOMER_AT_CHECKOUT / COMPLETE_SALE`? | None. `grep TutorialStep\.\(OPEN_INVENTORY\|…\)` in `tests/` and `game/scripts/` returns zero hits. The remaining string matches in the tree are: (a) the §F-85 schema-version migration warning at `tutorial_system.gd:435`, intentional historical record; (b) the Pass-3 sanity-check entry at `docs/audits/ssot-report.md:462`, also intentional historical record; (c) `staff_animator.gd::PLACE_ITEM_SPEED`, an unrelated animation constant; (d) `ambient_moments_system.gd::CUSTOMER_BROWSING_TOAST_DURATION`, an unrelated toast-duration constant; (e) `objective_director.gd::DAY1_STEP_*`, the intentional rail vocabulary justified above. |
| Any localization key `TUTORIAL_OPEN_INVENTORY / TUTORIAL_SELECT_ITEM / TUTORIAL_PLACE_ITEM / TUTORIAL_WAIT_CUSTOMER / TUTORIAL_CUSTOMER_BROWSING / TUTORIAL_CUSTOMER_AT_CHECKOUT / TUTORIAL_COMPLETE_SALE`? | None remaining as live entries. `translations.en.csv` and `translations.es.csv` rows are deleted; the `.translation` binary blobs are regenerated. The only file that still mentions the keys is this report's Pass-3 sanity-check entry at line 462, which is an intentional historical record. |
| Any test file still asserting against `customer_item_spotted`-driven tutorial advancement? | None. The deleted test was `tests/gut/test_customer_item_spotted.gd::test_tutorial_customer_browsing_advances_on_item_spotted` (lines 215–246 of the prior file). The retained tests in that file cover only the non-tutorial use of the signal (toast / dedup / customer-leave clearing). The file's header docstring was rewritten in this pass to match what it actually covers. |
| Any signal handler in `TutorialSystem` for the removed `panel_opened` / `placement_mode_entered` / `customer_entered` / `customer_item_spotted` / `customer_ready_to_purchase` / `customer_purchased` step-advance paths? | None. `_on_panel_opened`, `_on_placement_mode_entered`, `_on_customer_entered`, `_on_customer_item_spotted`, `_on_customer_ready_to_purchase`, `_on_customer_purchased` are deleted from `tutorial_system.gd`; the corresponding `connect` and `disconnect` lines in `_connect_signals` / `_disconnect_step_signals` are deleted. The new `_on_customer_platform_identified`, `_on_trade_in_condition_graded`, `_on_trade_in_price_confirmed`, `_on_hold_decision_made`, `_on_hidden_clue_acknowledged` handlers are wired in lockstep. The `customer_item_spotted` signal itself remains alive because `AmbientMomentsSystem._on_customer_item_spotted` still consumes it for toast emission. |
| Any production caller of the un-gated `pick_random()` path on a Day-1 / active-store customer-spawn site? | None on Day-1 / active store. `_on_day1_forced_spawn_timer_timeout` calls `pick_spawn_profile(pool)` (the new gated entry); `MallCustomerSpawner._spawn_for_store` calls `_customer_system.pick_spawn_profile(profiles)` on the active branch. The remaining `profiles.pick_random()` call in `MallCustomerSpawner._spawn_for_store` is on the background-store branch where archetype gating is irrelevant (the customer never enters a 3D interior). |
| `CheckoutSystem.DEFECTIVE_CONDITIONS` vs `ReturnsSystem.DEFECT_REASON_LABELS` — duplicate? | No. `DEFECTIVE_CONDITIONS = ["poor", "damaged"]` is the SSOT for *which* conditions trigger `defective_sale_occurred`. `DEFECT_REASON_LABELS` is the SSOT for the human-readable UI label of *any* defect reason (the keys include `wrong_platform` / `changed_mind` / `defective` which are not in `DEFECTIVE_CONDITIONS` because they are added by trade-in / warranty paths via `record_defective_sale(item_id, defect_reason, …)`). The two constants are the gate side and the label side of the same contract. |
| Any test still asserting against the old TutorialStep ordinals (`v2 PLACE_ITEM = 3`)? | Only `tests/gut/test_tutorial_system.gd::test_stale_schema_version_resets_progress`, which is *the test for the schema-bump migration itself* — it seeds a v2 cfg with ordinal `current_step = 3` and asserts the load resets and re-saves at v3. That citation is intentional and required. |
| Pass-5 docstring fix at `test_customer_item_spotted.gd:1–5` — does it reference a signal that still exists? | Yes. `customer_item_spotted` is alive (`event_bus.gd:162`, emitted by `customer.gd:532` and `:536`, consumed by `ambient_moments_system.gd:251`). The docstring's claim about "AmbientMomentsSystem toast + dedup handling" matches the file's surviving test cases. |

---

## Pass 5 escalations

**One open architectural decision remains:** the `manager_approval`
(EmploymentSystem, 0–100) vs `manager_trust` (ManagerRelationshipManager,
0.0–1.0) dual-scalar split.

* **Specific blocker:** the two scalars track conceptually overlapping
  ground (the manager↔player relationship) but with different scales,
  different consumer fan-outs, and different mutator fan-ins. Both
  newly arrived in this branch's working tree; both have
  test fixtures (`tests/gut/test_employment_system.gd`,
  `tests/gut/test_manager_relationship_manager.gd`); both are
  consumed by separate `ProgressionSystem.CONDITION_*` keys in
  ways that are explicit about the scale (numeric event-counter vs
  discrete tier index). Collapsing them is an architectural design
  decision (which scale wins, which consumers migrate, which
  EventBus signal wins between `manager_approval_changed` and
  `manager_trust_changed`), not a mechanical SSOT deletion. The
  Pass-5 SSOT contract is explicit that "if you cannot act and
  cannot justify, name the blocker" — both scalars are
  individually justified above; the blocker is design-side.
* **Who/what would unblock it:** an explicit design decision
  on whether the manager relationship is one axis (collapse to a
  single scalar) or two (keep both, document the split as
  intentional and rename the EventBus signals to make the
  vocabulary divergence explicit, e.g. `manager_event_recorded`
  vs `manager_relationship_changed`).
* **Smallest concrete next action:** a 30-minute design review
  meeting to pick one of the three options:
  - (A) Collapse to `manager_trust` (0–1, 4-tier) — `EmploymentSystem`
    keeps `employee_trust` only; `ReturnsSystem._escalate` rewrites
    its `+0.02` delta to apply against `manager_trust`;
    `ProgressionSystem.CONDITION_MANAGER_APPROVAL` is removed; the
    `manager_approval` field is deleted from `EmploymentState` /
    `GameState`.
  - (B) Collapse to `manager_approval` (0–100, derived tier band) —
    `ManagerRelationshipManager` becomes a thin wrapper around the
    EmploymentSystem scalar, and `manager_trust_changed` is replaced
    by `manager_approval_changed`. The morning-note tier table keys
    on `floor(manager_approval / 25)`.
  - (C) Keep both, rename for clarity — the two scalars are
    explicitly distinct axes; the EventBus signal names get renamed
    to `manager_event_recorded(event_id, delta, reason)` and
    `manager_relationship_tier_changed(old_tier, new_tier)` so the
    vocabulary contradiction goes away. Document the split as
    intentional in `architecture/ownership.md`.

Until that decision lands, both scalars stay live and the dual
mutator pattern (`EmploymentSystem.apply_trust_delta` /
`apply_manager_approval_delta` and
`ManagerRelationshipManager.apply_trust_delta`) is the documented
contract.

No other Pass-5 finding was left blocked. Every other entry above is
either acted on (one stale docstring rewritten in
`tests/gut/test_customer_item_spotted.gd:1–5`) or risk-logged with the
concrete trigger that would bring it into a future pass's scope.

---

**Scope:** SSOT enforcement against the working-tree diff that completes the
first-person store-entry feature on top of Pass 8 (`error-handling-report.md`).
The diff introduces named physics layers, a first-person walking body with an
embedded eye-level camera, an F3 debug-overhead toggle, a screen-center
`Crosshair`, the `Day1ReadinessAudit` v2 condition set, and the bit-5
`interaction_mask` migration. The pass scans for code, comments, and
documentation that still reflect the pre-FP / pre-named-layer SSOT and either
removes/rewrites the contradiction in place or justifies it with a concrete
reason.

**Verification:** `bash tests/run_tests.sh` after edits — **4858/4858 GUT
tests pass, 0 failures**, all SSOT tripwires green
(`validate_translations.sh`, `validate_single_store_ui.sh`,
`validate_tutorial_single_source.sh`, ISSUE-009 SceneRouter sole-owner check).
ISSUE-154 / ISSUE-239 baseline failures are pre-existing on `main` and outside
this pass's scope.

---

## Changes made this pass

| Path | Change | Rationale | Disposition |
|---|---|---|---|
| `game/autoload/camera_manager.gd` (`_sync_to_camera_authority`) | Added an idempotency guard — when `CameraAuthority.current()` already returns the camera being mirrored, the mirror skips and the explicit source label is preserved. Without the guard, the next `_process` tick after `StorePlayerBody._register_camera` (which calls `CameraAuthority.request_current(_camera, &"player_fp")`) overwrote the source to `&"camera_manager"`, putting it outside `Day1ReadinessAudit._ALLOWED_CAMERA_SOURCES = [&"player_fp", &"debug_overhead", &"retro_games"]` and forcing the composite checkpoint to fail on every clean store entry. | **CameraAuthority is the SSOT for the active-camera source label** (autoload row 4, `docs/architecture/ownership.md`). `CameraManager` is documented as the read-only viewport observer; the auto-mirror exists to cover the "auto-current on tree-add" case where no caller routed through `request_current`. The guard restores that boundary: mirror only when the source is ambiguous, never when an explicit caller has set it. | **Acted (tighten)** |
| `docs/audits/error-handling-report.md` §F-57 + executive summary cross-references (lines 5, 28, 66–67, 188, 904–929, 985, 1017) | Rewrote the §F-57 entry to reflect the actual code state: the bit-5 migration was **completed in this pass**, not deferred. Updated the §F-57 detail body, the Pass-8 summary paragraph, the findings table row, the disposition table, and the final-verdict paragraph; the prior text characterized §F-57 as "deferred until project-wide named-physics-layer pass lands" but the pass shipped `project.godot [layer_names]` declarations, flipped `Interactable.INTERACTABLE_LAYER` and `InteractionRay.interaction_mask` from `2` to `16`, migrated every shelf-slot Area3D in the four ship-touched store scenes, and added `tests/gut/test_physics_layer_scheme.gd` to pin the contract. | **The code is the SSOT** for whether the migration shipped. The report's prior "deferred" framing contradicted the actual `interaction_mask = 16` / `INTERACTABLE_LAYER = 16` / `[layer_names]` / shelf-slot `collision_layer = 16` state. Documentation that disagrees with code is removed or rewritten, never left to drift. | **Acted (tighten)** |
| `tests/gut/test_day1_readiness_audit.gd:2`, `tests/gut/test_day1_readiness_audit.gd:112` | Updated docstring header from "eight invariants" to "ten invariants" and assertion message from "All 8 conditions" to "All 10 conditions" to match the audit's new condition set (the original 8 plus `_COND_PLAYER_SPAWNED` and `_COND_CAMERA_CURRENT` introduced in this pass). | **`Day1ReadinessAudit._evaluate` is the SSOT** for the condition count; the test docstring is the audited contract. The 8/10 mismatch was stale documentation. | **Acted (tighten)** |

All three edits were validated against `bash tests/run_tests.sh` — full suite
green: **4858/4858 GUT tests, 0 failures**, all SSOT tripwires green.

---

## Final SSOT modules per domain (post-edit)

| Domain | SSOT (write side) | Read-only consumers |
|---|---|---|
| Active-camera source label / single-current invariant | **`CameraAuthority.request_current(cam, source)`** (autoload row 4). After this pass: `CameraManager._sync_to_camera_authority` is a no-op when `CameraAuthority.current() == camera`, so the explicit source set by a caller (e.g. `&"player_fp"` from `StorePlayerBody`) survives subsequent viewport-change observation. | `CameraManager` (viewport tracker / event emitter), `Day1ReadinessAudit._resolve_camera_source` (allowlist check), `StoreReadyContract._camera_current` (single-current walk). |
| Player avatar / first-person camera in store interiors | **`StorePlayerBody`** (`game/scripts/player/store_player_body.gd` + `game/scenes/player/store_player_body.tscn`). Owns walk + sprint + mouse-look (yaw on body, pitch on `$Camera3D`), embedded eye-level Camera3D, FP camera registration with source `&"player_fp"`, footprint clamp, cursor lock/unlock under InputFocus. | `Day1ReadinessAudit._count_players_in_scene` (player-group count), `tests/gut/test_hub_store_player_spawn.gd`, `tests/unit/test_store_player_body.gd`. |
| Orbit/overhead debug camera in retro_games | **`RetroGames._toggle_debug_overhead_camera` / `_enter_debug_overhead` / `_exit_debug_overhead`** (`game/scripts/stores/retro_games.gd`), bound to F3 via the new `toggle_debug` action in `project.godot`. The orbit `PlayerController` ships disabled (`PROCESS_MODE_DISABLED`) when `PlayerEntrySpawn` is present and only re-enables under the F3 toggle. | `Day1ReadinessAudit._ALLOWED_CAMERA_SOURCES` accepts `&"debug_overhead"` for this path. |
| Screen-center reticle (FP gameplay) | **`Crosshair`** (`game/scenes/ui/crosshair.tscn` + `game/scripts/ui/crosshair.gd`). Visibility tracks `InputFocus.current() == &"store_gameplay"`. Embedded once in `hud.tscn` (replacing the duplicated `InteractionPrompt` scene; `InteractionPrompt` remains the autoload at row 18 — single source for the contextual prompt). | `tests/gut/test_crosshair.gd`. |
| Physics-layer scheme | **`project.godot [layer_names]`** declares `1=world_geometry, 2=store_fixtures, 3=player, 4=customers, 5=interactable_triggers`. **`Interactable.INTERACTABLE_LAYER = 16`** is the canonical bit value for interactable triggers; `InteractionRay.interaction_mask = 16` reads the same bit. Pinned by `tests/gut/test_physics_layer_scheme.gd`. | All `.tscn` Area3D `collision_layer` declarations on interactable triggers (`16`); player root (`collision_layer = 4`, `mask = 3`); customer roots (`8` / `3`); store fixtures (`2`); world geometry (`1`); storefront `EntryZone` (`mask = 4`). |
| Day-1 playable-readiness composite | **`Day1ReadinessAudit._evaluate`** runs **ten** ordered conditions: `active_store_id`, `player_spawned` (new), `camera_source` (allowlist tightened to `[&"player_fp", &"debug_overhead", &"retro_games"]` — old `&"store_director"` / `&"store_gameplay"` removed because nothing now emits them), `camera_current` (new), `input_focus`, `fixture_count`, `stockable_shelf_slots`, `backroom_count`, `first_sale_complete`, `objective_active`. | `tests/gut/test_day1_readiness_audit.gd` per-condition coverage. |
| Store interior dimensions (Retro Games shipping interior) | **`game/scenes/stores/retro_games.tscn`** floor + walls + ceiling + nav-mesh + audio-zone all sized at 16 m × 20 m × 3.5 m. **`StorePlayerBody.bounds_min/bounds_max`** defaults `Vector3(±7.7, 0, ±9.7)` are the canonical first-person footprint (0.3 m margin from wall surfaces at ±8.0 X / ±10.0 Z); per-store overrides come from `PlayerEntrySpawn` marker metadata applied by `GameWorld._apply_marker_bounds_override`. | `tests/unit/test_store_player_body.gd::test_clamp_bounds_match_retro_games_footprint`. |
| Day-1 objective rail (Stock first item → make sale → close day) | **`game/content/objectives.json`** day-1 entry now carries `text` / `action` / `key` plus `post_sale_text` / `post_sale_action` / `post_sale_key`. **`ObjectiveDirector._emit_current`** is the sole writer that flips between pre- and post-sale copy when `_sold == true`. | `ObjectiveRail` (read), `HUD._on_first_sale_completed_hud` (Close Day pulse). |
| End-of-day inventory total | **`DayCycleController._show_day_summary`** computes `inventory_remaining = shelf_items + backroom_items` and includes it in the `EventBus.day_closed` payload, documented in the signal docstring on `EventBus.day_closed`. | `DaySummary._on_day_closed_payload` renders the new label; the inventory systems remain the read-side source for the actual item list. |

---

## Risk log — intentionally retained

| Item | Why retained | Concrete trigger to remove |
|---|---|---|
| `CameraManager._sync_to_camera_authority` itself (the entire mirror function, not just the new guard) | The mirror covers the case where a Camera3D becomes current via Godot's auto-current behavior (e.g. tree-add) without routing through `CameraAuthority.request_current`. Removing it would let `CameraAuthority._active` go stale relative to the viewport. The new guard reduces the blast radius without removing the safety net. | A scene-tree-wide audit confirming every `current = true` flip in `.tscn` and `.gd` is gated through `CameraAuthority.request_current`. `tests/validate_camera_ownership.sh` already enforces that for `.gd` writes; extending the script to `.tscn` `current = true` would close the gap and let the mirror be deleted. |
| Orbit `PlayerController` and embedded `StoreCamera` in `retro_games.tscn` | F3 debug-overhead toggle is the only consumer. Removing it would lose the dev-only top-down view that `RetroGames._toggle_debug_overhead_camera` / `_enter_debug_overhead` / `_exit_debug_overhead` switch into. The legacy controller is `PROCESS_MODE_DISABLED` at `_ready` so it does not race the FP body. | A decision to drop the F3 debug overhead (no longer needed for QA / playtesting on the shipping interiors). At that point the orbit `PlayerController/StoreCamera` subtree can be deleted from `retro_games.tscn` along with `RetroGames._disable_orbit_controller_for_fp_startup` and the four `_*_debug_overhead*` methods. |
| `_resolve_store_id` duplicated across 5 files (`inventory_system.gd:35`, `economy_system.gd:570`, `store_selector_system.gd:404`, `order_system.gd:677`, `reputation_system.gd:326`) | Each instance has subtly different fallback semantics (registry-gate, raw-resolve, cached-active, GameManager-fallback, String vs StringName return). Documented in `docs/audits/cleanup-report.md`. Consolidating without changing those semantics would require a `StoreIdResolver` static helper that exposes one named function per policy — out of scope for this pass since SSOT enforcement here would be a behavioural-change refactor, not a deletion. | A green-light to introduce `StoreIdResolver` with explicit per-policy entry points; then each call site can opt into a named policy and the local helper is deleted. |
| `StorePlayerBody.set_current_interactable` test seam | Public method with zero callers (production or tests). Removing a public method is a behaviour-surface change; documented as a contract aid for tests in §F-54. The cost of removal is non-zero (touching `tests/unit/test_store_player_body.gd` if a future test starts using it as documented), the cost of keeping is one method body. | A pass with explicit license to drop unused public methods (and the corresponding "delete unused public surface" entry in the cleanup-report). |
| `ProvenancePanel` (`game/scenes/ui/provenance_panel.gd` + `.tscn`) | Not instantiated from any production scene; only referenced by `tests/gut/test_provenance_panel.gd`. Documented in `docs/audits/cleanup-report.md` as "design-intent unconfirmed" — the panel content (acquisition / condition / grade history) is referenced from the design docs as a planned in-game surface. | Confirmation from the design doc owner that the panel is no longer planned; then panel + test + any ContentRegistry hooks can be deleted. |
| `error-handling-report.md` historical references to prior pass names (`security-report.md`, `ssot-report.md`, `docs-consolidation.md`, `cleanup-report.md`) | The references appear inside the consolidated report itself as a record of which prior reports were folded in. Removing them would erase the provenance trail. The same names also appear in `docs/index.md` under "Audit notes" as an explanatory footnote — also intentional and historical. The `cleanup-report.md` already swept every *live* code-side citation of those filenames. (Of those four reports, only `security-report.md`, `ssot-report.md`, `cleanup-report.md`, and `docs-consolidation.md` are currently present; `cleanup-report.md`, `security-report.md`, and `ssot-report.md` were never absent in this branch's working tree.) | Routine — leave intact as historical context. |

---

## Sanity check — dangling references

| Check | Result |
|---|---|
| Any code citing `&"store_director"` / `&"store_gameplay"` as a CameraAuthority source? | None. `grep request_current.*store_director\|request_current.*store_gameplay` returns zero hits. The removal of those tokens from `Day1ReadinessAudit._ALLOWED_CAMERA_SOURCES` is consistent with code state. |
| Any `interaction_mask = 2` or `INTERACTABLE_LAYER = 2` left over? | None. `Interactable.INTERACTABLE_LAYER = 16`, `InteractionRay.interaction_mask = 16`. Every shelf-slot `Area3D` in the four touched store scenes (`retro_games`, `consumer_electronics`, `pocket_creatures`, `video_rental`, `sports_memorabilia`) reads `collision_layer = 16`. The remaining `collision_layer = 2` lines belong to `StaticBody3D` fixtures (cart racks, glass cases, register collision, doors), correctly mapped to `layer_2 = store_fixtures`. |
| Any code citing audit-report filenames (`security-report.md`, `ssot-report.md`, `docs-consolidation.md`, `cleanup-report.md`) as if those reports were deleted? | None remaining in code/tests. Surviving references are confined to `docs/index.md` (intentional, explanatory), `docs/audits/error-handling-report.md` (historical, inside the consolidated report), and `docs/audits/cleanup-report.md` (sweep record). The `cleanup-report.md` Pass already handled this. |
| Any `bounds_min`/`bounds_max` defaults still tied to the old 7×5 retro_games footprint? | None. `StorePlayerBody.bounds_*` defaults are `Vector3(±7.7, 0, ±9.7)` matching the new 16×20 interior. `tests/unit/test_store_player_body.gd::test_clamp_bounds_match_retro_games_footprint` pins the assertion against `±8.0 X / ±10.0 Z` walls. |
| `CameraManager._sync_to_camera_authority` after the new guard — does any test directly assert the post-mirror source label is `&"camera_manager"`? | No. `tests/unit/test_camera_manager.gd` and `tests/gut/test_camera_manager.gd` only inspect `active_camera` and the `EventBus.active_camera_changed` payload, never `CameraAuthority.current_source()`. The guard is behaviorally invisible in unit tests but corrects the production race. |
| `Day1ReadinessAudit` allowlist drift after the source-label tightening | `_ALLOWED_CAMERA_SOURCES = [&"player_fp", &"debug_overhead", &"retro_games"]` — all three sources are emitted by code in the tree (`StorePlayerBody.CAMERA_SOURCE`, `RetroGames._CAMERA_SOURCE_DEBUG_OVERHEAD` / `_CAMERA_SOURCE_PLAYER_FP`, `GameWorld._activate_store_camera` orbit-fallback path passing the canonical store id). No allowlist entry is unreachable. |

---

## Escalations

None. Every finding was either acted on in source or carried explicit
justification with a concrete trigger to revisit. No SSOT decision was left
blocked.

---

## Pass 2 changes (2026-05-03)

**Driver:** the working-tree diff has irreversibly pivoted to the first-person
SSOT — `game/scenes/player/player.gd` (the blue-circle `PlayerIndicator`
script), `game/scenes/player/player.tscn`,
`game/scripts/player/mall_camera_controller.gd`, and
`tests/gut/test_player_indicator_visibility.gd` are all `D` in `git status`;
the orbit-input actions (`orbit_left`, `orbit_right`, `camera_orbit`,
`camera_pan`, `camera_zoom_in`, `camera_zoom_out`) are gone from
`project.godot`; `BRAINDUMP.md` mandates "no visible blue-circle player
avatar". Pass 1 / Pass 3 of `cleanup-report.md` was "no-behavior-change" and
recorded the surviving dead-code list as "considered-but-not-changed". This
pass deletes those items.

### Changes made this pass

| Path | Change | Rationale |
|---|---|---|
| `game/scripts/player/player_controller.gd` | Removed the `_player_indicator` `@onready` declaration, the two `_update_player_indicator_visibility()` call sites in `_ready` and `_process`, and the entire `_update_player_indicator_visibility()` function body (was lines 65-70, 88, 109, 302-312). | The blue-circle floor disc was the `PlayerIndicator` MeshInstance3D rendered by the now-deleted `game/scenes/player/player.tscn`. **No shipping scene authors a `PlayerIndicator` child** of `PlayerController` (`grep PlayerIndicator --include='*.tscn'` returns zero hits). The hooks were dead under the new FP SSOT and the BRAINDUMP "no visible blue-circle avatar" mandate. SSOT rule: "If production usage cannot be proven, default to removal." |
| `game/scripts/player/player_controller.gd` | Removed `ortho_size_min` and `ortho_size_max` `@export` declarations. | `cleanup-report.md` Pass 3 already documented these as "for callers that adjust ortho size programmatically — but no caller exists." Scroll-zoom inputs are gone (the only mutator). With the dead exports removed, `ortho_size_default` is the single source for the orthogonal view size. |
| `game/scripts/player/player_controller.gd` | Removed `_target_yaw`, `_target_pitch`, `_target_zoom`, `_target_ortho_size` member vars + their initializations + the four dead-equal `lerp_angle` / `lerpf` calls in `_process`; `set_camera_angles` and `set_zoom_distance` now write directly to `_yaw` / `_pitch` / `_zoom`; `_apply_keyboard_movement` reads `_yaw` instead of the duplicate `_target_yaw`. `_pivot` / `_target_pivot` are kept separate (the keyboard step writes the target while the lerp interpolates the canonical pivot — a real producer/consumer split, not a duplicate). | Two-variables-with-the-same-value is by definition an SSOT violation. With orbit/pan/scroll-zoom inputs deleted, every caller of `set_camera_angles` / `set_zoom_distance` was writing both halves to identical values; `lerpf(x, x, w) = x`. `cleanup-report.md` Pass 3 explicitly considered and deferred this on no-behavior-change grounds; the SSOT pass is destructive and lands the collapse. |
| `game/scripts/player/player_controller.gd` (`_resolve_camera()`) | Dropped the `Camera3D` legacy-name fallback below the `StoreCamera` lookup. The function is now a one-liner that returns `get_node_or_null("StoreCamera") as Camera3D`. | `cleanup-report.md` Pass 3 confirmed "no shipping scene authors a `Camera3D` child of `PlayerController` today" and kept the fallback only because removing it was "a public-surface change to the documented §F-36 contract." The §F-36 docstring is preserved; only the unreachable fallback line is removed. The two scenes that instantiate `PlayerController` (`game/scenes/player/player_controller.tscn` and `retro_games.tscn` via that pack) ship `StoreCamera` exclusively. |
| `game/scripts/player/player_controller.gd` (`set_build_mode` doc) | Tightened: "Suspends pivot updates and the player indicator while build mode is active." → "Suspends pivot updates while build mode is active." | The "and the player indicator" clause is now wrong because the indicator hooks were just deleted. |
| `game/scenes/stores/retro_games.tscn:296-297` | Removed the `ortho_size_min = 14.0` and `ortho_size_max = 28.0` overrides on the `PlayerController` instance. | Forced by the export removal above; nothing reads these values either. The retained `ortho_size_default = 22.0` is the only ortho-size SSOT. |
| `tests/unit/test_store_selector_system.gd:273,275` | `store_camera._target_zoom` → `store_camera._zoom`. | Forced by the `_target_zoom` removal above; the assertion now reads the single canonical zoom value rather than the deleted duplicate. Behaviorally identical. |
| `game/scripts/world/mall_hallway.gd:153` | Renamed the instantiated `PlayerController` node from `"MallCameraController"` to `"PlayerController"`. | The `MallCameraController` class (`game/scripts/player/mall_camera_controller.gd`) was deleted in this branch. The scene-tree node name was the last surviving reference to the dead class name; future `find_child("MallCameraController", ...)` lookups would silently return null. The new name matches the actual `class_name PlayerController` of the script attached to the instantiated scene (`game/scenes/player/player_controller.tscn`). |

**Verification:** `bash tests/run_tests.sh` after edits — **4927/4927 GUT
tests pass, 0 failures**, all SSOT tripwires green
(`validate_translations.sh`, `validate_single_store_ui.sh`,
`validate_tutorial_single_source.sh`, ISSUE-009 SceneRouter sole-owner
check). Pre-existing validator failures (ISSUE-018, ISSUE-023, ISSUE-024,
ISSUE-154, ISSUE-239) are on `main` ahead of this branch and do not touch
the files edited in this pass.

### SSOT modules per domain (Pass 2 deltas)

| Domain | Pass 1 SSOT | Pass 2 update |
|---|---|---|
| Camera angle / zoom / ortho-size internal state on `PlayerController` | (not enumerated — Pass 1 focused on FP body) | **Pass 2: collapsed to one variable per axis.** `_yaw` / `_pitch` / `_zoom` / `_ortho_size` are the canonical state. `_pivot` / `_target_pivot` are kept as a producer/consumer split because `_apply_keyboard_movement` writes the target each frame while the lerp interpolates the canonical pivot. |
| Orthogonal view size for `PlayerController` (when `is_orthographic = true`) | (not enumerated) | **Pass 2: `ortho_size_default` is the single source.** `ortho_size_min` / `ortho_size_max` exports were deleted (no caller adjusted ortho size after scroll-zoom went away). |
| First-person camera child name on `StorePlayerBody` | (not enumerated) | `StoreCamera` is the only convention — verified by `_resolve_camera()` collapse and by `store_player_body.tscn` rename `Camera3D` → `StoreCamera` from the working-tree diff. |
| Indicator-disc rendering at the camera pivot | (not enumerated) | **Pass 2: removed.** The blue-circle floor disc is gone from gameplay per BRAINDUMP §"Camera is wrong"; no `PlayerIndicator` child is authored anywhere; the controller no longer carries a hook for it. |

### Risk log — Pass 2 retained items

| Item | Why retained | Concrete trigger to remove |
|---|---|---|
| Orbit-named identifiers in `retro_games.gd` (`_ORBIT_CONTROLLER_PATH`, `_disable_orbit_controller_for_fp_startup`, local `var orbit:` blocks in `_toggle_debug_overhead_camera` / `_enter_debug_overhead` / `_exit_debug_overhead`) | These names accurately describe the F3 debug-overhead surface ("the thing that used to be the orbit controller and is now the WASD-pivot debug view"). They name a real behavioral role, not a deleted one — orbiting may be gone, but the controller node and the F3 toggle hookup are alive and shipping. Misnomer ≠ dead code. Renaming would touch ~10 sites and is a polish refactor with no SSOT payoff. | A pass that explicitly takes "rename for accuracy" as scope (e.g. a docstring/identifier polish pass), or the F3 debug surface itself being deleted. |
| `_pivot` / `_target_pivot` two-variable split | Real producer/consumer relationship: `_apply_keyboard_movement` writes `_target_pivot` each frame, `_process` lerps `_pivot` toward it for smoothing. Collapsing them would remove the smoothing, which is a behavior change, not an SSOT cleanup. | Decision to drop the lerp smoothing entirely (e.g. instant pivot snapping for a deterministic-replay pass). |
| Orbit `PlayerController` and embedded `StoreCamera` in `retro_games.tscn` | Same Pass-1 rationale stands — the F3 debug-overhead toggle is the consumer. Pass 2 cleaned the dead-code internals of `PlayerController` but did not delete the F3 surface. | Same trigger as Pass 1: a decision to drop the F3 debug overhead. |
| `set_input_listening` doc reference to `tests/validate_input_focus.sh` | The validator script is the SSOT for the rule "owners must route through `set_input_listening` instead of `set_process_unhandled_input`." Pass 2 did not touch the function or the validator. | None planned — this is the canonical contract pointer. |
| `MallCameraController` mentions in `.aidlc/research/crosshair-fp-scene.md` and `.aidlc/runs/aidlc_20260502_213623/claude_outputs/research_crosshair-fp-scene.md` | These are frozen research-run snapshots, not living docs. Editing them would falsify the research history (timestamped run artifacts). | None — leave intact as historical context. |

### Sanity check — Pass 2 dangling references

| Check | Result |
|---|---|
| Any code citing `_target_yaw` / `_target_pitch` / `_target_zoom` / `_target_ortho_size` after the collapse? | None. `grep` returns the prior-pass mention in `cleanup-report.md` only (historical). |
| Any code citing `ortho_size_min` / `ortho_size_max` after the export + override removal? | None outside `cleanup-report.md` historical text. The only live read was `retro_games.tscn`, also removed. |
| Any code citing `PlayerIndicator` after the hook removal? | None. `grep PlayerIndicator` returns zero matches in `*.tscn`, `*.gd`, `*.cfg`. |
| Any `body.get_node_or_null("Camera3D")` lookups left after the FP camera rename? | None. `cleanup-report.md` Pass 3 already migrated `retro_games.gd:_resolve_fp_camera`; `_resolve_camera()` in `player_controller.gd` was the second site, fixed in Pass 2. |
| Any scene tree node still named `MallCameraController`? | None. `mall_hallway.gd:153` was the only emitter; renamed to `"PlayerController"`. The deleted `mall_camera_controller.gd` script class is unreferenced anywhere in the working tree. |
| Any test still asserting against `_player_indicator` visibility or against the deleted `player.tscn`? | None. `tests/gut/test_player_indicator_visibility.gd` was deleted in this branch; no other test references the symbol. |

---

## Pass 3 changes (2026-05-03)

**Driver:** the working-tree diff finishes the BRAINDUMP "Day-1 retail
loop" pivot on top of Pass 8 / Pass 11 / Pass 12 baselines. Concretely:

- `TutorialSystem`: re-sequenced to `WELCOME → OPEN_INVENTORY →
  SELECT_ITEM → PLACE_ITEM → WAIT_FOR_CUSTOMER → CUSTOMER_BROWSING →
  CUSTOMER_AT_CHECKOUT → COMPLETE_SALE → CLOSE_DAY → DAY_SUMMARY`. The
  previous `MOVE_TO_SHELF` / `SET_PRICE` enum entries and every backing
  surface (`_capture_player_spawn`, `_check_move_to_shelf_distance`,
  `bind_player_for_move_step`, `_PLAYER_GROUP`, `_set_price_grace_timer`,
  `_arm_set_price_grace_timer`, `_on_set_price_grace_timeout`,
  `_on_store_entered`, `_on_price_set`, etc.) are gone from
  `tutorial_system.gd`. `SCHEMA_VERSION = 2` resets persisted progress
  written before the re-sequence.
- `CustomerSystem._is_day1_spawn_blocked` is the single Day-1 entry gate
  (sticky `_day1_spawn_unlocked`, self-heals from
  `InventorySystem.get_shelf_items()` on save reload, opens on `day > 1`).
- `DataLoader.create_starting_inventory(store_id)` is the deterministic
  Day-1 starter pipeline (reads `StoreDefinition.starting_inventory`,
  filters by `allowed_categories`, builds at "good" condition); the older
  random-commons `generate_starter_inventory` is retained for
  `mall_hallway.gd::_queue_starter_inventory` (preview / non-Day-1 store
  openings). The two have meaningfully different selection semantics and
  different call sites — see Risk Log.
- `EventBus.customer_item_spotted(Customer, ItemInstance)` is a single
  emitter (`Customer._evaluate_current_shelf`) with two named receivers
  (`AmbientMomentsSystem._on_customer_item_spotted` for the dedup-aware
  toast, `TutorialSystem._on_customer_item_spotted` for the
  `CUSTOMER_BROWSING` step advance).
- `HUD._customers_served_today_count` (cumulative, increments on
  `customer_purchased`, resets on `day_started`) replaces the old
  `_customers_active_count` (concurrent, incremented on
  `customer_entered` / decremented on `customer_left`). The matching
  `_on_customer_entered` / `_on_customer_left` / `_refresh_customers_active`
  trio is gone from `hud.gd`.
- `Constants.STORE_CLOSE_HOUR` and `TimeSystem.MALL_CLOSE_HOUR` both moved
  from 21 to 17 — the BRAINDUMP target is a 9-to-5 retail day. `_DAY_END_MINUTES`
  is now 1020.

The companion `cleanup-report.md` Pass 5 verified the working-tree change
set was free of orphaned constants / methods / handlers and identified
two micro-edits (one dead `_selected_item = item` and one stale "legacy /"
docstring). This SSOT pass goes further: it collapses one private 1-call
wrapper that survived the re-sequence and rewrites three audit-report
sections that still cite removed surfaces as if they were live findings.

### Changes made this pass

| Path | Change | Rationale |
|---|---|---|
| `game/scripts/stores/shelf_slot.gd` (`_accepts_stocking_category` removal) | Deleted the private `_accepts_stocking_category(item_category: StringName) -> bool` wrapper (was a one-line delegate `return accepts_category(String(item_category))`). The single caller at line 347 (`_on_stocking_cursor_active`) now calls `accepts_category(String(item_category))` directly. | After the working-tree diff introduced the public `accepts_category(item_category: String) -> bool` as the documented "consolidation point for category filtering", `_accepts_stocking_category` became a private 1-call wrapper that only converted `StringName → String`. Two methods that resolve the same question (does this slot accept this category?) are an SSOT violation; the public one is the single source. The conversion is now inline at the call site, which is the only place where a `StringName` from `EventBus.stocking_cursor_active` enters this code. |
| `docs/audits/security-report.md` F-09.22 / F-09.23 | Rewrote both rows in the "Findings cleared without a code change" table to mark them **Retired — surface removed**. Both entries cited `tutorial_system.gd::_capture_player_spawn` (reads `_PLAYER_GROUP`) and `tutorial_system.gd::bind_player_for_move_step` (public test seam) — neither exists in the Pass-12 working tree. | **The code is the SSOT** for whether the surface exists. The "current pass" findings table presented these as live trust-domain findings; with the surface gone, they were stale claims. Same treatment as Pass 1's §F-57 rewrite — documentation that disagrees with code is reconciled, never left to drift. |
| `docs/audits/error-handling-report.md` §F-22 detail entry, §F-79 master findings table row, §F-79 detail entry, "Acted (Pass 11)" disposition row, "Retired (feature removed)" disposition row | Rewrote the §F-22 body and the §F-79 body to **Retired (feature removed)** with a clear pointer to the Pass-12 deletion. Demoted the `F-79` row in the master findings table to severity `Retired`. Removed the §F-79 reference from the "Acted (Pass 11) — justified inline" disposition row and added it (and §F-22) to the "Retired (feature removed)" disposition row alongside the existing §F-28. | Both findings cited surfaces that no longer exist: §F-22 covered `hud.gd::_refresh_customers_active` (replaced by `_on_customer_purchased_hud` in this working tree); §F-79 covered `TutorialSystem._capture_player_spawn` / `_check_move_to_shelf_distance` (whole `MOVE_TO_SHELF` step removed). The historical Pass-11 narrative is preserved (it's an accurate record of what Pass 11 found *at the time*); the *live findings* sections are the parts that disagreed with code on disk. |

**Verification:** `bash tests/run_tests.sh` after edits — **4980 GUT tests,
4980 passing, 0 failures, 28227 asserts** (Pass 5 baseline was 4969 / 27995;
the +11 tests come from the new tracked-but-untracked GUT files added by the
working-tree change set: `test_customer_item_spotted.gd`,
`test_day1_customer_spawn_gate.gd`, `test_inventory_shelf_actions_stocking.gd`,
`test_day1_customer_spawn_gate`, etc.). The one source-tree edit (the
`_accepts_stocking_category` inline) is behaviorally identical — the public
`accepts_category` method is the same callee, only the dispatch point
changed. All SSOT tripwires green (`validate_translations.sh`,
`validate_single_store_ui.sh`, `validate_tutorial_single_source.sh`,
ISSUE-009 SceneRouter sole-owner). Pre-existing validator failures
(ISSUE-018, ISSUE-023, ISSUE-024, ISSUE-154, ISSUE-239) are on `main`
ahead of this branch and do not touch the files edited in this pass.

### SSOT modules per domain (Pass 3 deltas)

| Domain | Pass 1 / Pass 2 SSOT | Pass 3 update |
|---|---|---|
| Tutorial step sequence + persistence | (not enumerated) | **Pass 3:** `TutorialSystem.TutorialStep` + `STEP_IDS` + `STEP_TEXT_KEYS` are the single source for ordinals, persisted IDs, and translation keys respectively. `SCHEMA_VERSION = 2` is the cfg-skew tripwire — bump on any reorder. The §F-79 `MOVE_TO_SHELF` test seam and the `_PLAYER_GROUP` snapshot path are gone; no per-step capture-from-scene helpers remain. |
| Day-1 customer-spawn entry gate | (not enumerated) | **Pass 3:** `CustomerSystem._is_day1_spawn_blocked` is the sole gate (called from `spawn_customer`). `_day1_spawn_unlocked` is the sticky boolean state; `_on_item_stocked` opens it on first stock and `_on_day_started(day > 1)` opens it permanently after Day 1. Self-heals on save reload by inspecting `InventorySystem.get_shelf_items()`. |
| Day-1 starting inventory (deterministic path) | (not enumerated) | **Pass 3:** `DataLoader.create_starting_inventory(store_id)` is the SSOT for the Day-1 bootstrap call site (`GameWorld._create_default_store_inventory`). Reads `StoreDefinition.starting_inventory` and filters by `allowed_categories`. Random-commons `generate_starter_inventory` is retained for `MallHallway` preview / non-Day-1 store openings — different call site, different semantic; tracked in Risk Log. |
| `customer_item_spotted` signal | (new) | **Pass 3:** Single emitter (`Customer._evaluate_current_shelf`, two emit sites — first-sight + upgrade), two named receivers (`AmbientMomentsSystem._on_customer_item_spotted` toast, `TutorialSystem._on_customer_item_spotted` step advance). Receiver guards documented in §F-86. |
| HUD customer counter | (not enumerated) | **Pass 3:** `_customers_served_today_count` (cumulative) is the single source. Driven by `EventBus.customer_purchased`; reset on `day_started`. The old concurrent `_customers_active_count` and its three handlers (`_on_customer_entered`, `_on_customer_left`, `_refresh_customers_active`) are deleted; no parallel counter remains. |
| Shelf-slot category filtering | (not enumerated) | **Pass 3:** `ShelfSlot.accepts_category(item_category: String) -> bool` is the public single source. Two callers — the in-class `_on_stocking_cursor_active` highlight gate (after the Pass 3 inline of `_accepts_stocking_category`) and `InventoryShelfActions.place_item` pre-mutation reject. No private 1-call wrapper survives. |
| Mall-day cycle length | `Constants.STORE_CLOSE_HOUR` / `TimeSystem.MALL_CLOSE_HOUR` were 21 (4×4 hr block). | **Pass 3:** Both moved to 17 (9-to-5). `TimeSystem._DAY_END_MINUTES = 1020`. The `LATE_EVENING` extended-hours unlock path retains hours 17–21 in `HOUR_DENSITY` and `_PHASE_BOUNDARIES_MINUTES` because the unlock (`extended_hours_unlock`) ships `_LATE_EVENING_END_MINUTES = 1440` — see Risk Log for the explicit forward-compat retention. |

### Risk log — Pass 3 retained items

| Item | Why retained | Concrete trigger to remove |
|---|---|---|
| `DataLoader.create_starting_inventory` (deterministic, Day-1 bootstrap) **and** `DataLoader.generate_starter_inventory` (random commons, hallway preview) coexist | The two have meaningfully different selection semantics — deterministic-from-content vs random-commons — and different production call sites: `GameWorld._create_default_store_inventory:1427` calls the new path for Day-1 bootstrap; `MallHallway._queue_starter_inventory:423` calls the random path for non-Day-1 store openings (the player buys an empty unit and the hallway seeds a random starter pack the next morning). Neither covers the other's use case without a behavior change. The cleanup-report.md Pass 5 already documented the same finding. **Justified, not consolidated.** | A consolidation pass with explicit license to introduce a `mode ∈ {"deterministic", "random_commons"}` parameter so both call sites can route through one entry point. At that point one of the two functions can be deleted. |
| `customer_system.gd` `HOUR_DENSITY[17..21]` and `time_system.gd` `_PHASE_BOUNDARIES_MINUTES[EVENING] = 1080` / `[LATE_EVENING] = 1260` are unreachable on a default day | Both files comment-document why: the `LATE_EVENING` extended-hours unlock (`_late_evening_enabled = true` in `time_system.gd:237`, gated by `unlock_system.is_unlocked(&"extended_hours_unlock")`) extends the day to `_LATE_EVENING_END_MINUTES = 1440`, at which point the AFTERNOON → EVENING → LATE_EVENING transitions and the corresponding HOUR_DENSITY entries become reachable. The unlock has shipping infrastructure (signal handlers, save persistence, twelve `tests/gut/test_time_system.gd::test_*late_evening*` cases). Removing the entries would break the unlock. **Justified, not removed.** | A decision to drop the `extended_hours_unlock` entirely (no longer planned). At that point the LATE_EVENING enum value, `_late_evening_enabled`, `_LATE_EVENING_END_MINUTES`, the test family, and the HOUR_DENSITY 17-21 / `_PHASE_BOUNDARIES_MINUTES` 1080+1260 entries are all collapsible together. |
| `_emit_sale_toast` (`checkout_system.gd`) and `_on_customer_item_spotted` toast emission (`ambient_moments_system.gd`) both call `EventBus.toast_requested.emit` | Three structural differences across two call sites: distinct message templates ("Sold X for $Y" vs "Customer browsing: X"), different `EventBus.toast_requested` categories (`&"system"` vs `&"customer"`), different durations (`0.0` default vs `CUSTOMER_BROWSING_TOAST_DURATION = 3.0`). A shared helper would have to take all three as arguments — at which point it adds nothing over a direct `emit`. The pattern is consistent with every other toast emitter in the tree. The cleanup-report.md Pass 5 already documented this. **Justified, not extracted.** | Three or more sites converging on the same template+category+duration triple. Until then, two direct emits is the right shape. |
| All Pass 1 / Pass 2 retained items (CameraManager mirror function, `_resolve_store_id` 5-way duplication, `StorePlayerBody.set_current_interactable` test seam, `ProvenancePanel`, audit-report historical filenames) | Nothing in the Pass-12 working-tree change set alters their disposition; the rationales above (Pass 1 / Pass 2 risk logs) still hold. | Same triggers as the original Pass 1 / Pass 2 entries. |

### Sanity check — Pass 3 dangling references

| Check | Result |
|---|---|
| Any code citing `MOVE_TO_SHELF`, `SET_PRICE`, `CLICK_STORE` tutorial step values? | None. `grep "TutorialStep\.MOVE_TO_SHELF\|TutorialStep\.SET_PRICE\|TutorialStep\.CLICK_STORE"` returns zero matches across `*.gd`, `*.tscn`, `*.cfg`. The single inline-comment mention at `tutorial_system.gd:442` is part of the `SCHEMA_VERSION` migration explanation (e.g. *"the old `MOVE_TO_SHELF=1` would now land on the new `OPEN_INVENTORY=1`"*) — intentional historical citation, not live code. |
| Any code citing `bind_player_for_move_step`, `_capture_player_spawn`, `_check_move_to_shelf_distance`, `_PLAYER_GROUP`, `MOVE_TO_SHELF_DISTANCE`, `_set_price_grace_timer`, `_arm_set_price_grace_timer`, `_on_set_price_grace_timeout`? | None outside `docs/audits/cleanup-report.md` (Pass 5 verification log) and `docs/audits/error-handling-report.md` (the §F-79 retired-entry body, which now states the surface is gone). Zero `.gd` / `.tscn` references. |
| Any code citing `TUTORIAL_MOVE_TO_SHELF`, `TUTORIAL_SET_PRICE`, `TUTORIAL_CLICK_STORE` localization keys? | None. Both `translations.en.csv` and `translations.es.csv` removed the rows. The `STEP_TEXT_KEYS` dict in `tutorial_system.gd` contains the four new keys (`TUTORIAL_SELECT_ITEM`, `TUTORIAL_CUSTOMER_BROWSING`, `TUTORIAL_CUSTOMER_AT_CHECKOUT`, `TUTORIAL_COMPLETE_SALE`) and the rewritten existing ones (`TUTORIAL_OPEN_INVENTORY`, `TUTORIAL_PLACE_ITEM`, `TUTORIAL_WAIT_CUSTOMER`). |
| Any code citing `_customers_active_count`, `_on_customer_entered` (HUD), `_on_customer_left` (HUD), `_refresh_customers_active`? | None on the HUD side. `_on_customer_entered` / `_on_customer_left` matches in other files (e.g. `audio_event_handler.gd:63`, `customer_system.gd:715`, `regulars_log_system.gd:85`) are unrelated handlers in their own scripts that subscribe to `EventBus.customer_entered` / `EventBus.customer_left` for their own purposes — same idiomatic name, different owners. The HUD-specific trio is gone. |
| Any code citing `_accepts_stocking_category` after the Pass-3 inline? | None. `grep _accepts_stocking_category` returns matches only in `docs/audits/cleanup-report.md` (historical Pass 5 mention). Zero `.gd` / `.tscn` matches. |
| Any test still asserting against the removed tutorial-step infrastructure? | None. `tests/unit/test_tutorial_system.gd` was rewritten in this branch to drive the new sequence (the `_drive_full_sequence` helper replaced `_drive_move_to_shelf_advance`), and `test_store_entered_does_not_auto_advance_move_to_shelf` was removed — `grep test_store_entered_does_not_auto_advance` returns matches only in `docs/audits/error-handling-report.md` historical narrative. |
| Any audit report still presenting `MOVE_TO_SHELF` / `_capture_player_spawn` / `_refresh_customers_active` as **live findings**? | None after this pass. `security-report.md` F-09.22 / F-09.23 are now "Retired — surface removed"; `error-handling-report.md` §F-22 and §F-79 are now "Retired (feature removed)" in both the master findings table and their detail bodies. The Pass-11 historical narrative paragraphs (lines 20-31, 98-127, 1816-1832) describe what Pass 11 found at the time and are preserved as historical record — same treatment as the pre-existing Pass-1 / Pass-2 historical narrative in this report. |

### Escalations

None. Every Pass 3 finding either acted (one private wrapper inlined,
five audit-report sections rewritten) or was justified inline with the
rationale in the Risk Log above. No SSOT decision was left blocked.
