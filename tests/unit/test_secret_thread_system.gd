## GUT unit tests for SecretThreadSystem — condition tracking, unlock detection, persistence.
extends GutTest


var _system: SecretThreadSystem

var _simple_def: Dictionary = {
	"id": "test_simple",
	"display_name": "Simple Thread",
	"resettable": false,
	"timeout_days": 0,
	"preconditions": [
		{"type": "day_reached", "value": 3},
	],
	"reveal_moment": "",
	"reward": {"type": "cash", "amount": 100.0},
}

var _multi_precondition_def: Dictionary = {
	"id": "test_multi",
	"display_name": "Multi Precondition",
	"resettable": false,
	"timeout_days": 0,
	"preconditions": [
		{"type": "day_reached", "value": 10},
		{"type": "signal_count", "signal": "item_sold", "threshold": 5},
	],
	"reveal_moment": "",
	"reward": {"type": "cash", "amount": 200.0},
}

var _cash_stat_def: Dictionary = {
	"id": "test_cash_stat",
	"display_name": "Cash Stat Thread",
	"resettable": false,
	"timeout_days": 0,
	"preconditions": [
		{"type": "stat_threshold", "stat": "player_cash", "threshold": 500.0},
	],
	"reveal_moment": "",
	"reward": {"type": "cash", "amount": 50.0},
}

var _unlock_def: Dictionary = {
	"id": "test_unlock",
	"display_name": "Unlock Thread",
	"resettable": false,
	"timeout_days": 0,
	"preconditions": [
		{"type": "day_reached", "value": 2},
	],
	"reveal_moment": "",
	"reward_unlock_id": "test_unlock_reward",
}

var _resettable_def: Dictionary = {
	"id": "test_resettable",
	"display_name": "Resettable Thread",
	"resettable": true,
	"timeout_days": 10,
	"preconditions": [
		{"type": "signal_count", "signal": "item_sold", "threshold": 2},
	],
	"reveal_moment": "",
	"reward": {"type": "cash", "amount": 25.0},
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


# --- Initialization ---


func test_all_threads_initialize_dormant() -> void:
	var defs: Array[Dictionary] = _all_json_defs()
	assert_true(defs.size() > 0, "Should load thread defs from JSON")
	_setup_with_defs(defs)
	for def: Dictionary in defs:
		var thread_id: String = str(def.get("id", ""))
		assert_eq(
			_system.get_thread_phase(thread_id),
			SecretThreadSystem.ThreadPhase.DORMANT,
			"Thread '%s' should start DORMANT" % thread_id
		)


func test_all_threads_initialize_with_step_index_zero() -> void:
	var defs: Array[Dictionary] = _all_json_defs()
	_setup_with_defs(defs)
	var save_data: Dictionary = _system.get_save_data()
	var states: Dictionary = save_data.get("thread_states", {})
	for thread_id: String in states:
		var state: Dictionary = states[thread_id]
		assert_eq(
			int(state.get("step_index", -1)), 0,
			"Thread '%s' step_index should be 0" % thread_id
		)


# --- Precondition gating ---


func test_thread_stays_dormant_until_all_preconditions_met() -> void:
	_setup_with_defs([_multi_precondition_def])
	for i: int in range(5):
		_system._on_item_sold("item_%d" % i, 10.0, "cards")
	assert_eq(
		_system.get_thread_phase("test_multi"),
		SecretThreadSystem.ThreadPhase.WATCHING,
		"With only signal_count met, should be WATCHING not ACTIVE"
	)


func test_thread_transitions_dormant_to_watching() -> void:
	_setup_with_defs([_simple_def])
	_system._on_day_started(1)
	assert_eq(
		_system.get_thread_phase("test_simple"),
		SecretThreadSystem.ThreadPhase.WATCHING,
		"Thread should move to WATCHING on first relevant signal"
	)


func test_thread_transitions_watching_to_active() -> void:
	_setup_with_defs([_simple_def])
	for day: int in range(1, 4):
		_system._on_day_started(day)
	assert_eq(
		_system.get_thread_phase("test_simple"),
		SecretThreadSystem.ThreadPhase.ACTIVE,
		"Thread should be ACTIVE when day_reached precondition met"
	)


func test_thread_transitions_active_to_completed() -> void:
	_setup_with_defs([_simple_def])
	for day: int in range(1, 6):
		_system._on_day_started(day)
	assert_eq(
		_system.get_thread_phase("test_simple"),
		SecretThreadSystem.ThreadPhase.RESOLVED,
		"Thread should reach RESOLVED after full lifecycle"
	)


# --- Completion signal ---


func test_secret_thread_completed_signal_emitted() -> void:
	_setup_with_defs([_simple_def])
	var completed_ids: Array[StringName] = []
	EventBus.secret_thread_completed.connect(
		func(tid: StringName, _reward_data: Dictionary) -> void:
			completed_ids.append(tid)
	)
	for day: int in range(1, 6):
		_system._on_day_started(day)
	assert_has(
		completed_ids, &"test_simple",
		"secret_thread_completed should emit for resolved thread"
	)


func test_completed_thread_ignores_further_triggers() -> void:
	_setup_with_defs([_simple_def])
	var emit_count: Array = [0]
	EventBus.secret_thread_completed.connect(
		func(_tid: StringName, _reward_data: Dictionary) -> void:
			emit_count[0] += 1
	)
	for day: int in range(1, 6):
		_system._on_day_started(day)
	assert_eq(emit_count[0], 1, "Should emit once during lifecycle")
	for day: int in range(6, 20):
		_system._on_day_started(day)
	assert_eq(
		emit_count[0], 1,
		"Should not re-emit after RESOLVED"
	)


# --- Save/Load ---


func test_get_save_data_includes_thread_states() -> void:
	_setup_with_defs([_simple_def, _multi_precondition_def])
	_system._on_day_started(1)
	var save_data: Dictionary = _system.get_save_data()
	assert_true(
		save_data.has("thread_states"),
		"Save data should have 'thread_states' key"
	)
	assert_true(
		save_data.has("signal_counts"),
		"Save data should have 'signal_counts' key"
	)
	var states: Dictionary = save_data["thread_states"]
	assert_true(
		states.has("test_simple"),
		"thread_states should contain thread entries"
	)
	var entry: Dictionary = states["test_simple"]
	assert_true(
		entry.has("step_index"),
		"Thread entry should include step_index"
	)
	assert_true(
		entry.has("watch_counters"),
		"Thread entry should include watch_counters"
	)


func test_load_state_restores_watching_state() -> void:
	_setup_with_defs([_simple_def])
	var save_data: Dictionary = {
		"thread_states": {
			"test_simple": {
				"phase": SecretThreadSystem.ThreadPhase.WATCHING,
				"step_index": 0,
				"activated_day": 0,
				"revealed_day": 0,
				"watch_counters": {"day_started": 1},
			},
		},
		"signal_counts": {"day_started": 1},
		"owned_store_count": 0,
	}
	_system.load_state(save_data)
	assert_eq(
		_system.get_thread_phase("test_simple"),
		SecretThreadSystem.ThreadPhase.WATCHING,
		"load_state should restore WATCHING phase"
	)


func test_load_state_restores_step_index() -> void:
	_setup_with_defs([_resettable_def])
	var save_data: Dictionary = {
		"thread_states": {
			"test_resettable": {
				"phase": SecretThreadSystem.ThreadPhase.ACTIVE,
				"step_index": 2,
				"activated_day": 5,
				"revealed_day": 0,
				"watch_counters": {"item_sold": 3},
			},
		},
		"signal_counts": {"item_sold": 3},
		"owned_store_count": 0,
	}
	_system.load_state(save_data)
	var restored: Dictionary = _system.get_save_data()
	var thread_data: Dictionary = restored["thread_states"]["test_resettable"]
	assert_eq(
		int(thread_data.get("step_index", -1)), 2,
		"load_state should restore step_index"
	)


func test_load_state_does_not_emit_signals() -> void:
	_setup_with_defs([_simple_def])
	var emitted: Array = [false]
	EventBus.secret_thread_state_changed.connect(
		func(
			_tid: StringName, _old: StringName, _new: StringName
		) -> void:
			emitted[0] = true
	)
	EventBus.secret_thread_completed.connect(
		func(_tid: StringName, _reward_data: Dictionary) -> void:
			emitted[0] = true
	)
	var save_data: Dictionary = {
		"thread_states": {
			"test_simple": {
				"phase": SecretThreadSystem.ThreadPhase.RESOLVED,
				"step_index": 0,
				"activated_day": 3,
				"revealed_day": 4,
				"watch_counters": {},
			},
		},
		"signal_counts": {},
		"owned_store_count": 0,
	}
	_system.load_state(save_data)
	assert_false(
		emitted[0],
		"load_state should not emit any signals"
	)


# --- Reward unlock wiring ---


func test_completion_emits_reward_unlock_id() -> void:
	_setup_with_defs([_unlock_def])
	var received_unlock: Array = [&""]
	EventBus.secret_thread_completed.connect(
		func(_tid: StringName, reward_data: Dictionary) -> void:
			received_unlock[0] = StringName(
				str(reward_data.get("unlock_id", ""))
			)
	)
	for day: int in range(1, 5):
		_system._on_day_started(day)
	assert_eq(
		received_unlock[0], &"test_unlock_reward",
		"Should emit reward_unlock_id from thread definition"
	)


# --- Stat threshold precondition ---


func test_stat_threshold_precondition_gates_activation() -> void:
	_setup_with_defs([_cash_stat_def])
	_system._player_cash = 100.0
	_system._on_day_started(1)
	assert_ne(
		_system.get_thread_phase("test_cash_stat"),
		SecretThreadSystem.ThreadPhase.ACTIVE,
		"Should not activate when cash below threshold"
	)
	_system._player_cash = 500.0
	_system._on_day_started(2)
	assert_eq(
		_system.get_thread_phase("test_cash_stat"),
		SecretThreadSystem.ThreadPhase.ACTIVE,
		"Should activate when cash meets threshold"
	)


# --- Multi-precondition activation ---


func test_multi_precondition_requires_all_met() -> void:
	_setup_with_defs([_multi_precondition_def])
	for day: int in range(1, 11):
		_system._on_day_started(day)
	assert_eq(
		_system.get_thread_phase("test_multi"),
		SecretThreadSystem.ThreadPhase.WATCHING,
		"Day reached alone should not activate"
	)
	for i: int in range(5):
		_system._on_item_sold("item_%d" % i, 10.0, "cards")
	assert_eq(
		_system.get_thread_phase("test_multi"),
		SecretThreadSystem.ThreadPhase.ACTIVE,
		"Both preconditions met should activate"
	)


# --- Resettable thread cycle ---


func test_resettable_thread_returns_to_dormant() -> void:
	_setup_with_defs([_resettable_def])
	for i: int in range(2):
		_system._on_item_sold("item_%d" % i, 10.0, "cards")
	# After item_sold events the thread is ACTIVE with activated_day=0.
	# day_started(1) auto-reveals (day 1 > 0). day_started(2) resolves; since
	# the def is resettable, phase transitions back to DORMANT.
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


# --- State changed signal tracks transitions ---


func test_state_changed_signal_tracks_all_transitions() -> void:
	_setup_with_defs([_simple_def])
	var phases: Array[StringName] = []
	EventBus.secret_thread_state_changed.connect(
		func(
			_tid: StringName, _old: StringName, new_p: StringName
		) -> void:
			phases.append(new_p)
	)
	for day: int in range(1, 6):
		_system._on_day_started(day)
	assert_eq(phases.size(), 4, "Should have 4 transitions")
	assert_eq(phases[0], &"WATCHING")
	assert_eq(phases[1], &"ACTIVE")
	assert_eq(phases[2], &"REVEALED")
	assert_eq(phases[3], &"RESOLVED")
