## Immutable definition of a sports season period loaded from JSON.
class_name SportsSeasonDefinition
extends Resource

@export var id: String = ""
@export var sport_tag: String = ""
@export var start_day: int = 0
@export var end_day: int = 0
@export var in_season_multiplier: float = 1.0
@export var off_season_multiplier: float = 1.0


## Returns true if the given day falls within this sport's active season.
func is_in_season(day: int) -> bool:
	var cycle_day: int = _get_cycle_day(day)
	if start_day <= end_day:
		return cycle_day >= start_day and cycle_day <= end_day
	return cycle_day >= start_day or cycle_day <= end_day


## Returns the appropriate multiplier for the given day.
func get_multiplier(day: int) -> float:
	if is_in_season(day):
		return in_season_multiplier
	return off_season_multiplier


func _get_cycle_day(day: int) -> int:
	var cycle_length: int = 365
	if day <= 0:
		return 1
	return ((day - 1) % cycle_length) + 1
