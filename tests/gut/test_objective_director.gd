## Tests for ObjectiveDirector: signal connections, payload emission, and auto-hide logic.
extends GutTest


func _make_director() -> Node:
	# Sync the autoload's _sold flag with any test-local instance so
	# first_sale_completed still fires exactly once across both listeners.
	ObjectiveDirector._sold = false
	ObjectiveDirector._stocked = false
	ObjectiveDirector._current_day = 0
	ObjectiveDirector._loop_completed = false
	ObjectiveDirector._loop_completed_today = false
	ObjectiveDirector._day1_step_index = -1
	ObjectiveDirector._waiting_for_note_dismiss = false
	var director: Node = preload(
		"res://game/autoload/objective_director.gd"
	).new() as Node
	add_child_autofree(director)
	return director


## Drives the production handshake: day_started fires the pre-chain gate, then
## the player dismisses Vic's morning note to release the chain at OPEN_INVENTORY.
## Tests that exercise step-chain advancement go through this helper.
func _start_day1_after_note_dismiss() -> void:
	EventBus.day_started.emit(1)
	EventBus.manager_note_dismissed.emit("")


# ── Signal connection: day_started ────────────────────────────────────────────

func test_day_started_emits_objective_changed() -> void:
	var director := _make_director()
	watch_signals(EventBus)
	EventBus.day_started.emit(1)
	assert_signal_emitted(EventBus, "objective_changed")


func test_day_started_payload_has_objective_key() -> void:
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	EventBus.day_started.emit(1)
	assert_true(received.size() > 0)
	assert_true(received[0].has("objective"), "payload must have 'objective' key")


func test_day_started_day1_pre_chain_surfaces_read_vic_note() -> void:
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	EventBus.day_started.emit(1)
	assert_eq(
		received[0].get("objective", ""),
		"Read Vic's morning note",
		"Day 1 must surface the pre-chain READ_VIC_NOTE prompt before any step"
	)


func test_note_dismiss_advances_day1_chain_to_open_inventory() -> void:
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	EventBus.day_started.emit(1)
	EventBus.manager_note_dismissed.emit("")
	assert_eq(
		received[received.size() - 1].get("objective", ""),
		"Open your inventory",
		"Note dismissal must advance the rail to step 1 (open inventory)"
	)


func test_day_started_unknown_day_falls_back_to_default() -> void:
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	EventBus.day_started.emit(99)
	assert_eq(received[0].get("objective", ""), "Keep the store running")


# ── Signal connection: store_entered ──────────────────────────────────────────

func test_store_entered_emits_objective_changed() -> void:
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	_start_day1_after_note_dismiss()
	EventBus.store_entered.emit(&"retro_games")
	assert_gt(received.size(), 0, "objective_changed must fire")
	var payload: Dictionary = received[received.size() - 1]
	assert_eq(payload.get("objective", ""), "Open your inventory")
	assert_eq(payload.get("action", ""), "Press I to open the inventory panel")
	assert_eq(payload.get("key", ""), "I")


# ── Signal connection: item_stocked ───────────────────────────────────────────

func test_item_stocked_emits_objective_changed() -> void:
	var director := _make_director()
	watch_signals(EventBus)
	EventBus.day_started.emit(1)
	EventBus.item_stocked.emit("item_001", "shelf_a")
	assert_signal_emitted(EventBus, "objective_changed")


# ── Signal connection: item_sold → first_sale_completed ───────────────────────

func test_first_item_sold_emits_first_sale_completed() -> void:
	var director := _make_director()
	watch_signals(EventBus)
	EventBus.day_started.emit(1)
	EventBus.item_sold.emit("item_001", 20.0, "retro")
	assert_signal_emitted(EventBus, "first_sale_completed")


func test_second_item_sold_does_not_re_emit_first_sale_completed() -> void:
	var autoload_handler: Callable = ObjectiveDirector._on_item_sold
	if EventBus.item_sold.is_connected(autoload_handler):
		EventBus.item_sold.disconnect(autoload_handler)
	var director := _make_director()
	EventBus.day_started.emit(1)
	var count: Array = [0]
	EventBus.first_sale_completed.connect(
		func(_sid: StringName, _iid: String, _p: float) -> void: count[0] += 1
	)
	EventBus.item_sold.emit("item_001", 20.0, "retro")
	EventBus.item_sold.emit("item_002", 15.0, "retro")
	assert_eq(count[0], 1, "first_sale_completed must emit exactly once per day cycle")
	if not EventBus.item_sold.is_connected(autoload_handler):
		EventBus.item_sold.connect(autoload_handler)


# ── Day 1 chain: signal-driven step advancement ──────────────────────────────

func test_day1_initial_step_is_open_inventory_after_note_dismiss() -> void:
	var director := _make_director()
	_start_day1_after_note_dismiss()
	assert_eq(
		ObjectiveDirector._day1_step_index,
		ObjectiveDirector.DAY1_STEP_OPEN_INVENTORY,
		"Day 1 chain must arm at step 1 once the morning note is dismissed"
	)


func test_day1_chain_is_gated_until_note_dismissed() -> void:
	var director := _make_director()
	EventBus.day_started.emit(1)
	assert_eq(
		ObjectiveDirector._day1_step_index, -1,
		"Day 1 chain must not arm until the morning note is dismissed"
	)
	assert_true(
		ObjectiveDirector._waiting_for_note_dismiss,
		"day_started(1) must enter the pre-chain note-wait state"
	)


func test_day1_chain_advances_through_each_signal_in_order() -> void:
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	_start_day1_after_note_dismiss()
	# Step 1 → 2: opening the inventory panel.
	EventBus.panel_opened.emit("inventory")
	assert_eq(received[received.size() - 1].get("text", ""),
		"Select an item from the Backroom",
		"panel_opened(inventory) must advance to step 2 (select item)")
	# Step 2 → 3: the player enters placement mode.
	EventBus.placement_mode_entered.emit()
	assert_eq(received[received.size() - 1].get("text", ""),
		"Stock the item on the Used Shelves",
		"placement_mode_entered must advance to step 3 (stock item)")
	# Step 3 → 4: the item lands on a shelf.
	EventBus.item_stocked.emit("item_001", "shelf_a")
	assert_eq(received[received.size() - 1].get("text", ""),
		"Wait for a customer to arrive",
		"item_stocked must advance to step 4 (wait for customer)")
	# Step 4 → 5: a customer FSM entered BROWSING.
	EventBus.customer_state_changed.emit(null, Customer.State.BROWSING)
	assert_eq(received[received.size() - 1].get("text", ""),
		"A customer is browsing your shelves",
		"customer_state_changed BROWSING must advance to step 5")
	# Step 5 → 6: the customer reaches the register.
	EventBus.customer_ready_to_purchase.emit({})
	assert_eq(received[received.size() - 1].get("text", ""),
		"Customer is heading to checkout",
		"customer_ready_to_purchase must advance to step 6")
	# Step 6 → 7: the sale closes.
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_001", 20.0, &"customer_1"
	)
	assert_eq(received[received.size() - 1].get("text", ""),
		"Sale complete!",
		"customer_purchased must advance to step 7 (sale complete)")


func test_day1_close_day_step_reached_after_sale_complete_timer() -> void:
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	_start_day1_after_note_dismiss()
	EventBus.panel_opened.emit("inventory")
	EventBus.placement_mode_entered.emit()
	EventBus.item_stocked.emit("item_001", "shelf_a")
	EventBus.customer_state_changed.emit(null, Customer.State.BROWSING)
	EventBus.customer_ready_to_purchase.emit({})
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_001", 20.0, &"customer_1"
	)
	# Skip past the sale-complete display window. Both the test director and
	# the production autoload reach step 6 (SALE_COMPLETE) on customer_purchased
	# above; advance both so the rail and any production listeners see the
	# close-day prompt.
	director._advance_to_close_day_step()
	ObjectiveDirector._advance_to_close_day_step()
	var final_payload: Dictionary = received[received.size() - 1]
	assert_eq(
		final_payload.get("text", ""),
		"Close the day when ready",
		"After step 7, rail must surface the close-day prompt"
	)
	assert_eq(
		final_payload.get("key", ""),
		"F4",
		"Close-day step must publish the F4 hint badge"
	)
	assert_eq(
		director._day1_step_index,
		ObjectiveDirector.DAY1_STEP_CLOSE_DAY,
		"Director must terminate at the close-day step"
	)


func test_day1_chain_ignores_out_of_order_signals() -> void:
	var director := _make_director()
	_start_day1_after_note_dismiss()
	# customer_purchased fired before any earlier step must not skip ahead.
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_001", 20.0, &"customer_1"
	)
	assert_eq(
		ObjectiveDirector._day1_step_index,
		ObjectiveDirector.DAY1_STEP_OPEN_INVENTORY,
		"Out-of-order customer_purchased must not skip past step 1"
	)


func test_day1_chain_ignores_duplicate_triggers() -> void:
	var director := _make_director()
	_start_day1_after_note_dismiss()
	EventBus.panel_opened.emit("inventory")
	assert_eq(
		ObjectiveDirector._day1_step_index,
		ObjectiveDirector.DAY1_STEP_SELECT_ITEM,
		"First panel_opened must advance to step 2"
	)
	# A duplicate must not jump again.
	EventBus.panel_opened.emit("inventory")
	assert_eq(
		ObjectiveDirector._day1_step_index,
		ObjectiveDirector.DAY1_STEP_SELECT_ITEM,
		"Duplicate panel_opened must not advance further"
	)


func test_day1_customer_state_changed_ignores_non_browsing_states() -> void:
	var director := _make_director()
	_start_day1_after_note_dismiss()
	EventBus.panel_opened.emit("inventory")
	EventBus.placement_mode_entered.emit()
	EventBus.item_stocked.emit("item_001", "shelf_a")
	# ENTERING is emitted on customer.initialize before BROWSING; it must not
	# advance the chain.
	EventBus.customer_state_changed.emit(null, Customer.State.ENTERING)
	assert_eq(
		ObjectiveDirector._day1_step_index,
		ObjectiveDirector.DAY1_STEP_WAIT_FOR_CUSTOMER,
		"Non-BROWSING customer_state_changed must not advance the chain"
	)
	EventBus.customer_state_changed.emit(null, Customer.State.BROWSING)
	assert_eq(
		ObjectiveDirector._day1_step_index,
		ObjectiveDirector.DAY1_STEP_CUSTOMER_BROWSING,
		"BROWSING transition must advance to step 5"
	)


func test_day1_panel_opened_other_panels_do_not_advance() -> void:
	var director := _make_director()
	_start_day1_after_note_dismiss()
	EventBus.panel_opened.emit("staff")
	assert_eq(
		ObjectiveDirector._day1_step_index,
		ObjectiveDirector.DAY1_STEP_OPEN_INVENTORY,
		"Opening unrelated panels must not satisfy the inventory step"
	)


func test_day1_chain_does_not_run_on_other_days() -> void:
	var director := _make_director()
	EventBus.day_started.emit(2)
	assert_eq(
		ObjectiveDirector._day1_step_index, -1,
		"Day 2 must not initialize the Day 1 step chain"
	)
	EventBus.panel_opened.emit("inventory")
	assert_eq(
		ObjectiveDirector._day1_step_index, -1,
		"Day 2 panel_opened must leave the chain dormant"
	)


func test_item_sold_still_emits_first_sale_completed_with_chain_active() -> void:
	# The legacy first_sale_completed wiring must remain intact when the Day 1
	# chain is running so HUD/DayManager listeners still receive the signal.
	var autoload_handler: Callable = ObjectiveDirector._on_item_sold
	if EventBus.item_sold.is_connected(autoload_handler):
		EventBus.item_sold.disconnect(autoload_handler)
	var director := _make_director()
	EventBus.day_started.emit(1)
	watch_signals(EventBus)
	EventBus.item_sold.emit("item_001", 20.0, "retro")
	assert_signal_emitted(EventBus, "first_sale_completed")
	if not EventBus.item_sold.is_connected(autoload_handler):
		EventBus.item_sold.connect(autoload_handler)


# ── Day 1 Pass recovery: rail rolls back to wait_for_customer ─────────────────

func test_pass_at_checkout_rolls_back_day1_chain_to_wait_for_customer() -> void:
	var director := _make_director()
	_start_day1_after_note_dismiss()
	EventBus.panel_opened.emit("inventory")
	EventBus.placement_mode_entered.emit()
	EventBus.item_stocked.emit("item_001", "shelf_a")
	EventBus.customer_state_changed.emit(null, Customer.State.BROWSING)
	EventBus.customer_ready_to_purchase.emit({})
	assert_eq(
		director._day1_step_index,
		ObjectiveDirector.DAY1_STEP_CUSTOMER_AT_CHECKOUT,
		"precondition: chain must reach the at-checkout step before Pass"
	)
	EventBus.checkout_declined.emit(null)
	assert_eq(
		director._day1_step_index,
		ObjectiveDirector.DAY1_STEP_WAIT_FOR_CUSTOMER,
		"Pass at the register must roll the rail back to wait-for-customer"
	)


func test_pass_at_browsing_step_also_rolls_back_to_wait_for_customer() -> void:
	# Edge case: a panel-opened mutex on `CheckoutPanel` can fire sale_declined
	# while the customer is still BROWSING. Rollback must still land at step 3.
	var director := _make_director()
	_start_day1_after_note_dismiss()
	EventBus.panel_opened.emit("inventory")
	EventBus.placement_mode_entered.emit()
	EventBus.item_stocked.emit("item_001", "shelf_a")
	EventBus.customer_state_changed.emit(null, Customer.State.BROWSING)
	assert_eq(
		director._day1_step_index,
		ObjectiveDirector.DAY1_STEP_CUSTOMER_BROWSING,
		"precondition: chain must be on the browsing step"
	)
	EventBus.checkout_declined.emit(null)
	assert_eq(
		director._day1_step_index,
		ObjectiveDirector.DAY1_STEP_WAIT_FOR_CUSTOMER,
		"Pass during browsing must also roll back to wait-for-customer"
	)


func test_pass_after_first_sale_does_not_roll_back() -> void:
	var director := _make_director()
	_start_day1_after_note_dismiss()
	EventBus.panel_opened.emit("inventory")
	EventBus.placement_mode_entered.emit()
	EventBus.item_stocked.emit("item_001", "shelf_a")
	EventBus.customer_state_changed.emit(null, Customer.State.BROWSING)
	EventBus.customer_ready_to_purchase.emit({})
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_001", 20.0, &"customer_1"
	)
	EventBus.item_sold.emit("item_001", 20.0, "retro")
	var step_after_sale: int = director._day1_step_index
	EventBus.checkout_declined.emit(null)
	assert_eq(
		director._day1_step_index, step_after_sale,
		"Pass after first sale completed must not rewind the chain"
	)


func test_pass_outside_day1_is_a_noop() -> void:
	var director := _make_director()
	EventBus.day_started.emit(2)
	var step_before: int = director._day1_step_index
	EventBus.checkout_declined.emit(null)
	assert_eq(
		director._day1_step_index, step_before,
		"checkout_declined must not touch the step index outside Day 1"
	)


# ── Post-sale rail copy: days without a steps array still flip text ───────────

func test_day_without_post_sale_copy_keeps_default_text_after_sale() -> void:
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	EventBus.day_started.emit(2)
	EventBus.item_sold.emit("item_002", 30.0, "retro")
	var latest: Dictionary = received[received.size() - 1]
	assert_eq(
		latest.get("text", ""),
		"Find your pricing sweet spot",
		"Days without post_sale_text must keep emitting their default copy"
	)


# ── Auto-hide: loop complete + day > 3 ────────────────────────────────────────

func test_no_auto_hide_before_day_4() -> void:
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	# Complete a full loop on day 3
	EventBus.day_started.emit(3)
	EventBus.item_stocked.emit("item_a", "shelf_a")
	EventBus.item_sold.emit("item_a", 10.0, "retro")
	EventBus.day_closed.emit(3, {})
	# Day 3 objective should still emit content (not hidden)
	received.clear()
	EventBus.day_started.emit(3)
	assert_false(received.is_empty())
	assert_false(received[0].get("hidden", false), "day 3 must not trigger auto-hide")


func test_auto_hide_emitted_after_day3_loop_complete() -> void:
	var director := _make_director()
	# Complete a loop on day 1 first
	EventBus.day_started.emit(1)
	EventBus.item_stocked.emit("item_a", "shelf_a")
	EventBus.item_sold.emit("item_a", 10.0, "retro")
	EventBus.day_closed.emit(1, {})
	# Now start day 4 with loop already complete
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	EventBus.day_started.emit(4)
	assert_false(received.is_empty())
	assert_true(received[0].get("hidden", false), "day > 3 after loop must emit hidden payload")


func test_show_objective_rail_setting_overrides_auto_hide() -> void:
	var director := _make_director()
	# Complete loop
	EventBus.day_started.emit(1)
	EventBus.item_stocked.emit("item_a", "shelf_a")
	EventBus.item_sold.emit("item_a", 10.0, "retro")
	EventBus.day_closed.emit(1, {})
	# Re-enable via Settings before day 4
	Settings.show_objective_rail = true
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	EventBus.day_started.emit(4)
	# With show_objective_rail = true, should emit content not hidden
	assert_false(received.is_empty())
	assert_false(received[0].get("hidden", false), "show_objective_rail=true must override auto-hide")


func after_each() -> void:
	# Restore Settings default so tests don't bleed
	Settings.show_objective_rail = false
	ObjectiveDirector._waiting_for_note_dismiss = false


# ── Pre-chain READ_VIC_NOTE gate ──────────────────────────────────────────────

func test_pre_chain_payload_carries_pre_step_action_and_key() -> void:
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	EventBus.day_started.emit(1)
	var payload: Dictionary = received[received.size() - 1]
	assert_eq(
		payload.get("text", ""), "Read Vic's morning note",
		"Pre-chain payload must publish the read-vic-note text"
	)
	assert_eq(
		payload.get("action", ""), "Press E to dismiss the note",
		"Pre-chain payload must publish the dismiss action prompt"
	)
	assert_eq(
		payload.get("key", ""), "E",
		"Pre-chain payload must publish the E key badge"
	)


func test_note_dismissed_on_day_2_is_a_noop() -> void:
	var director := _make_director()
	EventBus.day_started.emit(2)
	var step_before: int = director._day1_step_index
	var waiting_before: bool = director._waiting_for_note_dismiss
	EventBus.manager_note_dismissed.emit("day_2_morning")
	assert_eq(
		director._day1_step_index, step_before,
		"manager_note_dismissed must not touch the step index outside Day 1"
	)
	assert_eq(
		director._waiting_for_note_dismiss, waiting_before,
		"manager_note_dismissed must not flip the gate flag outside Day 1"
	)


func test_duplicate_note_dismiss_is_a_noop() -> void:
	var director := _make_director()
	_start_day1_after_note_dismiss()
	EventBus.panel_opened.emit("inventory")
	var step_after_advance: int = director._day1_step_index
	# A second dismiss while the chain is mid-flight must not roll the chain
	# back to OPEN_INVENTORY or re-arm the gate.
	EventBus.manager_note_dismissed.emit("")
	assert_eq(
		director._day1_step_index, step_after_advance,
		"Late manager_note_dismissed must not rewind the chain"
	)
	assert_false(
		director._waiting_for_note_dismiss,
		"Late manager_note_dismissed must not re-arm the pre-chain gate"
	)


func test_store_entered_during_pre_chain_re_emits_pre_step_payload() -> void:
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	EventBus.day_started.emit(1)
	EventBus.store_entered.emit(&"retro_games")
	var payload: Dictionary = received[received.size() - 1]
	assert_eq(
		payload.get("objective", ""), "Read Vic's morning note",
		"store_entered while waiting for note dismiss must keep the rail on the pre-step"
	)
