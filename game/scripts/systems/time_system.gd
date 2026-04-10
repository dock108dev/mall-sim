## Manages in-game time progression, day phases, and scheduling.
class_name TimeSystem
extends Node


enum DayPhase { MORNING, MIDDAY, AFTERNOON, EVENING }

const VALID_SPEEDS: Array[float] = [0.0, 1.0, 2.0, 4.0]

## Hour boundaries for each day phase (store hours 9-21).
const _PHASE_BOUNDARIES: Dictionary = {
	DayPhase.MORNING: 9,
	DayPhase.MIDDAY: 11,
	DayPhase.AFTERNOON: 14,
	DayPhase.EVENING: 18,
}

var current_day: int = 1
var current_hour: int = Constants.STORE_OPEN_HOUR
var current_phase: DayPhase = DayPhase.MORNING
var time_scale: float = 1.0
var _elapsed: float = 0.0
var _total_play_time: float = 0.0
var _speed_before_pause: float = 1.0


func initialize() -> void:
	current_day = 1
	current_hour = Constants.STORE_OPEN_HOUR
	current_phase = DayPhase.MORNING
	time_scale = 1.0
	_elapsed = 0.0
	_total_play_time = 0.0
	_speed_before_pause = 1.0


func _process(delta: float) -> void:
	if time_scale <= 0.0:
		return
	var scaled_delta: float = delta * time_scale
	_total_play_time += scaled_delta
	_elapsed += scaled_delta
	if _elapsed >= Constants.SECONDS_PER_GAME_MINUTE * Constants.MINUTES_PER_HOUR:
		_elapsed = 0.0
		_advance_hour()


func _advance_hour() -> void:
	current_hour += 1
	EventBus.hour_changed.emit(current_hour)
	_check_phase_transition()
	if current_hour >= Constants.STORE_CLOSE_HOUR:
		_end_day()


func _end_day() -> void:
	set_process(false)
	EventBus.day_ended.emit(current_day)


## Called by day summary to advance to the next day.
func advance_to_next_day() -> void:
	current_day += 1
	current_hour = Constants.STORE_OPEN_HOUR
	current_phase = DayPhase.MORNING
	_elapsed = 0.0
	set_process(true)
	EventBus.day_phase_changed.emit(current_phase)
	EventBus.day_started.emit(current_day)


func _check_phase_transition() -> void:
	var new_phase: DayPhase = _get_phase_for_hour(current_hour)
	if new_phase != current_phase:
		current_phase = new_phase
		EventBus.day_phase_changed.emit(current_phase)


func _get_phase_for_hour(hour: int) -> DayPhase:
	if hour >= _PHASE_BOUNDARIES[DayPhase.EVENING]:
		return DayPhase.EVENING
	if hour >= _PHASE_BOUNDARIES[DayPhase.AFTERNOON]:
		return DayPhase.AFTERNOON
	if hour >= _PHASE_BOUNDARIES[DayPhase.MIDDAY]:
		return DayPhase.MIDDAY
	return DayPhase.MORNING


## Sets the time scale. Valid values: 0.0 (pause), 1.0, 2.0, 4.0.
func set_time_scale(scale: float) -> void:
	if scale not in VALID_SPEEDS:
		push_warning("TimeSystem: Invalid time scale %.1f" % scale)
		return
	var old_scale: float = time_scale
	time_scale = scale
	if scale > 0.0:
		_speed_before_pause = scale
	if old_scale != scale:
		EventBus.speed_changed.emit(scale)


## Toggles between paused and the previous speed.
func toggle_pause() -> void:
	if time_scale > 0.0:
		set_time_scale(0.0)
	else:
		set_time_scale(_speed_before_pause)


func is_paused() -> bool:
	return time_scale <= 0.0


func get_play_time_seconds() -> float:
	return _total_play_time


## Serializes time state for saving.
func get_save_data() -> Dictionary:
	return {
		"current_day": current_day,
		"current_hour": current_hour,
		"current_phase": current_phase,
		"elapsed": _elapsed,
		"total_play_time": _total_play_time,
		"time_scale": time_scale,
	}


## Restores time state from saved data.
func load_save_data(data: Dictionary) -> void:
	current_day = int(data.get("current_day", 1))
	current_hour = int(
		data.get("current_hour", Constants.STORE_OPEN_HOUR)
	)
	current_phase = int(
		data.get("current_phase", DayPhase.MORNING)
	) as DayPhase
	_elapsed = float(data.get("elapsed", 0.0))
	_total_play_time = float(data.get("total_play_time", 0.0))
	var saved_scale: float = float(data.get("time_scale", 1.0))
	set_time_scale(saved_scale)
