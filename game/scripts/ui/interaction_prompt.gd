## Context-sensitive interaction prompt overlay shown when aiming at interactables.
extends CanvasLayer


const FADE_DURATION: float = 0.15

var _fade_tween: Tween

@onready var _panel: PanelContainer = $PanelContainer
@onready var _label: Label = $PanelContainer/Label


func _ready() -> void:
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_panel.visible = false
	EventBus.interactable_focused.connect(_on_interactable_focused)
	EventBus.interactable_unfocused.connect(_on_interactable_unfocused)


func _on_interactable_focused(action_label: String) -> void:
	_label.text = action_label
	_panel.visible = true
	_fade_to(1.0)


func _on_interactable_unfocused() -> void:
	_fade_to(0.0)


func _fade_to(target_alpha: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = _panel.create_tween()
	_fade_tween.tween_property(
		_panel, "modulate:a", target_alpha, FADE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if is_zero_approx(target_alpha):
		_fade_tween.tween_callback(_panel.hide)
