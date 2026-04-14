## GUT tests for EndingEvaluatorSystem trigger guards, signal ordering, and persistence.
extends GutTest


var _system: EndingEvaluatorSystem


func before_each() -> void:
	_system = EndingEvaluatorSystem.new()
	add_child_autofree(_system)
	_system.initialize()


func _build_stats(overrides: Dictionary) -> Dictionary:
	var base: Dictionary = {
		"cumulative_revenue": 0.0, "cumulative_expenses": 0.0,
		"peak_cash": 0.0, "final_cash": 0.0,
		"days_survived": 0.0, "owned_store_count_peak": 0.0,
		"owned_store_count_final": 0.0, "total_sales_count": 0.0,
		"satisfied_customer_count": 0.0,
		"unsatisfied_customer_count": 0.0,
		"satisfaction_ratio": 0.0, "max_reputation_tier": 0.0,
		"final_reputation_tier": 0.0,
		"secret_threads_completed": 0.0,
		"haggle_attempts": 0.0, "haggle_never_used": 1.0,
		"days_near_bankruptcy": 0.0, "rare_items_sold": 0.0,
		"market_events_survived": 0.0,
		"unique_store_types_owned": 0.0,
		"trigger_type_bankruptcy": 0.0,
		"ghost_tenant_thread_completed": 0.0,
	}
	for key: String in overrides:
		base[key] = overrides[key]
	return base


# ── Group 3: Trigger and guard behavior ──


func test_bankruptcy_declared_triggers_evaluation() -> void:
	watch_signals(EventBus)
	EventBus.bankruptcy_declared.emit()
	assert_signal_emitted(
		EventBus, "ending_triggered",
		"bankruptcy_declared should trigger ending evaluation"
	)
	assert_eq(
		_system.get_tracked_stat(&"trigger_type_bankruptcy"),
		1.0, "trigger_type_bankruptcy should be 1.0"
	)


func test_ending_requested_voluntary_triggers() -> void:
	watch_signals(EventBus)
	EventBus.ending_requested.emit("voluntary")
	assert_signal_emitted(
		EventBus, "ending_triggered",
		"ending_requested should trigger evaluation"
	)
	assert_eq(
		_system.get_tracked_stat(&"trigger_type_bankruptcy"),
		0.0, "Voluntary trigger should not set bankruptcy flag"
	)


func test_second_trigger_is_noop() -> void:
	var fire_count: int = 0
	var on_ending: Callable = func(
		_id: StringName, _stats: Dictionary
	) -> void:
		fire_count += 1
	EventBus.ending_triggered.connect(on_ending)

	EventBus.ending_requested.emit("voluntary")
	EventBus.ending_requested.emit("voluntary")
	EventBus.bankruptcy_declared.emit()

	assert_eq(
		fire_count, 1,
		"Only the first trigger should emit ending_triggered"
	)
	EventBus.ending_triggered.disconnect(on_ending)


func test_mixed_trigger_paths_emit_once() -> void:
	var fire_count: int = 0
	var on_ending: Callable = func(
		_id: StringName, _stats: Dictionary
	) -> void:
		fire_count += 1
	EventBus.ending_triggered.connect(on_ending)

	EventBus.bankruptcy_declared.emit()
	EventBus.ending_requested.emit("voluntary")

	assert_eq(
		fire_count, 1,
		"Mixing trigger paths should still emit exactly once"
	)
	EventBus.ending_triggered.disconnect(on_ending)


func test_snapshot_emitted_before_triggered() -> void:
	var events: Array[String] = []
	var on_snap: Callable = func(_s: Dictionary) -> void:
		events.append("snapshot")
	var on_end: Callable = func(
		_id: StringName, _s: Dictionary
	) -> void:
		events.append("triggered")

	EventBus.ending_stats_snapshot_ready.connect(on_snap)
	EventBus.ending_triggered.connect(on_end)

	EventBus.ending_requested.emit("voluntary")

	assert_eq(events.size(), 2, "Both signals should fire")
	assert_eq(
		events[0], "snapshot",
		"snapshot must fire before ending_triggered"
	)
	assert_eq(
		events[1], "triggered",
		"ending_triggered must fire second"
	)
	EventBus.ending_stats_snapshot_ready.disconnect(on_snap)
	EventBus.ending_triggered.disconnect(on_end)


func test_force_ending_emits_signals() -> void:
	watch_signals(EventBus)
	_system.force_ending(&"the_local_legend")
	assert_signal_emitted(
		EventBus, "ending_stats_snapshot_ready",
		"force_ending should emit stats snapshot"
	)
	assert_signal_emitted(
		EventBus, "ending_triggered",
		"force_ending should emit ending_triggered"
	)
	assert_eq(
		_system.get_resolved_ending_id(), &"the_local_legend",
		"Resolved ending should match forced ID"
	)


func test_force_ending_blocked_after_first() -> void:
	var fire_count: int = 0
	var on_ending: Callable = func(
		_id: StringName, _stats: Dictionary
	) -> void:
		fire_count += 1
	EventBus.ending_triggered.connect(on_ending)

	_system.force_ending(&"the_local_legend")
	_system.force_ending(&"broke_even")

	assert_eq(fire_count, 1, "Second force_ending should be blocked")
	assert_eq(
		_system.get_resolved_ending_id(), &"the_local_legend",
		"Resolved ending should remain first forced one"
	)
	EventBus.ending_triggered.disconnect(on_ending)


# ── Group 4: Persistence ──


func test_save_data_includes_required_keys() -> void:
	var data: Dictionary = _system.get_save_data()
	assert_true(
		data.has("stats"), "Save data must have 'stats' key"
	)
	assert_true(
		data.has("ending_triggered"),
		"Save data must have 'ending_triggered' key"
	)


func test_load_state_restores_revenue() -> void:
	_system.load_state({
		"stats": _build_stats({"cumulative_revenue": 5000.0}),
	})
	assert_eq(
		_system.get_tracked_stat(&"cumulative_revenue"), 5000.0,
		"load_state should restore cumulative_revenue"
	)


func test_load_triggered_prevents_new_triggers() -> void:
	_system.load_state({
		"stats": _build_stats({}),
		"ending_triggered": true,
		"resolved_ending_id": "the_local_legend",
	})

	var fire_count: int = 0
	var on_ending: Callable = func(
		_id: StringName, _stats: Dictionary
	) -> void:
		fire_count += 1
	EventBus.ending_triggered.connect(on_ending)

	EventBus.ending_requested.emit("voluntary")

	assert_eq(
		fire_count, 0,
		"Loaded ending_triggered=true should prevent new triggers"
	)
	assert_true(
		_system.has_ending_been_shown(),
		"has_ending_been_shown should be true after load"
	)
	EventBus.ending_triggered.disconnect(on_ending)


func test_save_load_round_trip() -> void:
	EventBus.customer_purchased.emit(&"s", &"a", 100.0, &"c")
	EventBus.customer_purchased.emit(&"s", &"b", 200.0, &"c")
	EventBus.day_started.emit(1)
	EventBus.day_started.emit(2)
	EventBus.haggle_completed.emit(
		&"s", &"i", 15.0, 20.0, true, 1
	)

	var save_data: Dictionary = _system.get_save_data()
	var restored: EndingEvaluatorSystem = (
		EndingEvaluatorSystem.new()
	)
	add_child_autofree(restored)
	restored.initialize()
	restored.load_state(save_data)

	assert_eq(
		restored.get_tracked_stat(&"cumulative_revenue"), 300.0,
		"Revenue should survive round-trip"
	)
	assert_eq(
		restored.get_tracked_stat(&"days_survived"), 2.0,
		"Days survived should survive round-trip"
	)
	assert_eq(
		restored.get_tracked_stat(&"haggle_never_used"), 0.0,
		"haggle_never_used should survive round-trip"
	)


func test_load_state_does_not_emit_signals() -> void:
	var signal_fired: bool = false
	var on_ending: Callable = func(
		_id: StringName, _stats: Dictionary
	) -> void:
		signal_fired = true
	EventBus.ending_triggered.connect(on_ending)

	_system.load_state({
		"stats": _build_stats({"total_sales_count": 5.0}),
		"ending_triggered": true,
		"resolved_ending_id": "broke_even",
	})

	assert_false(
		signal_fired, "load_state must not emit ending_triggered"
	)
	EventBus.ending_triggered.disconnect(on_ending)


func test_load_restores_resolved_ending_id() -> void:
	_system.load_state({
		"stats": _build_stats({}),
		"ending_triggered": true,
		"resolved_ending_id": "the_collector",
	})
	assert_eq(
		_system.get_resolved_ending_id(), &"the_collector",
		"Resolved ending ID should be restored from save"
	)


# ── Group 5: Priority conflict — one signal, highest-priority winner ──


func test_priority_conflict_emits_once_with_highest_priority_winner() -> void:
	# Stats satisfy both the_mall_legend_redux (priority 1) and
	# the_mall_tycoon (priority 8) simultaneously. Only one
	# ending_triggered should fire, carrying the lower priority number.
	_system.load_state({
		"stats": _build_stats({
			"ghost_tenant_thread_completed": 0.0,
			"secret_threads_completed": 4.0,
			"cumulative_revenue": 25000.0,
			"owned_store_count_final": 5.0,
			"trigger_type_bankruptcy": 0.0,
		}),
	})

	var emitted_ids: Array[StringName] = []
	var on_ending: Callable = func(
		ending_id: StringName, _stats: Dictionary
	) -> void:
		emitted_ids.append(ending_id)
	EventBus.ending_triggered.connect(on_ending)

	EventBus.ending_requested.emit("voluntary")

	assert_eq(
		emitted_ids.size(), 1,
		"Exactly one ending_triggered should fire even when multiple endings match"
	)
	assert_eq(
		emitted_ids[0], &"the_mall_legend_redux",
		"Highest-priority ending (lowest priority number) should win"
	)
	EventBus.ending_triggered.disconnect(on_ending)
