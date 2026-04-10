## Manages random events that create operational challenges and opportunities.
class_name RandomEventSystem
extends Node


const BASE_EVENT_CHANCE: float = 0.125
const CELEBRITY_TRAFFIC_MULTIPLIER: float = 3.0
const POWER_OUTAGE_TRAFFIC_MULTIPLIER: float = 0.5
const COLLECTOR_CONVENTION_TRAFFIC_MULTIPLIER: float = 2.0
const VIRAL_TREND_DEMAND_MULTIPLIER: float = 5.0

var _event_definitions: Array[RandomEventDefinition] = []
var _active_event: Dictionary = {}
var _cooldowns: Dictionary = {}
var _disabled_fixture_id: String = ""
var _effects: RandomEventEffects


func initialize(
	data_loader: DataLoader,
	inventory_system: InventorySystem,
	reputation_system: ReputationSystem
) -> void:
	_event_definitions = []
	_active_event = {}
	_cooldowns = {}
	_disabled_fixture_id = ""
	_effects = RandomEventEffects.new()
	_effects.initialize(inventory_system, reputation_system)
	if data_loader:
		_event_definitions = data_loader.get_all_random_events()
	EventBus.day_started.connect(_on_day_started)


## Returns the demand multiplier applied by active viral trend events.
func get_demand_multiplier(item_id: String) -> float:
	if _active_event.is_empty():
		return 1.0
	var def: RandomEventDefinition = _active_event.get(
		"definition", null
	) as RandomEventDefinition
	if not def or def.effect_type != "viral_trend":
		return 1.0
	var target: String = _active_event.get("target_item_id", "")
	if target == item_id:
		return VIRAL_TREND_DEMAND_MULTIPLIER
	return 1.0


## Returns the traffic multiplier from active events.
func get_traffic_multiplier() -> float:
	if _active_event.is_empty():
		return 1.0
	var def: RandomEventDefinition = _active_event.get(
		"definition", null
	) as RandomEventDefinition
	if not def:
		return 1.0
	match def.effect_type:
		"celebrity_visit":
			return CELEBRITY_TRAFFIC_MULTIPLIER
		"power_outage":
			return POWER_OUTAGE_TRAFFIC_MULTIPLIER
		"collector_convention":
			return COLLECTOR_CONVENTION_TRAFFIC_MULTIPLIER
	return 1.0


## Returns the category blocked by an active supply shortage, or empty.
func get_blocked_category() -> String:
	if _active_event.is_empty():
		return ""
	var def: RandomEventDefinition = _active_event.get(
		"definition", null
	) as RandomEventDefinition
	if not def or def.effect_type != "supply_shortage":
		return ""
	return _active_event.get("target_category", "")


## Returns the fixture id disabled by water leak, or empty.
func get_disabled_fixture_id() -> String:
	return _disabled_fixture_id


## Returns the currently active event for UI display, or empty dict.
func get_active_event() -> Dictionary:
	if _active_event.is_empty():
		return {}
	return _active_event.duplicate()


## Returns true if any random event is currently active.
func has_active_event() -> bool:
	return not _active_event.is_empty()


## Serializes state for saving.
func get_save_data() -> Dictionary:
	var active_save: Dictionary = {}
	if not _active_event.is_empty():
		var def: RandomEventDefinition = _active_event.get(
			"definition", null
		) as RandomEventDefinition
		active_save = {
			"definition_id": def.id if def else "",
			"start_day": _active_event.get("start_day", 0),
			"target_category": _active_event.get(
				"target_category", ""
			),
			"target_item_id": _active_event.get(
				"target_item_id", ""
			),
			"disabled_fixture_id": _disabled_fixture_id,
		}
	var cooldown_save: Dictionary = {}
	for event_id: String in _cooldowns:
		cooldown_save[event_id] = _cooldowns[event_id]
	return {
		"active_event": active_save,
		"cooldowns": cooldown_save,
	}


## Restores state from saved data.
func load_save_data(data: Dictionary) -> void:
	_active_event = {}
	_cooldowns = {}
	_disabled_fixture_id = ""
	var active_data: Variant = data.get("active_event", {})
	if active_data is Dictionary:
		_load_active_event(active_data as Dictionary)
	var cooldown_data: Variant = data.get("cooldowns", {})
	if cooldown_data is Dictionary:
		for key: String in (cooldown_data as Dictionary):
			_cooldowns[key] = int(
				(cooldown_data as Dictionary)[key]
			)


func _load_active_event(active: Dictionary) -> void:
	if not active.has("definition_id"):
		return
	var def_id: String = str(active.get("definition_id", ""))
	if def_id.is_empty():
		return
	var def: RandomEventDefinition = _find_definition(def_id)
	if not def:
		push_warning(
			"RandomEventSystem: saved event '%s' not found" % def_id
		)
		return
	_active_event = {
		"definition": def,
		"start_day": int(active.get("start_day", 0)),
		"target_category": str(
			active.get("target_category", "")
		),
		"target_item_id": str(
			active.get("target_item_id", "")
		),
	}
	_disabled_fixture_id = str(
		active.get("disabled_fixture_id", "")
	)


func _on_day_started(day: int) -> void:
	_tick_cooldowns()
	_check_active_event_expiry(day)
	if _active_event.is_empty():
		_try_trigger_event(day)


## Decrements all cooldown counters by 1 day.
func _tick_cooldowns() -> void:
	var to_remove: PackedStringArray = []
	for event_id: String in _cooldowns:
		_cooldowns[event_id] = int(_cooldowns[event_id]) - 1
		if int(_cooldowns[event_id]) <= 0:
			to_remove.append(event_id)
	for event_id: String in to_remove:
		_cooldowns.erase(event_id)


## Expires the active event if its duration has elapsed.
func _check_active_event_expiry(day: int) -> void:
	if _active_event.is_empty():
		return
	var def: RandomEventDefinition = _active_event.get(
		"definition", null
	) as RandomEventDefinition
	if not def:
		_active_event = {}
		return
	var start_day: int = _active_event.get("start_day", 0) as int
	if day >= start_day + def.duration_days:
		_end_active_event(def)


## Ends the currently active event and applies resolution effects.
func _end_active_event(def: RandomEventDefinition) -> void:
	_disabled_fixture_id = ""
	if not def.resolution_text.is_empty():
		EventBus.notification_requested.emit(def.resolution_text)
	EventBus.random_event_ended.emit(def.id)
	_cooldowns[def.id] = def.cooldown_days
	_active_event = {}


## Rolls for a new random event with ~10-15% daily chance.
func _try_trigger_event(day: int) -> void:
	var roll: float = randf()
	if roll > BASE_EVENT_CHANCE:
		return
	var eligible: Array[RandomEventDefinition] = _get_eligible()
	if eligible.is_empty():
		return
	var chosen: RandomEventDefinition = eligible[
		randi() % eligible.size()
	]
	_activate_event(chosen, day)


func _get_eligible() -> Array[RandomEventDefinition]:
	var eligible: Array[RandomEventDefinition] = []
	for def: RandomEventDefinition in _event_definitions:
		if not _cooldowns.has(def.id):
			eligible.append(def)
	return eligible


## Activates a specific random event and applies its immediate effects.
func _activate_event(
	def: RandomEventDefinition, day: int
) -> void:
	_active_event = {
		"definition": def,
		"start_day": day,
		"target_category": "",
		"target_item_id": "",
	}
	EventBus.random_event_started.emit(def.id)
	match def.effect_type:
		"supply_shortage":
			_effects.apply_supply_shortage(def, _active_event)
		"viral_trend":
			_effects.apply_viral_trend(def, _active_event)
		"health_inspection":
			_effects.apply_health_inspection(def)
			_finish_instant_event(def)
		"shoplifting":
			_effects.apply_shoplifting(def)
			_finish_instant_event(def)
		"water_leak":
			_disabled_fixture_id = "fixture_leak_%d" % randi()
			var msg: String = def.notification_text % def.duration_days
			EventBus.notification_requested.emit(msg)
		"celebrity_visit", "power_outage", "collector_convention":
			EventBus.notification_requested.emit(
				def.notification_text
			)


## Clears the active event for instant-resolution events.
func _finish_instant_event(def: RandomEventDefinition) -> void:
	_active_event = {}
	_cooldowns[def.id] = def.cooldown_days
	EventBus.random_event_ended.emit(def.id)


func _find_definition(id: String) -> RandomEventDefinition:
	for def: RandomEventDefinition in _event_definitions:
		if def.id == id:
			return def
	return null
