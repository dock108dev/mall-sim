## Attach to any Control to show a text tooltip on hover.
class_name TooltipTrigger
extends Node


const HOVER_DELAY: float = PanelAnimator.TOOLTIP_HOVER_DELAY

@export var tooltip_text: String = ""

var _parent_control: Control = null
var _hover_timer: Timer = null
var _is_hovering: bool = false


func _ready() -> void:
	var parent: Node = get_parent()
	if not parent is Control:
		push_error("TooltipTrigger must be a child of a Control node.")
		return
	_parent_control = parent as Control
	_hover_timer = Timer.new()
	_hover_timer.one_shot = true
	_hover_timer.wait_time = HOVER_DELAY
	_hover_timer.timeout.connect(_on_hover_timeout)
	add_child(_hover_timer)
	_parent_control.mouse_entered.connect(_on_mouse_entered)
	_parent_control.mouse_exited.connect(_on_mouse_exited)
	_parent_control.gui_input.connect(_on_gui_input)


func _on_mouse_entered() -> void:
	if tooltip_text.is_empty():
		return
	_is_hovering = true
	_hover_timer.start()


func _on_mouse_exited() -> void:
	_is_hovering = false
	_cancel_pending_tooltip()
	TooltipManager.hide_tooltip()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_cancel_pending_tooltip()
		TooltipManager.hide_tooltip()


func _exit_tree() -> void:
	_cancel_pending_tooltip()
	TooltipManager.hide_tooltip()


func _on_hover_timeout() -> void:
	if not _is_hovering or _parent_control == null:
		return
	if tooltip_text.is_empty():
		return
	var mouse_pos: Vector2 = _parent_control.get_global_mouse_position()
	TooltipManager.show_tooltip(tooltip_text, mouse_pos)


func _cancel_pending_tooltip() -> void:
	if _hover_timer != null and not _hover_timer.is_stopped():
		_hover_timer.stop()
