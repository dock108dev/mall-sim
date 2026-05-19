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
## the player dismisses Vic's morning note to release the chain at TALK_TO_CUSTOMER.
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


func test_note_dismiss_advances_day1_chain_to_talk_to_customer() -> void:
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	EventBus.day_started.emit(1)
	EventBus.manager_note_dismissed.emit("")
	assert_eq(
		received[received.size() - 1].get("objective", ""),
		"Talk to the customer at the register checkout.",
		"Note dismissal must advance the rail to step 1 (talk to customer)"
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
	assert_eq(payload.get("objective", ""), "Talk to the customer at the register checkout.")
	assert_eq(payload.get("action", ""), "Press E at the counter")
	assert_eq(payload.get("key", ""), "E")


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

func test_day1_initial_step_is_talk_to_customer_after_note_dismiss() -> void:
	var director := _make_director()
	_start_day1_after_note_dismiss()
	assert_eq(
		ObjectiveDirector._day1_step_index,
		ObjectiveDirector.DAY1_STEP_TALK_TO_CUSTOMER,
		"Day 1 chain must arm at step 1 (talk to customer) after note dismiss"
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
	# Step 0 → 1: player interacts with the customer at the counter.
	EventBus.customer_interacted.emit(null)
	assert_eq(received[received.size() - 1].get("text", ""),
		"Check the back room delivery.",
		"customer_interacted must advance to step 2 (back room inventory)")
	# Step 1 → 2: player enters placement mode by picking up the back-room box.
	EventBus.placement_mode_entered.emit()
	assert_eq(received[received.size() - 1].get("text", ""),
		"Stock the Retro Games shelves.",
		"placement_mode_entered must advance to step 3 (stock shelf)")
	# Step 2 → 3: the item lands on the restock shelf.
	EventBus.item_stocked.emit("item_001", "shelf_a")
	assert_eq(received[received.size() - 1].get("text", ""),
		"Close the day at the register.",
		"item_stocked must advance to step 4 (close day)")
	assert_eq(
		ObjectiveDirector._day1_step_index,
		ObjectiveDirector.DAY1_STEP_CLOSE_DAY,
		"Director must terminate at the close-day step"
	)
	assert_eq(
		received[received.size() - 1].get("key", ""),
		"F4",
		"Close-day step must publish the F4 hint badge"
	)


func test_day1_chain_ignores_out_of_order_signals() -> void:
	var director := _make_director()
	_start_day1_after_note_dismiss()
	# item_stocked fired before the earlier steps must not skip ahead.
	EventBus.item_stocked.emit("item_001", "shelf_a")
	assert_eq(
		ObjectiveDirector._day1_step_index,
		ObjectiveDirector.DAY1_STEP_TALK_TO_CUSTOMER,
		"Out-of-order item_stocked must not skip past step 1"
	)


func test_day1_chain_ignores_duplicate_triggers() -> void:
	var director := _make_director()
	_start_day1_after_note_dismiss()
	EventBus.customer_interacted.emit(null)
	assert_eq(
		ObjectiveDirector._day1_step_index,
		ObjectiveDirector.DAY1_STEP_BACK_ROOM_INVENTORY,
		"First customer_interacted must advance to step 2"
	)
	# A duplicate must not jump again.
	EventBus.customer_interacted.emit(null)
	assert_eq(
		ObjectiveDirector._day1_step_index,
		ObjectiveDirector.DAY1_STEP_BACK_ROOM_INVENTORY,
		"Duplicate customer_interacted must not advance further"
	)


func test_day1_chain_does_not_run_on_other_days() -> void:
	var director := _make_director()
	EventBus.day_started.emit(2)
	assert_eq(
		ObjectiveDirector._day1_step_index, -1,
		"Day 2 must not initialize the Day 1 step chain"
	)
	EventBus.customer_interacted.emit(null)
	assert_eq(
		ObjectiveDirector._day1_step_index, -1,
		"Day 2 customer_interacted must leave the chain dormant"
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
	EventBus.customer_interacted.emit(null)
	var step_after_advance: int = director._day1_step_index
	# A second dismiss while the chain is mid-flight must not roll the chain
	# back to TALK_TO_CUSTOMER or re-arm the gate.
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


# ── Emit dedup ────────────────────────────────────────────────────────────────

func _count_director_emissions(received: Array[Dictionary]) -> int:
	# A `_make_director()` test instance and the production autoload both
	# subscribe to EventBus, so a single director-action emits twice. Tests
	# in this section assert relative counts (before/after), so the inflated
	# baseline is consistent across the assertions.
	return received.size()


func test_store_entered_does_not_re_emit_identical_pre_step_payload() -> void:
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	EventBus.day_started.emit(1)
	var baseline: int = _count_director_emissions(received)
	# store_entered while still on the pre-chain emits the same pre-step
	# payload _emit_current already produced for day_started; the dedup hash
	# must suppress it.
	EventBus.store_entered.emit(&"retro_games")
	assert_eq(
		_count_director_emissions(received), baseline,
		"store_entered with an identical payload must be deduped"
	)


func test_store_entered_does_not_re_emit_identical_step_payload() -> void:
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	_start_day1_after_note_dismiss()
	var baseline: int = _count_director_emissions(received)
	EventBus.store_entered.emit(&"retro_games")
	assert_eq(
		_count_director_emissions(received), baseline,
		"store_entered must not re-emit an unchanged Day 1 step payload"
	)


func test_out_of_order_item_stocked_does_not_re_emit() -> void:
	# _on_item_stocked unconditionally calls _emit_current() even when
	# _advance_day1_step_if was a no-op. With dedup, the unchanged payload
	# is suppressed so the rail's reveal tween does not retrigger.
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	_start_day1_after_note_dismiss()
	var baseline: int = _count_director_emissions(received)
	EventBus.item_stocked.emit("item_001", "shelf_a")
	assert_eq(
		_count_director_emissions(received), baseline,
		"item_stocked at step 0 must not re-emit the identical step 0 payload"
	)


func test_day_started_resets_dedup_so_first_emit_always_fires() -> void:
	# A new day whose content happens to repeat the previous payload must
	# still emit — the reset on day_started is the safety valve that keeps
	# the rail from staying silent across day boundaries.
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	EventBus.day_started.emit(99)
	var baseline: int = _count_director_emissions(received)
	# Re-firing day_started for an unknown day still resolves to the same
	# default-text payload, but day_started must always re-arm the dedup so
	# the rail can pick up the boundary even when content is identical.
	EventBus.day_started.emit(99)
	assert_gt(
		_count_director_emissions(received), baseline,
		"day_started must reset _last_payload_hash so the first emit always fires"
	)


func test_chain_step_change_breaks_dedup_and_re_emits() -> void:
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	_start_day1_after_note_dismiss()
	var baseline: int = _count_director_emissions(received)
	EventBus.customer_interacted.emit(null)
	assert_gt(
		_count_director_emissions(received), baseline,
		"A real chain advance must produce a fresh emission past the dedup gate"
	)
