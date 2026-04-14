## Integration test: bankruptcy_declared → EndingEvaluatorSystem selects correct BANKRUPTCY
## ending based on days_survived → ending_triggered with correct ending_id → GAME_OVER.
extends GutTest


## Bankruptcy-category ending IDs from ending_config.json.
const EARLY_BANKRUPTCY_ENDING: StringName = &"lights_out"
const MID_BANKRUPTCY_ENDING: StringName = &"foreclosure"
const LATE_BANKRUPTCY_ENDING: StringName = &"going_going_gone"

const BANKRUPTCY_ENDINGS: Array[StringName] = [
	&"lights_out", &"foreclosure", &"going_going_gone",
]

const SUCCESS_ENDINGS: Array[StringName] = [
	&"prestige_champion", &"the_local_legend", &"the_mini_empire",
	&"the_mall_tycoon", &"the_fair_dealer", &"the_collector",
	&"the_mall_legend_redux", &"the_ghost_between_the_walls",
]

const SURVIVAL_ENDINGS: Array[StringName] = [
	&"broke_even", &"the_comfortable_middle", &"crisis_operator",
]

var _ending_evaluator: EndingEvaluatorSystem

var _saved_state: GameManager.GameState
var _saved_ending_id: StringName


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_ending_id = GameManager.get_ending_id()

	GameManager.current_state = GameManager.GameState.GAMEPLAY
	GameManager._ending_id = &""

	_ending_evaluator = EndingEvaluatorSystem.new()
	add_child_autofree(_ending_evaluator)
	_ending_evaluator.initialize()


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager._ending_id = _saved_ending_id


## Sets the days_survived stat without emitting day_started signals.
func _set_days_survived(count: float) -> void:
	var save_data: Dictionary = _ending_evaluator.get_save_data()
	var stats: Dictionary = save_data.get("stats", {}).duplicate()
	stats["days_survived"] = count
	save_data["stats"] = stats
	_ending_evaluator.load_state(save_data)


## Returns the stat_summary_keys for an ending from the catalog.
func _get_stat_summary_keys(ending_id: StringName) -> Array:
	var ending_data: Dictionary = _ending_evaluator.get_ending_data(ending_id)
	var keys: Variant = ending_data.get("stat_summary_keys", [])
	if keys is Array:
		return keys as Array
	return []


## Case A: days_survived = 5 (< 7) — bankruptcy_declared triggers lights_out ending.
func test_early_bankruptcy_triggers_lights_out() -> void:
	_set_days_survived(5.0)

	var triggered_id: Array = [&""]
	var triggered_stats: Dictionary = {}
	var fire_count: Array = [0]
	var on_ending: Callable = func(id: StringName, stats: Dictionary) -> void:
		triggered_id[0] = id
		triggered_stats = stats
		fire_count[0] += 1
	EventBus.ending_triggered.connect(on_ending)

	EventBus.bankruptcy_declared.emit()

	assert_eq(
		triggered_id[0],
		EARLY_BANKRUPTCY_ENDING,
		"days_survived = 5 should select lights_out (days_survived <= 7)"
	)
	assert_eq(
		fire_count[0], 1,
		"ending_triggered must fire exactly once per bankruptcy_declared"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAME_OVER,
		"GameManager must transition to GAME_OVER after bankruptcy chain"
	)
	assert_true(
		_ending_evaluator.has_ending_been_shown(),
		"EndingEvaluatorSystem must mark ending as shown"
	)

	EventBus.ending_triggered.disconnect(on_ending)

	_verify_final_stats_contains_stat_summary_keys(
		triggered_id, triggered_stats
	)
	_verify_trigger_type_bankruptcy_in_stats(triggered_stats)


## Case B: days_survived = 20 (>= 15) — bankruptcy_declared triggers going_going_gone ending.
func test_late_bankruptcy_triggers_going_going_gone() -> void:
	_set_days_survived(20.0)

	var triggered_id: Array = [&""]
	var triggered_stats: Dictionary = {}
	var fire_count: Array = [0]
	var on_ending: Callable = func(id: StringName, stats: Dictionary) -> void:
		triggered_id[0] = id
		triggered_stats = stats
		fire_count[0] += 1
	EventBus.ending_triggered.connect(on_ending)

	EventBus.bankruptcy_declared.emit()

	assert_eq(
		triggered_id[0],
		LATE_BANKRUPTCY_ENDING,
		"days_survived = 20 should select going_going_gone (days_survived >= 15)"
	)
	assert_eq(
		fire_count[0], 1,
		"ending_triggered must fire exactly once per bankruptcy_declared"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAME_OVER,
		"GameManager must transition to GAME_OVER after bankruptcy chain"
	)
	assert_true(
		_ending_evaluator.has_ending_been_shown(),
		"EndingEvaluatorSystem must mark ending as shown"
	)

	EventBus.ending_triggered.disconnect(on_ending)

	_verify_final_stats_contains_stat_summary_keys(
		triggered_id, triggered_stats
	)
	_verify_trigger_type_bankruptcy_in_stats(triggered_stats)


## Case C: days_survived = 10 (8–14) — bankruptcy_declared triggers foreclosure ending.
func test_mid_bankruptcy_triggers_foreclosure() -> void:
	_set_days_survived(10.0)

	var triggered_id: Array = [&""]
	var triggered_stats: Dictionary = {}
	var fire_count: Array = [0]
	var on_ending: Callable = func(id: StringName, stats: Dictionary) -> void:
		triggered_id[0] = id
		triggered_stats = stats
		fire_count[0] += 1
	EventBus.ending_triggered.connect(on_ending)

	EventBus.bankruptcy_declared.emit()

	assert_eq(
		triggered_id[0],
		MID_BANKRUPTCY_ENDING,
		"days_survived = 10 should select foreclosure (days_survived 8–14)"
	)
	assert_eq(
		fire_count[0], 1,
		"ending_triggered must fire exactly once per bankruptcy_declared"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAME_OVER,
		"GameManager must transition to GAME_OVER after bankruptcy chain"
	)

	EventBus.ending_triggered.disconnect(on_ending)

	_verify_final_stats_contains_stat_summary_keys(
		triggered_id, triggered_stats
	)
	_verify_trigger_type_bankruptcy_in_stats(triggered_stats)


## No SUCCESS or SURVIVAL ending fires on bankruptcy_declared, even when success criteria
## would otherwise be satisfied.
func test_bankruptcy_does_not_emit_success_or_survival_ending() -> void:
	var save_data: Dictionary = _ending_evaluator.get_save_data()
	var stats: Dictionary = save_data.get("stats", {}).duplicate()
	stats["days_survived"] = 5.0
	stats["cumulative_revenue"] = 50000.0
	stats["max_reputation_tier"] = 4.0
	stats["satisfaction_ratio"] = 0.95
	stats["satisfied_customer_count"] = 300.0
	save_data["stats"] = stats
	_ending_evaluator.load_state(save_data)

	var triggered_id: Array = [&""]
	var on_ending: Callable = func(id: StringName, _stats: Dictionary) -> void:
		triggered_id[0] = id
	EventBus.ending_triggered.connect(on_ending)

	EventBus.bankruptcy_declared.emit()

	assert_false(
		triggered_id in SUCCESS_ENDINGS,
		"No SUCCESS ending should fire on bankruptcy; got: %s" % triggered_id[0]
	)
	assert_false(
		triggered_id in SURVIVAL_ENDINGS,
		"No SURVIVAL ending should fire on bankruptcy; got: %s" % triggered_id[0]
	)
	assert_true(
		triggered_id in BANKRUPTCY_ENDINGS,
		"Only a BANKRUPTCY ending should fire; got: %s" % triggered_id[0]
	)

	EventBus.ending_triggered.disconnect(on_ending)


## Second bankruptcy_declared emission after the ending is already triggered must not
## cause a second ending_triggered emission.
func test_duplicate_bankruptcy_declared_does_not_double_fire() -> void:
	_set_days_survived(5.0)

	var fire_count: Array = [0]
	var on_ending: Callable = func(_id: StringName, _stats: Dictionary) -> void:
		fire_count[0] += 1
	EventBus.ending_triggered.connect(on_ending)

	EventBus.bankruptcy_declared.emit()
	EventBus.bankruptcy_declared.emit()

	assert_eq(
		fire_count[0], 1,
		"ending_triggered must fire exactly once despite two bankruptcy_declared emissions"
	)

	EventBus.ending_triggered.disconnect(on_ending)


## final_stats payload must include trigger_type_bankruptcy = 1.0 and days_survived
## matching the value set before bankruptcy_declared.
func test_final_stats_contains_bankruptcy_flag_and_days_survived() -> void:
	_set_days_survived(20.0)

	var captured_stats: Dictionary = {}
	var on_ending: Callable = func(_id: StringName, stats: Dictionary) -> void:
		captured_stats = stats
	EventBus.ending_triggered.connect(on_ending)

	EventBus.bankruptcy_declared.emit()

	assert_false(
		captured_stats.is_empty(),
		"final_stats must not be empty"
	)
	assert_true(
		captured_stats.has("trigger_type_bankruptcy"),
		"final_stats must include trigger_type_bankruptcy key"
	)
	assert_eq(
		captured_stats.get("trigger_type_bankruptcy", 0.0),
		1.0,
		"trigger_type_bankruptcy must be 1.0 in final_stats"
	)
	assert_true(
		captured_stats.has("days_survived"),
		"final_stats must include days_survived key"
	)
	assert_eq(
		captured_stats.get("days_survived", 0.0),
		20.0,
		"days_survived in final_stats must reflect the pre-bankruptcy value"
	)

	EventBus.ending_triggered.disconnect(on_ending)


## ending_stats_snapshot_ready fires before ending_triggered in the bankruptcy chain.
func test_snapshot_signal_fires_before_ending_triggered() -> void:
	_set_days_survived(5.0)

	var events: Array[String] = []
	var on_snapshot: Callable = func(_stats: Dictionary) -> void:
		events.append("snapshot")
	var on_ending: Callable = func(_id: StringName, _stats: Dictionary) -> void:
		events.append("triggered")
	EventBus.ending_stats_snapshot_ready.connect(on_snapshot)
	EventBus.ending_triggered.connect(on_ending)

	EventBus.bankruptcy_declared.emit()

	assert_eq(events.size(), 2, "Both snapshot and triggered signals should fire")
	assert_eq(
		events[0], "snapshot",
		"ending_stats_snapshot_ready must fire before ending_triggered"
	)
	assert_eq(
		events[1], "triggered",
		"ending_triggered must fire second in the bankruptcy chain"
	)

	EventBus.ending_stats_snapshot_ready.disconnect(on_snapshot)
	EventBus.ending_triggered.disconnect(on_ending)


## Verifies all stat_summary_keys listed for a given ending appear in final_stats.
func _verify_final_stats_contains_stat_summary_keys(
	ending_id: StringName, final_stats: Dictionary
) -> void:
	var summary_keys: Array = _get_stat_summary_keys(ending_id)
	for key: Variant in summary_keys:
		var stat_key: String = str(key)
		assert_true(
			final_stats.has(stat_key),
			"final_stats missing stat_summary_key '%s' for ending '%s'" % [
				stat_key, ending_id
			]
		)


## Verifies that trigger_type_bankruptcy is present and set to 1.0 in final_stats.
func _verify_trigger_type_bankruptcy_in_stats(final_stats: Dictionary) -> void:
	assert_true(
		final_stats.has("trigger_type_bankruptcy"),
		"final_stats must include trigger_type_bankruptcy"
	)
	assert_eq(
		final_stats.get("trigger_type_bankruptcy", 0.0),
		1.0,
		"trigger_type_bankruptcy must be 1.0 in final_stats for bankruptcy endings"
	)
