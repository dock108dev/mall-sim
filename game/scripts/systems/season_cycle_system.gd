## Manages sports league season rotation for the sports memorabilia store.
class_name SeasonCycleSystem
extends RefCounted


enum SeasonPhase { HOT, WARM, NEUTRAL, COLD }

const LEAGUES: Array[String] = ["CBF", "NHA", "GPL"]
const MIN_CYCLE_DAYS: int = 8
const MAX_CYCLE_DAYS: int = 12
const ANNOUNCEMENT_LEAD_DAYS: int = 2

const PHASE_MULTIPLIERS: Dictionary = {
	SeasonPhase.HOT: 2.0,
	SeasonPhase.WARM: 1.2,
	SeasonPhase.NEUTRAL: 1.0,
	SeasonPhase.COLD: 0.5,
}

## Index into LEAGUES for the currently hot league.
var _hot_index: int = 0
## Day number when the next rotation occurs.
var _next_rotation_day: int = 1
## Whether the upcoming shift has been announced.
var _announced: bool = false
## Current game day, updated via process_day.
var _current_day: int = 1


## Initializes the season cycle for a new game starting on the given day.
func initialize(starting_day: int = 1) -> void:
	_current_day = starting_day
	_hot_index = randi() % LEAGUES.size()
	_next_rotation_day = starting_day + _random_cycle_length()
	_announced = false


## Called by the owning controller each day to advance the season cycle.
func process_day(day: int) -> void:
	_current_day = day
	_check_announcement()
	_check_rotation()


## Returns the season multiplier for an item based on its league tags.
func get_season_multiplier(item: ItemInstance) -> float:
	if not item or not item.definition:
		return 1.0
	if item.definition.store_type != "sports_memorabilia":
		return 1.0
	var tags: PackedStringArray = item.definition.tags
	for i: int in range(LEAGUES.size()):
		if tags.has(LEAGUES[i]):
			return PHASE_MULTIPLIERS[_get_phase_for_league(i)]
	return 1.0


## Returns the name of the currently hot league.
func get_hot_league() -> String:
	return LEAGUES[_hot_index]


## Returns the phase for a given league tag string.
func get_league_phase(league: String) -> SeasonPhase:
	var idx: int = _find_league_index(league)
	if idx < 0:
		return SeasonPhase.NEUTRAL
	return _get_phase_for_league(idx)


## Returns true if the given item belongs to the currently hot league.
func is_item_hot(item: ItemInstance) -> bool:
	if not item or not item.definition:
		return false
	return item.definition.tags.has(get_hot_league())


## Returns the day number of the next rotation.
func get_next_rotation_day() -> int:
	return _next_rotation_day


## Returns a display-friendly summary of current season phases.
func get_season_summary() -> Dictionary:
	var summary: Dictionary = {}
	for i: int in range(LEAGUES.size()):
		var phase: SeasonPhase = _get_phase_for_league(i)
		summary[LEAGUES[i]] = {
			"phase": _phase_name(phase),
			"multiplier": PHASE_MULTIPLIERS[phase],
		}
	return summary


## Serializes season cycle state for saving.
func get_save_data() -> Dictionary:
	return {
		"hot_index": _hot_index,
		"next_rotation_day": _next_rotation_day,
		"announced": _announced,
		"current_day": _current_day,
	}


## Restores season cycle state from saved data.
func load_save_data(data: Dictionary) -> void:
	_hot_index = int(data.get("hot_index", 0))
	_next_rotation_day = int(data.get("next_rotation_day", 1))
	_announced = bool(data.get("announced", false))
	_current_day = int(data.get("current_day", 1))


func _check_announcement() -> void:
	if _announced:
		return
	var days_until: int = _next_rotation_day - _current_day
	if days_until > ANNOUNCEMENT_LEAD_DAYS:
		return
	_announced = true
	var next_hot: String = LEAGUES[(_hot_index + 1) % LEAGUES.size()]
	EventBus.season_cycle_announced.emit(next_hot, days_until)
	EventBus.notification_requested.emit(
		"%s season heating up in %d day%s!" % [
			next_hot, days_until, "" if days_until == 1 else "s",
		]
	)


func _check_rotation() -> void:
	if _current_day < _next_rotation_day:
		return
	var old_hot: String = LEAGUES[_hot_index]
	_hot_index = (_hot_index + 1) % LEAGUES.size()
	var new_hot: String = LEAGUES[_hot_index]
	_next_rotation_day = _current_day + _random_cycle_length()
	_announced = false
	EventBus.season_cycle_shifted.emit(new_hot, old_hot)
	EventBus.notification_requested.emit(
		"%s season is now hot! %s items in high demand." % [
			new_hot, new_hot,
		]
	)


func _get_phase_for_league(league_index: int) -> SeasonPhase:
	var offset: int = (league_index - _hot_index)
	if offset < 0:
		offset += LEAGUES.size()
	if offset == 0:
		return SeasonPhase.HOT
	if offset == 1:
		return SeasonPhase.WARM
	return SeasonPhase.COLD


func _find_league_index(league: String) -> int:
	for i: int in range(LEAGUES.size()):
		if LEAGUES[i] == league:
			return i
	return -1


func _phase_name(phase: SeasonPhase) -> String:
	match phase:
		SeasonPhase.HOT:
			return "hot"
		SeasonPhase.WARM:
			return "warm"
		SeasonPhase.NEUTRAL:
			return "neutral"
		SeasonPhase.COLD:
			return "cold"
	return "neutral"


func _random_cycle_length() -> int:
	return randi_range(MIN_CYCLE_DAYS, MAX_CYCLE_DAYS)
