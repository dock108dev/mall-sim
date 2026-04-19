## Manages recurring seasonal events and scheduled tournament events.
class_name SeasonalEventSystem
extends Node


const ANNOUNCEMENT_DAYS: int = 1
const STORE_TYPE_POCKET_CREATURES: String = "pocket_creatures"
const DAYS_PER_SEASON: int = 30
const SEASONS_PER_YEAR: int = 4

var _event_definitions: Array[SeasonalEventDefinition] = []
var _active_events: Array[Dictionary] = []
var _announced_events: Array[Dictionary] = []
var _sports_seasons: Array[SportsSeasonDefinition] = []
var _current_day: int = 1
var _active_sport_multipliers: Dictionary = {}
var _current_season: int = 0
var _seasonal_config: Array[Dictionary] = []
var _current_multipliers: Dictionary = {}

var _tournament_definitions: Array[TournamentEventDefinition] = []
var _active_tournaments: Array[Dictionary] = []
var _announced_tournaments: Array[Dictionary] = []

var _season_table: Array[Dictionary] = []
var _season_cycle_length: int = 70
var _current_named_season: StringName = &""


func _ready() -> void:
	_ensure_day_started_connected()


func initialize(data_loader: DataLoader) -> void:
	_event_definitions = []
	_sports_seasons = []
	_tournament_definitions = []
	_seasonal_config = []
	_season_table = []
	if data_loader:
		_event_definitions = data_loader.get_all_seasonal_events()
		_sports_seasons = data_loader.get_all_sports_seasons()
		_tournament_definitions = (
			data_loader.get_all_tournament_events()
		)
		_seasonal_config = data_loader.get_seasonal_config()
		_season_table = data_loader.get_named_seasons()
		_season_cycle_length = (
			data_loader.get_named_season_cycle_length()
		)
		_validate_tournament_schedule()
	_apply_state({})
	_ensure_day_started_connected()


func get_traffic_multiplier() -> float:
	var combined: float = 1.0
	for evt: Dictionary in _active_events:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if def:
			combined *= def.customer_traffic_multiplier
	for evt: Dictionary in _active_tournaments:
		var def: TournamentEventDefinition = evt.get(
			"definition", null
		) as TournamentEventDefinition
		if def and def.traffic_multiplier != 1.0:
			combined *= def.traffic_multiplier
	return combined


func get_spending_multiplier() -> float:
	var combined: float = 1.0
	for evt: Dictionary in _active_events:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if def:
			combined *= def.spending_multiplier
	return combined


func get_customer_type_weights() -> Dictionary:
	var merged: Dictionary = {}
	for evt: Dictionary in _active_events:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if not def:
			continue
		for type_id: String in def.customer_type_weights:
			var weight: float = float(
				def.customer_type_weights[type_id]
			)
			if merged.has(type_id):
				merged[type_id] = (merged[type_id] as float) * weight
			else:
				merged[type_id] = weight
	return merged


func get_active_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for evt: Dictionary in _active_events:
		result.append(evt.duplicate())
	return result


func get_announced_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for evt: Dictionary in _announced_events:
		result.append(evt.duplicate())
	return result


func get_sport_season_multiplier(item: ItemInstance) -> float:
	if not item or not item.definition:
		return 1.0
	if item.definition.store_type != "sports":
		return 1.0
	var tags: PackedStringArray = item.definition.tags
	var combined: float = 1.0
	var matched: bool = false
	for season: SportsSeasonDefinition in _sports_seasons:
		if tags.has(season.sport_tag):
			combined *= season.get_multiplier(_current_day)
			matched = true
	if not matched:
		return 1.0
	return combined


func get_active_sport_multipliers() -> Dictionary:
	return _active_sport_multipliers.duplicate()


## Returns the tournament demand multiplier for an item.
func get_tournament_demand_multiplier(item: ItemInstance) -> float:
	if not item or not item.definition:
		return 1.0
	if item.definition.store_type != STORE_TYPE_POCKET_CREATURES:
		return 1.0
	var combined: float = 1.0
	for evt: Dictionary in _active_tournaments:
		var def: TournamentEventDefinition = evt.get(
			"definition", null
		) as TournamentEventDefinition
		if def and item.definition.category == def.card_category:
			combined *= def.demand_multiplier
	return combined


## Returns the price_spike_multiplier for an item from active tournaments.
## Matches on creature_type_focus (item tag) if set; falls back to card_category.
func get_tournament_price_spike_multiplier(item: ItemInstance) -> float:
	if not item or not item.definition:
		return 1.0
	if item.definition.store_type != STORE_TYPE_POCKET_CREATURES:
		return 1.0
	var combined: float = 1.0
	for evt: Dictionary in _active_tournaments:
		var def: TournamentEventDefinition = evt.get(
			"definition", null
		) as TournamentEventDefinition
		if not def:
			continue
		var matches: bool = false
		if not def.creature_type_focus.is_empty():
			matches = item.definition.tags.has(def.creature_type_focus)
		if not matches:
			matches = item.definition.category == def.card_category
		if matches:
			combined *= def.price_spike_multiplier
	return combined


func get_active_tournaments() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for evt: Dictionary in _active_tournaments:
		result.append(evt.duplicate())
	return result


func get_announced_tournaments() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for evt: Dictionary in _announced_tournaments:
		result.append(evt.duplicate())
	return result


func get_impact_summary() -> String:
	if _active_events.is_empty():
		return ""
	var lines: PackedStringArray = []
	for evt: Dictionary in _active_events:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if not def:
			continue
		var parts: PackedStringArray = []
		if not is_equal_approx(def.customer_traffic_multiplier, 1.0):
			var pct: int = roundi(
				(def.customer_traffic_multiplier - 1.0) * 100.0
			)
			var sign: String = "+" if pct > 0 else ""
			parts.append("%s%d%% traffic" % [sign, pct])
		if not is_equal_approx(def.spending_multiplier, 1.0):
			var pct: int = roundi(
				(def.spending_multiplier - 1.0) * 100.0
			)
			var sign: String = "+" if pct > 0 else ""
			parts.append("%s%d%% spending" % [sign, pct])
		if not parts.is_empty():
			lines.append(
				"%s: %s" % [def.name, ", ".join(parts)]
			)
	return "\n".join(lines)


static func compute_season(day: int) -> int:
	return ((day - 1) / DAYS_PER_SEASON) % SEASONS_PER_YEAR


func get_current_season() -> StringName:
	return _current_named_season


func get_calendar_season_index() -> int:
	return _current_season


func get_demand_multiplier(category: StringName) -> float:
	var season: Dictionary = _find_named_season(
		_current_named_season
	)
	if season.is_empty():
		return 1.0
	var mults: Variant = season.get("category_multipliers", {})
	if mults is not Dictionary:
		return 1.0
	return float((mults as Dictionary).get(String(category), 1.0))


func get_price_sensitivity_modifier() -> float:
	var season: Dictionary = _find_named_season(
		_current_named_season
	)
	if season.is_empty():
		return 1.0
	return float(season.get("price_sensitivity_modifier", 1.0))


func get_current_multipliers() -> Dictionary:
	return _current_multipliers.duplicate()


func get_store_seasonal_multiplier(store_id: String) -> float:
	return float(_current_multipliers.get(store_id, 1.0))


## Returns the combined price multiplier from all active events for store_id.
## Returns 1.0 when no active event targets that store.
func get_event_price_multiplier_for_store(store_id: String) -> float:
	var combined: float = 1.0
	for evt: Dictionary in _active_events:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if not def:
			continue
		if def.affected_stores.has(store_id):
			combined *= def.price_multiplier
	return combined


func _update_calendar_season(day: int) -> void:
	var new_season: int = compute_season(day)
	if new_season != _current_season:
		var old_season: int = _current_season
		_current_season = new_season
		EventBus.season_changed.emit(new_season, old_season)
	_current_multipliers = _build_multipliers(_current_season)
	EventBus.seasonal_multipliers_updated.emit(
		_current_multipliers.duplicate()
	)


func _build_multipliers(season_index: int) -> Dictionary:
	for entry: Dictionary in _seasonal_config:
		if int(entry.get("index", -1)) == season_index:
			var mults: Variant = entry.get("store_multipliers", {})
			if mults is Dictionary:
				return mults as Dictionary
	return {}


func get_save_data() -> Dictionary:
	return {
		"active_events": _serialize_list(
			_active_events, "start_day"
		),
		"announced_events": _serialize_list(
			_announced_events, "announced_day"
		),
		"active_tournaments": _serialize_list(
			_active_tournaments, "start_day"
		),
		"announced_tournaments": _serialize_list(
			_announced_tournaments, "announced_day"
		),
		"current_day": _current_day,
		"current_season": _current_season,
	}


func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


func _serialize_list(
	events: Array[Dictionary], day_key: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for evt: Dictionary in events:
		var def_id: String = ""
		var def: Variant = evt.get("definition")
		if def and def is Resource:
			def_id = str(def.get("id"))
		var entry: Dictionary = {
			"definition_id": def_id,
			day_key: evt.get(day_key, 0),
		}
		if evt.has("start_day") and day_key != "start_day":
			entry["start_day"] = evt["start_day"]
		result.append(entry)
	return result


func _apply_state(data: Dictionary) -> void:
	_current_day = int(data.get("current_day", 1))
	_current_season = int(
		data.get("current_season", compute_season(_current_day))
	)
	_current_multipliers = _build_multipliers(_current_season)
	_init_named_season(_current_day)
	_active_events = _restore_seasonal_list(
		data.get("active_events", []), "start_day"
	)
	_announced_events = _restore_seasonal_list(
		data.get("announced_events", []), "announced_day"
	)
	_active_tournaments = _restore_tournament_list(
		data.get("active_tournaments", []), "start_day"
	)
	_announced_tournaments = _restore_tournament_list(
		data.get("announced_tournaments", []), "announced_day"
	)
	_recalculate_sport_seasons()


func _restore_seasonal_list(
	saved: Array, day_key: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Variant in saved:
		if entry is not Dictionary:
			continue
		var evt: Dictionary = entry as Dictionary
		var def_id: String = evt.get("definition_id", "")
		var def: SeasonalEventDefinition = _find_definition(def_id)
		if not def:
			if not def_id.is_empty():
				push_warning(
					"SeasonalEventSystem: saved event '%s' not found"
					% def_id
				)
			continue
		var restored: Dictionary = {
			"definition": def,
			day_key: int(evt.get(day_key, 0)),
		}
		if evt.has("start_day"):
			restored["start_day"] = int(evt["start_day"])
		result.append(restored)
	return result


func _restore_tournament_list(
	saved: Array, day_key: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Variant in saved:
		if entry is not Dictionary:
			continue
		var evt: Dictionary = entry as Dictionary
		var def_id: String = evt.get("definition_id", "")
		var def: TournamentEventDefinition = (
			_find_tournament_definition(def_id)
		)
		if not def:
			continue
		result.append({
			"definition": def,
			day_key: int(evt.get(day_key, 0)),
		})
	return result


func _on_day_started(day: int) -> void:
	_current_day = day
	_update_calendar_season(day)
	_update_named_season(day)
	_recalculate_sport_seasons()
	_expire_active_events(day)
	_promote_announced_events(day)
	_check_for_new_events(day)
	_expire_active_tournaments(day)
	_promote_announced_tournaments(day)
	_check_for_new_tournaments(day)


func _ensure_day_started_connected() -> void:
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)
	if not EventBus.day_ended.is_connected(_on_day_ended):
		EventBus.day_ended.connect(_on_day_ended)


func _init_named_season(day: int) -> void:
	if _season_table.is_empty():
		_current_named_season = &""
		return
	var cycle_day: int = _day_in_cycle(day)
	for entry: Dictionary in _season_table:
		var start: int = int(entry.get("start_day", 0))
		var end: int = int(entry.get("end_day", 0))
		if cycle_day >= start and cycle_day <= end:
			_current_named_season = StringName(
				str(entry.get("id", ""))
			)
			return
	_current_named_season = &""


func _update_named_season(day: int) -> void:
	if _season_table.is_empty():
		return
	var cycle_day: int = _day_in_cycle(day)
	var new_season: StringName = &""
	for entry: Dictionary in _season_table:
		var start: int = int(entry.get("start_day", 0))
		var end: int = int(entry.get("end_day", 0))
		if cycle_day >= start and cycle_day <= end:
			new_season = StringName(str(entry.get("id", "")))
			break
	if new_season != _current_named_season:
		_current_named_season = new_season
		if not new_season.is_empty():
			EventBus.seasonal_event_started.emit(
				String(new_season)
			)


func _day_in_cycle(day: int) -> int:
	if _season_cycle_length <= 0:
		return day
	return ((day - 1) % _season_cycle_length) + 1


func _find_named_season(season_id: StringName) -> Dictionary:
	for entry: Dictionary in _season_table:
		if StringName(str(entry.get("id", ""))) == season_id:
			return entry
	return {}


func _expire_active_events(day: int) -> void:
	var remaining: Array[Dictionary] = []
	for evt: Dictionary in _active_events:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if not def:
			continue
		var start_day: int = evt.get("start_day", 0) as int
		if day < start_day + def.duration_days:
			remaining.append(evt)
		else:
			EventBus.seasonal_event_ended.emit(def.id)
	_active_events = remaining


func _promote_announced_events(day: int) -> void:
	var remaining: Array[Dictionary] = []
	for evt: Dictionary in _announced_events:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if not def:
			continue
		var announced_day: int = evt.get("announced_day", 0) as int
		var start_day: int = evt.get(
			"start_day",
			announced_day + maxi(def.telegraph_days, 1)
		) as int
		if day >= start_day:
			_active_events.append({
				"definition": def, "start_day": start_day,
			})
			EventBus.seasonal_event_started.emit(def.id)
			if not def.active_text.is_empty():
				EventBus.notification_requested.emit(def.active_text)
		else:
			remaining.append(evt)
	_announced_events = remaining


func _check_for_new_events(day: int) -> void:
	for def: SeasonalEventDefinition in _event_definitions:
		if _is_event_active_or_announced(def.id):
			continue
		if not _should_trigger(day, def):
			continue
		_announce_event(def, day)


func _should_trigger(
	day: int, def: SeasonalEventDefinition
) -> bool:
	var adjusted: int = day - def.offset_days
	if adjusted <= 0:
		return false
	return adjusted % def.frequency_days == 0


func _is_event_active_or_announced(event_id: String) -> bool:
	for evt: Dictionary in _active_events:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if def and def.id == event_id:
			return true
	for evt: Dictionary in _announced_events:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if def and def.id == event_id:
			return true
	return false


func _announce_event(
	def: SeasonalEventDefinition, day: int
) -> void:
	var lead: int = maxi(def.telegraph_days, 1)
	_announced_events.append({
		"definition": def,
		"announced_day": day,
		"start_day": day + lead,
	})
	EventBus.seasonal_event_announced.emit(def.id)
	EventBus.event_telegraphed.emit(def.id, lead)
	if not def.announcement_text.is_empty():
		EventBus.notification_requested.emit(def.announcement_text)


func _recalculate_sport_seasons() -> void:
	_active_sport_multipliers.clear()
	for season: SportsSeasonDefinition in _sports_seasons:
		_active_sport_multipliers[season.sport_tag] = (
			season.get_multiplier(_current_day)
		)


func _find_definition(id: String) -> SeasonalEventDefinition:
	for def: SeasonalEventDefinition in _event_definitions:
		if def.id == id:
			return def
	return null


# ── Tournament Event Management ──────────────────────────────────────


func _validate_tournament_schedule() -> void:
	for i: int in range(_tournament_definitions.size()):
		var a: TournamentEventDefinition = _tournament_definitions[i]
		var a_end: int = a.start_day + a.duration_days
		for j: int in range(i + 1, _tournament_definitions.size()):
			var b: TournamentEventDefinition = (
				_tournament_definitions[j]
			)
			if a.card_category != b.card_category:
				continue
			var b_end: int = b.start_day + b.duration_days
			if a.start_day < b_end and b.start_day < a_end:
				push_error(
					"Tournament overlap on '%s': '%s' [%d-%d) "
					% [a.card_category, a.id, a.start_day, a_end]
					+ "and '%s' [%d-%d)"
					% [b.id, b.start_day, b_end]
				)


func _expire_active_tournaments(day: int) -> void:
	var remaining: Array[Dictionary] = []
	for evt: Dictionary in _active_tournaments:
		var def: TournamentEventDefinition = evt.get(
			"definition", null
		) as TournamentEventDefinition
		if not def:
			continue
		var start_day: int = evt.get("start_day", 0) as int
		if day < start_day + def.duration_days:
			remaining.append(evt)
		else:
			EventBus.tournament_event_ended.emit(def.id)
	_active_tournaments = remaining


func _promote_announced_tournaments(day: int) -> void:
	var remaining: Array[Dictionary] = []
	for evt: Dictionary in _announced_tournaments:
		var def: TournamentEventDefinition = evt.get(
			"definition", null
		) as TournamentEventDefinition
		if not def:
			continue
		if day >= def.start_day:
			_active_tournaments.append({
				"definition": def, "start_day": def.start_day,
			})
			EventBus.tournament_event_started.emit(def.id)
			if not def.active_text.is_empty():
				EventBus.notification_requested.emit(def.active_text)
		else:
			remaining.append(evt)
	_announced_tournaments = remaining


func _check_for_new_tournaments(day: int) -> void:
	for def: TournamentEventDefinition in _tournament_definitions:
		if _is_tournament_active_or_announced(def.id):
			continue
		var lead: int = maxi(def.telegraph_days, 1)
		if day != def.start_day - lead:
			continue
		_announce_tournament(def, day)


func _is_tournament_active_or_announced(
	event_id: String
) -> bool:
	for evt: Dictionary in _active_tournaments:
		var def: TournamentEventDefinition = evt.get(
			"definition", null
		) as TournamentEventDefinition
		if def and def.id == event_id:
			return true
	for evt: Dictionary in _announced_tournaments:
		var def: TournamentEventDefinition = evt.get(
			"definition", null
		) as TournamentEventDefinition
		if def and def.id == event_id:
			return true
	return false


func _announce_tournament(
	def: TournamentEventDefinition, day: int
) -> void:
	_announced_tournaments.append({
		"definition": def, "announced_day": day,
	})
	EventBus.tournament_event_announced.emit(def.id)
	EventBus.tournament_telegraphed.emit(def.id)
	if not def.announcement_text.is_empty():
		EventBus.notification_requested.emit(def.announcement_text)


func _on_day_ended(day: int) -> void:
	for evt: Dictionary in _active_tournaments:
		var def: TournamentEventDefinition = evt.get(
			"definition", null
		) as TournamentEventDefinition
		if not def:
			continue
		var start_day: int = evt.get("start_day", 0) as int
		if day == start_day + def.duration_days - 1:
			var result_summary: Dictionary = {
				"tournament_id": def.id,
				"display_name": def.name,
				"creature_type_focus": def.creature_type_focus,
				"duration_days": def.duration_days,
				"traffic_multiplier": def.traffic_multiplier,
				"price_spike_multiplier": def.price_spike_multiplier,
			}
			EventBus.tournament_ended.emit(def.id, result_summary)


func _find_tournament_definition(
	id: String
) -> TournamentEventDefinition:
	for def: TournamentEventDefinition in _tournament_definitions:
		if def.id == id:
			return def
	return null
