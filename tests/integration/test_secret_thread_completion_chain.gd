## Integration test — SecretThreadSystem RESOLVED completion chain:
## thread_completed → UnlockSystemSingleton.grant_unlock → unlock_granted signal.
class_name TestSecretThreadCompletionChain
extends GutTest


const THREAD_ID: StringName = &"test_thread"
const UNLOCK_ID: StringName = &"test_unlock"
const FAIL_THREAD_ID: StringName = &"fail_thread"
const NO_REWARD_THREAD_ID: StringName = &"no_reward_thread"

var _thread_system: SecretThreadSystem
var _unlock_system: UnlockSystem

## Thread with reward_unlock_id — drives the full DORMANT→RESOLVED lifecycle.
var _complete_def: Dictionary = {
	"id": "test_thread",
	"display_name": "Test Thread",
	"resettable": false,
	"timeout_days": 0,
	"preconditions": [{"type": "day_reached", "value": 2}],
	"reveal_moment": "",
	"reward_unlock_id": "test_unlock",
}

## Thread that times out (timeout_days=1) before reaching REVEALED.
var _fail_def: Dictionary = {
	"id": "fail_thread",
	"display_name": "Fail Thread",
	"resettable": false,
	"timeout_days": 1,
	"preconditions": [{"type": "day_reached", "value": 1}],
	"reveal_moment": "",
	"reward_unlock_id": "test_unlock",
}

## Thread with no reward_unlock_id.
var _no_reward_def: Dictionary = {
	"id": "no_reward_thread",
	"display_name": "No Reward Thread",
	"resettable": false,
	"timeout_days": 0,
	"preconditions": [{"type": "day_reached", "value": 2}],
	"reveal_moment": "",
	"reward_unlock_id": "",
}


func before_each() -> void:
	_unlock_system = UnlockSystem.new()
	_unlock_system.name = "UnlockSystem"
	get_tree().root.add_child(_unlock_system)

	_thread_system = SecretThreadSystem.new()
	add_child_autofree(_thread_system)


func after_each() -> void:
	if is_instance_valid(_unlock_system):
		_unlock_system.get_parent().remove_child(_unlock_system)
		_unlock_system.queue_free()


func _setup_thread(def: Dictionary) -> void:
	_thread_system._thread_defs = [def]
	_thread_system._init_thread_states()


## Drives _complete_def through all four day ticks required to reach RESOLVED.
## Phase sequence: DORMANT→WATCHING (day 1) →ACTIVE (day 2) →REVEALED (day 3) →RESOLVED (day 4).
func _drive_complete_thread() -> void:
	for day: int in range(1, 5):
		_thread_system._on_day_started(day)


func test_completed_thread_grants_unlock() -> void:
	_setup_thread(_complete_def)
	_drive_complete_thread()
	assert_true(
		_unlock_system.is_unlocked(UNLOCK_ID),
		"UnlockSystem should mark the unlock as granted after thread resolves"
	)


func test_completed_emits_secret_thread_completed_once_with_correct_args() -> void:
	_setup_thread(_complete_def)
	var emit_count: int = 0
	var received_thread_id: StringName = &""
	var received_unlock_id: StringName = &""
	EventBus.secret_thread_completed.connect(
		func(tid: StringName, uid: StringName) -> void:
			emit_count += 1
			received_thread_id = tid
			received_unlock_id = uid
	)
	_drive_complete_thread()
	assert_eq(emit_count, 1, "secret_thread_completed should emit exactly once")
	assert_eq(received_thread_id, THREAD_ID, "emitted thread_id must match")
	assert_eq(received_unlock_id, UNLOCK_ID, "emitted reward_unlock_id must match")


func test_completed_emits_unlock_granted_once() -> void:
	_setup_thread(_complete_def)
	var emit_count: int = 0
	EventBus.unlock_granted.connect(
		func(uid: StringName) -> void:
			if uid == UNLOCK_ID:
				emit_count += 1
	)
	_drive_complete_thread()
	assert_eq(emit_count, 1, "unlock_granted should emit exactly once for the reward unlock")


func test_failed_thread_emits_failed_and_no_unlock() -> void:
	_setup_thread(_fail_def)
	var failed_emitted: bool = false
	var unlock_count: int = 0
	EventBus.secret_thread_failed.connect(
		func(tid: StringName) -> void:
			if tid == FAIL_THREAD_ID:
				failed_emitted = true
	)
	EventBus.unlock_granted.connect(
		func(_uid: StringName) -> void:
			unlock_count += 1
	)
	# Day 1: DORMANT→WATCHING
	# Day 2: WATCHING→ACTIVE (activated_day=2); timeout check: 2-2=0 < 1
	# Day 3: timeout fires (3-2=1 >= timeout=1) → secret_thread_failed emitted
	for day: int in range(1, 4):
		_thread_system._on_day_started(day)
	assert_true(failed_emitted, "secret_thread_failed should be emitted on timeout")
	assert_eq(unlock_count, 0, "unlock_granted must NOT emit on failure")
	assert_false(
		_unlock_system.is_unlocked(UNLOCK_ID),
		"UnlockSystem should not grant unlock after failure"
	)


func test_unlock_granted_not_re_emitted_after_save_load_cycle() -> void:
	_setup_thread(_complete_def)
	# Seed _valid_ids so load_state can restore this synthetic unlock without warnings.
	_unlock_system._valid_ids[UNLOCK_ID] = true
	var emit_count: int = 0
	EventBus.unlock_granted.connect(
		func(uid: StringName) -> void:
			if uid == UNLOCK_ID:
				emit_count += 1
	)
	_drive_complete_thread()
	assert_eq(emit_count, 1, "unlock_granted emitted once on first completion")

	var thread_save: Dictionary = _thread_system.get_save_data()
	var unlock_save: Dictionary = _unlock_system.get_save_data()

	# Restore both systems from saved state.
	var reloaded_thread: SecretThreadSystem = SecretThreadSystem.new()
	add_child_autofree(reloaded_thread)
	reloaded_thread._thread_defs = [_complete_def]
	reloaded_thread._init_thread_states()
	reloaded_thread.load_state(thread_save)
	_unlock_system.load_state(unlock_save)

	# Drive additional days — thread is RESOLVED and must not re-trigger.
	for day: int in range(5, 9):
		reloaded_thread._on_day_started(day)

	assert_eq(emit_count, 1, "unlock_granted must not re-emit after save/load re-evaluation")
	assert_true(
		_unlock_system.is_unlocked(UNLOCK_ID),
		"unlock remains granted after load"
	)


func test_empty_reward_unlock_id_emits_completed_without_unlock_granted() -> void:
	_setup_thread(_no_reward_def)
	var completed_emitted: bool = false
	var completed_unlock_id: StringName = &"SENTINEL"
	var unlock_granted_emitted: bool = false
	EventBus.secret_thread_completed.connect(
		func(tid: StringName, uid: StringName) -> void:
			if tid == NO_REWARD_THREAD_ID:
				completed_emitted = true
				completed_unlock_id = uid
	)
	EventBus.unlock_granted.connect(
		func(_uid: StringName) -> void:
			unlock_granted_emitted = true
	)
	for day: int in range(1, 5):
		_thread_system._on_day_started(day)
	assert_true(
		completed_emitted,
		"secret_thread_completed should emit even when reward_unlock_id is empty"
	)
	assert_eq(
		completed_unlock_id, &"",
		"emitted reward_unlock_id should be empty string"
	)
	assert_false(
		unlock_granted_emitted,
		"unlock_granted must NOT emit when reward_unlock_id is empty"
	)
