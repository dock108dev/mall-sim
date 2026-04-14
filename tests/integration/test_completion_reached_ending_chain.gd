## GUT integration test — completion_reached triggers EndingEvaluatorSystem evaluation chain.
extends GutTest


var _system: EndingEvaluatorSystem


func before_each() -> void:
	_system = EndingEvaluatorSystem.new()
	add_child_autofree(_system)
	_system.initialize()


## Acceptance criterion 1 & 3: completion_reached('time_limit') causes
## EndingEvaluatorSystem to evaluate and emit ending_triggered.
func test_time_limit_reason_triggers_ending_triggered() -> void:
	var ending_id: StringName = &""
	var on_triggered: Callable = func(
		id: StringName, _stats: Dictionary
	) -> void:
		ending_id = id
	EventBus.ending_triggered.connect(on_triggered)

	EventBus.completion_reached.emit("time_limit")

	assert_ne(
		ending_id,
		&"",
		"completion_reached('time_limit') must cause ending_triggered to fire"
	)
	assert_true(
		_system.has_ending_been_shown(),
		"System must record that an ending has been triggered"
	)

	EventBus.ending_triggered.disconnect(on_triggered)


## Acceptance criterion 2: ending_stats_snapshot_ready fires before ending_triggered.
func test_snapshot_fires_before_ending_triggered() -> void:
	var events: Array[String] = []
	var on_snapshot: Callable = func(_stats: Dictionary) -> void:
		events.append("snapshot")
	var on_triggered: Callable = func(
		_id: StringName, _stats: Dictionary
	) -> void:
		events.append("triggered")

	EventBus.ending_stats_snapshot_ready.connect(on_snapshot)
	EventBus.ending_triggered.connect(on_triggered)

	EventBus.completion_reached.emit("time_limit")

	assert_eq(events.size(), 2, "Both signals must fire")
	assert_eq(
		events[0],
		"snapshot",
		"ending_stats_snapshot_ready must precede ending_triggered"
	)
	assert_eq(
		events[1],
		"triggered",
		"ending_triggered must follow ending_stats_snapshot_ready"
	)

	EventBus.ending_stats_snapshot_ready.disconnect(on_snapshot)
	EventBus.ending_triggered.disconnect(on_triggered)


## Acceptance criterion 2: snapshot contains all required stat keys.
func test_snapshot_contains_required_stat_keys() -> void:
	var required_keys: Array[StringName] = [
		&"cumulative_revenue",
		&"cumulative_expenses",
		&"peak_cash",
		&"final_cash",
		&"days_survived",
		&"owned_store_count_peak",
		&"owned_store_count_final",
		&"total_sales_count",
		&"satisfied_customer_count",
		&"unsatisfied_customer_count",
		&"satisfaction_ratio",
		&"max_reputation_tier",
		&"final_reputation_tier",
		&"secret_threads_completed",
		&"haggle_attempts",
		&"haggle_never_used",
		&"days_near_bankruptcy",
		&"rare_items_sold",
		&"market_events_survived",
		&"unique_store_types_owned",
		&"trigger_type_bankruptcy",
		&"ghost_tenant_thread_completed",
	]

	var snapshot: Dictionary = {}
	var on_snapshot: Callable = func(stats: Dictionary) -> void:
		snapshot = stats.duplicate()
	EventBus.ending_stats_snapshot_ready.connect(on_snapshot)

	EventBus.completion_reached.emit("time_limit")

	for key: StringName in required_keys:
		assert_true(
			snapshot.has(String(key)),
			"Snapshot must include stat key: %s" % key
		)

	EventBus.ending_stats_snapshot_ready.disconnect(on_snapshot)


## Acceptance criterion 4: final_stats in ending_triggered matches the snapshot.
func test_final_stats_matches_snapshot() -> void:
	var snapshot: Dictionary = {}
	var final_stats: Dictionary = {}

	var on_snapshot: Callable = func(stats: Dictionary) -> void:
		snapshot = stats.duplicate()
	var on_triggered: Callable = func(
		_id: StringName, stats: Dictionary
	) -> void:
		final_stats = stats.duplicate()

	EventBus.ending_stats_snapshot_ready.connect(on_snapshot)
	EventBus.ending_triggered.connect(on_triggered)

	EventBus.completion_reached.emit("time_limit")

	assert_false(snapshot.is_empty(), "Snapshot must not be empty")
	assert_eq(
		final_stats,
		snapshot,
		"final_stats in ending_triggered must equal the emitted snapshot"
	)

	EventBus.ending_stats_snapshot_ready.disconnect(on_snapshot)
	EventBus.ending_triggered.disconnect(on_triggered)


## Acceptance criterion 3: ending_id matches deterministic stub stats.
## Seed stats to hit a specific ending threshold (just_getting_by fallback here).
func test_ending_id_matches_catalog_threshold() -> void:
	var triggered_id: StringName = &""
	var on_triggered: Callable = func(
		id: StringName, _stats: Dictionary
	) -> void:
		triggered_id = id
	EventBus.ending_triggered.connect(on_triggered)

	EventBus.completion_reached.emit("time_limit")

	assert_eq(
		triggered_id,
		&"just_getting_by",
		"With zero stats, evaluate() must match the fallback just_getting_by ending"
	)

	EventBus.ending_triggered.disconnect(on_triggered)


## Acceptance criterion 3 (variant): Stats seeded to hit broke_even ending.
func test_ending_id_matches_broke_even_threshold() -> void:
	var stats: Dictionary = _system.get_all_tracked_stats()
	stats["days_survived"] = 30.0
	stats["final_cash"] = 200.0
	stats["cumulative_revenue"] = 500.0
	_system.load_state({"stats": stats})

	var triggered_id: StringName = &""
	var on_triggered: Callable = func(
		id: StringName, _stats: Dictionary
	) -> void:
		triggered_id = id
	EventBus.ending_triggered.connect(on_triggered)

	EventBus.completion_reached.emit("time_limit")

	assert_eq(
		triggered_id,
		&"broke_even",
		"Stats meeting broke_even criteria must resolve to broke_even"
	)

	EventBus.ending_triggered.disconnect(on_triggered)


## Acceptance criterion 5: all_criteria reason also triggers evaluation chain.
func test_all_criteria_reason_triggers_ending_triggered() -> void:
	var ending_id: StringName = &""
	var on_triggered: Callable = func(
		id: StringName, _stats: Dictionary
	) -> void:
		ending_id = id
	EventBus.ending_triggered.connect(on_triggered)

	EventBus.completion_reached.emit("all_criteria")

	assert_ne(
		ending_id,
		&"",
		"completion_reached('all_criteria') must also trigger ending evaluation"
	)
	assert_true(
		_system.has_ending_been_shown(),
		"System must record ending as shown after all_criteria reason"
	)

	EventBus.ending_triggered.disconnect(on_triggered)


## Acceptance criterion 6: idempotency — second completion_reached does not re-trigger.
func test_second_completion_reached_does_not_re_trigger() -> void:
	var fire_count: int = 0
	var on_triggered: Callable = func(
		_id: StringName, _stats: Dictionary
	) -> void:
		fire_count += 1
	EventBus.ending_triggered.connect(on_triggered)

	EventBus.completion_reached.emit("time_limit")
	EventBus.completion_reached.emit("time_limit")

	assert_eq(
		fire_count,
		1,
		"ending_triggered must fire exactly once regardless of duplicate completion_reached emissions"
	)

	EventBus.ending_triggered.disconnect(on_triggered)


## Idempotency also holds across different reasons.
func test_different_reasons_still_idempotent() -> void:
	var fire_count: int = 0
	var on_triggered: Callable = func(
		_id: StringName, _stats: Dictionary
	) -> void:
		fire_count += 1
	EventBus.ending_triggered.connect(on_triggered)

	EventBus.completion_reached.emit("time_limit")
	EventBus.completion_reached.emit("all_criteria")

	assert_eq(
		fire_count,
		1,
		"Switching reasons must not bypass the idempotency guard"
	)

	EventBus.ending_triggered.disconnect(on_triggered)
