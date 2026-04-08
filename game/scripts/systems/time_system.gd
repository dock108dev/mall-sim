## Manages in-game time progression, day/night, and scheduling.
class_name TimeSystem
extends Node

var current_day: int = 1
var current_hour: int = Constants.STORE_OPEN_HOUR
var _elapsed: float = 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= Constants.SECONDS_PER_GAME_MINUTE * Constants.MINUTES_PER_HOUR:
		_elapsed = 0.0
		_advance_hour()


func _advance_hour() -> void:
	current_hour += 1
	EventBus.hour_changed.emit(current_hour)
	if current_hour >= Constants.STORE_CLOSE_HOUR:
		_end_day()


func _end_day() -> void:
	EventBus.day_ended.emit(current_day)
	current_day += 1
	current_hour = Constants.STORE_OPEN_HOUR
	EventBus.day_started.emit(current_day)
