## Tests for SecretThreadSystem: phase transitions, preconditions, save/load.
extends GutTest


var _system: SecretThreadSystem

var _slow_burn_def: Dictionary = {
	"id": "the_slow_burn",
	"display_name": "The Slow Burn",
	"resettable": false,
	"timeout_days": 0,
	"preconditions": [
		{
			"type": "day_reached",
			"value": 31,
		},
		{
			"type": "signal_count",
			"signal": "haggle_completed",
			"threshold": 0,
			"comparison": "equal",
		},
	],
	"reveal_moment": "ambient_management_letter",
	"reward": {"type": "cash", "amount": 300.0},
}

var _unlock_reward_def: Dictionary = {
	"id": "the_unlockable",
	"display_name": "Unlock Thread",
	"resettable": false,
	"timeout_days": 0,
	"preconditions": [
		{
			"type": "day_reached",
			"value": 5,
		},
	],
	"reveal_moment": "",
	"reward_unlock_id": "extended_hours_unlock",
}

var _resettable_def: Dictionary = {
	"id": "test_resettable",
	"display_name": "Resettable Thread",
	"resettable": true,
	"timeout_days": 5,
	"preconditions": [
		{
			"type": "signal_count",
			"signal": "item_sold",
			"threshold": 3,
		},
	],
	"reveal_moment": "ambient_test",
	"reward": {"type": "cash", "amount": 50.0},
}


func before_each() -> void:
	_system = SecretThreadSystem.new()
	add_child_autofree(_system)


func _setup_with_defs(defs: Array[Dictionary]) -> void:
	_system._thread_defs = defs
	_system._init_thread_states()


func _all_json_defs() -> Array[Dictionary]:
	var file: FileAccess = FileAccess.open(
		"res://game/content/meta/secret_threads.json", FileAccess.READ
	)
	if not file:
		return [] as Array[Dictionary]
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		var result: Array[Dictionary] = []
		for entry: Variant in (parsed as Array):
			if entry is Dictionary:
				result.append(entry as Dictionary)
		return result
	return [] as Array[Dictionary]


# --- Phase transitions ---


func test_threads_start_dormant() -> void:
	_setup_with_defs([_slow_burn_def])
	assert_eq(
		_system.get_thread_phase("the_slow_burn"),
		SecretThreadSystem.ThreadPhase.DORMANT,
		"Threads should start DORMANT"
	)


func test_dormant_to_watching_on_first_precondition() -> void:
	_setup_with_defs([_slow_burn_def])
	_system._on_day_started(1)
	assert_eq(
		_system.get_thread_phase("the_slow_burn"),
		SecretThreadSystem.ThreadPhase.WATCHING,
		"Thread should move to WATCHING on first relevant signal"
	)


func test_watching_stays_until_preconditions_met() -> void:
	_setup_with_defs([_slow_burn_def])
	for day: int in range(1, 30):
		_system._on_day_started(day)
	assert_eq(
		_system.get_thread_phase("the_slow_burn"),
		SecretThreadSystem.ThreadPhase.WATCHING,
		"Thread should stay WATCHING until all preconditions met"
	)


func test_watching_to_active_when_all_preconditions_met() -> void:
	_setup_with_defs([_slow_burn_def])
	for day: int in range(1, 32):
		_system._on_day_started(day)
	assert_eq(
		_system.get_thread_phase("the_slow_burn"),
		SecretThreadSystem.ThreadPhase.ACTIVE,
		"Thread should be ACTIVE when day >= 31 and no haggles"
	)


func test_active_to_revealed_next_day() -> void:
	_setup_with_defs([_slow_burn_def])
	for day: int in range(1, 33):
		_system._on_day_started(day)
	assert_eq(
		_system.get_thread_phase("the_slow_burn"),
		SecretThreadSystem.ThreadPhase.REVEALED,
		"Thread should be REVEALED day after activation"
	)


func test_revealed_to_resolved_next_day() -> void:
	_setup_with_defs([_slow_burn_def])
	for day: int in range(1, 34):
		_system._on_day_started(day)
	assert_eq(
		_system.get_thread_phase("the_slow_burn"),
		SecretThreadSystem.ThreadPhase.RESOLVED,
		"Thread should be RESOLVED day after reveal"
	)


func test_slow_burn_completes_full_lifecycle() -> void:
	_setup_with_defs([_slow_burn_def])
	var completed_thread: Array = [&""]
	var completed_reward: Array = [{}]
	EventBus.secret_thread_completed.connect(
		func(tid: StringName, reward_data: Dictionary) -> void:
			completed_thread[0] = tid
			completed_reward[0] = reward_data
	)
	for day: int in range(1, 34):
		_system._on_day_started(day)
	assert_eq(
		completed_thread[0], &"the_slow_burn",
		"Completion signal should fire for the_slow_burn"
	)
	assert_eq(
		str((completed_reward[0] as Dictionary).get("unlock_id", "")), "",
		"Thread with no reward_unlock_id should omit unlock_id"
	)


func test_json_slow_burn_completes_when_day_31_and_no_haggles() -> void:
	var defs: Array[Dictionary] = _all_json_defs()
	var slow_burn: Dictionary = {}
	for def: Dictionary in defs:
		if str(def.get("id", "")) == "the_slow_burn":
			slow_burn = def
			break
	assert_false(slow_burn.is_empty(), "secret_threads.json must define the_slow_burn")
	_setup_with_defs([slow_burn])
	for day: int in range(1, 32):
		_system._on_day_started(day)
	assert_eq(
		_system.get_thread_phase("the_slow_burn"),
		SecretThreadSystem.ThreadPhase.ACTIVE,
		"the_slow_burn should activate at day >= 31 when haggle count is 0"
	)


func test_slow_burn_fails_if_haggle_occurred() -> void:
	_setup_with_defs([_slow_burn_def])
	_system._on_day_started(1)
	_system._on_haggle_completed(&"", &"test_item", 5.0, 10.0, true, 1)
	for day: int in range(2, 35):
		_system._on_day_started(day)
	assert_ne(
		_system.get_thread_phase("the_slow_burn"),
		SecretThreadSystem.ThreadPhase.RESOLVED,
		"Thread should not resolve if haggle occurred"
	)


# --- Resettable threads ---


func test_resettable_returns_to_dormant() -> void:
	_setup_with_defs([_resettable_def])
	for i: int in range(3):
		_system._on_item_sold("item_%d" % i, 10.0, "cards")
	_system._on_day_started(1)
	assert_eq(
		_system.get_thread_phase("test_resettable"),
		SecretThreadSystem.ThreadPhase.REVEALED
	)
	_system._on_day_started(2)
	assert_eq(
		_system.get_thread_phase("test_resettable"),
		SecretThreadSystem.ThreadPhase.DORMANT,
		"Resettable thread should return to DORMANT after resolve"
	)


# --- Timeout ---


func test_timeout_emits_failed() -> void:
	_setup_with_defs([_resettable_def])
	var failed_id: Array = [&""]
	EventBus.secret_thread_failed.connect(
		func(tid: StringName) -> void:
			failed_id[0] = tid
	)
	_system.load_state({
		"thread_states": {
			"test_resettable": {
				"phase": SecretThreadSystem.ThreadPhase.ACTIVE,
				"step_index": 0,
				"activated_day": 1,
				"revealed_day": 0,
				"watch_counters": {},
			},
		},
		"signal_counts": {"day_started": 1},
		"owned_store_count": 0,
	})
	_system._on_day_started(7)
	assert_eq(
		failed_id[0], &"test_resettable",
		"Timeout should emit secret_thread_failed"
	)
	assert_eq(
		_system.get_thread_phase("test_resettable"),
		SecretThreadSystem.ThreadPhase.DORMANT,
		"Resettable timed-out thread should return to DORMANT"
	)


# --- State change signal ---


func test_state_changed_signal_fires() -> void:
	_setup_with_defs([_slow_burn_def])
	var transitions: Array[Dictionary] = []
	EventBus.secret_thread_state_changed.connect(
		func(
			tid: StringName, old_p: StringName, new_p: StringName
		) -> void:
			transitions.append({
				"id": tid, "old": old_p, "new": new_p,
			})
	)
	_system._on_day_started(1)
	assert_eq(transitions.size(), 1)
	assert_eq(
		transitions[0]["new"], &"WATCHING",
		"First transition should be to WATCHING"
	)


# --- Save/Load ---


func test_save_load_roundtrip() -> void:
	_setup_with_defs([_slow_burn_def])
	for day: int in range(1, 32):
		_system._on_day_started(day)
	var save_data: Dictionary = _system.get_save_data()
	assert_true(
		save_data.has("thread_states"),
		"Save data should have thread_states"
	)
	var thread_data: Dictionary = save_data["thread_states"]
	assert_true(
		thread_data.has("the_slow_burn"),
		"Save data should be keyed by thread_id"
	)
	var saved_state: Dictionary = thread_data["the_slow_burn"]
	assert_eq(
		saved_state.get("phase", -1),
		SecretThreadSystem.ThreadPhase.ACTIVE
	)
	assert_true(
		saved_state.has("step_index"),
		"Save state should include step_index"
	)
	assert_true(
		saved_state.has("watch_counters"),
		"Save state should include watch_counters"
	)


func test_load_restores_phase() -> void:
	_setup_with_defs([_slow_burn_def])
	var save_data: Dictionary = {
		"thread_states": {
			"the_slow_burn": {
				"phase": SecretThreadSystem.ThreadPhase.REVEALED,
				"step_index": 0,
				"activated_day": 31,
				"revealed_day": 32,
				"watch_counters": {},
			},
		},
		"signal_counts": {"day_started": 32},
		"owned_store_count": 0,
	}
	_system.load_state(save_data)
	assert_eq(
		_system.get_thread_phase("the_slow_burn"),
		SecretThreadSystem.ThreadPhase.REVEALED,
		"Load should restore phase without re-emitting signals"
	)


func test_load_does_not_emit_completion() -> void:
	_setup_with_defs([_slow_burn_def])
	var completed: Array = [false]
	EventBus.secret_thread_completed.connect(
		func(_tid: StringName, _reward_data: Dictionary) -> void:
			completed[0] = true
	)
	var save_data: Dictionary = {
		"thread_states": {
			"the_slow_burn": {
				"phase": SecretThreadSystem.ThreadPhase.RESOLVED,
				"step_index": 0,
				"activated_day": 31,
				"revealed_day": 32,
				"watch_counters": {},
			},
		},
		"signal_counts": {},
		"owned_store_count": 0,
	}
	_system.load_state(save_data)
	assert_false(
		completed[0],
		"Load should not re-emit completion signals"
	)


# --- Store owned precondition ---


func test_store_owned_precondition() -> void:
	var ghost_def: Dictionary = {
		"id": "the_ghost_tenant",
		"display_name": "Ghost Tenant",
		"resettable": false,
		"timeout_days": 0,
		"preconditions": [
			{"type": "store_owned", "threshold": 2},
		],
		"reveal_moment": "ambient_phantom",
		"reward": {"type": "none", "amount": 0.0},
	}
	_setup_with_defs([ghost_def])
	_system._on_lease_completed(&"store_a", true, "")
	assert_eq(
		_system.get_thread_phase("the_ghost_tenant"),
		SecretThreadSystem.ThreadPhase.WATCHING
	)
	_system._on_lease_completed(&"store_b", true, "")
	assert_eq(
		_system.get_thread_phase("the_ghost_tenant"),
		SecretThreadSystem.ThreadPhase.ACTIVE,
		"Should activate when enough stores owned"
	)


# --- Unknown thread ---


func test_unknown_thread_returns_dormant() -> void:
	_setup_with_defs([_slow_burn_def])
	assert_eq(
		_system.get_thread_phase("nonexistent"),
		SecretThreadSystem.ThreadPhase.DORMANT
	)


# --- Unlock wiring ---


func test_completed_thread_emits_reward_unlock_id() -> void:
	_setup_with_defs([_unlock_reward_def])
	var completed_unlock: Array = [&""]
	EventBus.secret_thread_completed.connect(
		func(_tid: StringName, reward_data: Dictionary) -> void:
			completed_unlock[0] = StringName(
				str(reward_data.get("unlock_id", ""))
			)
	)
	for day: int in range(1, 8):
		_system._on_day_started(day)
	assert_eq(
		completed_unlock[0], &"extended_hours_unlock",
		"Should emit reward_unlock_id from thread def"
	)


func test_empty_reward_unlock_id_skips_grant() -> void:
	_setup_with_defs([_slow_burn_def])
	var completed_unlock: Array = [&"sentinel"]
	EventBus.secret_thread_completed.connect(
		func(_tid: StringName, reward_data: Dictionary) -> void:
			completed_unlock[0] = StringName(
				str(reward_data.get("unlock_id", ""))
			)
	)
	for day: int in range(1, 34):
		_system._on_day_started(day)
	assert_eq(
		completed_unlock[0], &"",
		"Empty reward_unlock_id should emit empty StringName"
	)


func test_failed_thread_does_not_emit_completed() -> void:
	_setup_with_defs([_resettable_def])
	var completed: Array = [false]
	EventBus.secret_thread_completed.connect(
		func(_tid: StringName, _reward_data: Dictionary) -> void:
			completed[0] = true
	)
	_system.load_state({
		"thread_states": {
			"test_resettable": {
				"phase": SecretThreadSystem.ThreadPhase.ACTIVE,
				"step_index": 0,
				"activated_day": 1,
				"revealed_day": 0,
				"watch_counters": {},
			},
		},
		"signal_counts": {"day_started": 1},
		"owned_store_count": 0,
	})
	_system._on_day_started(7)
	assert_false(
		completed[0],
		"Timed-out thread should not emit secret_thread_completed"
	)
