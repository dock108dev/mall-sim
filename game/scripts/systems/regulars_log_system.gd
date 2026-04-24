## Tracks named returning customers (regulars) and evaluates per-customer
## narrative thread triggers after each visit.
##
## Trigger condition types (defined in regulars_threads.json):
##   visit_count  — regular's own visit count reaches a threshold
##   purchase_type — regular's purchase history contains a matching category
##   day_range    — current game day falls within [min_day, max_day]
class_name RegularsLogSystem
extends Node

## Visit count at which a customer is first flagged as a regular.
const RECOGNITION_THRESHOLD: int = 3

## customer_id (String) -> entry dict:
##   name, visit_count, last_seen_day, purchase_history[], thread_state{}
var _log: Dictionary = {}
var _thread_defs: Array[Dictionary] = []
var _current_day: int = 0


func initialize() -> void:
	_load_thread_definitions()
	_connect_signals()


func _ready() -> void:
	if _thread_defs.is_empty():
		_load_thread_definitions()
	_connect_signals()


func _load_thread_definitions() -> void:
	var path: String = "res://game/content/meta/regulars_threads.json"
	var parsed: Variant = DataLoader.load_json(path)
	if not (parsed is Array):
		push_error("RegularsLogSystem: failed to load %s as Array" % path)
		return
	for entry: Variant in (parsed as Array):
		if entry is Dictionary:
			_thread_defs.append(entry as Dictionary)


func _connect_signals() -> void:
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)
	if not EventBus.customer_purchased.is_connected(_on_customer_purchased):
		EventBus.customer_purchased.connect(_on_customer_purchased)
	if not EventBus.customer_left.is_connected(_on_customer_left):
		EventBus.customer_left.connect(_on_customer_left)


func _on_day_started(day: int) -> void:
	_current_day = day


func _on_customer_purchased(
	_store_id: StringName, item_id: StringName,
	_price: float, customer_id: StringName
) -> void:
	var key: String = str(customer_id)
	if key.is_empty() or not _log.has(key):
		return
	var item_entry: Dictionary = ContentRegistry.get_entry(item_id)
	var category: String = str(item_entry.get("category", ""))
	_record_purchase(key, str(item_id), category)


## Records a purchase for a tracked regular. Exposed for testing.
func _record_purchase(
	customer_id: String, item_id: String, category: String
) -> void:
	if not _log.has(customer_id):
		return
	var entry: Dictionary = _log[customer_id]
	var history: Array = entry.get("purchase_history", []) as Array
	history.append({
		"item_id": item_id,
		"category": category,
		"day": _current_day,
	})
	entry["purchase_history"] = history
	_evaluate_threads(customer_id)


func _on_customer_left(customer_data: Dictionary) -> void:
	var raw_id: Variant = customer_data.get("customer_id", "")
	var customer_id: String = str(raw_id)
	if customer_id.is_empty():
		return
	var display_name: String = str(customer_data.get("profile_name", ""))
	_record_visit(customer_id, display_name)
	_evaluate_threads(customer_id)


## Records a visit for a customer, creating their log entry if absent.
## Emits regular_recognized on the visit that meets RECOGNITION_THRESHOLD.
func _record_visit(customer_id: String, display_name: String) -> void:
	if not _log.has(customer_id):
		_log[customer_id] = {
			"name": display_name,
			"visit_count": 0,
			"last_seen_day": 0,
			"purchase_history": [],
			"thread_state": {},
		}
	var entry: Dictionary = _log[customer_id]
	var new_count: int = int(entry.get("visit_count", 0)) + 1
	entry["visit_count"] = new_count
	entry["last_seen_day"] = _current_day
	if not display_name.is_empty():
		entry["name"] = display_name
	if new_count == RECOGNITION_THRESHOLD:
		EventBus.regular_recognized.emit(
			StringName(customer_id),
			str(entry.get("name", "")),
			new_count
		)
	_evaluate_threads(customer_id)


func _evaluate_threads(customer_id: String) -> void:
	if not _log.has(customer_id):
		return
	var entry: Dictionary = _log[customer_id]
	for def: Dictionary in _thread_defs:
		_evaluate_thread_for_regular(customer_id, entry, def)


func _evaluate_thread_for_regular(
	customer_id: String, entry: Dictionary, def: Dictionary
) -> void:
	var thread_id: String = str(def.get("id", ""))
	if thread_id.is_empty():
		return
	var thread_states: Dictionary = entry.get("thread_state", {})
	if not thread_states.has(thread_id):
		thread_states[thread_id] = {"phase": 0}
		entry["thread_state"] = thread_states
	var state: Dictionary = thread_states[thread_id]
	var current_phase: int = int(state.get("phase", 0))
	var phases: Array = def.get("phases", []) as Array
	if current_phase >= phases.size():
		return
	var phase_def: Variant = phases[current_phase]
	if phase_def is not Dictionary:
		return
	var phase_dict: Dictionary = phase_def as Dictionary
	var trigger: Dictionary = phase_dict.get("trigger", {})
	if not _check_trigger(trigger, entry):
		return
	var new_phase: int = current_phase + 1
	state["phase"] = new_phase
	var payoff: String = str(phase_dict.get("payoff_text", ""))
	if new_phase >= phases.size():
		EventBus.thread_resolved.emit(thread_id, "resolved")
	else:
		EventBus.thread_advanced.emit(
			thread_id, StringName(customer_id), new_phase
		)


func _check_trigger(trigger: Dictionary, entry: Dictionary) -> bool:
	var type: String = str(trigger.get("type", ""))
	match type:
		"visit_count":
			var threshold: int = int(trigger.get("threshold", 1))
			return int(entry.get("visit_count", 0)) >= threshold
		"purchase_type":
			var category: String = str(trigger.get("category", ""))
			if category.is_empty():
				return false
			var history: Array = entry.get("purchase_history", []) as Array
			for item: Variant in history:
				if item is not Dictionary:
					continue
				if str((item as Dictionary).get("category", "")) == category:
					return true
			return false
		"day_range":
			var min_day: int = int(trigger.get("min_day", 0))
			var max_day: int = int(trigger.get("max_day", 999999))
			return _current_day >= min_day and _current_day <= max_day
	return false


## Returns the full log entry for a customer_id, or empty dict if not tracked.
func get_regular(customer_id: String) -> Dictionary:
	return _log.get(customer_id, {})


## Returns the phase index of a thread for a customer (0 = not started).
func get_thread_phase(customer_id: String, thread_id: String) -> int:
	var entry: Dictionary = _log.get(customer_id, {})
	var states: Dictionary = entry.get("thread_state", {})
	return int(states.get(thread_id, {}).get("phase", 0))


## Serializes the regulars log for inclusion in the save file.
func get_save_data() -> Dictionary:
	return {"regulars_log": _log.duplicate(true)}


## Restores the regulars log from save data.
func load_state(data: Dictionary) -> void:
	var raw: Variant = data.get("regulars_log", {})
	if raw is Dictionary:
		_log = (raw as Dictionary).duplicate(true)
