## Day 1 contextual hint system that guides new players through key moments.
class_name OnboardingSystem
extends Node


const ONBOARDING_CONFIG_PATH := "res://game/content/onboarding/onboarding_config.json"

var _shown_hints: Dictionary = {}
var _hint_definitions: Array[Dictionary] = []
var _trigger_map: Dictionary = {}
var _active: bool = true
var _current_day: int = 1


func _ready() -> void:
	_load_hint_definitions()
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)


func maybe_show_hint(trigger: StringName) -> void:
	if not _active:
		return
	if _current_day > 1:
		return

	var hint: Dictionary = _trigger_map.get(trigger, {})
	if hint.is_empty():
		return

	var hint_id: StringName = StringName(hint.get("id", ""))
	if hint_id.is_empty():
		return
	if _shown_hints.get(hint_id, false):
		return

	var message: String = hint.get("message", "")
	var position_hint: String = hint.get("position_hint", "center")

	_shown_hints[hint_id] = true
	EventBus.onboarding_hint_shown.emit(hint_id, message, position_hint)


func disable() -> void:
	_active = false


func is_active() -> bool:
	return _active


func get_save_data() -> Dictionary:
	var serialized_hints: Dictionary = {}
	for key: StringName in _shown_hints:
		serialized_hints[String(key)] = _shown_hints[key]
	return {
		"shown_hints": serialized_hints,
		"active": _active,
	}


func load_save_data(data: Dictionary) -> void:
	var hints_data: Variant = data.get("shown_hints", {})
	_shown_hints.clear()
	if hints_data is Dictionary:
		for key: String in hints_data:
			_shown_hints[StringName(key)] = true
	_active = data.get("active", true)


func _load_hint_definitions() -> void:
	if not FileAccess.file_exists(ONBOARDING_CONFIG_PATH):
		push_error("OnboardingSystem: config not found at %s" % ONBOARDING_CONFIG_PATH)
		return

	var file: FileAccess = FileAccess.open(ONBOARDING_CONFIG_PATH, FileAccess.READ)
	if not file:
		push_error("OnboardingSystem: failed to open %s" % ONBOARDING_CONFIG_PATH)
		return

	var json: JSON = JSON.new()
	var error: Error = json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_error("OnboardingSystem: JSON parse error in %s: %s" % [
			ONBOARDING_CONFIG_PATH, json.get_error_message()
		])
		return

	var config: Variant = json.data
	if not config is Dictionary:
		push_error("OnboardingSystem: config root must be a Dictionary")
		return

	var hints: Variant = config.get("hints", [])
	if not hints is Array:
		push_error("OnboardingSystem: 'hints' must be an Array")
		return

	for hint: Variant in hints:
		if not hint is Dictionary:
			continue
		var hint_dict: Dictionary = hint as Dictionary
		var trigger: String = hint_dict.get("trigger", "")
		if trigger.is_empty():
			continue
		_hint_definitions.append(hint_dict)
		_trigger_map[StringName(trigger)] = hint_dict


func _on_day_started(day: int) -> void:
	_current_day = day
	if day > 1:
		disable()


func _on_day_ended(_day: int) -> void:
	if _current_day >= 1:
		disable()
