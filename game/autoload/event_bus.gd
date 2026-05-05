## Central signal bus for decoupled communication between systems.
##
## Per docs/architecture/ownership.md row 10, EventBus is the only permitted
## cross-system signal route. Owner autoloads declare their own authoritative
## signals on themselves; the Phase 1 mirror block below lets other systems
## listen through the bus without reaching into owners directly.
extends Node

# ── Phase 1 Signal Inventory ──────────────────────────────────────────────────
# Typed cross-system signals for the golden path: Boot → Mall → Store Ready.
# Emitters must still be the conceptual owners listed in ownership.md; these
# mirrors are listener-facing. Use the emit_* wrappers below for type safety.
signal store_ready(store_id: StringName)
signal store_failed(store_id: StringName, reason: String)
signal scene_ready(scene_name: StringName)
# NOTE: the Phase 1 parameterless `game_state_changed()` is satisfied by
# `run_state_changed()` below. The legacy
# `game_state_changed(old_state: int, new_state: int)` is the GameManager FSM
# transition signal and predates Phase 1 — both are typed. See
# docs/architecture/ownership.md row 6.
signal input_focus_changed(owner: StringName)
signal camera_authority_changed(camera_path: NodePath)

# ── Content Pipeline ──────────────────────────────────────────────────────────
signal content_loaded()
signal content_load_failed(errors: Array[String])

# ── Time ──────────────────────────────────────────────────────────────────────
signal day_started(day: int)
signal hour_changed(hour: int)
signal day_ended(day: int)
## Emitted by the player via HUD to request early end-of-day.
signal day_close_requested()
## Emitted by DayCycleController after all store_day_closed signals have fired.
## summary keys: day, total_revenue, total_expenses, net_profit, items_sold,
## rent, net_cash, store_revenue, warranty_revenue, warranty_claims,
## seasonal_impact, discrepancy, staff_wages, inventory_remaining
signal day_closed(day: int, summary: Dictionary)
signal day_phase_changed(new_phase: int)
signal speed_changed(new_speed: float)
signal speed_reduced_by_event(reason: String)
signal time_speed_requested(speed_tier: int)

# ── Game State ────────────────────────────────────────────────────────────────
signal boot_completed()
signal game_state_changed(old_state: int, new_state: int)
## Emitted by GameState on any mutation to the active run state
## (active_store_id, day, money, flags). Parameterless on purpose — listeners
## read the current values directly from the GameState autoload. Distinct from
## game_state_changed, which is the GameManager FSM transition signal.
signal run_state_changed()
signal gameplay_ready()
signal game_over_triggered()
signal next_day_confirmed()
signal day_acknowledged()

# ── Economy and Leasing ───────────────────────────────────────────────────────
signal transaction_completed(amount: float, success: bool, message: String)
signal money_changed(old_amount: float, new_amount: float)
signal item_sold(item_id: String, price: float, category: String)
## Emitted by ObjectiveDirector on the first item_sold in a run.
signal first_sale_completed(store_id: StringName, item_id: String, price: float)
signal item_lost(item_id: String, reason: String)
## Emitted when a sold item is later flagged as defective (failed warranty,
## customer return, broken-on-arrival). Drives angry_return_customer spawn gate.
signal defective_sale_occurred(item_id: String, reason: String)
## Emitted by ReturnsSystem when an item enters the damaged bin (post-accept
## return) so listeners can update the bin UI and inventory variance accounting.
signal defective_item_received(item_id: String)
signal lease_requested(store_id: StringName, slot_index: int, store_name: String)
signal lease_completed(store_id: StringName, success: bool, message: String)
signal owned_slots_restored(slots: Dictionary)
signal player_bankrupt()
signal bankruptcy_declared()
signal player_quit_to_end()

# ── Store Transitions ─────────────────────────────────────────────────────────
## Emitted by each StoreController when day_ended fires. store_summary contains
## at least {day: int}; revenue data is in day_closed summary from EconomySystem.
signal store_day_closed(store_id: StringName, store_summary: Dictionary)
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
## Emitted by DrawerHost when a store drawer has begun opening for store_id.
signal drawer_opened(store_id: StringName)
## Emitted by DrawerHost when the active drawer has begun closing for store_id.
signal drawer_closed(store_id: StringName)
## Emitted by ActionDrawer when it opens a mechanic content pane. mode is ActionDrawer.Mode int.
signal action_drawer_opened(mode: int)
## Emitted by ActionDrawer when it collapses back to the chrome button bar (IDLE).
signal action_drawer_closed()
## Emitted by ActionDrawer when the player accepts an incoming trade offer.
signal trade_player_accepted()
## Emitted by ActionDrawer when the player declines an incoming trade offer.
signal trade_player_declined()

# ── Store Actions (ActionDrawer) ──────────────────────────────────────────────
## Emitted by a StoreController when it enters; carries the list of action
## descriptors ({id: StringName, label: String, icon: String}) that the drawer
## should render for that store.
signal actions_registered(store_id: StringName, actions: Array)
## Emitted by ActionDrawer when the player presses an action button.
signal action_requested(action_id: StringName, store_id: StringName)

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
signal customer_purchased(
	store_id: StringName,
	item_id: StringName,
	price: float,
	customer_id: StringName,
)
signal customer_walked(store_id: StringName, item_id: StringName, reason: String)
signal customer_left(customer_data: Dictionary)
signal customer_left_mall(customer: Node, satisfied: bool)
signal customer_ready_to_purchase(customer_data: Dictionary)
## Emitted by CustomerSystem when the greeter entry conversion bonus applies.
signal customer_greeted(customer_id: StringName, store_id: StringName)
signal queue_advanced(queue_size: int)
signal queue_changed(queue_size: int)
signal customer_abandoned_queue(customer: Node)
signal customer_state_changed(customer: Node, new_state: int)
## Emitted by Customer when _evaluate_current_shelf assigns or upgrades the
## desired item. Carries both the customer and the item so listeners can post
## browsing feedback without holding per-customer references.
signal customer_item_spotted(customer: Customer, item: ItemInstance)
signal spawn_npc_requested(archetype_id: StringName, entry_position: Vector3)
## Emitted by NPCSpawnerSystem when an NPC is explicitly removed from the active pool.
signal npc_despawned(npc_id: StringName)
## Emitted by the platform-match dialogue when the player selects a platform for
## a confused-parent customer. correct is true when the chosen platform_id
## matches the customer's referenced platform. Fires on every selection so the
## embedded tutorial's PLATFORM_MATCH beat advances on engagement, not accuracy.
signal customer_platform_identified(
	customer_id: StringName, platform_id: StringName, correct: bool
)

# ── Checkout ──────────────────────────────────────────────────────────────────
signal customer_reached_checkout(customer: Node)
signal checkout_started(items: Array, customer_node: Node)
signal checkout_queue_ready(customer: Node)
signal checkout_completed(customer: Node)
## Player pressed Pass at the register before any sale fired. Distinct from
## `checkout_completed` (which fires for both accept and decline) so listeners
## can drive recovery flows — Day 1 rail rollback, forced-spawn re-arm — that
## should not run after a successful sale.
signal checkout_declined(customer: Node)

# ── Haggling ──────────────────────────────────────────────────────────────────
signal haggle_requested(item_id: String, customer_id: int)
signal haggle_started(item_id: String, customer_id: int)
signal haggle_completed(
	store_id: StringName,
	item_id: StringName,
	final_price: float,
	asking_price: float,
	accepted: bool,
	offer_count: int,
)
signal haggle_failed(item_id: String, customer_id: int)
## Emitted after a haggle resolves with the PriceResolver-computed multiplier applied.
signal haggle_resolved(item_id: StringName, final_price: float, haggle_multiplier: float)
## Emitted by HaggleSystem when the customer's mood tier changes during negotiation.
signal customer_mood_changed(item_id: StringName, mood: String)
## Emitted by SportsMemorabiliaController when an authenticated item sells via accepted haggle.
signal bonus_sale_completed(item_id: StringName, bonus_amount: float)
## Emitted by HaggleSystem alongside its local negotiation_started for ActionDrawer listeners.
signal haggle_negotiation_started(
	item_name: String,
	condition: String,
	sticker_price: float,
	customer_offer: float,
	max_rounds: int,
	time_per_turn: float,
)
## Emitted by HaggleSystem alongside its local customer_countered for ActionDrawer listeners.
signal haggle_customer_countered(new_offer: float, round_number: int, max_rounds: int)
## Emitted by ActionDrawer when the player accepts the current haggle offer.
signal haggle_player_accepted()
## Emitted by ActionDrawer when the player submits a counter-offer.
signal haggle_player_countered(price: float)
## Emitted by ActionDrawer when the player declines to negotiate further.
signal haggle_player_declined()

# ── Reputation ────────────────────────────────────────────────────────────────
## Emitted by ReputationSystem after every reputation mutation.
## old_score is the pre-mutation score; new_score is the post-clamp score.
signal reputation_changed(store_id: String, old_score: float, new_score: float)
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
## Emitted alongside `placement_mode_entered` when a specific item is being
## placed. `item_name` is the localized display name; consumers render a
## persistent hint such as "Click a shelf slot to place <item_name>" because
## `InteractionPrompt` is suppressed by `CTX_MODAL` during placement mode.
signal placement_hint_requested(item_name: String)

# ── Stocking ──────────────────────────────────────────────────────────────────
## Emitted when inventory is open and the player hovers a stockable item.
## item_category identifies which ShelfSlot category markers to reveal.
signal stocking_cursor_active(item_category: StringName)
## Emitted when inventory closes or the player stops hovering a stockable item.
signal stocking_cursor_inactive()

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
## Emitted by RandomEventSystem at STORE_CLOSE_HOUR - 12 on days 3+ to telegraph
## upcoming market activity.
signal random_event_telegraphed(message: String)
signal random_event_resolved(event_id: StringName, outcome: StringName)
signal random_event_triggered(event_id: StringName, store_id: StringName, effect: Dictionary)
signal bulk_order_started(item_id: StringName, quantity: int, unit_price: float)
signal trend_changed(trending: Array, cold: Array)
signal trend_shifted(category_id: StringName, new_level: float)
## Emitted by TrendSystem when a category's effective trend multiplier changes.
signal trend_updated(category: StringName, multiplier: float)

# ── Seasonal Events ──────────────────────────────────────────────────────────
signal seasonal_event_announced(event_id: String)
## Fires telegraph_days before seasonal_event_started; gives players advance notice.
signal event_telegraphed(event_id: String, days_until: int)
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
## Emitted by ActionDrawer when the player submits an item for authentication at a tier.
## tier matches SportsMemorabiliaController.AuthTier (0=ECONOMY, 1=EXPRESS, 2=PREMIUM).
signal authentication_player_submitted(item_id: String, tier: int)
## Emitted when an item is submitted to CARB for multi-state grading.
## tier matches SportsMemorabiliaController.AuthTier (0=ECONOMY, 1=EXPRESS, 2=PREMIUM).
signal store_auth_started(item_id: StringName, tier: int, cost: float)
## Emitted when CARB finalizes grading. grade is the AuthGrade int value (0–10, skips 6).
signal store_auth_resolved(item_id: StringName, grade: int, final_value: float)

# ── Sports Cards — Authentication & Grading ───────────────────────────────────
## Emitted when provenance_score meets the authentication threshold.
signal card_authenticated(item_id: StringName)
## Emitted when provenance_score falls below the authentication threshold.
signal card_rejected(item_id: StringName)
## Emitted after authentication succeeds with the assigned grade (F/D/C/B/A/S).
signal card_graded(item_id: StringName, grade: String)

# ── Sports Cards — Grading Hint & Fake Sale Penalty ──────────────────────────
## Emitted by SportsMemorabiliaController.request_grading_hint() after a paid
## probabilistic hint is stamped onto the item. hint is one of
## "authentic" | "questionable" | "fake"; fee is the charge deducted.
signal grading_hint_revealed(item_id: StringName, hint: String, fee: float)
## Emitted when the player sells a card the hidden true_authenticity of which
## is "fake" while declaring it authentic. reputation_delta is negative.
signal fake_sold_as_authentic(
	item_id: StringName,
	store_id: StringName,
	price: float,
	reputation_delta: float,
)

# ── Sports Cards — ACC Numeric Grading ───────────────────────────────────────
## Emitted when the player submits a card to the Apex Card Certification service.
## card_id is the item instance_id; day_submitted is the current game day.
signal grade_submitted(card_id: StringName, day_submitted: int)
## Emitted at day_started of day N+1 for each card submitted on day N.
## grade is a numeric int 1–10 matching PriceResolver.NUMERIC_GRADE_MULTIPLIERS.
signal grade_returned(card_id: StringName, grade: int)
## Emitted by SportsMemorabiliaController on day_ended with a summary of grading
## activity: pending_count is cards still in queue; returned is an Array of
## Dictionaries with keys {card_id, card_name, grade, grade_label}.
signal grading_day_summary(pending_count: int, returned: Array)

# ── Card Condition Grading (Sports Memorabilia) ───────────────────────────────
## Emitted by ConditionPickerDialog when the player confirms a condition grade.
signal card_condition_selected(item_id: StringName, condition: String)
## Emitted to request the condition picker dialog for a sports card item.
signal condition_picker_requested(item_id: StringName)
## Emitted by PriceResolver.resolve_for_item after the full multiplier chain
## (base → seasonal → reputation → event → haggle) has produced a final price.
signal price_resolved(item_id: StringName, final_price: float, audit_steps: Array)

# ── Provenance Verification (Sports Memorabilia) ─────────────────────────────
signal provenance_requested(item_id: String, customer: Node)
signal provenance_accepted(item_id: String)
signal provenance_rejected(item_id: String)
signal provenance_completed(item_id: String, success: bool, message: String)

# ── Testing Station ──────────────────────────────────────────────────────────
signal item_testing_started(instance_id: String, duration: float)
signal item_test_completed(instance_id: String, result: String)

# ── Retro Games — Quality Grading ─────────────────────────────────────────────
## Emitted by RetroGames.inspect_item() when condition data is ready for display.
signal inspection_ready(item_id: StringName, condition_data: Dictionary)
## Emitted by RetroGames.assign_grade() when the player confirms a grade tier.
signal grade_assigned(item_id: StringName, grade_id: String)
## Emitted by RetroGames after PriceResolver produces a final graded price.
signal item_priced(item_id: StringName, price: float)

# ── Refurbishment ─────────────────────────────────────────────────────────────
signal refurbishment_started(item_id: String, parts_cost: float, duration: int)
signal refurbishment_completed(item_id: String, success: bool, new_condition: String)
signal refurbishment_failed(item_id: String)
## Emitted by ActionDrawer when the player queues an item for refurbishment.
signal refurb_player_queued(store_id: StringName)

# ── Pack Opening ──────────────────────────────────────────────────────────────
signal pack_opening_started(pack_id: String, card_results: Array[Dictionary])
signal pack_opened(pack_id: String, cards: Array[String])
signal items_revealed(pack_id: String, creatures: Array)
## Emitted after pack_opened when at least one card is holo_rare, secret_rare, or ultra_rare.
signal rare_pull_occurred(pack_id: String)

# ── Tournament ────────────────────────────────────────────────────────────────
signal tournament_started(participant_count: int, cost: float)
signal tournament_completed(participant_count: int, revenue: float)
signal tournament_resolved(winner_id: StringName, prize: float)

# ── Tournament Events (Scheduled) ────────────────────────────────────────────
signal tournament_event_announced(event_id: String)
signal tournament_event_started(event_id: String)
signal tournament_event_ended(event_id: String)
## Emitted telegraph_days before a scheduled tournament starts.
signal tournament_telegraphed(tournament_id: String)
## Emitted at the close of a scheduled tournament's last day with a result summary.
signal tournament_ended(tournament_id: String, result_summary: Dictionary)

# ── Meta Shift (PocketCreatures) ─────────────────────────────────────────────
signal meta_shift_announced(rising: Array[String], falling: Array[String])
signal meta_shift_activated(rising: Array[String], falling: Array[String])
signal meta_shift_started(card_id: StringName, modifier: float, duration: int)
signal meta_shift_ended(card_id: StringName)
## Emitted 1 day before a JSON-defined meta shift activates.
signal meta_shift_telegraphed(shift_id: String, affected_types: Array[String], message: String)
## Emitted when a JSON-defined meta shift becomes active; PriceResolver callers
## should fetch updated multipliers.
signal meta_shift_applied(
	shift_id: String, affected_types: Array[String], multiplier: float
)

# ── Rental ────────────────────────────────────────────────────────────────────
signal item_rented(item_id: String, rental_fee: float, rental_tier: String)
signal rental_returned(item_id: String, degraded: bool)
signal rental_late_fee(item_id: String, late_fee: float, days_late: int)
signal rental_item_lost(item_id: String)
## Canonical rental lifecycle signals (aliases kept for backward compatibility).
signal title_rented(item_id: String, rental_fee: float, rental_tier: String)
signal title_returned(item_id: String, degraded: bool)
## Player waived a late fee; reputation_delta is the positive rep awarded.
signal late_fee_waived(item_id: String, amount: float, reputation_delta: float)
## Player (or auto-collect) collected a late fee from an overdue return.
signal late_fee_collected(item_id: String, amount: float, days_late: int)
## Emitted at day transition for each item still out past its deadline.
## customer_id may be empty when the rental was created without one.
signal rental_overdue(customer_id: String, item_id: String)
## Canonical store-scoped rental lifecycle signals.
signal store_rental_started(item_id: String, customer_id: String, due_day: int)
signal store_rental_returned(item_id: String, late_days: int)
signal store_rental_overdue(customer_id: String, item_id: String)

# ── Warranty ──────────────────────────────────────────────────────────────────
signal warranty_purchased(item_id: String, warranty_fee: float)
signal warranty_claim_triggered(item_id: String, replacement_cost: float)
signal warranty_offer_presented(item_id: String)
## Emitted when a customer accepts a warranty pitch for a specific tier.
signal warranty_accepted(item_id: String, tier_id: String, warranty_fee: float)
## Emitted when a customer declines a warranty pitch for a specific tier.
signal warranty_declined(item_id: String, tier_id: String)
## Emitted by ActionDrawer when the player confirms offering warranty to the customer.
signal warranty_player_accepted(item_id: String, tier_id: String)
## Emitted by ActionDrawer when the player skips the warranty pitch.
signal warranty_player_declined(item_id: String)

# ── Demo Station ──────────────────────────────────────────────────────────────
signal demo_item_placed(item_id: String)
signal demo_item_removed(item_id: String, days_on_demo: int)
signal demo_item_degraded(item_id: String, new_condition: String)
signal demo_interaction_triggered(item_id: String)
## Emitted when a demo unit is activated on the floor (canonical mechanic signal).
signal demo_unit_activated(item_id: String, category: String)
## Emitted when a demo unit is removed from the floor (canonical mechanic signal).
signal demo_unit_removed(item_id: String, days_on_demo: int)
## Emitted when a demo unit is retired to inventory at its depreciated value.
signal demo_item_retired(item_id: String, remaining_value: float)
## Emitted when a same-category sale occurs while a demo unit is active. The
## amount is the portion of the sale price attributable to the demo buff.
signal demo_contribution_recorded(amount: float)

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
## Emitted by ProgressionSystem alongside milestone_completed; carries only the
## ID for lightweight listeners.
signal milestone_reached(milestone_id: StringName)
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
## Emitted when the active tutorial context swaps to the store the player just
## entered. `context_id` is the StoreDefinition.tutorial_context_id;
## `first_step_text` is the localized prompt for the first step of that context.
signal tutorial_context_entered(
	store_id: StringName, context_id: StringName, first_step_text: String
)
## Emitted when leaving a store clears the active tutorial context.
signal tutorial_context_cleared()

# ── Onboarding ───────────────────────────────────────────────────────────────
signal onboarding_hint_shown(hint_id: StringName, message: String, position_hint: String)
signal onboarding_disabled()

# ── Regulars Log ──────────────────────────────────────────────────────────────
## Emitted when a customer's visit count first reaches the recognition threshold.
signal regular_recognized(customer_id: StringName, regular_name: String, visit_count: int)
## Emitted when a regulars-log thread advances to a new phase (not the final phase).
signal thread_advanced(thread_id: String, customer_id: StringName, new_phase: int)
## Emitted when any narrative thread closes. resolution_type is "resolved"
## (player completed the deliberate action) or "non_resolved" (timeout / passive path).
signal thread_resolved(thread_id: String, resolution_type: String)

# ── Ambient Moments ──────────────────────────────────────────────────────────
signal mystery_item_inspected(instance_id: String)
signal odd_notification_read(notification_id: String)
signal discrepancy_noticed(day: int)
signal renovation_sounds_heard()
signal wrong_name_customer_interacted()
signal ambient_moment_queued(moment_id: StringName)
signal ambient_moment_delivered(
	moment_id: StringName,
	display_type: StringName,
	flavor_text: String,
	audio_cue_id: StringName,
)
signal ambient_moment_cancelled(moment_id: StringName, reason: StringName)
## Emitted when a moment card becomes visible in the tray.
signal moment_displayed(moment_id: StringName, flavor_text: String, duration_seconds: float)
## Emitted when a moment card's display duration expires and it is dismissed.
signal moment_expired(moment_id: StringName)
## Emitted when all active moment slots are empty and the waiting queue is also empty.
signal moment_queue_empty()

# ── 30-Day Arc ────────────────────────────────────────────────────────────────
## Emitted by DayManager the first time a day-threshold unlock is reached.
## unlock_id matches an entry in arc_unlocks.json; fires exactly once per run.
signal arc_unlock_triggered(unlock_id: String, day: int)
## Emitted by DayManager after day acknowledgement when win/loss is determined.
## outcome: 'win' | 'loss'. stats_dict keys: outcome, final_cash (float),
## days_survived (int), items_sold_per_store (Dictionary), endings_unlocked (Array).
signal game_ended(outcome: String, stats_dict: Dictionary)
## Emitted by EconomySystem on days that are multiples of 30 (30, 60, 90…).
## total_amount is the sum deducted across all owned stores for the month.
signal monthly_rent_posted(day: int, total_amount: float)
## Emitted by EconomySystem on day 90 and every 90 days thereafter.
## Triggers the quarterly lease review event (rent-increase risk).
signal quarterly_lease_review(day: int)

# ── Endings ───────────────────────────────────────────────────────────────────
signal ending_requested(trigger_type: String)
signal ending_stats_snapshot_ready(stats: Dictionary)
signal ending_triggered(ending_id: StringName, final_stats: Dictionary)
signal ending_dismissed()

# ── Performance Reports ───────────────────────────────────────────────────────
signal performance_report_ready(report: PerformanceReport)
## Emitted by EconomySystem at end of each day with the day's financial totals.
signal daily_financials_snapshot(revenue: float, expenses: float, net: float)
## Emitted whenever a customer interaction resolves (sale, return accepted,
## hold honored, trade-in accepted, walkout). outcome is one of
## "satisfied" or "unsatisfied" — accumulated daily by PerformanceReportSystem
## to compute customer_satisfaction.
signal customer_resolution_logged(outcome: String)
## Emitted whenever the player makes a mistake during the day (overcharge,
## wrong item, failed restocking, transaction reversal). Accumulated daily
## by PerformanceReportSystem; reset at day_started.
signal player_mistake_recorded(mistake_type: String, context: String)
## Emitted by narrative systems when a hidden-thread consequence should be
## surfaced in the closing summary. The most recent value wins for the day.
signal hidden_thread_consequence_triggered(text: String)
## Emitted by InventoryDiscrepancyChecker (or the closing checklist) per
## flagged discrepancy. Accumulated daily; reset at day_started.
signal inventory_discrepancy_flagged(
	item_id: String, expected: int, actual: int
)
## Emitted by DayCycleController when the closing checklist completes (or is
## skipped) so listeners may proceed to the day-summary stage.
signal closing_checklist_completed(day: int)

# ── Save and Load ─────────────────────────────────────────────────────────────
signal save_load_failed(slot: int, reason: String)

# ── Player ────────────────────────────────────────────────────────────────────
signal player_interacted(target: Node)
signal interactable_interacted(target: Interactable, type: int)
signal interactable_right_clicked(target: Interactable, type: int)
signal interactable_focused(action_label: String)
## Emitted when the InteractionRay focuses an Interactable whose
## `can_interact()` returns false. `reason` is the `get_disabled_reason()`
## text — may be empty when the override returns "". Listeners (HUD, hint
## banner) render this without an E-key affordance and with a visually
## muted treatment, distinguishing it from the active focus signal.
signal interactable_focused_disabled(reason: String)
signal interactable_unfocused()
## Emitted by NavZoneInteractable when clicked or triggered by keyboard shortcut.
## PlayerController subscribes to snap _pivot to zone_position instantly.
signal nav_zone_selected(zone_position: Vector3)
## Scoped hover and click events tagged with the interactable's stable id and
## its owning store_id. Listeners should prefer these over the target-reference
## signals above when they need to reason about *which* interactable in *which*
## store fired — no global fallback handler exists.
signal interactable_hovered(
	interactable_id: StringName, store_id: StringName, label: String
)
signal interactable_clicked(
	interactable_id: StringName, store_id: StringName
)

# ── UI ────────────────────────────────────────────────────────────────────────
## Emitted when a hub store card should be highlighted (e.g. from objective routing).
signal hub_store_highlighted(store_id: StringName)
signal toggle_milestones_panel()
signal toggle_staff_panel()
signal toggle_refurb_queue_panel()
## Opens/closes the hub-accessible Completion Tracker panel.
signal toggle_completion_tracker_panel()
signal notification_requested(message: String)
## Emitted for critical player-action messages that must display even during active tutorial steps.
signal critical_notification_requested(message: String)
## Emitted by any system requesting a non-blocking player notification.
signal toast_requested(message: String, category: StringName, duration: float)
signal panel_opened(panel_name: String)
signal panel_closed(panel_name: String)
## Emitted by ObjectiveDirector whenever the three-slot objective display should update.
## payload keys: text (String), action (String), key (String).
## When payload contains hidden: true the rail should conceal itself.
signal objective_changed(payload: Dictionary)
## Four-slot variant of objective_changed.
## payload keys: current_objective, next_action, input_hint, optional_hint (all String).
## hidden: true instructs the rail to conceal itself.
signal objective_updated(payload: Dictionary)
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

# ── Platform (Console / Handheld Market) ──────────────────────────────────────
## Emitted by PlatformSystem the day units_in_stock first drops below
## shortage_threshold for the platform.
signal platform_shortage_started(platform_id: StringName)
## Emitted by PlatformSystem when a previously-shortage platform's stock
## recovers to or above shortage_threshold.
signal platform_shortage_ended(platform_id: StringName)
## Emitted by PlatformSystem when hype_level crosses one of the named tiers
## (1=warming, 2=hot, 3=mania). tier is monotonic per shortage spell — it only
## fires on upward crossings, not on hype decay.
signal platform_hype_threshold_crossed(platform_id: StringName, tier: int)
## Emitted by PlatformSystem after a successful restock event credits qty units
## to a platform's stock.
signal platform_restock_received(platform_id: StringName, qty: int)

# ── Employment ────────────────────────────────────────────────────────────────
## Emitted by EmploymentSystem when a new employment relationship begins
## (start of season or new hire). Listeners initialize trust/approval HUDs.
signal employment_started(store_id: StringName, season_number: int)
## Emitted at season end or immediate firing. outcome is one of
## "active", "probation", "at_risk", "fired", "retained".
signal employment_ended(outcome: StringName)
## Emitted by EmploymentSystem after an employee_trust mutation. delta is the
## clamped change applied; reason is a short human-readable cause.
signal trust_changed(delta: float, reason: String)
## Emitted by EmploymentSystem after a manager_approval mutation.
signal manager_approval_changed(delta: float, reason: String)
## Emitted when EmploymentSystem credits the player for a worked shift.
signal wage_issued(amount: float)
## Emitted when a manager assigns a new task to the player.
signal task_assigned(task_id: StringName)
## Emitted when the player completes (or auto-resolves) an assigned task.
signal task_completed(task_id: StringName)

# ── Shift / Clock ─────────────────────────────────────────────────────────────
## Emitted by ShiftSystem when the player clocks in (manual or auto-fallback).
## timestamp is the in-game minute of day; late is true when auto-clock-in
## fired at the 08:55 fallback boundary.
signal shift_started(store_id: StringName, timestamp: float, late: bool)
## Emitted by ShiftSystem when the player clocks out. hours_worked is computed
## from the in-game minutes between clock-in and clock-out.
signal shift_ended(store_id: StringName, hours_worked: float)
## Emitted by ShiftSystem when a late-arrival or missing-clock-out event must
## raise a manager-side note. Consumed by the manager-relationship layer to
## queue a warning memo.
signal manager_warning_note_requested(reason: String)

# ── Midday Events ────────────────────────────────────────────────────────────
## Fired by MiddayEventSystem when a beat triggers; carries the full beat
## Dictionary (id, title, body, choices). Listeners present a decision card and
## must respond by emitting midday_event_resolved.
signal midday_event_fired(beat: Dictionary)
## Emitted by the decision card UI after the player selects a choice. choice_index
## is the position in beat.choices that was chosen.
signal midday_event_resolved(beat_id: StringName, choice_index: int)


# ── Store Artifact Interactables ─────────────────────────────────────────────
## Emitted by RetroGames when the player examines the front-counter Delivery
## Manifest interactable. Hidden Thread tier-1 trigger plus a pre-open ritual
## anchor for the morning beat.
signal delivery_manifest_examined(store_id: StringName, day: int)
## Emitted by RetroGames when the player flags a SKU mismatch on the back-room
## inventory shelf. Idempotent per (store_id, item_id) per day — repeat presses
## on the same row do not emit again. Hidden Thread tier-1 trigger.
signal inventory_variance_noted(
	store_id: StringName, item_id: StringName, expected: int, actual: int
)


# ── Hold List / Reservation ──────────────────────────────────────────────────
## Emitted by RetroGames when a hold slip is added to the store-local HoldList.
## slip_id is the canonical "HOLD-####" identifier; item_id and customer_name
## carry the slip metadata so listeners can render toasts or update the
## terminal without re-reading the slip from the list.
signal hold_added(
	store_id: StringName,
	slip_id: String,
	item_id: StringName,
	customer_name: String,
)
## Emitted by RetroGames when a slip is fulfilled (terminal action or via the
## conflict resolution flow). reason is "manual", "earliest_expiry", or
## "manager_escalation".
signal hold_fulfilled(
	store_id: StringName, slip_id: String, item_id: StringName, reason: String
)
## Emitted by RetroGames at day_started for each slip whose expiry_day has
## passed. Listeners (visualization, hidden thread system) consume this to
## crumple the physical slip prop and re-spawn it near the register.
signal hold_expired(
	store_id: StringName, slip_id: String, item_id: StringName
)
## Emitted by RetroGames when a hold request collides with an existing active
## slip (same serial + different name OR same name + different serial).
## new_slip_id and existing_slip_id reference the two HOLD-#### records;
## both are flagged in the HoldList so the terminal can render a diff view.
signal hold_duplicate_detected(
	store_id: StringName,
	new_slip_id: String,
	existing_slip_id: String,
	conflict_field: StringName,
)
## Emitted by RetroGames when a slip is created with requestor_tier SHADY or
## ANONYMOUS. Hidden-thread listeners consume this as a Tier 1 trigger.
signal hold_shady_request_received(
	store_id: StringName,
	slip_id: String,
	item_id: StringName,
	requestor_tier: int,
)
## Emitted by RetroGames when the player resolves a Fulfillment Conflict by
## bypassing all competing holds and giving the unit to a walk-in customer.
## Hidden-thread listeners consume this as a Tier 2 trigger.
## disputed_slip_ids is the list of HOLD-#### records transitioned to DISPUTED.
signal hold_conflict_bypassed(
	store_id: StringName, item_id: StringName, disputed_slip_ids: Array
)
## Emitted when the player resolves a hold-vs-walk-in conflict in the embedded
## tutorial. honored is true when the original hold slip wins the unit, false
## when the walk-in offer is accepted. Fires on either resolution so tutorial
## progression is non-blocking.
signal hold_decision_made(item_id: StringName, honored: bool)


# ── Returns and Exchanges ────────────────────────────────────────────────────
## Emitted by ReturnsSystem when the angry-return decision flow opens for the
## player. Listeners (HUD, telemetry) can pre-populate context. customer_id
## carries the StringName id of the returning NPC; reason is the defect label
## (e.g. "scratched_disc", "wrong_platform").
signal return_initiated(
	customer_id: StringName, item_id: StringName, reason: String
)
## Emitted by ReturnsSystem when the player accepts a return. resolution_type is
## one of "refund" or "exchange" so listeners can branch on whether cash moved.
signal return_accepted(
	customer_id: StringName, item_id: StringName, resolution_type: String
)
## Emitted by ReturnsSystem when the player denies a return outright. Listeners
## may bump unhappy-customer telemetry or trigger reputation penalties.
signal return_denied(customer_id: StringName, item_id: StringName)


# ── Trade-In Intake ──────────────────────────────────────────────────────────
## Emitted by TradeInPanel when a customer trade-in interaction begins.
signal trade_in_initiated(customer_id: String)
## Emitted by TradeInPanel after the player appraises a condition and the
## valuation formula produces an offer.
signal trade_in_offer_made(
	customer_id: String,
	item_def_id: String,
	condition: String,
	offer_value: float,
)
## Emitted by TradeInPanel when the player confirms the offer to the customer.
signal trade_in_accepted(
	customer_id: String, instance_id: String, credit_value: float
)
## Emitted by TradeInPanel when the player declines or silently cancels the
## interaction. Carries the customer id so listeners can route the customer
## back to a normal exit.
signal trade_in_rejected(customer_id: String)
## Emitted by TradeInPanel after the new ItemInstance is created and added to
## the backroom inventory.
signal trade_in_completed(customer_id: String, instance_id: String)
## Emitted when the player confirms a condition grade for a trade-in item.
## Fires for any chosen grade (not just the "correct" one) so the embedded
## tutorial advances on player engagement, not on accuracy.
signal trade_in_condition_graded(item_id: StringName, grade: String)
## Emitted when the player taps "Confirm Offer" on the trade-in buyback UI.
## offered_price is the depreciated value the player accepted. Gates the
## embedded tutorial's SPORTS_DEPRECIATION beat.
signal trade_in_price_confirmed(item_id: StringName, offered_price: float)


# ── Hidden Thread ────────────────────────────────────────────────────────────
## Emitted by HiddenThreadSystem on every Tier 1, Tier 2, or Tier 3 trigger.
## tier is 1, 2, or 3; context is an open dictionary of trigger metadata
## (e.g. {"trigger_id": &"delivery_manifest_examined", "store_id": &"retro_games"}).
signal hidden_thread_interaction_fired(tier: int, context: Dictionary)
## Emitted when the player acknowledges a hidden-thread clue from the journal
## affordance. Distinct from hidden_thread_interacted, which the trigger system
## emits on every Tier 1/2/3 awareness bump — this signal only fires from the
## player-side journal acknowledgement and gates the embedded tutorial's
## HIDDEN_THREAD beat.
signal hidden_clue_acknowledged(clue_id: StringName)
## Emitted by HiddenThreadSystem when awareness_score crosses a tier boundary.
## Boundaries: 0 → 1 at score 25, 1 → 2 at score 50, 2 → 3 at score 75.
signal hidden_awareness_tier_changed(old_tier: int, new_tier: int)
## Emitted by HiddenThreadSystem at day_ended when an artifact passes its
## awareness threshold and is added to the discovered_artifacts catalog.
signal hidden_artifact_spawned(artifact_id: StringName)
## Emitted by HiddenThreadSystem on every Tier 1/2/3 trigger so the ending
## evaluator (ISSUE-017) can shadow stats without coupling to internal state.
## thread_id identifies the trigger (e.g. &"delivery_manifest_examined",
## &"unsatisfied_streak", &"delivery_manifest_carbon").
signal hidden_thread_interacted(thread_id: StringName)
## Emitted by StoreCustomizationSystem (ISSUE-018) when the active featured
## display lands on the new-console-hype category while VecForce HD has a
## suspicious active hold. HiddenThreadSystem consumes this as a Tier 1 trigger.
signal display_exposes_weird_inventory(store_id: StringName)


# ── Manager Relationship ─────────────────────────────────────────────────────
## Emitted by ManagerRelationshipManager at day_started after note selection.
## note_id matches an entry id in manager_notes.json so listeners can render or
## telemetry-tag the specific note. allow_auto_dismiss is false on Day 1 and on
## unlock-override mornings so the panel must be dismissed manually.
signal manager_note_shown(
	note_id: String, body_text: String, allow_auto_dismiss: bool
)
## Emitted by MorningNotePanel when the player explicitly dismisses the note
## (E-key, click on the panel, or auto-dismiss timer). note_id matches the id
## passed to manager_note_shown so listeners can scope reactions to a specific
## note.
signal manager_note_dismissed(note_id: String)
## Emitted by ManagerRelationshipManager after every manager_trust mutation.
## delta is the post-clamp change applied; reason is a short cause label.
signal manager_trust_changed(delta: float, reason: String)
## Emitted when a manager-side confrontation is triggered (low trust or a
## major violation). Listeners may render a confrontation panel or beat.
signal manager_confrontation_triggered(reason: String)
## Emitted by ManagerRelationshipManager at day_closed after the metric-driven
## end-of-day comment has been selected. comment_id matches an entry id in
## manager_notes.json under end_of_day_comments[tier][condition]; body is the
## display string DaySummary renders attributed to Vic. Fires before
## DaySummary.show_summary() so the panel can cache the text in advance.
signal manager_end_of_day_comment(comment_id: String, body: String)

var _latest_day_end_summary: Dictionary = {}


func _ready() -> void:
	day_started.connect(_on_day_started)


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


# ── Phase 1 emit_* wrappers ───────────────────────────────────────────────────
# Thin type-safe wrappers around the Phase 1 signals. No logic — the wrappers
# exist so callers get a method signature GDScript can typecheck, rather than
# passing arbitrary args to `emit_signal("…", …)`.

func emit_store_ready(store_id: StringName) -> void:
	store_ready.emit(store_id)


func emit_store_failed(store_id: StringName, reason: String) -> void:
	store_failed.emit(store_id, reason)


func emit_scene_ready(scene_name: StringName) -> void:
	scene_ready.emit(scene_name)


func emit_input_focus_changed(owner: StringName) -> void:
	input_focus_changed.emit(owner)


func emit_camera_authority_changed(camera_path: NodePath) -> void:
	camera_authority_changed.emit(camera_path)


func emit_stocking_cursor_active(item_category: StringName) -> void:
	stocking_cursor_active.emit(item_category)


func emit_stocking_cursor_inactive() -> void:
	stocking_cursor_inactive.emit()
