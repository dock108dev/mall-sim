## Persistent HUD strip showing the player's current three-slot objective display.
## Registered as an autoload CanvasLayer so it survives scene transitions.
## Content arrives via EventBus.objective_changed(payload); no text is hardcoded here.
## Mouse input is never captured — all containers use MOUSE_FILTER_IGNORE.
## Auto-hide and Settings-override logic lives in ObjectiveDirector, not here.
class_name ObjectiveRail
extends CanvasLayer

@onready var _objective_label: Label = $MarginContainer/VBoxContainer/ObjectiveLabel
@onready var _action_label: Label = $MarginContainer/VBoxContainer/ActionLabel
@onready var _hint_label: Label = $MarginContainer/VBoxContainer/HintLabel

var _auto_hidden: bool = false
var _current_payload: Dictionary = {}


func _ready() -> void:
	EventBus.objective_changed.connect(_on_objective_changed)
	EventBus.preference_changed.connect(_on_preference_changed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.arc_unlock_triggered.connect(_on_arc_unlock_triggered)
	visible = false


func _on_day_started(_day: int) -> void:
	_refresh_visibility()


func _on_arc_unlock_triggered(_unlock_id: String, _day: int) -> void:
	_refresh_visibility()


func _on_objective_changed(payload: Dictionary) -> void:
	if payload.get("hidden", false):
		_auto_hidden = true
		_refresh_visibility()
		return
	_auto_hidden = false
	_current_payload = payload
	_objective_label.text = str(payload.get("text", ""))
	_action_label.text = str(payload.get("action", ""))
	_hint_label.text = str(payload.get("key", ""))
	_refresh_visibility()


## ObjectiveDirector re-emits the appropriate payload on preference_changed,
## so this handler only needs to trigger a visibility recalc.
func _on_preference_changed(key: String, _value: Variant) -> void:
	if key == "show_objective_rail":
		_refresh_visibility()


func _refresh_visibility() -> void:
	visible = not _auto_hidden and not _current_payload.is_empty()
