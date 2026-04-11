## Central signal bus for decoupled communication between systems.
@warning_ignore("unused_signal")
extends Node

# Player
signal player_interacted(target: Node)
signal interactable_interacted(target: Interactable, type: int)

# Economy
signal item_sold(item_id: String, price: float, category: String)
signal money_changed(old_amount: float, new_amount: float)
signal item_lost(item_id: String, reason: String)

# Store
signal store_opened(store_id: String)
signal store_closed(store_id: String)
## customer_data keys: customer_id, profile_id, profile_name, store_id
signal customer_entered(customer_data: Dictionary)
## customer_data keys: customer_id, profile_id, profile_name, store_id
signal customer_left(customer_data: Dictionary)
signal customer_ready_to_purchase(customer_data: Dictionary)

# Time
signal day_started(day: int)
signal day_ended(day: int)
signal hour_changed(hour: int)
signal day_phase_changed(new_phase: int)
signal speed_changed(new_speed: float)

# Game State
signal game_state_changed(old_state: int, new_state: int)

# Data
signal content_loaded()

# Inventory
signal item_stocked(item_id: String, shelf_id: String)
signal item_removed_from_shelf(item_id: String, shelf_id: String)
signal inventory_changed()

# Placement
signal placement_mode_entered()
signal placement_mode_exited()
signal interactable_right_clicked(target: Interactable, type: int)

# Pricing
signal price_set(item_id: String, price: float)

# Haggling
signal haggle_started(item_id: String, customer_id: int)
signal haggle_completed(item_id: String, final_price: float)
signal haggle_failed(item_id: String, customer_id: int)

# Seasonal Events
signal seasonal_event_announced(event_id: String)
signal seasonal_event_started(event_id: String)
signal seasonal_event_ended(event_id: String)

# Market Events
signal market_event_announced(event_id: String)
signal market_event_started(event_id: String)
signal market_event_ended(event_id: String)

# Season Cycle (Sports Memorabilia)
signal season_cycle_shifted(new_hot_league: String, old_hot_league: String)
signal season_cycle_announced(next_hot_league: String, days_until: int)
signal random_event_started(event_id: String)
signal random_event_ended(event_id: String)
signal trend_changed(trending: Array, cold: Array)

# Orders
signal order_placed(order_data: Dictionary)
signal order_delivered(order_data: Dictionary)
signal supplier_tier_changed(old_tier: int, new_tier: int)
signal order_cash_check(amount: float, result: Array)
signal order_cash_deduct(amount: float, reason: String, result: Array)

# Pack Opening
signal pack_opened(pack_id: String, cards: Array[String])

# Tournament
signal tournament_started(participant_count: int, cost: float)
signal tournament_completed(participant_count: int, revenue: float)

# Trade (PocketCreatures)
signal trade_offered(customer_id: int, wanted_item_id: String, offered_item_id: String)
signal trade_accepted(wanted_item_id: String, offered_item_id: String)
signal trade_declined(customer_id: int)

# Meta Shift (PocketCreatures)
signal meta_shift_announced(rising: Array[String], falling: Array[String])
signal meta_shift_activated(rising: Array[String], falling: Array[String])
signal meta_shift_ended()

# Authentication (Sports Memorabilia)
signal authentication_started(item_id: String, cost: float)
signal authentication_completed(item_id: String, is_genuine: bool)

# Testing Station
signal item_tested(item_id: String, success: bool)

# Refurbishment
signal refurbishment_started(item_id: String, parts_cost: float, duration: int)
signal refurbishment_completed(item_id: String, success: bool, new_condition: String)
signal refurbishment_failed(item_id: String)

# Rental
signal item_rented(item_id: String, rental_fee: float, rental_tier: String)
signal rental_returned(item_id: String, degraded: bool)
signal rental_late_fee(item_id: String, late_fee: float, days_late: int)
signal rental_item_lost(item_id: String)

# Reputation
signal reputation_changed(old_value: float, new_value: float)

# Build Mode
signal build_mode_entered()
signal build_mode_exited()
signal fixture_placed(fixture_id: String, grid_pos: Vector2i)
signal fixture_removed(fixture_id: String, grid_pos: Vector2i)
signal fixture_selected(fixture_id: String)
signal fixture_upgraded(fixture_id: String, new_tier: int)
signal fixture_placement_invalid(reason: String)

# Mall
signal storefront_entered(slot_index: int, store_id: String)
signal storefront_exited()
signal store_leased(slot_index: int, store_type: String)
signal store_unlocked(store_type: String, lease_cost: float)
signal store_switched(old_store_id: String, new_store_id: String)

# Warranty
signal warranty_purchased(item_id: String, warranty_fee: float)
signal warranty_claim_triggered(item_id: String, replacement_cost: float)

# Demo Station
signal demo_item_placed(item_id: String)
signal demo_item_removed(item_id: String, days_on_demo: int)
signal demo_item_degraded(item_id: String, new_condition: String)

# Electronics Lifecycle
signal electronics_product_announced(product_line: String, generation: int, launch_day: int)
signal electronics_product_launched(product_line: String, generation: int)
signal electronics_phase_changed(item_id: String, old_phase: String, new_phase: String)

# Milestones
signal milestone_completed(milestone_id: String, milestone_name: String, reward_description: String)

# Staff
signal staff_hired(staff_id: String, store_id: String)
signal staff_fired(staff_id: String, store_id: String)
signal staff_wages_paid(total_amount: float)

# Tutorial
signal tutorial_step_changed(step_id: String)
signal tutorial_step_completed(step_id: String)
signal tutorial_completed()
signal tutorial_skipped()
signal contextual_tip_requested(tip_text: String)

# UI
signal toggle_milestones_panel()
signal toggle_staff_panel()
signal notification_requested(message: String)
signal panel_opened(panel_name: String)
signal panel_closed(panel_name: String)
signal keybind_changed(action: String, new_event: InputEventKey)
signal item_tooltip_requested(item: ItemInstance)
signal item_tooltip_hidden()

# Accessibility
signal colorblind_mode_changed(enabled: bool)

# Localization
signal locale_changed(new_locale: String)

# Endings
signal all_milestones_completed()
signal ending_triggered(ending_type: String)
signal ending_dismissed()

# Ambient Moments (Secret Thread)
signal mystery_item_inspected(instance_id: String)
signal odd_notification_read(notification_id: String)
signal discrepancy_noticed(day: int)
signal renovation_sounds_heard()
signal wrong_name_customer_interacted()
