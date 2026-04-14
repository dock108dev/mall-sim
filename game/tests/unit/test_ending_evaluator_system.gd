## GUT unit tests for EndingEvaluatorSystem — stat initialization, accumulation,
## evaluate() logic, trigger guards, and save/load symmetry.
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
		"final_reputation_tier": 0.0, "secret_threads_completed": 0.0,
		"haggle_attempts": 0.0, "haggle_never_used": 1.0,
		"days_near_bankruptcy": 0.0, "rare_items_sold": 0.0,
		"market_events_survived": 0.0, "unique_store_types_owned": 0.0,
		"trigger_type_bankruptcy": 0.0,
		"ghost_tenant_thread_completed": 0.0,
	}
	for key: String in overrides:
		base[key] = overrides[key]
	return base


func _load_stats(overrides: Dictionary) -> void:
	_system.load_state({"stats": _build_stats(overrides)})


# ── 1. Stat initialization ──


func test_all_numeric_stats_initialize_to_zero() -> void:
	var stats: Dictionary = _system.get_all_tracked_stats()
	var numeric_keys: Array[String] = [
		"cumulative_revenue", "cumulative_expenses", "peak_cash",
		"final_cash", "days_survived", "owned_store_count_peak",
		"owned_store_count_final", "total_sales_count",
		"satisfied_customer_count", "unsatisfied_customer_count",
		"satisfaction_ratio", "max_reputation_tier", "final_reputation_tier",
		"secret_threads_completed", "haggle_attempts",
		"days_near_bankruptcy", "rare_items_sold", "market_events_survived",
		"unique_store_types_owned", "trigger_type_bankruptcy",
		"ghost_tenant_thread_completed",
	]
	for key: String in numeric_keys:
		assert_eq(
			float(stats.get(key, -1.0)), 0.0,
			"%s should initialize to 0.0" % key
		)


func test_haggle_never_used_starts_true() -> void:
	assert_eq(
		_system.get_tracked_stat(&"haggle_never_used"), 1.0,
		"haggle_never_used should start at 1.0"
	)


# ── 2. Stat accumulation via signals ──


func test_customer_purchased_accumulates_revenue_and_sales() -> void:
	EventBus.customer_purchased.emit(&"store", &"item_a", 100.0, &"cust")
	EventBus.customer_purchased.emit(&"store", &"item_b", 250.0, &"cust")
	assert_eq(
		_system.get_tracked_stat(&"cumulative_revenue"), 350.0,
		"Revenue should accumulate all purchase prices"
	)
	assert_eq(
		_system.get_tracked_stat(&"total_sales_count"), 2.0,
		"total_sales_count should increment on each purchase"
	)


func test_customer_left_increments_correct_counter() -> void:
	EventBus.customer_left.emit({"satisfied": true})
	EventBus.customer_left.emit({"satisfied": true})
	EventBus.customer_left.emit({"satisfied": false})
	assert_eq(
		_system.get_tracked_stat(&"satisfied_customer_count"), 2.0,
		"satisfied_customer_count should count satisfied customers"
	)
	assert_eq(
		_system.get_tracked_stat(&"unsatisfied_customer_count"), 1.0,
		"unsatisfied_customer_count should count unsatisfied customers"
	)


func test_satisfaction_ratio_recalculates_after_each_customer_left() -> void:
	EventBus.customer_left.emit({"satisfied": true})
	EventBus.customer_left.emit({"satisfied": true})
	EventBus.customer_left.emit({"satisfied": true})
	EventBus.customer_left.emit({"satisfied": false})
	var stats: Dictionary = _system.get_all_tracked_stats()
	assert_almost_eq(
		float(stats.get("satisfaction_ratio", 0.0)),
		0.75, 0.001, "3 satisfied / 4 total = 0.75 ratio"
	)


func test_haggle_completed_sets_never_used_false_and_counts_attempts() -> void:
	EventBus.haggle_completed.emit(&"store", &"item", 15.0, 20.0, true, 1)
	assert_eq(
		_system.get_tracked_stat(&"haggle_never_used"), 0.0,
		"haggle_never_used should be 0.0 after first haggle"
	)
	assert_eq(
		_system.get_tracked_stat(&"haggle_attempts"), 1.0,
		"haggle_attempts should increment"
	)


func test_haggle_never_used_does_not_revert_to_true() -> void:
	EventBus.haggle_completed.emit(&"store", &"item", 15.0, 20.0, true, 1)
	EventBus.haggle_completed.emit(&"store", &"item", 10.0, 15.0, false, 2)
	assert_eq(
		_system.get_tracked_stat(&"haggle_never_used"), 0.0,
		"haggle_never_used must stay 0.0 after subsequent haggles"
	)


func test_ghost_thread_sets_flag_other_threads_do_not() -> void:
	EventBus.secret_thread_completed.emit(&"some_other_thread", &"")
	assert_eq(
		_system.get_tracked_stat(&"ghost_tenant_thread_completed"), 0.0,
		"Non-ghost threads must not set ghost_tenant_thread_completed"
	)
	EventBus.secret_thread_completed.emit(&"the_ghost_tenant", &"")
	assert_eq(
		_system.get_tracked_stat(&"ghost_tenant_thread_completed"), 1.0,
		"ghost_tenant_thread_completed should be 1.0 after ghost thread"
	)
	assert_eq(
		_system.get_tracked_stat(&"secret_threads_completed"), 2.0,
		"secret_threads_completed should count all completions"
	)


func test_random_event_ended_increments_market_events_survived() -> void:
	EventBus.random_event_ended.emit("market_crash")
	assert_eq(
		_system.get_tracked_stat(&"market_events_survived"), 1.0,
		"random_event_ended should increment market_events_survived"
	)


func test_day_started_increments_days_survived() -> void:
	EventBus.day_started.emit(1)
	EventBus.day_started.emit(2)
	assert_eq(
		_system.get_tracked_stat(&"days_survived"), 2.0,
		"days_survived should increment on each day_started"
	)


func test_days_near_bankruptcy_increments_only_below_threshold() -> void:
	EventBus.money_changed.emit(0.0, 50.0)
	EventBus.day_ended.emit(1)
	EventBus.day_ended.emit(2)
	assert_eq(
		_system.get_tracked_stat(&"days_near_bankruptcy"), 2.0,
		"Cash < 100 at day_ended should increment days_near_bankruptcy"
	)
	EventBus.money_changed.emit(50.0, 500.0)
	EventBus.day_ended.emit(3)
	assert_eq(
		_system.get_tracked_stat(&"days_near_bankruptcy"), 2.0,
		"Cash >= 100 must not increment days_near_bankruptcy"
	)


func test_money_changed_tracks_expenses_and_peak_cash() -> void:
	EventBus.money_changed.emit(0.0, 300.0)
	EventBus.money_changed.emit(300.0, 250.0)
	assert_eq(
		_system.get_tracked_stat(&"peak_cash"), 300.0,
		"peak_cash should track highest balance seen"
	)
	assert_eq(
		_system.get_tracked_stat(&"cumulative_expenses"), 50.0,
		"cumulative_expenses should accumulate money decreases"
	)


func test_reputation_changed_updates_max_tier_and_never_decreases() -> void:
	EventBus.reputation_changed.emit("store", 85.0)
	assert_eq(
		_system.get_tracked_stat(&"max_reputation_tier"), 4.0,
		"Reputation 85 should map to tier 4"
	)
	EventBus.reputation_changed.emit("store", 30.0)
	assert_eq(
		_system.get_tracked_stat(&"max_reputation_tier"), 4.0,
		"max_reputation_tier should never decrease"
	)


# ── 3. evaluate() — one test per ending condition ──


func test_ending_the_ghost_between_the_walls() -> void:
	_load_stats({
		"ghost_tenant_thread_completed": 1.0, "owned_store_count_final": 5.0,
	})
	assert_eq(_system.evaluate(), &"the_ghost_between_the_walls")


func test_ending_the_mall_legend_redux() -> void:
	_load_stats({
		"secret_threads_completed": 4.0, "cumulative_revenue": 25000.0,
	})
	assert_eq(_system.evaluate(), &"the_mall_legend_redux")


func test_ending_lights_out() -> void:
	_load_stats({
		"trigger_type_bankruptcy": 1.0, "days_survived": 7.0,
	})
	assert_eq(_system.evaluate(), &"lights_out",
		"Bankruptcy at 7 days = lights_out, not going_going_gone"
	)


func test_ending_foreclosure() -> void:
	_load_stats({
		"trigger_type_bankruptcy": 1.0, "days_survived": 10.0,
	})
	assert_eq(_system.evaluate(), &"foreclosure",
		"Bankruptcy at 10 days = foreclosure, not lights_out"
	)


func test_ending_going_going_gone() -> void:
	_load_stats({
		"trigger_type_bankruptcy": 1.0, "days_survived": 15.0,
	})
	assert_eq(_system.evaluate(), &"going_going_gone")


func test_ending_the_local_legend() -> void:
	_load_stats({
		"owned_store_count_final": 1.0,
		"max_reputation_tier": 4.0, "days_survived": 30.0,
	})
	assert_eq(_system.evaluate(), &"the_local_legend")


func test_ending_the_mini_empire() -> void:
	_load_stats({
		"owned_store_count_final": 3.0,
		"cumulative_revenue": 10000.0, "days_survived": 30.0,
	})
	assert_eq(_system.evaluate(), &"the_mini_empire")


func test_ending_the_mall_tycoon() -> void:
	_load_stats({
		"owned_store_count_final": 5.0, "cumulative_revenue": 25000.0,
	})
	assert_eq(_system.evaluate(), &"the_mall_tycoon")


func test_ending_the_fair_dealer_with_haggle_never_used_true() -> void:
	_load_stats({
		"satisfied_customer_count": 200.0,
		"haggle_never_used": 1.0, "max_reputation_tier": 3.0,
	})
	assert_eq(_system.evaluate(), &"the_fair_dealer",
		"haggle_never_used = true must qualify for the_fair_dealer"
	)


func test_ending_the_fair_dealer_blocked_when_haggle_never_used_false() -> void:
	_load_stats({
		"satisfied_customer_count": 200.0,
		"haggle_never_used": 0.0, "max_reputation_tier": 3.0,
	})
	assert_ne(_system.evaluate(), &"the_fair_dealer",
		"haggle_never_used = false must block the_fair_dealer"
	)


func test_ending_the_collector() -> void:
	_load_stats({
		"rare_items_sold": 10.0, "cumulative_revenue": 5000.0,
	})
	assert_eq(_system.evaluate(), &"the_collector")


func test_ending_broke_even() -> void:
	_load_stats({
		"days_survived": 30.0, "final_cash": 100.0,
		"cumulative_revenue": 1000.0,
	})
	assert_eq(_system.evaluate(), &"broke_even")


func test_ending_the_comfortable_middle() -> void:
	_load_stats({
		"days_survived": 30.0, "cumulative_revenue": 5000.0,
	})
	assert_eq(_system.evaluate(), &"the_comfortable_middle")


func test_ending_crisis_operator() -> void:
	_load_stats({
		"days_near_bankruptcy": 10.0, "days_survived": 30.0,
		"final_cash": 100.0, "cumulative_revenue": 15000.0,
	})
	assert_eq(_system.evaluate(), &"crisis_operator")


func test_secret_ending_priority_over_overlapping_success_endings() -> void:
	_load_stats({
		"ghost_tenant_thread_completed": 1.0,
		"owned_store_count_final": 5.0,
		"cumulative_revenue": 25000.0, "days_survived": 30.0,
		"max_reputation_tier": 4.0,
	})
	assert_eq(
		_system.evaluate(), &"the_ghost_between_the_walls",
		"Secret ending must beat success endings when criteria overlap"
	)


func test_forbidden_all_blocks_success_ending_on_bankruptcy() -> void:
	_load_stats({
		"trigger_type_bankruptcy": 1.0,
		"owned_store_count_final": 1.0,
		"max_reputation_tier": 4.0, "days_survived": 30.0,
	})
	assert_ne(
		_system.evaluate(), &"the_local_legend",
		"Bankruptcy flag must block success endings via forbidden_all"
	)


func test_fallback_just_getting_by_when_no_criteria_match() -> void:
	assert_eq(_system.evaluate(), &"just_getting_by",
		"Zero stats with no matching criteria returns just_getting_by"
	)


# ── 4. Trigger guard tests ──


func test_ending_triggered_emits_exactly_once_across_two_trigger_calls() -> void:
	var fire_count: Array = [0]
	var on_ending: Callable = func(_id: StringName, _s: Dictionary) -> void:
		fire_count[0] += 1
	EventBus.ending_triggered.connect(on_ending)

	EventBus.ending_requested.emit("voluntary")
	EventBus.ending_requested.emit("voluntary")

	assert_eq(fire_count[0], 1, "ending_triggered must emit exactly once")
	EventBus.ending_triggered.disconnect(on_ending)


func test_bankruptcy_declared_path_triggers_evaluation() -> void:
	watch_signals(EventBus)
	EventBus.bankruptcy_declared.emit()
	assert_signal_emitted(EventBus, "ending_triggered",
		"bankruptcy_declared should invoke ending evaluation"
	)
	assert_eq(
		_system.get_tracked_stat(&"trigger_type_bankruptcy"), 1.0,
		"trigger_type_bankruptcy should be 1.0 after bankruptcy_declared"
	)


func test_ending_requested_path_triggers_evaluation() -> void:
	watch_signals(EventBus)
	EventBus.ending_requested.emit("player_quit")
	assert_signal_emitted(EventBus, "ending_triggered",
		"ending_requested signal should invoke ending evaluation"
	)


func test_ending_stats_snapshot_emitted_before_ending_triggered() -> void:
	var events: Array[String] = []
	var on_snap: Callable = func(_s: Dictionary) -> void:
		events.append("snapshot")
	var on_end: Callable = func(_id: StringName, _s: Dictionary) -> void:
		events.append("triggered")
	EventBus.ending_stats_snapshot_ready.connect(on_snap)
	EventBus.ending_triggered.connect(on_end)

	EventBus.ending_requested.emit("voluntary")

	assert_eq(events.size(), 2, "Both signals should fire")
	assert_eq(events[0], "snapshot", "snapshot must fire before ending_triggered")
	EventBus.ending_stats_snapshot_ready.disconnect(on_snap)
	EventBus.ending_triggered.disconnect(on_end)


# ── 5. Save/load symmetry ──


func test_save_data_contains_all_22_stat_keys_and_ending_triggered() -> void:
	var data: Dictionary = _system.get_save_data()
	assert_true(data.has("stats"), "save data must have 'stats'")
	assert_true(data.has("ending_triggered"), "save data must have 'ending_triggered'")
	var stats: Dictionary = data["stats"] as Dictionary
	var expected_keys: Array[String] = [
		"cumulative_revenue", "cumulative_expenses", "peak_cash", "final_cash",
		"days_survived", "owned_store_count_peak", "owned_store_count_final",
		"total_sales_count", "satisfied_customer_count",
		"unsatisfied_customer_count", "satisfaction_ratio",
		"max_reputation_tier", "final_reputation_tier",
		"secret_threads_completed", "haggle_attempts", "haggle_never_used",
		"days_near_bankruptcy", "rare_items_sold", "market_events_survived",
		"unique_store_types_owned", "trigger_type_bankruptcy",
		"ghost_tenant_thread_completed",
	]
	for key: String in expected_keys:
		assert_true(stats.has(key), "stats must include key: %s" % key)


func test_save_load_round_trip_preserves_accumulated_stats() -> void:
	EventBus.customer_purchased.emit(&"store", &"item_a", 100.0, &"cust")
	EventBus.customer_purchased.emit(&"store", &"item_b", 200.0, &"cust")
	EventBus.day_started.emit(1)
	EventBus.day_started.emit(2)
	EventBus.haggle_completed.emit(&"store", &"item", 15.0, 20.0, true, 1)
	EventBus.secret_thread_completed.emit(&"the_ghost_tenant", &"")
	EventBus.customer_left.emit({"satisfied": true})
	EventBus.customer_left.emit({"satisfied": false})

	var save_data: Dictionary = _system.get_save_data()
	var restored: EndingEvaluatorSystem = EndingEvaluatorSystem.new()
	add_child_autofree(restored)
	restored.initialize()
	restored.load_state(save_data)

	assert_eq(restored.get_tracked_stat(&"cumulative_revenue"), 300.0,
		"cumulative_revenue must survive round-trip"
	)
	assert_eq(restored.get_tracked_stat(&"days_survived"), 2.0,
		"days_survived must survive round-trip"
	)
	assert_eq(restored.get_tracked_stat(&"haggle_never_used"), 0.0,
		"haggle_never_used must survive round-trip"
	)
	assert_eq(restored.get_tracked_stat(&"ghost_tenant_thread_completed"), 1.0,
		"ghost_tenant_thread_completed must survive round-trip"
	)
	assert_eq(restored.get_tracked_stat(&"satisfied_customer_count"), 1.0,
		"satisfied_customer_count must survive round-trip"
	)


func test_load_state_does_not_emit_signals() -> void:
	var signal_fired: Array = [false]
	var on_ending: Callable = func(_id: StringName, _s: Dictionary) -> void:
		signal_fired[0] = true
	EventBus.ending_triggered.connect(on_ending)

	_system.load_state({
		"stats": _build_stats({"total_sales_count": 5.0}),
		"ending_triggered": true,
		"resolved_ending_id": "broke_even",
	})

	assert_false(signal_fired[0], "load_state must not emit ending_triggered")
	EventBus.ending_triggered.disconnect(on_ending)
