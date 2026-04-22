## Manages random events that create operational challenges and opportunities.
class_name RandomEventSystem
extends Node


## RandomEventSystem is dormant on days 1-2; activates from day 3 onward.
const ACTIVATION_DAY: int = 3
## In-game hour at which the next-day event telegraph fires (STORE_CLOSE_HOUR - 12 = 9).
const TELEGRAPH_HOUR: int = 9

const CELEBRITY_TRAFFIC_MULTIPLIER: float = 3.0
const POWER_OUTAGE_TRAFFIC_MULTIPLIER: float = 0.5
const COLLECTOR_CONVENTION_TRAFFIC_MULTIPLIER: float = 2.0
const RAINY_DAY_TRAFFIC_MULTIPLIER: float = 0.7
const VIRAL_TREND_DEMAND_MULTIPLIER: float = 5.0
const COMPETITOR_SALE_DEMAND_MODIFIER: float = 0.9

var _event_pool: Array[Dictionary] = []
var _event_definitions: Array[RandomEventDefinition] = []
var _active_event: Dictionary = {}
var _cooldowns: Dictionary = {}
var _last_fired: Dictionary = {}
var _disabled_fixture_id: String = ""
var _effects: RandomEventEffects
var _daily_rolled: bool = false
var _hourly_rolled_events: Dictionary = {}
var _current_day: int = 1
var _telegraph_emitted_today: bool = false


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
		_rebuild_event_pool()
	_apply_state({})
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)
	if not EventBus.hour_changed.is_connected(_on_hour_changed):
		EventBus.hour_changed.connect(_on_hour_changed)


## Evaluates all eligible daily events and returns IDs of those that fire.
func evaluate_daily_events(day: int = -1) -> Array[StringName]:
	var fired: Array[StringName] = []
	var roll_day: int = day if day > 0 else _get_current_day()
	# Reset the once-per-day guard when the caller advances days directly.
	if roll_day != _current_day:
		_daily_rolled = false
	if _daily_rolled:
		return fired
	_daily_rolled = true
	_current_day = roll_day
	var eligible: Array[RandomEventDefinition] = _get_eligible_daily()
	if eligible.is_empty():
		return fired
	for def: RandomEventDefinition in eligible:
		if not _roll_event(def):
			continue
		_activate_event(def, roll_day)
		fired.append(StringName(def.id))
		if not _active_event.is_empty():
			break
	return fired


func _get_current_day() -> int:
	if _current_day > 0:
		return _current_day
	return max(GameManager.current_day, 1)


func _roll_event(def: RandomEventDefinition) -> bool:
	return randf() <= RandomEventProbability.event_probability(
		def, _event_pool
	)


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
	var config: Dictionary = RandomEventProbability.event_pool_config(
		def.id, _event_pool
	)
	if not config.is_empty():
		return config.duplicate()
	return RandomEventProbability.definition_to_config(def)


func _rebuild_event_pool() -> void:
	_event_pool = []
	for def: RandomEventDefinition in _event_definitions:
		_event_pool.append(
			RandomEventProbability.definition_to_config(def)
		)


func serialize() -> Dictionary:
	return get_save_data()


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


func get_disabled_fixture_id() -> String:
	return _disabled_fixture_id


func get_active_event() -> Dictionary:
	if _active_event.is_empty():
		return {}
	return _active_event.duplicate()


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
	var last_fired_save: Dictionary = {}
	for event_id: String in _last_fired:
		last_fired_save[event_id] = _last_fired[event_id]
	return {
		"active_event": active_save,
		"cooldowns": cooldown_save,
		"last_fired": last_fired_save,
	}


func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_active_event = {}
	_cooldowns = {}
	_last_fired = {}
	_disabled_fixture_id = ""
	_daily_rolled = false
	_hourly_rolled_events = {}
	_telegraph_emitted_today = false
	var active_data: Variant = data.get("active_event", {})
	if active_data is Dictionary:
		_load_active_event(active_data as Dictionary)
	var cooldown_data: Variant = data.get("cooldowns", {})
	if cooldown_data is Dictionary:
		for key: String in (cooldown_data as Dictionary):
			_cooldowns[key] = int(
				(cooldown_data as Dictionary)[key]
			)
	var last_fired_data: Variant = data.get("last_fired", {})
	if last_fired_data is Dictionary:
		for key: String in (last_fired_data as Dictionary):
			_last_fired[key] = int(
				(last_fired_data as Dictionary)[key]
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
	_current_day = day
	_daily_rolled = false
	_hourly_rolled_events = {}
	_telegraph_emitted_today = false
	_tick_cooldowns()
	_check_active_event_expiry(day)
	if _active_event.is_empty() and day >= ACTIVATION_DAY:
		evaluate_daily_events(day)


func _on_hour_changed(hour: int) -> void:
	if _current_day >= ACTIVATION_DAY and hour == TELEGRAPH_HOUR and not _telegraph_emitted_today:
		_telegraph_emitted_today = true
		EventBus.random_event_telegraphed.emit(
			"Unusual market activity expected — watch prices tomorrow."
		)
	if _current_day < ACTIVATION_DAY:
		return
	if not _active_event.is_empty():
		return
	_try_trigger_hourly_event(hour)


func _tick_cooldowns() -> void:
	var to_remove: PackedStringArray = []
	for event_id: String in _cooldowns:
		_cooldowns[event_id] = int(_cooldowns[event_id]) - 1
		if int(_cooldowns[event_id]) <= 0:
			to_remove.append(event_id)
	for event_id: String in to_remove:
		_cooldowns.erase(event_id)


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


func _end_active_event(def: RandomEventDefinition) -> void:
	_disabled_fixture_id = ""
	if not def.resolution_text.is_empty():
		EventBus.notification_requested.emit(def.resolution_text)
	_emit_event_modifier_expired(def)
	EventBus.random_event_ended.emit(def.id)
	_cooldowns[def.id] = def.cooldown_days
	_active_event = {}


func _try_trigger_daily_event(day: int) -> void:
	if _daily_rolled:
		return
	evaluate_daily_events(day)


func _try_trigger_hourly_event(hour: int) -> void:
	var eligible: Array[RandomEventDefinition] = (
		_get_eligible_hourly(hour)
	)
	if eligible.is_empty():
		return
	var current_day: int = 1
	if is_inside_tree():
		var time_system: Node = get_parent().get_node_or_null(
			"TimeSystem"
		)
		if time_system and time_system.has_method("get_current_day"):
			current_day = time_system.get_current_day()
	for def: RandomEventDefinition in eligible:
		if _roll_event(def):
			_activate_event(def, current_day)
			return


func _get_eligible_daily() -> Array[RandomEventDefinition]:
	var eligible: Array[RandomEventDefinition] = []
	for def: RandomEventDefinition in _event_definitions:
		if _is_on_cooldown(def, _current_day):
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
		if _is_on_cooldown(def, _get_current_day()):
			continue
		if _hourly_rolled_events.has(def.id):
			continue
		if def.time_window_start < 0 or def.time_window_end < 0:
			continue
		if hour < def.time_window_start or hour > def.time_window_end:
			continue
		eligible.append(def)
	return eligible


func _is_on_cooldown(def: RandomEventDefinition, day: int) -> bool:
	if _cooldowns.has(def.id):
		return true
	if not _last_fired.has(def.id):
		return false
	var last_day: int = int(_last_fired[def.id])
	return day - last_day < def.cooldown_days


func _activate_event(
	def: RandomEventDefinition, day: int
) -> void:
	_last_fired[def.id] = day
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
		GameManager.get_active_store_id()
	)
	EventBus.random_event_triggered.emit(
		StringName(def.id), store_id, effect
	)
	_emit_toast(def)


func _apply_effect(def: RandomEventDefinition) -> Dictionary:
	var effect: Dictionary = {"type": def.effect_type}
	match def.effect_type:
		"supply_shortage":
			if _effects:
				_effects.apply_supply_shortage(def, _active_event)
			effect["target_category"] = _active_event.get(
				"target_category", ""
			)
		"viral_trend":
			if _effects:
				_effects.apply_viral_trend(def, _active_event)
			effect["target_item_id"] = _active_event.get(
				"target_item_id", ""
			)
		"health_inspection":
			var passed: bool = false
			if _effects:
				passed = _effects.apply_health_inspection(def)
			effect["passed"] = passed
			_finish_instant_event(def)
		"theft", "shoplifting":
			var stolen_name: String = ""
			if _effects:
				stolen_name = _effects.apply_shoplifting(def)
			effect["stolen_item"] = stolen_name
			_finish_instant_event(def)
		"water_leak":
			_disabled_fixture_id = "fixture_leak_%d" % randi()
			effect["disabled_fixture"] = _disabled_fixture_id
			EventBus.notification_requested.emit(
				def.notification_text % def.duration_days
			)
		"celebrity_visit", "power_outage", "collector_convention":
			EventBus.notification_requested.emit(
				def.notification_text
			)
		"bulk_order":
			var amount: float = 0.0
			if _effects:
				amount = _effects.apply_bulk_order(def)
			effect["cash_amount"] = amount
			_finish_instant_event(def)
		"competitor_sale":
			if _effects:
				_effects.apply_competitor_sale(def)
			else:
				EventBus.notification_requested.emit(def.notification_text)
			effect["demand_modifier"] = -0.1
			_emit_event_modifier_active(def, {
				"purchase_intent_multiplier": COMPETITOR_SALE_DEMAND_MODIFIER,
			})
		"rainy_day":
			if _effects:
				_effects.apply_rainy_day(def)
			else:
				EventBus.notification_requested.emit(def.notification_text)
			effect["traffic_modifier"] = RAINY_DAY_TRAFFIC_MULTIPLIER
			_emit_event_modifier_active(def, {
				"spawn_rate_multiplier": RAINY_DAY_TRAFFIC_MULTIPLIER,
			})
		"estate_sale":
			var item_name: String = ""
			if _effects:
				item_name = _effects.apply_estate_sale(def)
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


func _emit_event_modifier_active(
	def: RandomEventDefinition, modifier: Dictionary
) -> void:
	EventBus.market_event_active.emit(StringName(def.id), modifier)


func _emit_event_modifier_expired(def: RandomEventDefinition) -> void:
	match def.effect_type:
		"competitor_sale", "rainy_day":
			EventBus.market_event_expired.emit(StringName(def.id))


func _finish_instant_event(def: RandomEventDefinition) -> void:
	_active_event = {}
	_cooldowns[def.id] = def.cooldown_days
	EventBus.random_event_ended.emit(def.id)


func _find_definition(id: String) -> RandomEventDefinition:
	for def: RandomEventDefinition in _event_definitions:
		if def.id == id:
			return def
	return null
