## GUT tests for EndingEvaluatorSystem stat accumulation and ending evaluation.
extends GutTest


var _system: EndingEvaluatorSystem


func before_each() -> void:
	_system = EndingEvaluatorSystem.new()
	add_child_autofree(_system)
	_system.initialize()


func test_initialize_loads_all_endings_from_content_registry() -> void:
	assert_eq(
		_system._ending_definitions.size(),
		14,
		"EndingEvaluatorSystem should load 14 endings from ContentRegistry"
	)


func test_customer_purchased_increments_total_sales_count() -> void:
	EventBus.customer_purchased.emit(&"", &"item_a", 10.0, &"")
	EventBus.customer_purchased.emit(&"", &"item_b", 20.0, &"")
	EventBus.customer_purchased.emit(&"", &"item_c", 15.0, &"")

	assert_eq(
		_system.get_tracked_stat(&"total_sales_count"),
		3.0,
		"3 customer_purchased signals should yield total_sales_count == 3"
	)


func test_customer_purchased_accumulates_revenue() -> void:
	EventBus.customer_purchased.emit(&"", &"item_a", 10.0, &"")
	EventBus.customer_purchased.emit(&"", &"item_b", 25.5, &"")

	assert_eq(
		_system.get_tracked_stat(&"cumulative_revenue"),
		35.5,
		"Revenue should sum purchase prices"
	)


func test_customer_purchased_tracks_rare_items_sold() -> void:
	if not ContentRegistry.exists("test_rare_item"):
		ContentRegistry.register_entry(
			{
				"id": "test_rare_item",
				"name": "Test Rare Item",
				"rarity": "legendary",
			},
			"item"
		)
	EventBus.customer_purchased.emit(
		&"", &"test_rare_item", 150.0, &""
	)
	assert_eq(
		_system.get_tracked_stat(&"rare_items_sold"),
		1.0,
		"Rare or legendary item sales should increment rare_items_sold"
	)


func test_customer_left_tracks_satisfaction() -> void:
	EventBus.customer_left.emit({"satisfied": true})
	EventBus.customer_left.emit({"satisfied": true})
	EventBus.customer_left.emit({"satisfied": false})

	assert_eq(
		_system.get_tracked_stat(&"satisfied_customer_count"),
		2.0,
		"Two satisfied customers expected"
	)
	assert_eq(
		_system.get_tracked_stat(&"unsatisfied_customer_count"),
		1.0,
		"One unsatisfied customer expected"
	)


func test_satisfaction_ratio_computed() -> void:
	EventBus.customer_left.emit({"satisfied": true})
	EventBus.customer_left.emit({"satisfied": true})
	EventBus.customer_left.emit({"satisfied": false})
	EventBus.customer_left.emit({"satisfied": false})

	var stats: Dictionary = _system.get_all_tracked_stats()
	assert_eq(
		stats.get("satisfaction_ratio", 0.0),
		0.5,
		"2 satisfied / 4 total should yield 0.5 ratio"
	)


func test_day_started_increments_days_survived() -> void:
	EventBus.day_started.emit(1)
	EventBus.day_started.emit(2)
	EventBus.day_started.emit(3)

	assert_eq(
		_system.get_tracked_stat(&"days_survived"),
		3.0,
		"3 day_started signals should yield days_survived == 3"
	)


func test_store_leased_tracks_peak_and_unique() -> void:
	EventBus.store_leased.emit(0, "sports_memorabilia")
	EventBus.store_leased.emit(1, "retro_games")
	EventBus.store_leased.emit(2, "video_rental")

	assert_eq(
		_system.get_tracked_stat(&"owned_store_count_peak"),
		3.0,
		"Peak store count should be 3"
	)
	assert_eq(
		_system.get_tracked_stat(&"unique_store_types_owned"),
		3.0,
		"Unique store types should be 3"
	)


func test_money_changed_tracks_peak_and_final() -> void:
	EventBus.money_changed.emit(0.0, 500.0)
	EventBus.money_changed.emit(500.0, 1000.0)
	EventBus.money_changed.emit(1000.0, 300.0)

	assert_eq(
		_system.get_tracked_stat(&"peak_cash"),
		1000.0,
		"Peak cash should be 1000"
	)
	assert_eq(
		_system.get_tracked_stat(&"final_cash"),
		300.0,
		"Final cash should track most recent value"
	)


func test_haggle_completed_sets_never_used_false() -> void:
	assert_eq(
		_system.get_tracked_stat(&"haggle_never_used"),
		1.0,
		"haggle_never_used should start as 1.0"
	)

	EventBus.haggle_completed.emit(&"", &"item_a", 15.0, 20.0, true, 1)

	assert_eq(
		_system.get_tracked_stat(&"haggle_never_used"),
		0.0,
		"haggle_never_used should be 0 after a haggle"
	)
	assert_eq(
		_system.get_tracked_stat(&"haggle_attempts"),
		1.0,
		"haggle_attempts should be 1"
	)



func test_days_near_bankruptcy_tracked() -> void:
	EventBus.money_changed.emit(0.0, 50.0)
	EventBus.day_ended.emit(1)
	EventBus.day_ended.emit(2)

	assert_eq(
		_system.get_tracked_stat(&"days_near_bankruptcy"),
		2.0,
		"Two days with cash < 100 should count"
	)


func test_random_event_resolved_tracks_survived_only() -> void:
	EventBus.random_event_resolved.emit(&"market_crash", &"survived")
	EventBus.random_event_resolved.emit(&"market_crash", &"failed")

	assert_eq(
		_system.get_tracked_stat(&"market_events_survived"),
		1.0,
		"Only survived random events should increment market_events_survived"
	)


func test_evaluate_returns_fallback_broke_even() -> void:
	var result: StringName = _system.evaluate()
	assert_eq(
		result,
		&"broke_even",
		"With no matching criteria, fallback ending should be broke_even"
	)


func test_evaluate_lights_out() -> void:
	EventBus.day_started.emit(1)
	EventBus.day_started.emit(2)

	var stats: Dictionary = _system.get_all_tracked_stats()
	stats["trigger_type_bankruptcy"] = 1.0
	stats["days_survived"] = 2.0
	stats["cumulative_revenue"] = 50.0
	_system.load_state({"stats": stats})

	var result: StringName = _system.evaluate()
	assert_eq(
		result,
		&"lights_out",
		"Short bankruptcy should be lights_out"
	)


func test_save_load_preserves_stats() -> void:
	EventBus.customer_purchased.emit(&"", &"item_a", 100.0, &"")
	EventBus.customer_purchased.emit(&"", &"item_b", 200.0, &"")
	EventBus.day_started.emit(1)

	var save_data: Dictionary = _system.get_save_data()

	var new_system: EndingEvaluatorSystem = (
		EndingEvaluatorSystem.new()
	)
	add_child_autofree(new_system)
	new_system.initialize()
	new_system.load_state(save_data)

	assert_eq(
		new_system.get_tracked_stat(&"total_sales_count"),
		2.0,
		"Stats should survive save/load round-trip"
	)
	assert_eq(
		new_system.get_tracked_stat(&"cumulative_revenue"),
		300.0,
		"Revenue should survive save/load round-trip"
	)


func test_load_state_does_not_emit_ending_triggered() -> void:
	var signal_fired: Array = [false]
	var on_ending: Callable = func(
		_id: StringName, _stats: Dictionary
	) -> void:
		signal_fired[0] = true
	EventBus.ending_triggered.connect(on_ending)

	_system.load_state({
		"stats": {"total_sales_count": 5.0},
		"ending_triggered": true,
		"resolved_ending_id": "broke_even",
	})

	assert_false(
		signal_fired[0],
		"load_state must not emit ending_triggered"
	)

	EventBus.ending_triggered.disconnect(on_ending)


func test_ending_requested_emits_signals_in_order() -> void:
	var events: Array[String] = []
	var on_snapshot: Callable = func(
		_stats: Dictionary
	) -> void:
		events.append("snapshot")
	var on_ending: Callable = func(
		_id: StringName, _stats: Dictionary
	) -> void:
		events.append("triggered")

	EventBus.ending_stats_snapshot_ready.connect(on_snapshot)
	EventBus.ending_triggered.connect(on_ending)

	EventBus.ending_requested.emit("voluntary")

	assert_eq(events.size(), 2, "Both signals should fire")
	assert_eq(
		events[0], "snapshot",
		"Stats snapshot should fire before ending_triggered"
	)
	assert_eq(
		events[1], "triggered",
		"ending_triggered should fire second"
	)

	EventBus.ending_stats_snapshot_ready.disconnect(on_snapshot)
	EventBus.ending_triggered.disconnect(on_ending)


func test_bankruptcy_declared_triggers_evaluate() -> void:
	var ending_id: Array = [&""]
	var on_ending: Callable = func(
		id: StringName, _stats: Dictionary
	) -> void:
		ending_id[0] = id
	EventBus.ending_triggered.connect(on_ending)

	EventBus.bankruptcy_declared.emit()

	assert_ne(
		ending_id[0], &"",
		"bankruptcy_declared should trigger ending evaluation"
	)
	assert_eq(
		_system.get_tracked_stat(&"trigger_type_bankruptcy"),
		1.0,
		"trigger_type_bankruptcy stat should be set to 1.0"
	)

	EventBus.ending_triggered.disconnect(on_ending)


func test_player_quit_to_end_triggers_evaluate() -> void:
	var ending_id: Array = [&""]
	var on_ending: Callable = func(
		id: StringName, _stats: Dictionary
	) -> void:
		ending_id[0] = id
	EventBus.ending_triggered.connect(on_ending)

	EventBus.player_quit_to_end.emit()

	assert_ne(
		ending_id[0], &"",
		"player_quit_to_end should trigger ending evaluation"
	)
	EventBus.ending_triggered.disconnect(on_ending)


func test_bankruptcy_declared_double_emit_no_double_evaluate() -> void:
	var fire_count: Array = [0]
	var on_ending: Callable = func(
		_id: StringName, _stats: Dictionary
	) -> void:
		fire_count[0] += 1
	EventBus.ending_triggered.connect(on_ending)

	EventBus.bankruptcy_declared.emit()
	EventBus.bankruptcy_declared.emit()

	assert_eq(
		fire_count[0], 1,
		"Second bankruptcy_declared should not trigger another evaluate"
	)

	EventBus.ending_triggered.disconnect(on_ending)


func test_ending_triggered_fires_only_once() -> void:
	var fire_count: Array = [0]
	var on_ending: Callable = func(
		_id: StringName, _stats: Dictionary
	) -> void:
		fire_count[0] += 1
	EventBus.ending_triggered.connect(on_ending)

	EventBus.ending_requested.emit("voluntary")
	EventBus.ending_requested.emit("voluntary")

	assert_eq(
		fire_count[0], 1,
		"ending_triggered should fire exactly once"
	)

	EventBus.ending_triggered.disconnect(on_ending)
