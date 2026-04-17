## Integration test — secret ending full path: thread_completed →
## UnlockSystemSingleton.grant_unlock → EndingEvaluatorSystem selects SECRET ending.
class_name TestSecretEndingFullPath
extends GutTest


const GHOST_THREAD_ID: StringName = &"the_ghost_tenant"
const GHOST_UNLOCK_ID: StringName = &"ghost_tenant_resolved"
const GHOST_ENDING_ID: StringName = &"the_mall_between_the_walls"

var _thread_system: SecretThreadSystem
var _unlock_system: UnlockSystem
var _ending_evaluator: EndingEvaluatorSystem

var _ghost_thread_def: Dictionary = {
	"id": "the_ghost_tenant",
	"display_name": "The Ghost Tenant",
	"resettable": false,
	"timeout_days": 0,
	"preconditions": [{"type": "day_reached", "value": 2}],
	"reveal_moment": "",
	"reward_unlock_id": "ghost_tenant_resolved",
}


func before_each() -> void:
	_unlock_system = UnlockSystemSingleton
	_unlock_system._granted.clear()
	_unlock_system._valid_ids.clear()
	_unlock_system._valid_ids[GHOST_UNLOCK_ID] = true
	if not ContentRegistry.exists(String(GHOST_UNLOCK_ID)):
		ContentRegistry.register_entry(
			{
				"id": String(GHOST_UNLOCK_ID),
				"name": "Ghost Tenant Resolved",
			},
			"unlock"
		)

	_thread_system = SecretThreadSystem.new()
	add_child_autofree(_thread_system)

	_ending_evaluator = EndingEvaluatorSystem.new()
	add_child_autofree(_ending_evaluator)
	_ending_evaluator.initialize()


func after_each() -> void:
	_unlock_system._granted.clear()
	_unlock_system._valid_ids.clear()


func _setup_ghost_thread() -> void:
	_thread_system._thread_defs = [_ghost_thread_def]
	_thread_system._init_thread_states()


func _drive_thread_to_resolved() -> void:
	for day: int in range(1, 5):
		_thread_system._on_day_started(day)


func _seed_ghost_ending_stats() -> void:
	var stats: Dictionary = _ending_evaluator.get_all_tracked_stats()
	stats["ghost_tenant_thread_completed"] = 1.0
	stats["owned_store_count_final"] = 5.0
	stats["days_survived"] = 30.0
	stats["trigger_type_bankruptcy"] = 0.0
	_ending_evaluator.load_state({"stats": stats})


func test_thread_completed_grants_unlock() -> void:
	_setup_ghost_thread()
	_drive_thread_to_resolved()

	assert_true(
		_unlock_system.is_unlocked(GHOST_UNLOCK_ID),
		"UnlockSystem must mark ghost_tenant_resolved as granted"
	)


func test_thread_completed_signal_fires_with_correct_args() -> void:
	_setup_ghost_thread()

	var received_thread_id: Array = [&""]
	var received_unlock_id: Array = [&""]
	EventBus.secret_thread_completed.connect(
		func(tid: StringName, reward_data: Dictionary) -> void:
			received_thread_id[0] = tid
			received_unlock_id[0] = StringName(
				str(reward_data.get("unlock_id", ""))
			)
	)

	_drive_thread_to_resolved()

	assert_eq(received_thread_id[0], GHOST_THREAD_ID)
	assert_eq(received_unlock_id[0], GHOST_UNLOCK_ID)


func test_ending_evaluator_tracks_ghost_thread_stat() -> void:
	_setup_ghost_thread()
	_drive_thread_to_resolved()

	var stat: float = _ending_evaluator.get_tracked_stat(
		&"ghost_tenant_thread_completed"
	)
	assert_eq(
		stat, 1.0,
		"ghost_tenant_thread_completed stat must be 1.0 after thread resolves"
	)


func test_secret_ending_selected_when_conditions_met() -> void:
	_seed_ghost_ending_stats()

	var selected: StringName = _ending_evaluator.evaluate()
	assert_eq(
		selected, GHOST_ENDING_ID,
		"evaluate() must select the_mall_between_the_walls when stats match"
	)


func test_secret_ending_prioritized_over_success_endings() -> void:
	var stats: Dictionary = _ending_evaluator.get_all_tracked_stats()
	stats["ghost_tenant_thread_completed"] = 1.0
	stats["owned_store_count_final"] = 5.0
	stats["cumulative_revenue"] = 50000.0
	stats["max_reputation_tier"] = 4.0
	stats["satisfaction_ratio"] = 0.90
	stats["days_survived"] = 30.0
	stats["final_cash"] = 5000.0
	stats["trigger_type_bankruptcy"] = 0.0
	_ending_evaluator.load_state({"stats": stats})

	var selected: StringName = _ending_evaluator.evaluate()
	assert_eq(
		selected, GHOST_ENDING_ID,
		"SECRET ending must take priority over prestige_champion (success)"
	)


func test_full_chain_ending_triggered_fires_with_secret_id() -> void:
	_setup_ghost_thread()
	_drive_thread_to_resolved()

	var stats: Dictionary = _ending_evaluator.get_all_tracked_stats()
	stats["owned_store_count_final"] = 5.0
	_ending_evaluator.load_state({"stats": stats})

	var triggered_id: Array = [&""]
	var triggered_stats: Array[Dictionary] = [{}]
	var on_triggered: Callable = func(
		id: StringName, fstats: Dictionary
	) -> void:
		triggered_id[0] = id
		triggered_stats[0] = fstats.duplicate()
	EventBus.ending_triggered.connect(on_triggered)

	EventBus.completion_reached.emit("time_limit")

	assert_eq(
		triggered_id[0], GHOST_ENDING_ID,
		"ending_triggered must fire with the_mall_between_the_walls"
	)

	var ending_data: Dictionary = _ending_evaluator.get_ending_data(
		GHOST_ENDING_ID
	)
	assert_eq(
		str(ending_data.get("category", "")), "secret",
		"Selected ending must have category 'secret'"
	)

	EventBus.ending_triggered.disconnect(on_triggered)


func test_full_chain_final_stats_contain_required_keys() -> void:
	_setup_ghost_thread()
	_drive_thread_to_resolved()

	var stats: Dictionary = _ending_evaluator.get_all_tracked_stats()
	stats["owned_store_count_final"] = 5.0
	_ending_evaluator.load_state({"stats": stats})

	var triggered_stats: Array[Dictionary] = [{}]
	var on_triggered: Callable = func(
		_id: StringName, fstats: Dictionary
	) -> void:
		triggered_stats[0] = fstats.duplicate()
	EventBus.ending_triggered.connect(on_triggered)

	EventBus.completion_reached.emit("time_limit")

	var ending_data: Dictionary = _ending_evaluator.get_ending_data(
		GHOST_ENDING_ID
	)
	var summary_keys: Variant = ending_data.get("stat_summary_keys", [])
	if summary_keys is Array:
		for key: Variant in summary_keys:
			assert_true(
				triggered_stats[0].has(str(key)),
				"final_stats must contain stat_summary_key: %s" % key
			)

	var core_keys: Array[String] = [
		"ghost_tenant_thread_completed",
		"owned_store_count_final",
		"days_survived",
		"cumulative_revenue",
		"secret_threads_completed",
	]
	for key: String in core_keys:
		assert_true(
			triggered_stats[0].has(key),
			"final_stats must contain tracked stat: %s" % key
		)

	EventBus.ending_triggered.disconnect(on_triggered)


func test_only_one_ending_triggered_fires() -> void:
	_setup_ghost_thread()
	_drive_thread_to_resolved()

	var stats: Dictionary = _ending_evaluator.get_all_tracked_stats()
	stats["owned_store_count_final"] = 5.0
	_ending_evaluator.load_state({"stats": stats})

	var fire_count: Array = [0]
	var on_triggered: Callable = func(
		_id: StringName, _stats: Dictionary
	) -> void:
		fire_count[0] += 1
	EventBus.ending_triggered.connect(on_triggered)

	EventBus.completion_reached.emit("time_limit")
	EventBus.completion_reached.emit("all_criteria")

	assert_eq(
		fire_count[0], 1,
		"ending_triggered must fire exactly once per run"
	)

	EventBus.ending_triggered.disconnect(on_triggered)


func test_mall_legend_redux_secret_ending_selectable() -> void:
	var stats: Dictionary = _ending_evaluator.get_all_tracked_stats()
	stats["secret_threads_completed"] = 4.0
	stats["cumulative_revenue"] = 25000.0
	stats["days_survived"] = 30.0
	stats["trigger_type_bankruptcy"] = 0.0
	_ending_evaluator.load_state({"stats": stats})

	var selected: StringName = _ending_evaluator.evaluate()
	assert_eq(
		selected, &"the_mall_legend_redux",
		"evaluate() must select the_mall_legend_redux when 4 threads + 25k revenue"
	)

	var ending_data: Dictionary = _ending_evaluator.get_ending_data(
		&"the_mall_legend_redux"
	)
	assert_eq(
		str(ending_data.get("category", "")), "secret",
		"the_mall_legend_redux must have category 'secret'"
	)


func test_ending_uses_real_config_with_secret_category() -> void:
	var ghost_data: Dictionary = _ending_evaluator.get_ending_data(
		GHOST_ENDING_ID
	)
	assert_false(
		ghost_data.is_empty(),
		"the_mall_between_the_walls must exist in endings_catalog"
	)
	assert_eq(
		str(ghost_data.get("category", "")), "secret",
		"the_mall_between_the_walls must have category 'secret'"
	)

	var legend_data: Dictionary = _ending_evaluator.get_ending_data(
		&"the_mall_legend_redux"
	)
	assert_false(
		legend_data.is_empty(),
		"the_mall_legend_redux must exist in endings_catalog"
	)
	assert_eq(
		str(legend_data.get("category", "")), "secret",
		"the_mall_legend_redux must have category 'secret'"
	)
