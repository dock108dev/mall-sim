## Integration test covering the full SecretThreadSystem thread lifecycle:
## DORMANT → WATCHING → ACTIVE → REVEALED → RESOLVED for the_regular thread.
extends GutTest


var _system: SecretThreadSystem
var _economy: EconomySystem
var _ambient: AmbientMomentsSystem

## Thread def in the format SecretThreadSystem code expects.
## Precondition: item_sold >= 3 — common purchases do not trigger WATCHING;
## only item_sold ("rare item" sold) makes the precondition relevant.
const THE_REGULAR_DEF: Dictionary = {
	"id": "the_regular",
	"display_name": "The Regular",
	"resettable": false,
	"timeout_days": 20,
	"preconditions": [
		{
			"type": "signal_count",
			"signal": "item_sold",
			"threshold": 3,
		},
	],
	"reveal_moment": "ambient_familiar_face",
	"completion_reward": {
		"type": "cash",
		"value": 150.0,
	},
}

const STORE_ID: StringName = &"test_store"
const STARTING_CASH: float = 500.0
const REWARD_AMOUNT: float = 150.0


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)

	_ambient = AmbientMomentsSystem.new()
	add_child_autofree(_ambient)

	_system = SecretThreadSystem.new()
	add_child_autofree(_system)
	_system._ambient_system = _ambient
	_system.set_economy_system(_economy)
	_system._thread_defs = [THE_REGULAR_DEF]
	_system._init_thread_states()
	_system._connect_signals()


# ── Lifecycle: DORMANT ────────────────────────────────────────────────────────


func test_thread_starts_dormant_with_zero_precondition_progress() -> void:
	assert_eq(
		_system.get_thread_phase("the_regular"),
		SecretThreadSystem.ThreadPhase.DORMANT,
		"Thread must start in DORMANT phase"
	)
	var state: Dictionary = _system._thread_states.get(
		"the_regular", {}
	)
	assert_eq(
		state.get("watch_counters", {"_": 1}),
		{},
		"Watch counters must be empty on init"
	)


func test_thread_stays_dormant_through_common_purchases() -> void:
	# customer_purchased alone does not trigger item_sold precondition relevance
	# while _current_day == 0 and item_sold not yet in signal_counts.
	for i: int in range(9):
		EventBus.customer_purchased.emit(
			STORE_ID, &"common_item_%d" % i, 5.0, &"cust_%d" % i
		)
	assert_eq(
		_system.get_thread_phase("the_regular"),
		SecretThreadSystem.ThreadPhase.DORMANT,
		"Thread must remain DORMANT after 9 common purchases (no item_sold)"
	)


# ── Lifecycle: DORMANT → WATCHING ────────────────────────────────────────────


func test_thread_transitions_to_watching_on_first_item_sold() -> void:
	EventBus.item_sold.emit("rare_item_001", 50.0, "collectibles")
	assert_eq(
		_system.get_thread_phase("the_regular"),
		SecretThreadSystem.ThreadPhase.WATCHING,
		"Thread must transition to WATCHING when item_sold fires for first time"
	)


func test_state_changed_signal_fires_on_dormant_to_watching() -> void:
	var transitions: Array[Dictionary] = []
	EventBus.secret_thread_state_changed.connect(
		func(tid: StringName, old_p: StringName, new_p: StringName) -> void:
			transitions.append({"id": tid, "old": old_p, "new": new_p})
	)
	EventBus.item_sold.emit("rare_item_001", 50.0, "collectibles")
	assert_eq(transitions.size(), 1)
	assert_eq(transitions[0]["id"], &"the_regular")
	assert_eq(transitions[0]["old"], &"DORMANT")
	assert_eq(transitions[0]["new"], &"WATCHING")


# ── Lifecycle: WATCHING → ACTIVE ─────────────────────────────────────────────


func test_thread_stays_watching_below_threshold() -> void:
	EventBus.item_sold.emit("rare_item_001", 50.0, "collectibles")
	EventBus.item_sold.emit("rare_item_002", 50.0, "collectibles")
	assert_eq(
		_system.get_thread_phase("the_regular"),
		SecretThreadSystem.ThreadPhase.WATCHING,
		"Thread must stay WATCHING when item_sold count is below threshold (2 of 3)"
	)


func test_thread_transitions_to_active_when_preconditions_met() -> void:
	for i: int in range(3):
		EventBus.item_sold.emit("rare_item_%d" % i, 50.0, "collectibles")
	assert_eq(
		_system.get_thread_phase("the_regular"),
		SecretThreadSystem.ThreadPhase.ACTIVE,
		"Thread must reach ACTIVE when item_sold >= 3"
	)


# ── Lifecycle: ACTIVE → REVEALED ─────────────────────────────────────────────


func test_thread_transitions_to_revealed_on_next_day() -> void:
	for i: int in range(3):
		EventBus.item_sold.emit("rare_item_%d" % i, 50.0, "collectibles")
	assert_eq(
		_system.get_thread_phase("the_regular"),
		SecretThreadSystem.ThreadPhase.ACTIVE
	)
	EventBus.day_started.emit(1)
	assert_eq(
		_system.get_thread_phase("the_regular"),
		SecretThreadSystem.ThreadPhase.REVEALED,
		"Thread must become REVEALED on the day after activation"
	)


func test_ambient_moment_queued_on_revealed_transition() -> void:
	var queued_moment: Array = [&""]
	EventBus.ambient_moment_queued.connect(
		func(moment_id: StringName) -> void:
			queued_moment[0] = moment_id
	)
	for i: int in range(3):
		EventBus.item_sold.emit("rare_item_%d" % i, 50.0, "collectibles")
	EventBus.day_started.emit(1)
	assert_eq(
		_system.get_thread_phase("the_regular"),
		SecretThreadSystem.ThreadPhase.REVEALED
	)
	assert_eq(
		queued_moment[0], &"ambient_familiar_face",
		"ambient_moment_queued must fire with reveal_moment id"
	)


# ── Lifecycle: REVEALED → RESOLVED ───────────────────────────────────────────


func test_thread_transitions_to_resolved_day_after_revealed() -> void:
	for i: int in range(3):
		EventBus.item_sold.emit("rare_item_%d" % i, 50.0, "collectibles")
	EventBus.day_started.emit(1)
	EventBus.day_started.emit(2)
	assert_eq(
		_system.get_thread_phase("the_regular"),
		SecretThreadSystem.ThreadPhase.RESOLVED,
		"Thread must be RESOLVED on the day after REVEALED"
	)


func test_secret_thread_completed_emitted_on_resolve() -> void:
	var completed_thread: Array = [&""]
	var completed_reward: Dictionary = {"unlock_id": "sentinel"}
	EventBus.secret_thread_completed.connect(
		func(tid: StringName, reward_data: Dictionary) -> void:
			completed_thread[0] = tid
			completed_reward = reward_data
	)
	for i: int in range(3):
		EventBus.item_sold.emit("rare_item_%d" % i, 50.0, "collectibles")
	EventBus.day_started.emit(1)
	EventBus.day_started.emit(2)
	assert_eq(
		completed_thread[0], &"the_regular",
		"secret_thread_completed must emit thread id 'the_regular'"
	)
	assert_eq(
		str(completed_reward.get("unlock_id", "")), "",
		"Thread with no reward_unlock_id must omit unlock_id"
	)


# ── Cash reward ───────────────────────────────────────────────────────────────


func test_cash_reward_applied_on_completion() -> void:
	var cash_before: float = _economy.get_cash()
	for i: int in range(3):
		EventBus.item_sold.emit("rare_item_%d" % i, 50.0, "collectibles")
	EventBus.day_started.emit(1)
	EventBus.day_started.emit(2)
	assert_eq(
		_system.get_thread_phase("the_regular"),
		SecretThreadSystem.ThreadPhase.RESOLVED
	)
	assert_almost_eq(
		_economy.get_cash(),
		cash_before + REWARD_AMOUNT,
		0.01,
		"EconomySystem cash must increase by the completion reward amount"
	)


func test_no_cash_reward_without_economy_system() -> void:
	# Rebuild system without economy reference — must not crash.
	var bare_system: SecretThreadSystem = SecretThreadSystem.new()
	add_child_autofree(bare_system)
	bare_system._ambient_system = _ambient
	bare_system._thread_defs = [THE_REGULAR_DEF]
	bare_system._init_thread_states()
	bare_system._connect_signals()

	for i: int in range(3):
		bare_system._on_item_sold("rare_item_%d" % i, 50.0, "collectibles")
	bare_system._on_day_started(1)
	bare_system._on_day_started(2)
	assert_eq(
		bare_system.get_thread_phase("the_regular"),
		SecretThreadSystem.ThreadPhase.RESOLVED,
		"Thread must still resolve even without economy system"
	)


# ── Save / Load round-trip ────────────────────────────────────────────────────


func test_save_data_captures_active_state() -> void:
	for i: int in range(3):
		EventBus.item_sold.emit("rare_item_%d" % i, 50.0, "collectibles")
	var save_data: Dictionary = _system.get_save_data()
	assert_true(save_data.has("thread_states"))
	var ts: Dictionary = save_data["thread_states"] as Dictionary
	assert_true(ts.has("the_regular"))
	var saved: Dictionary = ts["the_regular"] as Dictionary
	assert_eq(
		saved.get("phase", -1),
		SecretThreadSystem.ThreadPhase.ACTIVE,
		"Saved phase must be ACTIVE after all preconditions satisfied"
	)
	assert_true(saved.has("step_index"))
	assert_true(saved.has("watch_counters"))


func test_load_state_restores_active_phase_in_fresh_system() -> void:
	for i: int in range(3):
		EventBus.item_sold.emit("rare_item_%d" % i, 50.0, "collectibles")
	var save_data: Dictionary = _system.get_save_data()

	var fresh: SecretThreadSystem = SecretThreadSystem.new()
	add_child_autofree(fresh)
	fresh._thread_defs = [THE_REGULAR_DEF]
	fresh._init_thread_states()
	fresh.load_state(save_data)

	assert_eq(
		fresh.get_thread_phase("the_regular"),
		SecretThreadSystem.ThreadPhase.ACTIVE,
		"Deserialized system must restore ACTIVE phase"
	)


func test_load_state_does_not_emit_completion() -> void:
	var completed: Array = [false]
	EventBus.secret_thread_completed.connect(
		func(_tid: StringName, _reward_data: Dictionary) -> void:
			completed[0] = true
	)
	var save_data: Dictionary = {
		"thread_states": {
			"the_regular": {
				"phase": SecretThreadSystem.ThreadPhase.RESOLVED,
				"step_index": 0,
				"activated_day": 1,
				"revealed_day": 2,
				"watch_counters": {"item_sold": 3},
			},
		},
		"signal_counts": {"item_sold": 3},
		"owned_store_count": 0,
	}
	_system.load_state(save_data)
	assert_false(
		completed[0],
		"load_state must not re-emit secret_thread_completed"
	)
	assert_eq(
		_system.get_thread_phase("the_regular"),
		SecretThreadSystem.ThreadPhase.RESOLVED,
		"Loaded RESOLVED state must be preserved"
	)


func test_load_preserves_watch_counters_and_step_progress() -> void:
	var watch_counters: Dictionary = {"item_sold": 2}
	var save_data: Dictionary = {
		"thread_states": {
			"the_regular": {
				"phase": SecretThreadSystem.ThreadPhase.WATCHING,
				"step_index": 0,
				"activated_day": 0,
				"revealed_day": 0,
				"watch_counters": watch_counters,
			},
		},
		"signal_counts": {"item_sold": 2},
		"owned_store_count": 0,
	}
	_system.load_state(save_data)
	assert_eq(
		_system.get_thread_phase("the_regular"),
		SecretThreadSystem.ThreadPhase.WATCHING,
		"Loaded WATCHING state must be preserved"
	)
	var state: Dictionary = _system._thread_states.get("the_regular", {})
	var wc: Dictionary = state.get("watch_counters", {}) as Dictionary
	assert_eq(
		wc.get("item_sold", 0), 2,
		"Watch counters must be restored exactly from save data"
	)


# ── Timeout guard ─────────────────────────────────────────────────────────────


func test_timeout_emits_failed_and_keeps_resolved_when_non_resettable() -> void:
	var failed_id: Array = [&""]
	EventBus.secret_thread_failed.connect(
		func(tid: StringName) -> void:
			failed_id[0] = tid
	)
	for i: int in range(3):
		EventBus.item_sold.emit("rare_item_%d" % i, 50.0, "collectibles")
	# Activate on day 0; skip ahead past timeout_days (20) without revealing.
	_system._current_day = 0
	var state: Dictionary = _system._thread_states["the_regular"] as Dictionary
	state["activated_day"] = 0
	EventBus.day_started.emit(21)
	assert_eq(
		failed_id[0], &"the_regular",
		"secret_thread_failed must fire when timeout exceeded"
	)
	assert_eq(
		_system.get_thread_phase("the_regular"),
		SecretThreadSystem.ThreadPhase.RESOLVED,
		"Non-resettable timed-out thread must end in RESOLVED"
	)
