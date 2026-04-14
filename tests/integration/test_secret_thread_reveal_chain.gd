## Integration test — SecretThreadSystem ACTIVE→REVEALED ambient moment delivery
## via AmbientMomentsSystem: signal chain and cooldown cancellation.
class_name TestSecretThreadRevealChain
extends GutTest


const THREAD_ID: StringName = &"ghost_tenant"
const MOMENT_ID: StringName = &"ghost_tenant_whisper"

var _thread_system: SecretThreadSystem
var _ambient_system: AmbientMomentsSystem

## Thread definition with a known reveal_moment_id.
var _reveal_def: Dictionary = {
	"id": "ghost_tenant",
	"display_name": "Ghost Tenant",
	"resettable": false,
	"timeout_days": 0,
	"preconditions": [{"type": "day_reached", "value": 1}],
	"reveal_moment": "ghost_tenant_whisper",
	"reward_unlock_id": "",
}

## Thread definition that has no reveal_moment — controls reveal-less path.
var _no_moment_def: Dictionary = {
	"id": "ghost_tenant",
	"display_name": "Ghost Tenant No Moment",
	"resettable": false,
	"timeout_days": 0,
	"preconditions": [{"type": "day_reached", "value": 1}],
	"reveal_moment": "",
	"reward_unlock_id": "",
}


func before_each() -> void:
	_ambient_system = AmbientMomentsSystem.new()
	add_child_autofree(_ambient_system)
	_ambient_system._apply_state({})

	_thread_system = SecretThreadSystem.new()
	add_child_autofree(_thread_system)
	_thread_system._ambient_system = _ambient_system


## Seeds the thread definition and forces the thread into ACTIVE phase.
func _setup_active_thread(def: Dictionary) -> void:
	_thread_system._thread_defs = [def]
	_thread_system._init_thread_states()
	var tid: String = String(THREAD_ID)
	_thread_system._thread_states[tid]["phase"] = (
		SecretThreadSystem.ThreadPhase.ACTIVE
	)
	_thread_system._thread_states[tid]["activated_day"] = 0


# ── Signal wiring helpers ─────────────────────────────────────────────────────


func _capture_state_changed() -> Array:
	var captures: Array = []
	EventBus.secret_thread_state_changed.connect(
		func(tid: StringName, old_p: StringName, new_p: StringName) -> void:
			captures.append({"tid": tid, "old": old_p, "new": new_p})
	)
	return captures


func _capture_revealed() -> Array:
	var captures: Array = []
	EventBus.secret_thread_revealed.connect(
		func(tid: StringName) -> void:
			captures.append(tid)
	)
	return captures


func _capture_moment_queued() -> Array:
	var captures: Array = []
	EventBus.ambient_moment_queued.connect(
		func(mid: StringName) -> void:
			captures.append(mid)
	)
	return captures


func _capture_moment_cancelled() -> Array:
	var captures: Array = []
	EventBus.ambient_moment_cancelled.connect(
		func(mid: StringName, reason: StringName) -> void:
			captures.append({"mid": mid, "reason": reason})
	)
	return captures


# ── Tests ─────────────────────────────────────────────────────────────────────


## ACTIVE→REVEALED emits secret_thread_state_changed with correct phases.
func test_advance_emits_state_changed_active_to_revealed() -> void:
	_setup_active_thread(_reveal_def)
	var changes: Array = _capture_state_changed()

	_thread_system.advance_thread(String(THREAD_ID))

	assert_eq(changes.size(), 1, "state_changed must emit exactly once")
	assert_eq(
		changes[0]["old"], &"ACTIVE",
		"old_phase must be ACTIVE"
	)
	assert_eq(
		changes[0]["new"], &"REVEALED",
		"new_phase must be REVEALED"
	)
	assert_eq(
		changes[0]["tid"], THREAD_ID,
		"thread_id in state_changed must match"
	)


## ACTIVE→REVEALED emits secret_thread_revealed with the correct thread_id.
func test_advance_emits_secret_thread_revealed() -> void:
	_setup_active_thread(_reveal_def)
	var revealed: Array = _capture_revealed()

	_thread_system.advance_thread(String(THREAD_ID))

	assert_eq(revealed.size(), 1, "secret_thread_revealed must emit exactly once")
	assert_eq(
		revealed[0], THREAD_ID,
		"emitted thread_id must match"
	)


## enqueue_by_id is called, causing ambient_moment_queued to fire with reveal_moment_id.
func test_advance_queues_reveal_moment_in_ambient_system() -> void:
	_setup_active_thread(_reveal_def)
	var queued: Array = _capture_moment_queued()

	_thread_system.advance_thread(String(THREAD_ID))

	assert_eq(queued.size(), 1, "ambient_moment_queued must emit exactly once")
	assert_eq(
		queued[0], MOMENT_ID,
		"queued moment_id must match the thread's reveal_moment"
	)


## Thread phase is REVEALED after advance — it does NOT jump to RESOLVED.
func test_thread_stays_revealed_not_resolved_after_advance() -> void:
	_setup_active_thread(_reveal_def)

	_thread_system.advance_thread(String(THREAD_ID))

	var phase: int = _thread_system.get_thread_phase(String(THREAD_ID))
	assert_eq(
		phase, SecretThreadSystem.ThreadPhase.REVEALED,
		"Thread must be REVEALED, not RESOLVED, after a single advance"
	)
	assert_ne(
		phase, SecretThreadSystem.ThreadPhase.RESOLVED,
		"Thread must not skip to RESOLVED"
	)


## When a cooldown is active for the moment, ambient_moment_cancelled fires
## with reason='cooldown', but the thread still transitions to REVEALED.
func test_cooldown_cancels_moment_but_thread_still_reveals() -> void:
	_setup_active_thread(_reveal_def)
	_ambient_system._cooldowns[String(MOMENT_ID)] = 2

	var cancelled: Array = _capture_moment_cancelled()
	var queued: Array = _capture_moment_queued()
	var revealed: Array = _capture_revealed()

	_thread_system.advance_thread(String(THREAD_ID))

	assert_eq(cancelled.size(), 1, "ambient_moment_cancelled must emit once on cooldown")
	assert_eq(
		cancelled[0]["mid"], MOMENT_ID,
		"cancelled moment_id must match reveal_moment"
	)
	assert_eq(
		cancelled[0]["reason"], &"cooldown",
		"cancellation reason must be 'cooldown'"
	)
	assert_eq(
		queued.size(), 0,
		"ambient_moment_queued must NOT fire when cooldown blocks"
	)
	assert_eq(
		revealed.size(), 1,
		"secret_thread_revealed must still fire despite cooldown"
	)
	assert_eq(
		_thread_system.get_thread_phase(String(THREAD_ID)),
		SecretThreadSystem.ThreadPhase.REVEALED,
		"Thread must still reach REVEALED even when moment is on cooldown"
	)


## When reveal_moment is empty, no ambient_moment_queued fires.
func test_no_ambient_signal_when_reveal_moment_empty() -> void:
	_setup_active_thread(_no_moment_def)
	var queued: Array = _capture_moment_queued()
	var revealed: Array = _capture_revealed()

	_thread_system.advance_thread(String(THREAD_ID))

	assert_eq(queued.size(), 0, "ambient_moment_queued must not fire when reveal_moment is empty")
	assert_eq(revealed.size(), 1, "secret_thread_revealed must still fire")


## advance_thread on unknown thread_id does not emit any signals.
func test_advance_unknown_thread_id_is_a_noop() -> void:
	_thread_system._thread_defs = []
	_thread_system._init_thread_states()
	var changes: Array = _capture_state_changed()
	var revealed: Array = _capture_revealed()

	_thread_system.advance_thread("nonexistent_thread")

	assert_eq(changes.size(), 0, "No state_changed for unknown thread")
	assert_eq(revealed.size(), 0, "No revealed signal for unknown thread")
