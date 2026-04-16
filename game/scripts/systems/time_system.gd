## Manages in-game time progression, day phases, and speed controls.
class_name TimeSystem
extends Node


enum DayPhase { PRE_OPEN, MORNING_RAMP, MIDDAY_RUSH, AFTERNOON, EVENING, LATE_EVENING }

enum SpeedTier { PAUSED = 0, NORMAL = 1, FAST = 3, ULTRA = 6 }

const GAME_MINUTES_PER_REAL_SECOND_NORMAL: float = 1.0
const MALL_OPEN_HOUR: int = 9
const MALL_CLOSE_HOUR: int = 21
const DAYS_PER_MONTH: int = 30

const _PHASE_BOUNDARIES_MINUTES: Dictionary = {
	DayPhase.PRE_OPEN: 420,
	DayPhase.MORNING_RAMP: 540,
	DayPhase.MIDDAY_RUSH: 690,
	DayPhase.AFTERNOON: 840,
	DayPhase.EVENING: 1080,
	DayPhase.LATE_EVENING: 1260,
}

const _DAY_START_MINUTES: float = 420.0
const _DAY_END_MINUTES: float = 1260.0
const _LATE_EVENING_END_MINUTES: float = 1440.0

const _VALID_SPEED_VALUES: Array[int] = [
	SpeedTier.PAUSED, SpeedTier.NORMAL, SpeedTier.FAST, SpeedTier.ULTRA,
]

var current_day: int = 1
var current_hour: int = 7
var current_phase: DayPhase = DayPhase.PRE_OPEN
var game_time_minutes: float = _DAY_START_MINUTES
var speed_multiplier: float = 1.0

var _last_emitted_hour: int = 7
var _day_ended_emitted: bool = false
var _total_play_time: float = 0.0
var _speed_before_slow: float = 1.0
var _auto_slow_stack: Array[String] = []
var _requested_speed: SpeedTier = SpeedTier.NORMAL
var _late_evening_enabled: bool = false


func _ready() -> void:
	var unlock_system := (
		get_node_or_null("/root/UnlockSystemSingleton") as UnlockSystem
	)
	if unlock_system != null:
		_late_evening_enabled = unlock_system.is_unlocked(&"extended_hours_unlock")
	EventBus.unlock_granted.connect(_on_unlock_granted)


func initialize() -> void:
	_connect_runtime_signals()
	_apply_state({})


func _apply_state(data: Dictionary) -> void:
	current_day = int(data.get("current_day", 1))
	game_time_minutes = float(
		data.get("game_time_minutes", _DAY_START_MINUTES)
	)
	_total_play_time = float(data.get("total_play_time", 0.0))
	_last_emitted_hour = int(
		data.get("last_emitted_hour", int(game_time_minutes / 60.0))
	)
	current_hour = _last_emitted_hour
	current_phase = _get_phase_for_minutes(game_time_minutes)

	var saved_speed: int = int(data.get("speed_multiplier", SpeedTier.NORMAL))
	if saved_speed in _VALID_SPEED_VALUES:
		_requested_speed = saved_speed as SpeedTier
	else:
		_requested_speed = SpeedTier.NORMAL

	var saved_stack: Array = data.get("auto_slow_stack", [])
	_auto_slow_stack.clear()
	for entry: Variant in saved_stack:
		_auto_slow_stack.append(str(entry))

	_recalculate_effective_speed()


func _process(delta: float) -> void:
	if speed_multiplier <= 0.0:
		return

	if is_zero_approx(delta):
		var current_frame_hour: int = int(game_time_minutes / 60.0)
		_emit_hour_changes(current_frame_hour)
		_check_phase_transition()
		if game_time_minutes >= _get_day_end_minutes():
			_end_day()
		return

	var previous_minutes: float = game_time_minutes
	var advance: float = (
		delta * GAME_MINUTES_PER_REAL_SECOND_NORMAL * speed_multiplier
	)
	game_time_minutes += advance
	_total_play_time += delta

	var new_hour: int = int(game_time_minutes / 60.0)
	_emit_hour_changes(new_hour)
	_check_phase_transitions_between(previous_minutes, game_time_minutes)

	if game_time_minutes >= _get_day_end_minutes():
		_end_day()


func set_speed(tier: SpeedTier) -> void:
	if int(tier) not in _VALID_SPEED_VALUES:
		push_warning("TimeSystem: Invalid speed tier %d" % tier)
		return
	_requested_speed = tier
	_recalculate_effective_speed()


func get_current_phase() -> DayPhase:
	return current_phase


func get_active_phases() -> Array[DayPhase]:
	var phases: Array[DayPhase] = [
		DayPhase.PRE_OPEN,
		DayPhase.MORNING_RAMP,
		DayPhase.MIDDAY_RUSH,
		DayPhase.AFTERNOON,
		DayPhase.EVENING,
	]
	if _late_evening_enabled:
		phases.append(DayPhase.LATE_EVENING)
	return phases


func get_current_month() -> int:
	var month_index: int = ((current_day - 1) / DAYS_PER_MONTH) % 12
	return month_index + 1


func push_auto_slow(reason: String) -> void:
	if reason.is_empty():
		push_warning("TimeSystem: empty auto-slow reason")
		return
	_auto_slow_stack.append(reason)
	if _auto_slow_stack.size() == 1:
		_speed_before_slow = speed_multiplier
	_recalculate_effective_speed()
	EventBus.speed_reduced_by_event.emit(reason)


func pop_auto_slow(reason: String) -> void:
	var idx: int = _auto_slow_stack.rfind(reason)
	if idx == -1:
		push_warning(
			"TimeSystem: auto-slow reason not found: %s" % reason
		)
		return
	_auto_slow_stack.remove_at(idx)
	_recalculate_effective_speed()


func is_auto_slowed() -> bool:
	return not _auto_slow_stack.is_empty()


func toggle_pause() -> void:
	if _requested_speed == SpeedTier.PAUSED:
		set_speed(SpeedTier.NORMAL)
	else:
		set_speed(SpeedTier.PAUSED)


func is_paused() -> bool:
	return speed_multiplier <= 0.0


func get_play_time_seconds() -> float:
	return _total_play_time


func advance_to_next_day() -> void:
	_day_ended_emitted = false
	current_day += 1
	game_time_minutes = _DAY_START_MINUTES
	_last_emitted_hour = int(_DAY_START_MINUTES / 60.0)
	current_hour = _last_emitted_hour
	current_phase = DayPhase.PRE_OPEN
	_auto_slow_stack.clear()
	set_process(true)
	EventBus.day_phase_changed.emit(current_phase)
	EventBus.day_started.emit(current_day)


func get_save_data() -> Dictionary:
	return {
		"current_day": current_day,
		"game_time_minutes": game_time_minutes,
		"total_play_time": _total_play_time,
		"speed_multiplier": int(_requested_speed),
		"last_emitted_hour": _last_emitted_hour,
		"auto_slow_stack": _auto_slow_stack.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


func _connect_runtime_signals() -> void:
	if not EventBus.time_speed_requested.is_connected(
		_on_time_speed_requested
	):
		EventBus.time_speed_requested.connect(_on_time_speed_requested)


func _on_unlock_granted(unlock_id: StringName) -> void:
	if unlock_id == &"extended_hours_unlock":
		_late_evening_enabled = true


func _get_day_end_minutes() -> float:
	if _late_evening_enabled:
		return _LATE_EVENING_END_MINUTES
	return _DAY_END_MINUTES


func _on_time_speed_requested(speed_tier: int) -> void:
	if speed_tier not in _VALID_SPEED_VALUES:
		push_warning("TimeSystem: Invalid requested speed tier %d" % speed_tier)
		return
	set_speed(speed_tier as SpeedTier)


func _end_day() -> void:
	if _day_ended_emitted:
		return
	_day_ended_emitted = true
	set_process(false)
	EventBus.day_ended.emit(current_day)


func _check_phase_transition() -> void:
	var new_phase: DayPhase = _get_phase_for_minutes(game_time_minutes)
	if new_phase != current_phase:
		current_phase = new_phase
		EventBus.day_phase_changed.emit(current_phase)


func _check_phase_transitions_between(
	previous_minutes: float, new_minutes: float
) -> void:
	var phases: Array[DayPhase] = get_active_phases()
	for phase: DayPhase in phases:
		var boundary: float = float(_PHASE_BOUNDARIES_MINUTES[phase])
		if boundary <= previous_minutes or boundary > new_minutes:
			continue
		if phase == current_phase:
			continue
		current_phase = phase
		EventBus.day_phase_changed.emit(current_phase)


func _emit_hour_changes(new_hour: int) -> void:
	while _last_emitted_hour < new_hour:
		_last_emitted_hour += 1
		current_hour = _last_emitted_hour
		EventBus.hour_changed.emit(_last_emitted_hour)


func _get_phase_for_minutes(minutes: float) -> DayPhase:
	if _late_evening_enabled and minutes >= _PHASE_BOUNDARIES_MINUTES[DayPhase.LATE_EVENING]:
		return DayPhase.LATE_EVENING
	if minutes >= _PHASE_BOUNDARIES_MINUTES[DayPhase.EVENING]:
		return DayPhase.EVENING
	if minutes >= _PHASE_BOUNDARIES_MINUTES[DayPhase.AFTERNOON]:
		return DayPhase.AFTERNOON
	if minutes >= _PHASE_BOUNDARIES_MINUTES[DayPhase.MIDDAY_RUSH]:
		return DayPhase.MIDDAY_RUSH
	if minutes >= _PHASE_BOUNDARIES_MINUTES[DayPhase.MORNING_RAMP]:
		return DayPhase.MORNING_RAMP
	return DayPhase.PRE_OPEN


func _recalculate_effective_speed() -> void:
	var old_speed: float = speed_multiplier
	if not _auto_slow_stack.is_empty():
		speed_multiplier = float(SpeedTier.NORMAL)
	else:
		speed_multiplier = float(_requested_speed)
	if not is_equal_approx(old_speed, speed_multiplier):
		EventBus.speed_changed.emit(speed_multiplier)
