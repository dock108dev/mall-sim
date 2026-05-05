## GameState — pure in-memory holder for the active run's transient data
## (ISSUE-020). Single source of truth for: active_store_id, day, money, flags.
##
## Pure data. Does NOT load scenes, change cameras, touch input focus, or
## declare store readiness — those owners are SceneRouter, CameraAuthority,
## InputFocus, and StoreDirector respectively (see docs/architecture/ownership.md).
## Cross-system listeners react via EventBus.run_state_changed; GameState never
## holds direct references to consumers.
##
## Phase 1 scope: in-memory only, no save/load.
##
## Note on signal naming: EventBus.game_state_changed(int, int) is already taken
## by GameManager's FSM (BOOT/MENU/PLAYING transitions) and cannot be reused
## with a different signature. This module emits the distinct
## EventBus.run_state_changed() signal to satisfy the "emit on mutation" intent
## of ISSUE-020 without breaking existing consumers.
extends Node

## Local mirror of the EventBus.run_state_changed signal. Useful for tests
## that instantiate this script in isolation without the EventBus autoload.
signal changed()

const DEFAULT_DAY: int = 0
const DEFAULT_MONEY: int = 0
const DEFAULT_EMPLOYEE_TRUST: float = 50.0
const DEFAULT_MANAGER_APPROVAL: float = 0.5
const TRUST_MIN: float = 0.0
const TRUST_MAX: float = 100.0
const APPROVAL_MIN: float = 0.0
const APPROVAL_MAX: float = 100.0

var active_store_id: StringName = &"":
	set(value):
		if value == active_store_id:
			return
		active_store_id = value
		_emit_changed()

var day: int = DEFAULT_DAY:
	set(value):
		if value == day:
			return
		day = value
		_emit_changed()

var money: int = DEFAULT_MONEY:
	set(value):
		if value == money:
			return
		money = value
		_emit_changed()

## Employee trust score (0–100). Mirrored from EmploymentSystem so HUD can
## read trust through the same GameState contract used for `money` and `day`.
## Defaults to 50.0 so a fresh GameState (e.g. tests) sits above the 15.0
## firing floor; EmploymentSystem.start_employment() also seeds 50.0 explicitly.
var employee_trust: float = DEFAULT_EMPLOYEE_TRUST:
	set(value):
		var clamped: float = clampf(value, TRUST_MIN, TRUST_MAX)
		if is_equal_approx(clamped, employee_trust):
			return
		employee_trust = clamped
		_emit_changed()

## Manager approval score (0–100). Initial value 0.5 matches the issue spec —
## a low neutral placeholder before any manager event has fired. Distinct from
## employee_trust: trust is earned through customer interactions, approval
## through explicit manager-triggered events.
var manager_approval: float = DEFAULT_MANAGER_APPROVAL:
	set(value):
		var clamped: float = clampf(value, APPROVAL_MIN, APPROVAL_MAX)
		if is_equal_approx(clamped, manager_approval):
			return
		manager_approval = clamped
		_emit_changed()

var flags: Dictionary = {}

# Suppression flag — when true, individual field setters skip emitting so that
# multi-field operations (reset_new_game) can coalesce into a single signal.
var _suppress_emit: bool = false


## Resets all run state for a fresh New Game. Emits run_state_changed exactly
## once even when multiple fields change.
func reset_new_game() -> void:
	_suppress_emit = true
	active_store_id = &""
	day = DEFAULT_DAY
	money = DEFAULT_MONEY
	employee_trust = DEFAULT_EMPLOYEE_TRUST
	manager_approval = DEFAULT_MANAGER_APPROVAL
	flags.clear()
	_suppress_emit = false
	_emit_changed()


## Sets the active store for the current run. Empty StringName clears it.
## Emits run_state_changed exactly once when the value changes; no-op (and no
## emission) when called with the current id.
func set_active_store(id: StringName) -> void:
	active_store_id = id


## Sets a boolean flag by key. Emits run_state_changed when the value changes.
func set_flag(key: StringName, value: bool) -> void:
	assert(key != &"", "GameState.set_flag: empty key")
	var existing: bool = bool(flags.get(key, false))
	if existing == value:
		return
	flags[key] = value
	_emit_changed()


## Reads a flag; missing keys return false.
func get_flag(key: StringName) -> bool:
	return bool(flags.get(key, false))


func _emit_changed() -> void:
	if _suppress_emit:
		return
	changed.emit()
	var bus: Node = _resolve_event_bus()
	if bus != null:
		bus.run_state_changed.emit()


func _resolve_event_bus() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root: Node = tree.root
	if root == null or not root.has_node("EventBus"):
		return null
	return root.get_node("EventBus")
