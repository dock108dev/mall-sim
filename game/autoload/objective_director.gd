## Routes gameplay signals to EventBus.objective_changed with a three-slot payload.
## All text is sourced from objectives.json — zero hardcoded strings. Tutorial
## step text is rendered by `TutorialOverlay` (reading localization CSV via
## `tr()`), not by this director — the two-source overlap was removed per
## docs/audits/phase0-ui-integrity.md P1.3.
## Tracks the first full stock→sell→close loop to trigger auto-hide after day 3.
extends Node

const CONTENT_PATH := "res://game/content/objectives.json"

var _day_objectives: Dictionary = {}
var _defaults: Dictionary = {}

var _current_day: int = 0
var _stocked: bool = false
var _sold: bool = false
var _loop_completed: bool = false


func _ready() -> void:
	_load_content()
	EventBus.day_started.connect(_on_day_started)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.item_stocked.connect(_on_item_stocked)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.day_closed.connect(_on_day_closed)
	EventBus.preference_changed.connect(_on_preference_changed)


func _load_content() -> void:
	var data: Variant = DataLoader.load_json(CONTENT_PATH)
	if not (data is Dictionary):
		push_error("ObjectiveDirector: failed to load %s as Dictionary" % CONTENT_PATH)
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
			"post_sale_text": str(e.get("post_sale_text", "")),
			"post_sale_action": str(e.get("post_sale_action", "")),
			"post_sale_key": str(e.get("post_sale_key", "")),
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
		# §F-55 — set the flag before emitting so listeners that read
		# `GameState.get_flag(&"first_sale_complete")` from inside the
		# `first_sale_completed` handler see the already-true value.
		GameState.set_flag(&"first_sale_complete", true)
		EventBus.first_sale_completed.emit(&"", item_id, price)
	_emit_current()


func _on_day_closed(_day: int, _summary: Dictionary) -> void:
	if _stocked and _sold:
		_loop_completed = true


func _on_preference_changed(key: String, _value: Variant) -> void:
	if key == "show_objective_rail":
		_emit_current()


## Builds and emits the current payload from the day objective for the active
## day. Sends {hidden: true} when the auto-hide condition is met. Tutorial
## text is owned by `TutorialOverlay` and does not flow through this payload.
func _emit_current() -> void:
	var should_auto_hide: bool = _loop_completed and _current_day > 3
	if should_auto_hide and not Settings.show_objective_rail:
		var hidden: Dictionary = {"hidden": true}
		EventBus.objective_changed.emit(hidden)
		EventBus.objective_updated.emit(hidden)
		return
	var source: Dictionary = _day_objectives.get(_current_day, _defaults)
	var text_value: String = str(source.get("text", ""))
	var action_value: String = str(source.get("action", ""))
	var key_value: String = str(source.get("key", ""))
	# Once the first sale completes, advance the rail to the day's post-sale
	# copy when the day entry authors one. Day 1 uses this to flip from
	# "Stock your first item and make a sale" to "First sale complete. Close
	# the day when ready." so the rail confirms progress and points at the
	# next action.
	if _sold:
		var post_text: String = str(source.get("post_sale_text", ""))
		if not post_text.is_empty():
			text_value = post_text
			action_value = str(source.get("post_sale_action", ""))
			key_value = str(source.get("post_sale_key", ""))
	var payload: Dictionary = {
		"objective": text_value,
		"text": text_value,
		"action": action_value,
		"key": key_value,
	}
	EventBus.objective_changed.emit(payload)
	var updated: Dictionary = {
		"current_objective": text_value,
		"next_action": action_value,
		"input_hint": key_value,
		"optional_hint": str(source.get("optional_hint", "")),
	}
	EventBus.objective_updated.emit(updated)
