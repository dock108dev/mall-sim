## Tests for ObjectiveDirector: signal connections, payload emission, and auto-hide logic.
extends GutTest


func _make_director() -> ObjectiveDirector:
	var director: ObjectiveDirector = preload(
		"res://game/autoload/objective_director.gd"
	).new() as ObjectiveDirector
	add_child_autofree(director)
	return director


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


func test_day_started_day1_objective_text() -> void:
	var director := _make_director()
	var received: Array[Dictionary] = []
	EventBus.objective_changed.connect(
		func(p: Dictionary) -> void: received.append(p)
	)
	EventBus.day_started.emit(1)
	assert_eq(
		received[0].get("objective", ""),
		"Open the store and make your first sale"
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
	watch_signals(EventBus)
	EventBus.day_started.emit(1)
	EventBus.store_entered.emit(&"retro_games")
	assert_signal_emitted_with_parameters(
		EventBus, "objective_changed", [{"objective": "Open the store and make your first sale", "action": "Stock items on shelves", "key": "E"}]
	)


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
	var director := _make_director()
	EventBus.day_started.emit(1)
	var count: int = 0
	EventBus.first_sale_completed.connect(
		func(_sid: StringName, _iid: String, _p: float) -> void: count += 1
	)
	EventBus.item_sold.emit("item_001", 20.0, "retro")
	EventBus.item_sold.emit("item_002", 15.0, "retro")
	assert_eq(count, 1, "first_sale_completed must emit exactly once per day cycle")


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
	Settings.show_objective_rail = true
