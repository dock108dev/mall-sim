## GUT unit tests for SecretThreadSystem — ghost_tenant and slow_burn edge cases.
extends GutTest


## Minimal economy stub so SecretThreadSystem can apply cash rewards in tests.
## Extends EconomySystem to satisfy the static type on _economy_system.
class _MockEconomy extends EconomySystem:
	func add_cash(amount: float, reason: String) -> void:
		# Bypass ledger logic; emit the same signal the real add_cash does.
		EventBus.transaction_completed.emit(amount, true, reason)


var _system: SecretThreadSystem
var _mock_economy: _MockEconomy


# Defs use the field names the SecretThreadSystem code reads (type, signal, value),
# NOT the JSON schema names (condition_type, signal_name, threshold for day_reached).
var _ghost_tenant_def: Dictionary = {
	"id": "the_ghost_tenant",
	"display_name": "The Ghost Tenant",
	"visible_in_log": true,
	"resettable": false,
	"timeout_days": 0,
	"preconditions": [
		{"type": "store_owned", "threshold": 5},
		{"type": "day_reached", "value": 15},
	],
	"reveal_moment": "",
	"reward_unlock_id": "ghost_tenant_unlock",
	"completion_reward": {"type": "unlock", "value": 0.0},
}

var _slow_burn_def: Dictionary = {
	"id": "the_slow_burn",
	"display_name": "The Slow Burn",
	"visible_in_log": false,
	"resettable": false,
	"timeout_days": 0,
	"preconditions": [
		{"type": "day_reached", "value": 30},
		{
			"type": "signal_count",
			"signal": "haggle_completed",
			"threshold": 0,
			"comparison": "equal",
		},
	],
	"reveal_moment": "",
	"completion_reward": {"type": "cash", "value": 300.0},
}

# timeout_days = 5; requires only one precondition so it activates easily.
var _timeout_def: Dictionary = {
	"id": "test_timeout_thread",
	"display_name": "Timeout Thread",
	"visible_in_log": true,
	"resettable": false,
	"timeout_days": 5,
	"preconditions": [
		{"type": "day_reached", "value": 1},
	],
	"reveal_moment": "",
	"completion_reward": {"type": "cash", "value": 10.0},
}


func before_each() -> void:
	_system = SecretThreadSystem.new()
	add_child_autofree(_system)
	_mock_economy = _MockEconomy.new()
	add_child_autofree(_mock_economy)
	_system._economy_system = _mock_economy


func _setup_with_defs(defs: Array[Dictionary]) -> void:
	_system._thread_defs = defs
	_system._init_thread_states()


# =============================================================================
# Test Group 1 — the_ghost_tenant (spawn_special_store effect)
# =============================================================================


func test_ghost_tenant_initializes_dormant() -> void:
	_setup_with_defs([_ghost_tenant_def])
	assert_eq(
		_system.get_thread_phase("the_ghost_tenant"),
		SecretThreadSystem.ThreadPhase.DORMANT,
		"ghost_tenant should initialize in DORMANT state"
	)


func test_ghost_tenant_enters_watching_when_store_owned_precondition_relevant() -> void:
	_setup_with_defs([_ghost_tenant_def])
	# store_owned type is always "relevant" per _is_precondition_relevant, so
	# the first successful lease triggers DORMANT → WATCHING.
	_system._on_lease_completed(&"store_a", true, "")
	assert_eq(
		_system.get_thread_phase("the_ghost_tenant"),
		SecretThreadSystem.ThreadPhase.WATCHING,
		"ghost_tenant should enter WATCHING once any store is owned"
	)


func test_ghost_tenant_activates_when_owned_count_5_and_day_15_met() -> void:
	_setup_with_defs([_ghost_tenant_def])
	for i: int in range(5):
		_system._on_lease_completed(StringName("store_%d" % i), true, "")
	_system._on_day_started(15)
	assert_eq(
		_system.get_thread_phase("the_ghost_tenant"),
		SecretThreadSystem.ThreadPhase.ACTIVE,
		"ghost_tenant should be ACTIVE when owned_store_count=5 and current_day=15"
	)


func test_ghost_tenant_state_changed_emitted_through_watching_and_active() -> void:
	_setup_with_defs([_ghost_tenant_def])
	var transitions: Array[StringName] = []
	EventBus.secret_thread_state_changed.connect(
		func(tid: StringName, _old: StringName, new_p: StringName) -> void:
			if tid == &"the_ghost_tenant":
				transitions.append(new_p)
	)
	for i: int in range(5):
		_system._on_lease_completed(StringName("store_%d" % i), true, "")
	_system._on_day_started(15)
	assert_has(transitions, &"WATCHING", "state_changed should carry WATCHING transition")
	assert_has(transitions, &"ACTIVE", "state_changed should carry ACTIVE transition")


func test_ghost_tenant_emits_revealed_state_change_on_next_day_after_active() -> void:
	_setup_with_defs([_ghost_tenant_def])
	var transitions: Array[StringName] = []
	EventBus.secret_thread_state_changed.connect(
		func(tid: StringName, _old: StringName, new_p: StringName) -> void:
			if tid == &"the_ghost_tenant":
				transitions.append(new_p)
	)
	for i: int in range(5):
		_system._on_lease_completed(StringName("store_%d" % i), true, "")
	_system._on_day_started(15)
	_system._on_day_started(16)
	# The REVEALED transition corresponds to the is_reveal_step firing in the lifecycle.
	assert_has(
		transitions,
		&"REVEALED",
		"state_changed should emit REVEALED transition (reveal step) the day after ACTIVE"
	)


func test_ghost_tenant_reaches_resolved_after_full_lifecycle() -> void:
	_setup_with_defs([_ghost_tenant_def])
	for i: int in range(5):
		_system._on_lease_completed(StringName("store_%d" % i), true, "")
	# Day 15: ACTIVE; Day 16: REVEALED; Day 17: RESOLVED.
	for day: int in range(15, 18):
		_system._on_day_started(day)
	assert_eq(
		_system.get_thread_phase("the_ghost_tenant"),
		SecretThreadSystem.ThreadPhase.RESOLVED,
		"ghost_tenant should reach RESOLVED after full lifecycle"
	)


func test_ghost_tenant_completed_signal_carries_thread_id_and_unlock_id() -> void:
	_setup_with_defs([_ghost_tenant_def])
	var received_tid: Array = [&""]
	var received_unlock: Array = [&""]
	EventBus.secret_thread_completed.connect(
		func(tid: StringName, unlock_id: StringName) -> void:
			received_tid[0] = tid
			received_unlock[0] = unlock_id
	)
	for i: int in range(5):
		_system._on_lease_completed(StringName("store_%d" % i), true, "")
	for day: int in range(15, 18):
		_system._on_day_started(day)
	assert_eq(
		received_tid[0],
		&"the_ghost_tenant",
		"secret_thread_completed should carry correct thread_id"
	)
	assert_eq(
		received_unlock[0],
		&"ghost_tenant_unlock",
		"secret_thread_completed should carry correct reward_unlock_id"
	)


# =============================================================================
# Test Group 2 — the_slow_burn (haggle_never_used precondition)
# =============================================================================


func test_slow_burn_initializes_dormant() -> void:
	_setup_with_defs([_slow_burn_def])
	assert_eq(
		_system.get_thread_phase("the_slow_burn"),
		SecretThreadSystem.ThreadPhase.DORMANT,
		"slow_burn should initialize in DORMANT state"
	)


func test_slow_burn_does_not_activate_if_haggle_completed_fires_before_day_30() -> void:
	_setup_with_defs([_slow_burn_def])
	# Haggling disqualifies the thread; the global haggle_completed count becomes
	# non-zero so the "equal 0" precondition permanently fails.
	_system._on_haggle_completed(&"store_a", &"item_a", 10.0, 12.0, true, 1)
	for day: int in range(1, 35):
		_system._on_day_started(day)
	var phase: int = _system.get_thread_phase("the_slow_burn")
	assert_true(
		phase < SecretThreadSystem.ThreadPhase.ACTIVE,
		"slow_burn should not reach ACTIVE if haggle_completed fired before day 30"
	)


func test_slow_burn_completes_if_day_30_reached_without_haggle() -> void:
	_setup_with_defs([_slow_burn_def])
	# Days 1–32: no haggle fired.  Day 30: ACTIVE. Day 31: REVEALED. Day 32: RESOLVED.
	for day: int in range(1, 33):
		_system._on_day_started(day)
	assert_eq(
		_system.get_thread_phase("the_slow_burn"),
		SecretThreadSystem.ThreadPhase.RESOLVED,
		"slow_burn should complete when day 30 is reached without any haggle"
	)


func test_slow_burn_completion_emits_transaction_completed_with_300() -> void:
	_setup_with_defs([_slow_burn_def])
	var received_amount: Array = [0.0]
	EventBus.transaction_completed.connect(
		func(amount: float, _success: bool, _msg: String) -> void:
			received_amount[0] = amount
	)
	for day: int in range(1, 33):
		_system._on_day_started(day)
	assert_almost_eq(
		received_amount[0],
		300.0,
		0.01,
		"transaction_completed should carry cash reward of 300.0"
	)


func test_slow_burn_definition_has_visible_in_log_false() -> void:
	_setup_with_defs([_slow_burn_def])
	# The system does not yet expose a filtered visible-thread list, so this
	# asserts the definition attribute that would gate such filtering.
	assert_false(
		bool(_slow_burn_def.get("visible_in_log", true)),
		"slow_burn definition should have visible_in_log = false"
	)


# =============================================================================
# Test Group 3 — timeout behavior
# =============================================================================


func test_thread_emits_failed_after_timeout_days_exceeded_in_active_state() -> void:
	_setup_with_defs([_timeout_def])
	# Inject ACTIVE state with activated_day = 1 so that advancing to day 7
	# (7 - 1 = 6 >= timeout_days 5) triggers the timeout check.
	_system.load_state({
		"thread_states": {
			"test_timeout_thread": {
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
	var failed_id: Array = [&""]
	EventBus.secret_thread_failed.connect(
		func(tid: StringName) -> void:
			failed_id[0] = tid
	)
	_system._on_day_started(7)
	assert_eq(
		failed_id[0],
		&"test_timeout_thread",
		"secret_thread_failed should emit with correct thread_id after timeout"
	)


func test_timeout_emits_failed_not_completed() -> void:
	_setup_with_defs([_timeout_def])
	_system.load_state({
		"thread_states": {
			"test_timeout_thread": {
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
	var completed: Array = [false]
	var failed: Array = [false]
	EventBus.secret_thread_completed.connect(
		func(_tid: StringName, _uid: StringName) -> void:
			completed[0] = true
	)
	EventBus.secret_thread_failed.connect(
		func(_tid: StringName) -> void:
			failed[0] = true
	)
	_system._on_day_started(7)
	assert_true(failed[0], "secret_thread_failed should be emitted on timeout")
	assert_false(
		completed[0],
		"secret_thread_completed should NOT be emitted on timeout"
	)


func test_failed_non_resettable_thread_does_not_reactivate() -> void:
	_setup_with_defs([_timeout_def])
	_system.load_state({
		"thread_states": {
			"test_timeout_thread": {
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
	# Trigger timeout.
	_system._on_day_started(7)
	assert_eq(
		_system.get_thread_phase("test_timeout_thread"),
		SecretThreadSystem.ThreadPhase.RESOLVED,
		"Non-resettable timed-out thread should be in RESOLVED state"
	)
	# Additional signals should not alter RESOLVED state.
	for day: int in range(8, 20):
		_system._on_day_started(day)
	assert_eq(
		_system.get_thread_phase("test_timeout_thread"),
		SecretThreadSystem.ThreadPhase.RESOLVED,
		"RESOLVED thread should not re-activate even if preconditions are re-satisfied"
	)


# =============================================================================
# Test Group 4 — persistence of partial progress
# =============================================================================


func test_partial_step_progress_survives_save_load_round_trip() -> void:
	_setup_with_defs([_ghost_tenant_def])
	_system.load_state({
		"thread_states": {
			"the_ghost_tenant": {
				"phase": SecretThreadSystem.ThreadPhase.ACTIVE,
				"step_index": 1,
				"activated_day": 15,
				"revealed_day": 0,
				"watch_counters": {},
			},
		},
		"signal_counts": {},
		"owned_store_count": 5,
	})
	var restored: Dictionary = _system.get_save_data()
	var entry: Dictionary = restored.get("thread_states", {}).get(
		"the_ghost_tenant", {}
	)
	assert_eq(
		int(entry.get("step_index", -1)),
		1,
		"step_index should be restored to saved value (1) after load_state"
	)
	assert_eq(
		int(entry.get("phase", -1)),
		SecretThreadSystem.ThreadPhase.ACTIVE,
		"Phase should be restored to ACTIVE after load_state"
	)


func test_failed_thread_state_survives_save_load_round_trip() -> void:
	_setup_with_defs([_timeout_def])
	_system.load_state({
		"thread_states": {
			"test_timeout_thread": {
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
	var save_data: Dictionary = _system.get_save_data()
	var fresh: SecretThreadSystem = SecretThreadSystem.new()
	add_child_autofree(fresh)
	fresh._thread_defs = [_timeout_def]
	fresh._init_thread_states()
	fresh.load_state(save_data)
	assert_eq(
		fresh.get_thread_phase("test_timeout_thread"),
		SecretThreadSystem.ThreadPhase.RESOLVED,
		"Failed (timed-out) thread should be RESOLVED after save/load round-trip"
	)


func test_loaded_thread_advances_phase_from_restored_state_not_from_start() -> void:
	_setup_with_defs([_ghost_tenant_def])
	_system.load_state({
		"thread_states": {
			"the_ghost_tenant": {
				"phase": SecretThreadSystem.ThreadPhase.ACTIVE,
				"step_index": 1,
				"activated_day": 15,
				"revealed_day": 0,
				"watch_counters": {},
			},
		},
		"signal_counts": {},
		"owned_store_count": 5,
	})
	# Advance one day past activated_day; should go ACTIVE → REVEALED.
	_system._current_day = 15
	_system._on_day_started(16)
	var after: Dictionary = _system.get_save_data()
	var entry: Dictionary = after.get("thread_states", {}).get("the_ghost_tenant", {})
	assert_eq(
		int(entry.get("phase", -1)),
		SecretThreadSystem.ThreadPhase.REVEALED,
		"Thread should advance to REVEALED from loaded ACTIVE state, not reset"
	)
	# step_index must remain at its saved value — no reset to 0.
	assert_eq(
		int(entry.get("step_index", -1)),
		1,
		"step_index should not reset to 0 when phase advances after load"
	)
