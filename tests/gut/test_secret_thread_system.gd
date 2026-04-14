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
	var completed_thread: StringName = &""
	var completed_unlock: StringName = &""
	EventBus.secret_thread_completed.connect(
		func(tid: StringName, unlock_id: StringName) -> void:
			completed_thread = tid
			completed_unlock = unlock_id
	)
	for day: int in range(1, 34):
		_system._on_day_started(day)
	assert_eq(
		completed_thread, &"the_slow_burn",
		"Completion signal should fire for the_slow_burn"
	)
	assert_eq(
		completed_unlock, &"",
		"Thread with no reward_unlock_id should emit empty StringName"
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
		SecretThreadSystem.ThreadPhase.ACTIVE
	)
	_system._on_day_started(2)
	assert_eq(
		_system.get_thread_phase("test_resettable"),
		SecretThreadSystem.ThreadPhase.REVEALED
	)
	_system._on_day_started(3)
	assert_eq(
		_system.get_thread_phase("test_resettable"),
		SecretThreadSystem.ThreadPhase.DORMANT,
		"Resettable thread should return to DORMANT after resolve"
	)


# --- Timeout ---


func test_timeout_emits_failed() -> void:
	_setup_with_defs([_resettable_def])
	var failed_id: StringName = &""
	EventBus.secret_thread_failed.connect(
		func(tid: StringName) -> void:
			failed_id = tid
	)
	for i: int in range(3):
		_system._on_item_sold("item_%d" % i, 10.0, "cards")
	_system._on_day_started(1)
	assert_eq(
		_system.get_thread_phase("test_resettable"),
		SecretThreadSystem.ThreadPhase.ACTIVE
	)
	_system._on_day_started(6)
	assert_eq(
		failed_id, &"test_resettable",
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
	var completed: bool = false
	EventBus.secret_thread_completed.connect(
		func(_tid: StringName, _unlock_id: StringName) -> void:
			completed = true
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
		completed,
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
	_system._on_day_started(1)
	assert_eq(
		_system.get_thread_phase("the_ghost_tenant"),
		SecretThreadSystem.ThreadPhase.WATCHING
	)
	_system._on_lease_completed(&"store_b", true, "")
	_system._on_day_started(2)
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
	var completed_unlock: StringName = &""
	EventBus.secret_thread_completed.connect(
		func(_tid: StringName, unlock_id: StringName) -> void:
			completed_unlock = unlock_id
	)
	for day: int in range(1, 8):
		_system._on_day_started(day)
	assert_eq(
		completed_unlock, &"extended_hours_unlock",
		"Should emit reward_unlock_id from thread def"
	)


func test_empty_reward_unlock_id_skips_grant() -> void:
	_setup_with_defs([_slow_burn_def])
	var completed_unlock: StringName = &"sentinel"
	EventBus.secret_thread_completed.connect(
		func(_tid: StringName, unlock_id: StringName) -> void:
			completed_unlock = unlock_id
	)
	for day: int in range(1, 34):
		_system._on_day_started(day)
	assert_eq(
		completed_unlock, &"",
		"Empty reward_unlock_id should emit empty StringName"
	)


func test_failed_thread_does_not_emit_completed() -> void:
	_setup_with_defs([_resettable_def])
	var completed: bool = false
	EventBus.secret_thread_completed.connect(
		func(_tid: StringName, _unlock_id: StringName) -> void:
			completed = true
	)
	for i: int in range(3):
		_system._on_item_sold("item_%d" % i, 10.0, "cards")
	_system._on_day_started(1)
	_system._on_day_started(6)
	assert_false(
		completed,
		"Timed-out thread should not emit secret_thread_completed"
	)
