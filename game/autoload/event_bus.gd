## Central signal bus for decoupled communication between systems.
@warning_ignore("unused_signal")
extends Node

var _latest_day_end_summary: Dictionary = {}


func _ready() -> void:
	day_started.connect(_on_day_started)

# ── Content Pipeline ──────────────────────────────────────────────────────────
signal content_loaded()
signal content_load_failed(errors: Array[String])

# ── Time ──────────────────────────────────────────────────────────────────────
signal day_started(day: int)
signal hour_changed(hour: int)
signal day_ended(day: int)
signal day_phase_changed(new_phase: int)
signal speed_changed(new_speed: float)
signal speed_reduced_by_event(reason: String)
signal time_speed_requested(speed_tier: int)

# ── Game State ────────────────────────────────────────────────────────────────
signal game_state_changed(old_state: int, new_state: int)
signal gameplay_ready()
signal game_over_triggered()
signal next_day_confirmed()
signal day_acknowledged()

# ── Economy and Leasing ───────────────────────────────────────────────────────
signal transaction_completed(amount: float, success: bool, message: String)
signal money_changed(old_amount: float, new_amount: float)
signal item_sold(item_id: String, price: float, category: String)
signal item_lost(item_id: String, reason: String)
signal lease_requested(store_id: StringName, slot_index: int, store_name: String)
signal lease_completed(store_id: StringName, success: bool, message: String)
signal owned_slots_restored(slots: Dictionary)
signal player_bankrupt()
signal bankruptcy_declared()
signal player_quit_to_end()

# ── Store Transitions ─────────────────────────────────────────────────────────
signal store_entered(store_id: StringName)
signal store_exited(store_id: StringName)
signal active_store_changed(store_id: StringName)
signal store_opened(store_id: String)
signal store_closed(store_id: String)
signal enter_store_requested(store_id: StringName)
signal exit_store_requested()
signal store_leased(slot_index: int, store_type: String)
signal store_unlocked(store_type: String, lease_cost: float)
signal store_switched(old_store_id: String, new_store_id: String)
signal storefront_entered(slot_index: int, store_id: String)
signal storefront_exited()
signal storefront_zone_entered(store_id: String)
signal storefront_zone_exited(store_id: String)

# ── Inventory and Pricing ─────────────────────────────────────────────────────
signal inventory_updated(store_id: StringName)
signal inventory_changed()
signal inventory_item_added(store_id: StringName, item_id: StringName)
signal item_stocked(item_id: String, shelf_id: String)
signal item_removed_from_shelf(item_id: String, shelf_id: String)
signal inventory_item_removed(item_id: StringName, store_id: StringName, reason: StringName)
signal stock_changed(store_id: StringName, item_id: StringName, new_quantity: int)
signal out_of_stock(store_id: StringName, item_id: StringName)
signal price_set(item_id: String, price: float)
signal item_price_set(store_id: StringName, item_id: StringName, price: float, ratio: float)

# ── Orders ────────────────────────────────────────────────────────────────────
signal order_placed(store_id: StringName, item_id: StringName, quantity: int, delivery_day: int)
signal order_delivered(store_id: StringName, items: Array)
signal order_failed(reason: String)
signal supplier_tier_changed(old_tier: int, new_tier: int)
signal order_cash_check(amount: float, result: Array)
signal order_cash_deduct(amount: float, reason: String, result: Array)
## Emitted by OrderSystem when a partial stockout refund is owed to the player.
signal order_refund_issued(amount: float, reason: String)
## Emitted by InventorySystem when stock for a definition falls below its reorder_min threshold.
signal restock_requested(store_id: StringName, item_id: StringName, quantity: int)

# ── Customer and Sales ────────────────────────────────────────────────────────
signal customer_spawned(customer: Node)
signal customer_entered(customer_data: Dictionary)
signal customer_purchased(store_id: StringName, item_id: StringName, price: float, customer_id: StringName)
signal customer_left(customer_data: Dictionary)
signal customer_left_mall(customer: Node, satisfied: bool)
signal customer_ready_to_purchase(customer_data: Dictionary)
## Emitted by CustomerSystem when the greeter entry conversion bonus applies.
signal customer_greeted(customer_id: StringName, store_id: StringName)
signal queue_advanced(queue_size: int)
signal queue_changed(queue_size: int)
signal customer_abandoned_queue(customer: Node)
signal customer_state_changed(customer: Node, new_state: int)
signal spawn_npc_requested(archetype_id: StringName, entry_position: Vector3)
## Emitted by NPCSpawnerSystem when an NPC is explicitly removed from the active pool.
signal npc_despawned(npc_id: StringName)

# ── Checkout ──────────────────────────────────────────────────────────────────
signal customer_reached_checkout(customer: Node)
signal checkout_started(items: Array, customer_node: Node)
signal checkout_queue_ready(customer: Node)
signal checkout_completed(customer: Node)

# ── Haggling ──────────────────────────────────────────────────────────────────
signal haggle_requested(item_id: String, customer_id: int)
signal haggle_started(item_id: String, customer_id: int)
signal haggle_completed(store_id: StringName, item_id: StringName, final_price: float, asking_price: float, accepted: bool, offer_count: int)
signal haggle_failed(item_id: String, customer_id: int)
## Emitted by SportsMemorabiliaController when an authenticated item sells via accepted haggle.
signal bonus_sale_completed(item_id: StringName, bonus_amount: float)

# ── Reputation ────────────────────────────────────────────────────────────────
## Emitted by ReputationSystem when a store's reputation score changes.
signal reputation_changed(store_id: String, new_score: float)
## Emitted by ReputationSystem when an event raises a store into a new tier.
signal reputation_tier_changed(store_id: String, old_tier: int, new_tier: int)

# ── Staff ─────────────────────────────────────────────────────────────────────
signal staff_hired(staff_id: String, store_id: String)
signal staff_fired(staff_id: String, store_id: String)
## Emitted by StaffSystem when a staff member's morale hits zero and they leave.
signal staff_quit(staff_id: String)
signal staff_not_paid(staff_id: String)
signal staff_wages_paid(total_amount: float)
signal staff_morale_changed(staff_id: String, new_morale: float)
signal payroll_cash_check(amount: float, result: Array)
signal payroll_cash_deduct(amount: float, reason: String, result: Array)
## Emitted by StockerBehavior when auto-restock moves a backroom item to shelf.
signal staff_restocked_shelf(staff_id: String, item_id: String)

# ── Build Mode ────────────────────────────────────────────────────────────────
signal build_mode_entered()
signal build_mode_exited()
signal fixture_catalog_requested(fixture_id: String)
signal fixture_placed(fixture_id: String, grid_pos: Vector2i, rotation: int)
signal fixture_removed(fixture_id: String, grid_pos: Vector2i)
signal fixture_selected(fixture_id: String)
signal fixture_upgraded(fixture_id: String, new_tier: int)
signal fixture_placement_invalid(reason: String)
signal placement_mode_entered()
signal placement_mode_exited()
signal nav_mesh_baked()
signal customer_spawning_disabled()
signal customer_spawning_enabled()

# ── Camera ────────────────────────────────────────────────────────────────────
signal active_camera_changed(camera: Camera3D)

# ── Environment ───────────────────────────────────────────────────────────────
signal environment_changed(zone_key: StringName)

# ── Market and Events ─────────────────────────────────────────────────────────
signal market_event_announced(event_id: String)
signal market_event_started(event_id: String)
signal market_event_ended(event_id: String)
signal market_event_active(event_id: StringName, modifier: Dictionary)
signal market_event_expired(event_id: StringName)
signal market_event_triggered(event_id: StringName, store_id: StringName, effect: Dictionary)
signal random_event_started(event_id: String)
signal random_event_ended(event_id: String)
signal random_event_resolved(event_id: StringName, outcome: StringName)
signal random_event_triggered(event_id: StringName, store_id: StringName, effect: Dictionary)
signal bulk_order_started(item_id: StringName, quantity: int, unit_price: float)
signal trend_changed(trending: Array, cold: Array)
signal trend_shifted(category_id: StringName, new_level: float)
## Emitted by TrendSystem when a category's effective trend multiplier changes.
signal trend_updated(category: StringName, multiplier: float)

# ── Seasonal Events ──────────────────────────────────────────────────────────
signal seasonal_event_announced(event_id: String)
signal seasonal_event_started(event_id: String)
signal seasonal_event_ended(event_id: String)

# ── Calendar Seasons ─────────────────────────────────────────────────────────
signal season_changed(new_season: int, old_season: int)
signal seasonal_multipliers_updated(multipliers: Dictionary)

# ── Season Cycle (Sports Memorabilia) ─────────────────────────────────────────
signal season_cycle_shifted(new_hot_league: String, old_hot_league: String)
signal season_cycle_announced(next_hot_league: String, days_until: int)

# ── Authentication (Sports Memorabilia) ───────────────────────────────────────
signal authentication_started(item_id, cost: float)
signal authentication_completed(item_id, success: bool, result)
signal authentication_dialog_requested(item_id)
signal authentication_rejected(item_id: StringName)

# ── Provenance Verification (Sports Memorabilia) ─────────────────────────────
signal provenance_requested(item_id: String, customer: Node)
signal provenance_accepted(item_id: String)
signal provenance_rejected(item_id: String)
signal provenance_completed(item_id: String, success: bool, message: String)

# ── Testing Station ──────────────────────────────────────────────────────────
signal item_testing_started(instance_id: String, duration: float)
signal item_test_completed(instance_id: String, result: String)
signal item_tested(item_id: String, success: bool)

# ── Refurbishment ─────────────────────────────────────────────────────────────
signal refurbishment_started(item_id: String, parts_cost: float, duration: int)
signal refurbishment_completed(item_id: String, success: bool, new_condition: String)
signal refurbishment_failed(item_id: String)

# ── Pack Opening ──────────────────────────────────────────────────────────────
signal pack_opening_started(pack_id: String, card_results: Array[Dictionary])
signal pack_opened(pack_id: String, cards: Array[String])

# ── Tournament ────────────────────────────────────────────────────────────────
signal tournament_started(participant_count: int, cost: float)
signal tournament_completed(participant_count: int, revenue: float)
signal tournament_resolved(winner_id: StringName, prize: float)

# ── Tournament Events (Scheduled) ────────────────────────────────────────────
signal tournament_event_announced(event_id: String)
signal tournament_event_started(event_id: String)
signal tournament_event_ended(event_id: String)

# ── Trade (PocketCreatures) ───────────────────────────────────────────────────
signal trade_offered(customer_id: int, wanted_item_id: String, offered_item_id: String)
signal trade_offer_received(offer: Dictionary)
signal trade_accepted(wanted_item_id: String, offered_item_id: String)
signal trade_declined(customer_id: int)
signal trade_resolved(offer: Dictionary, accepted: bool)
signal trade_completed(offered_card_id: String, received_card_id: String)
signal trade_rejected(offered_card_id: String)

# ── Meta Shift (PocketCreatures) ─────────────────────────────────────────────
signal meta_shift_announced(rising: Array[String], falling: Array[String])
signal meta_shift_activated(rising: Array[String], falling: Array[String])
signal meta_shift_started(card_id: StringName, modifier: float, duration: int)
signal meta_shift_ended(card_id: StringName)

# ── Rental ────────────────────────────────────────────────────────────────────
signal item_rented(item_id: String, rental_fee: float, rental_tier: String)
signal rental_returned(item_id: String, degraded: bool)
signal rental_late_fee(item_id: String, late_fee: float, days_late: int)
signal rental_item_lost(item_id: String)

# ── Warranty ──────────────────────────────────────────────────────────────────
signal warranty_purchased(item_id: String, warranty_fee: float)
signal warranty_claim_triggered(item_id: String, replacement_cost: float)
signal warranty_offer_presented(item_id: String)

# ── Demo Station ──────────────────────────────────────────────────────────────
signal demo_item_placed(item_id: String)
signal demo_item_removed(item_id: String, days_on_demo: int)
signal demo_item_degraded(item_id: String, new_condition: String)

# ── Electronics Lifecycle ─────────────────────────────────────────────────────
signal electronics_product_announced(product_line: String, generation: int, launch_day: int)
signal electronics_product_launched(product_line: String, generation: int)
signal electronics_phase_changed(item_id: String, old_phase: String, new_phase: String)
signal product_entered_decline(item_id: String)
signal product_entered_clearance(item_id: String)

# ── Progression and Milestones ────────────────────────────────────────────────
## Emitted by MilestoneSystem when a milestone condition is first satisfied.
signal milestone_unlocked(milestone_id: StringName, reward: Dictionary)
signal milestone_completed(milestone_id: String, milestone_name: String, reward_description: String)
signal milestone_reputation_reward(milestone_id: StringName, delta: int)
signal milestone_unlock_granted(unlock_id: StringName)
signal store_slot_unlocked(slot_index: int)
signal all_milestones_completed()
signal completion_reached(reason: String)
## Emitted by UnlockSystem when a feature unlock is granted.
signal unlock_granted(unlock_id: StringName)

# ── Store Upgrades ────────────────────────────────────────────────────────────
signal upgrade_purchased(store_id: StringName, upgrade_id: String)
signal store_upgrade_effect_applied(
	store_id: StringName,
	upgrade_id: String,
	effect_type: String,
	effect_value: float,
)
signal toggle_upgrade_panel()

# ── Tutorial ──────────────────────────────────────────────────────────────────
signal tutorial_step_changed(step_id: String)
signal tutorial_step_completed(step_id: String)
signal tutorial_completed()
signal tutorial_skipped()
signal skip_tutorial_requested()
signal contextual_tip_requested(tip_text: String)

# ── Onboarding ───────────────────────────────────────────────────────────────
signal onboarding_hint_shown(hint_id: StringName, message: String, position_hint: String)
signal onboarding_disabled()

# ── Secret Threads ────────────────────────────────────────────────────────────
signal secret_thread_state_changed(thread_id: StringName, old_phase: StringName, new_phase: StringName)
signal secret_thread_completed(thread_id: StringName, reward_data: Dictionary)
signal secret_thread_revealed(thread_id: StringName)
signal secret_thread_failed(thread_id: StringName)

# ── Ambient Moments ──────────────────────────────────────────────────────────
signal mystery_item_inspected(instance_id: String)
signal odd_notification_read(notification_id: String)
signal discrepancy_noticed(day: int)
signal renovation_sounds_heard()
signal wrong_name_customer_interacted()
signal ambient_moment_queued(moment_id: StringName)
signal ambient_moment_delivered(moment_id: StringName, display_type: StringName, flavor_text: String, audio_cue_id: StringName)
signal ambient_moment_cancelled(moment_id: StringName, reason: StringName)

# ── Endings ───────────────────────────────────────────────────────────────────
signal ending_requested(trigger_type: String)
signal ending_stats_snapshot_ready(stats: Dictionary)
signal ending_triggered(ending_id: StringName, final_stats: Dictionary)
signal ending_dismissed()

# ── Performance Reports ───────────────────────────────────────────────────────
signal performance_report_ready(report: PerformanceReport)
## Emitted by EconomySystem at end of each day with the day's financial totals.
signal daily_financials_snapshot(revenue: float, expenses: float, net: float)

# ── Save and Load ─────────────────────────────────────────────────────────────
signal save_load_failed(slot: int, reason: String)

# ── Player ────────────────────────────────────────────────────────────────────
signal player_interacted(target: Node)
signal interactable_interacted(target: Interactable, type: int)
signal interactable_right_clicked(target: Interactable, type: int)
signal interactable_focused(action_label: String)
signal interactable_unfocused()

# ── UI ────────────────────────────────────────────────────────────────────────
signal toggle_milestones_panel()
signal toggle_staff_panel()
signal toggle_refurb_queue_panel()
signal notification_requested(message: String)
## Emitted by any system requesting a non-blocking player notification.
signal toast_requested(message: String, category: StringName, duration: float)
signal panel_opened(panel_name: String)
signal panel_closed(panel_name: String)
signal keybind_changed(action: String, new_event: InputEventKey)
signal item_tooltip_requested(item: ItemInstance)
signal item_tooltip_hidden()

# ── Input ─────────────────────────────────────────────────────────────────
signal cursor_locked()
signal cursor_unlocked()

# ── Accessibility ─────────────────────────────────────────────────────────────
signal colorblind_mode_changed(enabled: bool)

# ── Difficulty ────────────────────────────────────────────────────────────────
signal difficulty_changed(old_tier: int, new_tier: int)
signal order_stockout(item_id: StringName, requested: int, fulfilled: int)
signal emergency_cash_injected(amount: float, reason: String)

# ── Localization ──────────────────────────────────────────────────────────────
signal locale_changed(new_locale: String)

# ── Settings ──────────────────────────────────────────────────────────────────
signal preference_changed(key: String, value: Variant)


## Publishes the latest end-of-day summary for listeners that need more than
## the legacy day_ended(day) payload.
func publish_day_end_summary(summary: Dictionary) -> void:
	_latest_day_end_summary = summary.duplicate(true)


## Returns a defensive copy of the latest end-of-day summary.
func get_day_end_summary() -> Dictionary:
	return _latest_day_end_summary.duplicate(true)


## Clears any cached end-of-day summary once the next day begins.
func clear_day_end_summary() -> void:
	_latest_day_end_summary.clear()


func _on_day_started(_day: int) -> void:
	clear_day_end_summary()
