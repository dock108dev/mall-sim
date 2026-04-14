# EventBus Signal Catalog

Authoritative list of all signals declared on the `EventBus` autoload. All cross-system communication uses these signals exclusively. No system holds a direct reference to another.

Generated from `game/autoload/event_bus.gd` — keep in sync after any signal changes.

---

## Content Pipeline

```gdscript
content_loaded()
content_load_failed(errors: Array[String])
```

## Time

```gdscript
day_started(day: int)
hour_changed(hour: int)
day_ended(day: int)
day_phase_changed(new_phase: int)
speed_changed(new_speed: float)
speed_reduced_by_event(reason: String)
time_speed_requested(speed_tier: int)
day_acknowledged()
```

| Signal | Emitter | Subscriber(s) | Payload |
|---|---|---|---|
| `day_acknowledged` | `DaySummaryPanel` when the player dismisses the end-of-day summary dialog | Day cycle completion controller (ISSUE-353) to advance to the next day | _(none)_ |

## Game State

```gdscript
game_state_changed(old_state: int, new_state: int)
gameplay_ready()
game_over_triggered()
next_day_confirmed()
```

## Economy and Leasing

```gdscript
transaction_completed(amount: float, success: bool, message: String)
money_changed(old_amount: float, new_amount: float)
cash_changed(new_balance: float)
item_sold(item_id: String, price: float, category: String)
item_lost(item_id: String, reason: String)
lease_requested(store_id: StringName, slot_index: int, store_name: String)
lease_completed(store_id: StringName, success: bool, message: String)
owned_slots_restored(slots: Dictionary)
player_bankrupt()
bankruptcy_declared()
player_quit_to_end()
```

| Signal | Emitter | Subscriber(s) | Payload | Preconditions |
|---|---|---|---|---|
| `bankruptcy_declared` | `EconomySystem` when player cash reaches ≤ 0 after a deduction | `GameManager` (triggers ending evaluation); `DifficultySystem` (Easy mode: triggers emergency cash injection) | _(none)_ | Guarded by `_bankruptcy_declared` flag — emits at most once per run |

## Store Transitions

```gdscript
store_entered(store_id: StringName)
store_exited(store_id: StringName)
active_store_changed(store_id: StringName)
store_opened(store_id: String)
store_closed(store_id: String)
enter_store_requested(store_id: StringName)
exit_store_requested()
store_leased(slot_index: int, store_type: String)
store_unlocked(store_type: String, lease_cost: float)
store_switched(old_store_id: String, new_store_id: String)
storefront_entered(slot_index: int, store_id: String)
storefront_exited()
storefront_zone_entered(store_id: String)
storefront_zone_exited(store_id: String)
```

## Inventory and Pricing

```gdscript
inventory_updated(store_id: StringName)
inventory_changed()
inventory_item_added(store_id: StringName, item_id: StringName)
item_stocked(item_id: String, shelf_id: String)
item_removed_from_shelf(item_id: String, shelf_id: String)
price_set(item_id: String, price: float)
item_price_set(store_id: StringName, item_id: StringName, price: float, ratio: float)
```

## Orders

```gdscript
order_placed(store_id: StringName, item_id: StringName, quantity: int, delivery_day: int)
order_delivered(store_id: StringName, items: Array)
order_failed(reason: String)
supplier_tier_changed(old_tier: int, new_tier: int)
order_cash_check(amount: float, result: Array)
order_cash_deduct(amount: float, reason: String, result: Array)
order_refund_issued(amount: float, reason: String)
restock_requested(store_id: StringName, item_id: StringName, quantity: int)
```

## Customer and Sales

```gdscript
customer_spawned(customer: Node)
customer_entered(customer_data: Dictionary)
customer_purchased(store_id: StringName, item_id: StringName, price: float, customer_id: StringName)
customer_left(customer_data: Dictionary)
customer_left_mall(customer: Node, satisfied: bool)
customer_ready_to_purchase(customer_data: Dictionary)
queue_advanced(queue_size: int)
queue_changed(queue_size: int)
customer_abandoned_queue(customer: Node)
spawn_npc_requested(archetype_id: StringName, entry_position: Vector3)
```

## Checkout

```gdscript
customer_reached_checkout(customer: Node)
checkout_started(items: Array, customer_node: Node)
checkout_queue_ready(customer: Node)
checkout_completed(customer: Node)
```

| Signal | Emitter | Subscriber(s) | Payload |
|---|---|---|---|
| `customer_reached_checkout` | `QueueSystem` when a customer NPC arrives at the front of the checkout queue | `CheckoutSystem` to begin the transaction flow | `customer`: the `Node` instance of the customer NPC at the checkout counter |

## Haggling

```gdscript
haggle_requested(item_id: String, customer_id: int)
haggle_started(item_id: String, customer_id: int)
haggle_completed(store_id: StringName, item_id: StringName, final_price: float, asking_price: float, accepted: bool, offer_count: int)
haggle_failed(item_id: String, customer_id: int)
```

## Reputation

```gdscript
## Emitted by ReputationSystem when a store's reputation score changes.
reputation_changed(store_id: String, new_score: float)
```

## Staff

```gdscript
staff_hired(staff_id: String, store_id: String)
staff_fired(staff_id: String, store_id: String)
## Emitted by StaffSystem when a staff member's morale hits zero and they leave.
staff_quit(staff_id: String)
staff_not_paid(staff_id: String)
staff_wages_paid(total_amount: float)
staff_morale_changed(staff_id: String, new_morale: float)
payroll_cash_check(amount: float, result: Array)
payroll_cash_deduct(amount: float, reason: String, result: Array)
```

## Build Mode

```gdscript
build_mode_entered()
build_mode_exited()
fixture_placed(fixture_id: String, grid_pos: Vector2i, rotation: int)
fixture_removed(fixture_id: String, grid_pos: Vector2i)
fixture_selected(fixture_id: String)
fixture_upgraded(fixture_id: String, new_tier: int)
fixture_placement_invalid(reason: String)
placement_mode_entered()
placement_mode_exited()
nav_mesh_baked()
customer_spawning_disabled()
customer_spawning_enabled()
```

## Camera

```gdscript
active_camera_changed(camera: Camera3D)
```

## Environment

```gdscript
environment_changed(zone_key: StringName)
```

## Market and Events

```gdscript
market_event_announced(event_id: String)
market_event_started(event_id: String)
market_event_ended(event_id: String)
market_event_triggered(event_id: StringName, store_id: StringName, effect: Dictionary)
market_event_active(event_id: StringName, modifier: Dictionary)
market_event_expired(event_id: StringName)
random_event_started(event_id: String)
random_event_ended(event_id: String)
random_event_resolved(event_id: StringName, outcome: StringName)
trend_changed(trending: Array, cold: Array)
trend_updated(category: StringName, multiplier: float)
```

| Signal | Emitter | Subscriber(s) | Payload | Preconditions |
|---|---|---|---|---|
| `market_event_active` | `MarketEventSystem` when an event activates | `CustomerSystem` (spawn/intent modifier); `TrendsPanel` (UI badge) | `event_id`: canonical event id; `modifier`: Dictionary with keys `spawn_rate_multiplier: float`, `purchase_intent_multiplier: float`, `category: StringName` (affected category) | `event_id` must be a valid key in market_event_config.json |
| `market_event_expired` | `MarketEventSystem` when event duration ends | `CustomerSystem` (reset modifiers); `TrendsPanel` (clear badge) | `event_id`: same id as was passed to `market_event_active` | Must correspond to a previously active event |
| `trend_updated` | `TrendSystem` on each trend tick when a category's popularity multiplier changes | `MarketValueSystem` (caches for price calculation) | `category`: canonical item category StringName; `multiplier`: float where 1.0 = baseline, >1.0 = hot trend, <1.0 = cold trend | Emitted on trend tick (daily or hourly per TrendSystem update rate) |

## Seasonal Events

```gdscript
seasonal_event_announced(event_id: String)
seasonal_event_started(event_id: String)
seasonal_event_ended(event_id: String)
```

## Calendar Seasons

```gdscript
season_changed(new_season: int, old_season: int)
seasonal_multipliers_updated(multipliers: Dictionary)
```

## Season Cycle (Sports Memorabilia)

```gdscript
season_cycle_shifted(new_hot_league: String, old_hot_league: String)
season_cycle_announced(next_hot_league: String, days_until: int)
```

## Authentication (Sports Memorabilia)

```gdscript
authentication_started(item_id: String, cost: float)
authentication_completed(item_id: String, success: bool, message: String)
authentication_dialog_requested(item_id: String)
```

## Testing Station

```gdscript
item_tested(item_id: String, success: bool)
```

## Refurbishment

```gdscript
refurbishment_started(item_id: String, parts_cost: float, duration: int)
refurbishment_completed(item_id: String, success: bool, new_condition: String)
refurbishment_failed(item_id: String)
```

## Pack Opening

```gdscript
pack_opening_started(pack_id: String, card_results: Array[Dictionary])
pack_opened(pack_id: String, cards: Array[String])
```

## Tournament

```gdscript
tournament_started(participant_count: int, cost: float)
tournament_completed(participant_count: int, revenue: float)
```

## Trade (PocketCreatures)

```gdscript
trade_offered(customer_id: int, wanted_item_id: String, offered_item_id: String)
trade_accepted(wanted_item_id: String, offered_item_id: String)
trade_declined(customer_id: int)
```

## Meta Shift (PocketCreatures)

```gdscript
meta_shift_announced(rising: Array[String], falling: Array[String])
meta_shift_activated(rising: Array[String], falling: Array[String])
meta_shift_ended()
```

## Rental

```gdscript
item_rented(item_id: String, rental_fee: float, rental_tier: String)
rental_returned(item_id: String, degraded: bool)
rental_late_fee(item_id: String, late_fee: float, days_late: int)
rental_item_lost(item_id: String)
```

## Warranty

```gdscript
warranty_purchased(item_id: String, warranty_fee: float)
warranty_claim_triggered(item_id: String, replacement_cost: float)
```

## Demo Station

```gdscript
demo_item_placed(item_id: String)
demo_item_removed(item_id: String, days_on_demo: int)
demo_item_degraded(item_id: String, new_condition: String)
```

## Electronics Lifecycle

```gdscript
electronics_product_announced(product_line: String, generation: int, launch_day: int)
electronics_product_launched(product_line: String, generation: int)
electronics_phase_changed(item_id: String, old_phase: String, new_phase: String)
```

## Progression and Milestones

```gdscript
## Emitted by MilestoneSystem when a milestone condition is first satisfied.
milestone_unlocked(milestone_id: StringName, reward: Dictionary)
milestone_completed(milestone_id: String, milestone_name: String, reward_description: String)
store_slot_unlocked(slot_index: int)
all_milestones_completed()
completion_reached(reason: String)
## Emitted by UnlockSystem when a feature unlock is granted.
unlock_granted(unlock_id: StringName)
```

## Store Upgrades

```gdscript
upgrade_purchased(store_id: StringName, upgrade_id: String)
toggle_upgrade_panel()
```

## Tutorial

```gdscript
tutorial_step_changed(step_id: String)
tutorial_step_completed(step_id: String)
tutorial_completed()
tutorial_skipped()
contextual_tip_requested(tip_text: String)
```

## Onboarding

| Signal | Emitter | Subscriber(s) | Payload |
|---|---|---|---|
| `onboarding_hint_shown` | OnboardingSystem | HintOverlayUI | `hint_id`: contextual hint identifier, `message`: display text, `position_hint`: screen region hint for overlay placement |
| `onboarding_disabled` | OnboardingSystem | HintOverlayUI | _(none)_ |

```gdscript
onboarding_hint_shown(hint_id: StringName, message: String, position_hint: String)
onboarding_disabled()
```

## Secret Threads

```gdscript
secret_thread_state_changed(thread_id: StringName, old_phase: StringName, new_phase: StringName)
secret_thread_revealed(thread_id: StringName)
secret_thread_completed(thread_id: StringName, reward_unlock_id: StringName)
secret_thread_failed(thread_id: StringName)
```

## Ambient Moments

```gdscript
mystery_item_inspected(instance_id: String)
odd_notification_read(notification_id: String)
discrepancy_noticed(day: int)
renovation_sounds_heard()
wrong_name_customer_interacted()
ambient_moment_queued(moment_id: StringName)
ambient_moment_delivered(moment_id: StringName, display_type: StringName, text: String)
ambient_moment_cancelled(moment_id: StringName, reason: StringName)
```

## Endings

```gdscript
ending_requested(trigger_type: String)
ending_stats_snapshot_ready(stats: Dictionary)
ending_triggered(ending_id: StringName, final_stats: Dictionary)
ending_dismissed()
```

## Performance Reports

| Signal | Emitter | Subscriber(s) | Payload |
|---|---|---|---|
| `performance_report_ready` | PerformanceReportSystem | DaySummaryPanel | `report`: completed PerformanceReport resource for the just-ended day |
| `daily_financials_snapshot` | EconomySystem | PerformanceReportSystem | `revenue`: total cash received today, `expenses`: total cash spent today, `net`: revenue minus expenses |

```gdscript
performance_report_ready(report: PerformanceReport)
daily_financials_snapshot(revenue: float, expenses: float, net: float)
```

## Save and Load

```gdscript
save_load_failed(slot: int, reason: String)
```

## Player

```gdscript
player_interacted(target: Node)
interactable_interacted(target: Interactable, type: int)
interactable_right_clicked(target: Interactable, type: int)
```

## UI

```gdscript
toggle_milestones_panel()
toggle_staff_panel()
notification_requested(message: String)
## Emitted by any system requesting a non-blocking player notification.
toast_requested(message: String, category: StringName, duration: float)
panel_opened(panel_name: String)
panel_closed(panel_name: String)
keybind_changed(action: String, new_event: InputEventKey)
item_tooltip_requested(item: ItemInstance)
item_tooltip_hidden()
```

## Accessibility

```gdscript
colorblind_mode_changed(enabled: bool)
```

## Difficulty

| Signal | Emitter | Subscriber(s) | Payload |
|---|---|---|---|
| `difficulty_changed` | DifficultySystem | OrderSystem, any system caching difficulty-derived values | `old_tier`: previous difficulty tier, `new_tier`: new difficulty tier |
| `order_stockout` | OrderSystem | UI notification layer | `item_id`: item that was partially fulfilled, `requested`: quantity ordered, `fulfilled`: quantity actually delivered |
| `emergency_cash_injected` | EconomySystem | UI notification layer | `amount`: cash injected, `reason`: trigger description (e.g. Easy mode cash floor) |

```gdscript
difficulty_changed(old_tier: int, new_tier: int)
order_stockout(item_id: StringName, requested: int, fulfilled: int)
emergency_cash_injected(amount: float, reason: String)
```

## Localization

```gdscript
locale_changed(new_locale: String)
```

---

## Implementation Notes

- All signals are declared in `game/autoload/event_bus.gd` with typed parameters.
- Emitters call `EventBus.<signal_name>.emit(...)`. Receivers call `.connect(callback)` in `_ready()`.
- No system stores a reference to another system — all coordination is through these signals.
- The codebase uses GDScript 4 signal syntax exclusively (no `emit_signal()` or string-based `connect()`).
