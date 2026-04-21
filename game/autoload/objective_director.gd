## Routes gameplay signals to EventBus.objective_changed with a three-slot payload.
## All text is sourced from objectives.json or tutorial_steps.json — zero hardcoded strings.
## Tracks the first full stock→sell→close loop to trigger auto-hide after day 3.
## When the tutorial is active, tutorial step content takes priority over day objectives.
extends Node

const CONTENT_PATH := "res://game/content/objectives.json"
const TUTORIAL_STEPS_PATH := "res://game/content/tutorial_steps.json"

var _day_objectives: Dictionary = {}
var _defaults: Dictionary = {}
var _tutorial_steps: Dictionary = {}  # step_id (no "step_" prefix) → {text, action, key}

var _current_day: int = 0
var _stocked: bool = false
var _sold: bool = false
var _loop_completed: bool = false
var _tutorial_active: bool = false
var _current_tutorial_step_id: String = ""


func _ready() -> void:
	_load_content()
	_load_tutorial_steps()
	EventBus.day_started.connect(_on_day_started)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.item_stocked.connect(_on_item_stocked)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.day_closed.connect(_on_day_closed)
	EventBus.preference_changed.connect(_on_preference_changed)
	EventBus.tutorial_step_changed.connect(_on_tutorial_step_changed)
	EventBus.tutorial_completed.connect(_on_tutorial_finished)
	EventBus.tutorial_skipped.connect(_on_tutorial_finished)


func _load_content() -> void:
	var file := FileAccess.open(CONTENT_PATH, FileAccess.READ)
	if not file:
		push_error("ObjectiveDirector: cannot open %s" % CONTENT_PATH)
		return
	var raw: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(raw) != OK:
		push_error("ObjectiveDirector: parse error in objectives.json: %s" % json.get_error_message())
		return
	var data: Variant = json.get_data()
	if not (data is Dictionary):
		push_error("ObjectiveDirector: objectives.json root must be a Dictionary")
		return
	var d := data as Dictionary
	_defaults = {
		"text": str(d.get("default_text", "")),
		"action": str(d.get("default_action", "")),
		"key": str(d.get("default_key", "")),
	}
	for entry: Variant in d.get("objectives", []):
		if not (entry is Dictionary):
			continue
		var e := entry as Dictionary
		if not e.has("day"):
			continue
		_day_objectives[int(e["day"])] = {
			"text": str(e.get("text", _defaults["text"])),
			"action": str(e.get("action", _defaults["action"])),
			"key": str(e.get("key", _defaults["key"])),
		}


func _load_tutorial_steps() -> void:
	var file := FileAccess.open(TUTORIAL_STEPS_PATH, FileAccess.READ)
	if not file:
		push_warning("ObjectiveDirector: cannot open %s" % TUTORIAL_STEPS_PATH)
		return
	var raw: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(raw) != OK:
		push_warning("ObjectiveDirector: parse error in tutorial_steps.json")
		return
	var data: Variant = json.get_data()
	if not (data is Dictionary):
		return
	for entry: Variant in (data as Dictionary).get("tutorial_steps", []):
		if not (entry is Dictionary):
			continue
		var e := entry as Dictionary
		var step_id: String = str(e.get("id", ""))
		if step_id.is_empty():
			continue
		_tutorial_steps[step_id] = {
			"text": str(e.get("prompt_text", "")),
			"action": str(e.get("action", "")),
			"key": str(e.get("key", "")),
		}


func _on_day_started(day: int) -> void:
	_current_day = day
	_stocked = false
	_sold = false
	_emit_current()


func _on_store_entered(_store_id: StringName) -> void:
	_emit_current()


func _on_item_stocked(_item_id: String, _shelf_id: String) -> void:
	_stocked = true
	_emit_current()


func _on_item_sold(item_id: String, price: float, _category: String) -> void:
	if not _sold:
		_sold = true
		EventBus.first_sale_completed.emit(&"", item_id, price)
	_emit_current()


func _on_day_closed(_day: int, _summary: Dictionary) -> void:
	if _stocked and _sold:
		_loop_completed = true


func _on_preference_changed(key: String, _value: Variant) -> void:
	if key == "show_objective_rail":
		_emit_current()


func _on_tutorial_step_changed(step_id: String) -> void:
	_tutorial_active = true
	_current_tutorial_step_id = step_id
	_emit_current()


func _on_tutorial_finished() -> void:
	_tutorial_active = false
	_current_tutorial_step_id = ""
	_emit_current()


## Builds and emits the current payload. Tutorial content takes priority over day objectives
## when the tutorial is active. Sends {hidden: true} when the auto-hide condition is met.
func _emit_current() -> void:
	var should_auto_hide: bool = _loop_completed and _current_day > 3
	if should_auto_hide and not Settings.show_objective_rail:
		var hidden: Dictionary = {"hidden": true}
		EventBus.objective_changed.emit(hidden)
		EventBus.objective_updated.emit(hidden)
		return
	var payload: Dictionary
	if _tutorial_active and _tutorial_steps.has(_current_tutorial_step_id):
		payload = _tutorial_steps[_current_tutorial_step_id].duplicate()
	else:
		payload = _day_objectives.get(_current_day, _defaults).duplicate()
	EventBus.objective_changed.emit(payload)
	var updated: Dictionary = {
		"current_objective": str(payload.get("text", "")),
		"next_action": str(payload.get("action", "")),
		"input_hint": str(payload.get("key", "")),
		"optional_hint": str(payload.get("optional_hint", "")),
	}
	EventBus.objective_updated.emit(updated)
