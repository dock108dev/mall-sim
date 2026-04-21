## Drop onto any Control node to add hover interaction affordance.
## On mouse_entered: emits EventBus.interactable_focused(action_label) and applies
## accent_interact tint via self_modulate. On mouse_exited: emits unfocused and resets.
## Does not capture input — parent must have mouse_filter = STOP.
extends Node

const TWEEN_DURATION: float = 0.1
const ACCENT_INTERACT: Color = UIThemeConstants.SEMANTIC_INFO  # #5BB8E8

@export var action_label: String = "Interact"

var _parent: Control
var _tween: Tween


func _ready() -> void:
	_parent = get_parent() as Control
	if _parent == null:
		push_warning("InteractableHover: parent must be a Control node — %s" % get_path())
		return
	_parent.mouse_entered.connect(_on_mouse_entered)
	_parent.mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	if _parent == null:
		return
	_kill_tween()
	_tween = _parent.create_tween()
	_tween.tween_property(_parent, "self_modulate", ACCENT_INTERACT, TWEEN_DURATION)
	EventBus.interactable_focused.emit(action_label)


func _on_mouse_exited() -> void:
	if _parent == null:
		return
	_kill_tween()
	_tween = _parent.create_tween()
	_tween.tween_property(_parent, "self_modulate", Color.WHITE, TWEEN_DURATION)
	EventBus.interactable_unfocused.emit()


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
