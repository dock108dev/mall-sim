## Manages recurring seasonal events that affect customer traffic and spending.
class_name SeasonalEventSystem
extends Node


const ANNOUNCEMENT_DAYS: int = 1

var _event_definitions: Array[SeasonalEventDefinition] = []
var _active_events: Array[Dictionary] = []
var _announced_events: Array[Dictionary] = []


func initialize(data_loader: DataLoader) -> void:
	_event_definitions = []
	_active_events = []
	_announced_events = []
	if data_loader:
		_event_definitions = data_loader.get_all_seasonal_events()
	EventBus.day_started.connect(_on_day_started)


## Returns the combined customer traffic multiplier from all active events.
func get_traffic_multiplier() -> float:
	var combined: float = 1.0
	for evt: Dictionary in _active_events:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if def:
			combined *= def.customer_traffic_multiplier
	return combined


## Returns the combined spending multiplier from all active events.
func get_spending_multiplier() -> float:
	var combined: float = 1.0
	for evt: Dictionary in _active_events:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if def:
			combined *= def.spending_multiplier
	return combined


## Returns merged customer type weight overrides from all active events.
func get_customer_type_weights() -> Dictionary:
	var merged: Dictionary = {}
	for evt: Dictionary in _active_events:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if not def:
			continue
		for type_id: String in def.customer_type_weights:
			var weight: float = float(def.customer_type_weights[type_id])
			if merged.has(type_id):
				merged[type_id] = (merged[type_id] as float) * weight
			else:
				merged[type_id] = weight
	return merged


## Returns all currently active seasonal events for UI display.
func get_active_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for evt: Dictionary in _active_events:
		result.append(evt.duplicate())
	return result


## Returns all announced (upcoming) seasonal events for UI display.
func get_announced_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for evt: Dictionary in _announced_events:
		result.append(evt.duplicate())
	return result


## Returns a display string summarizing active seasonal event impacts.
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


## Serializes state for saving.
func get_save_data() -> Dictionary:
	var active_save: Array[Dictionary] = []
	for evt: Dictionary in _active_events:
		var save_evt: Dictionary = {
			"definition_id": "",
			"start_day": evt.get("start_day", 0),
		}
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if def:
			save_evt["definition_id"] = def.id
		active_save.append(save_evt)
	var announced_save: Array[Dictionary] = []
	for evt: Dictionary in _announced_events:
		var save_evt: Dictionary = {
			"definition_id": "",
			"announced_day": evt.get("announced_day", 0),
		}
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if def:
			save_evt["definition_id"] = def.id
		announced_save.append(save_evt)
	return {
		"active_events": active_save,
		"announced_events": announced_save,
	}


## Restores state from saved data.
func load_save_data(data: Dictionary) -> void:
	_active_events = []
	_announced_events = []
	var saved_active: Array = data.get("active_events", [])
	for entry: Variant in saved_active:
		if entry is not Dictionary:
			continue
		var evt: Dictionary = entry as Dictionary
		var def_id: String = evt.get("definition_id", "")
		var def: SeasonalEventDefinition = _find_definition(def_id)
		if not def:
			push_warning(
				"SeasonalEventSystem: saved event '%s' not found"
				% def_id
			)
			continue
		_active_events.append({
			"definition": def,
			"start_day": int(evt.get("start_day", 0)),
		})
	var saved_announced: Array = data.get("announced_events", [])
	for entry: Variant in saved_announced:
		if entry is not Dictionary:
			continue
		var evt: Dictionary = entry as Dictionary
		var def_id: String = evt.get("definition_id", "")
		var def: SeasonalEventDefinition = _find_definition(def_id)
		if not def:
			continue
		_announced_events.append({
			"definition": def,
			"announced_day": int(evt.get("announced_day", 0)),
		})


func _on_day_started(day: int) -> void:
	_expire_active_events(day)
	_promote_announced_events(day)
	_check_for_new_events(day)


## Removes active events whose duration has elapsed.
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


## Promotes announced events to active if their start day has arrived.
func _promote_announced_events(day: int) -> void:
	var remaining: Array[Dictionary] = []
	for evt: Dictionary in _announced_events:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if not def:
			continue
		var announced_day: int = evt.get("announced_day", 0) as int
		var start_day: int = announced_day + ANNOUNCEMENT_DAYS
		if day >= start_day:
			_active_events.append({
				"definition": def,
				"start_day": start_day,
			})
			EventBus.seasonal_event_started.emit(def.id)
			if not def.active_text.is_empty():
				EventBus.notification_requested.emit(def.active_text)
		else:
			remaining.append(evt)
	_announced_events = remaining


## Checks if any seasonal events should trigger based on day modulo.
func _check_for_new_events(day: int) -> void:
	for def: SeasonalEventDefinition in _event_definitions:
		if _is_event_active_or_announced(def.id):
			continue
		if not _should_trigger(day, def):
			continue
		_announce_event(def, day)


## Returns true if the event should trigger on this day.
func _should_trigger(
	day: int, def: SeasonalEventDefinition
) -> bool:
	var adjusted: int = day - def.offset_days
	if adjusted <= 0:
		return false
	return adjusted % def.frequency_days == 0


## Returns true if the given event is already active or announced.
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


## Announces an upcoming seasonal event.
func _announce_event(
	def: SeasonalEventDefinition, day: int
) -> void:
	_announced_events.append({
		"definition": def,
		"announced_day": day,
	})
	EventBus.seasonal_event_announced.emit(def.id)
	if not def.announcement_text.is_empty():
		EventBus.notification_requested.emit(def.announcement_text)


func _find_definition(
	id: String
) -> SeasonalEventDefinition:
	for def: SeasonalEventDefinition in _event_definitions:
		if def.id == id:
			return def
	return null
