# SSOT Enforcement Pass — 2026-05-02

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
