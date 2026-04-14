## Manages random events that create operational challenges and opportunities.
class_name RandomEventSystem
extends Node


const CELEBRITY_TRAFFIC_MULTIPLIER: float = 3.0
const POWER_OUTAGE_TRAFFIC_MULTIPLIER: float = 0.5
const COLLECTOR_CONVENTION_TRAFFIC_MULTIPLIER: float = 2.0
const RAINY_DAY_TRAFFIC_MULTIPLIER: float = 0.7
const VIRAL_TREND_DEMAND_MULTIPLIER: float = 5.0
const COMPETITOR_SALE_DEMAND_MODIFIER: float = 0.9

var _event_definitions: Array[RandomEventDefinition] = []
var _active_event: Dictionary = {}
var _cooldowns: Dictionary = {}
var _disabled_fixture_id: String = ""
var _effects: RandomEventEffects
var _daily_rolled: bool = false
var _hourly_rolled_events: Dictionary = {}


func initialize(
	data_loader: DataLoader,
	inventory_system: InventorySystem,
	reputation_system: ReputationSystem,
	economy_system: EconomySystem
) -> void:
	_event_definitions = []
	_effects = RandomEventEffects.new()
	_effects.initialize(
		inventory_system, reputation_system, economy_system
	)
	if data_loader:
		_event_definitions = data_loader.get_all_random_events()
	_apply_state({})
	EventBus.day_started.connect(_on_day_started)
	EventBus.hour_changed.connect(_on_hour_changed)


## Evaluates all eligible daily events and returns IDs of those that fire.
func evaluate_daily_events(day: int) -> Array[StringName]:
	_daily_rolled = true
	var fired: Array[StringName] = []
	var eligible: Array[RandomEventDefinition] = _get_eligible_daily()
	if eligible.is_empty():
		return fired
	var chosen: RandomEventDefinition = _weighted_pick(eligible)
	if not chosen:
		return fired
	_activate_event(chosen, day)
	fired.append(StringName(chosen.id))
	return fired


## Returns the config dictionary for a given event ID, or empty dict.
func get_event_config(event_id: StringName) -> Dictionary:
	var def: RandomEventDefinition = _find_definition(
		String(event_id)
	)
	if not def:
		push_error(
			"RandomEventSystem: unknown event_id '%s'" % event_id
		)
		return {}
	return {
		"id": def.id,
		"name": def.name,
		"description": def.description,
		"effect_type": def.effect_type,
		"duration_days": def.duration_days,
		"severity": def.severity,
		"cooldown_days": def.cooldown_days,
		"probability_weight": def.probability_weight,
		"target_category": def.target_category,
		"target_item_id": def.target_item_id,
		"notification_text": def.notification_text,
		"resolution_text": def.resolution_text,
		"toast_message": def.toast_message,
		"time_window_start": def.time_window_start,
		"time_window_end": def.time_window_end,
	}


## Serializes state for save system compatibility.
func serialize() -> Dictionary:
	return get_save_data()


## Restores state from serialized data.
func deserialize(data: Dictionary) -> void:
	load_save_data(data)


## Returns the demand multiplier applied by active viral trend events.
func get_demand_multiplier(item_id: String) -> float:
	if _active_event.is_empty():
		return 1.0
	var def: RandomEventDefinition = _active_event.get(
		"definition", null
	) as RandomEventDefinition
	if not def:
		return 1.0
	if def.effect_type == "viral_trend":
		var target: String = _active_event.get(
			"target_item_id", ""
		)
		if target == item_id:
			return VIRAL_TREND_DEMAND_MULTIPLIER
	if def.effect_type == "competitor_sale":
		return COMPETITOR_SALE_DEMAND_MODIFIER
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
		"rainy_day":
			return RAINY_DAY_TRAFFIC_MULTIPLIER
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
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_active_event = {}
	_cooldowns = {}
	_disabled_fixture_id = ""
	_daily_rolled = false
	_hourly_rolled_events = {}
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
	_daily_rolled = false
	_hourly_rolled_events = {}
	_tick_cooldowns()
	_check_active_event_expiry(day)
	if _active_event.is_empty():
		evaluate_daily_events(day)


func _on_hour_changed(hour: int) -> void:
	if not _active_event.is_empty():
		return
	_try_trigger_hourly_event(hour)


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


## Rolls for daily events using probability weights from definitions.
func _try_trigger_daily_event(day: int) -> void:
	if _daily_rolled:
		return
	evaluate_daily_events(day)


## Rolls for intra-day events in their time windows.
func _try_trigger_hourly_event(hour: int) -> void:
	var eligible: Array[RandomEventDefinition] = (
		_get_eligible_hourly(hour)
	)
	if eligible.is_empty():
		return
	var chosen: RandomEventDefinition = _weighted_pick(eligible)
	if not chosen:
		return
	var current_day: int = 1
	if is_inside_tree():
		var time_system: Node = get_parent().get_node_or_null(
			"TimeSystem"
		)
		if time_system and time_system.has_method("get_current_day"):
			current_day = time_system.get_current_day()
	_activate_event(chosen, current_day)


func _get_eligible_daily() -> Array[RandomEventDefinition]:
	var eligible: Array[RandomEventDefinition] = []
	for def: RandomEventDefinition in _event_definitions:
		if _cooldowns.has(def.id):
			continue
		if def.time_window_start >= 0:
			continue
		eligible.append(def)
	return eligible


func _get_eligible_hourly(
	hour: int
) -> Array[RandomEventDefinition]:
	var eligible: Array[RandomEventDefinition] = []
	for def: RandomEventDefinition in _event_definitions:
		if _cooldowns.has(def.id):
			continue
		if _hourly_rolled_events.has(def.id):
			continue
		if def.time_window_start < 0 or def.time_window_end < 0:
			continue
		if hour < def.time_window_start or hour > def.time_window_end:
			continue
		eligible.append(def)
	return eligible


## Selects an event using probability weights. Returns null if roll fails.
func _weighted_pick(
	candidates: Array[RandomEventDefinition]
) -> RandomEventDefinition:
	var total_weight: float = 0.0
	for def: RandomEventDefinition in candidates:
		total_weight += def.probability_weight
	if total_weight <= 0.0:
		return null
	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for def: RandomEventDefinition in candidates:
		cumulative += def.probability_weight
		if roll <= cumulative:
			return def
	return candidates[candidates.size() - 1]


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
	if def.time_window_start >= 0:
		_hourly_rolled_events[def.id] = true
	EventBus.random_event_started.emit(def.id)
	var effect: Dictionary = _apply_effect(def)
	var store_id: StringName = StringName(
		GameManager.current_store_id
	)
	EventBus.random_event_triggered.emit(
		StringName(def.id), store_id, effect
	)
	_emit_toast(def)


func _apply_effect(def: RandomEventDefinition) -> Dictionary:
	var effect: Dictionary = {"type": def.effect_type}
	match def.effect_type:
		"supply_shortage":
			_effects.apply_supply_shortage(def, _active_event)
			effect["target_category"] = _active_event.get(
				"target_category", ""
			)
		"viral_trend":
			_effects.apply_viral_trend(def, _active_event)
			effect["target_item_id"] = _active_event.get(
				"target_item_id", ""
			)
		"health_inspection":
			var passed: bool = _effects.apply_health_inspection(def)
			effect["passed"] = passed
			_finish_instant_event(def)
		"shoplifting":
			var stolen_name: String = _effects.apply_shoplifting(def)
			effect["stolen_item"] = stolen_name
			_finish_instant_event(def)
		"water_leak":
			_disabled_fixture_id = "fixture_leak_%d" % randi()
			effect["disabled_fixture"] = _disabled_fixture_id
			var msg: String = def.notification_text % def.duration_days
			EventBus.notification_requested.emit(msg)
		"celebrity_visit", "power_outage", "collector_convention":
			EventBus.notification_requested.emit(
				def.notification_text
			)
		"bulk_order":
			var amount: float = _effects.apply_bulk_order(def)
			effect["cash_amount"] = amount
			_finish_instant_event(def)
		"competitor_sale":
			_effects.apply_competitor_sale(def)
			effect["demand_modifier"] = -0.1
		"rainy_day":
			_effects.apply_rainy_day(def)
			effect["traffic_modifier"] = 0.7
		"estate_sale":
			var item_name: String = _effects.apply_estate_sale(def)
			effect["item_name"] = item_name
			_finish_instant_event(def)
	return effect


func _emit_toast(def: RandomEventDefinition) -> void:
	var message: String = def.toast_message
	if message.is_empty():
		message = def.name
	EventBus.toast_requested.emit(
		message, &"random_event", 4.0
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
