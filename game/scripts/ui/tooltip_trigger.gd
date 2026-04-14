## Attach to any Control to show a text tooltip on hover.
class_name TooltipTrigger
extends Node


@export var tooltip_text: String = ""

var _parent_control: Control = null


func _ready() -> void:
	var parent: Node = get_parent()
	if not parent is Control:
		push_error("TooltipTrigger must be a child of a Control node.")
		return
	_parent_control = parent as Control
	_parent_control.mouse_entered.connect(_on_mouse_entered)
	_parent_control.mouse_exited.connect(_on_mouse_exited)
	_parent_control.gui_input.connect(_on_gui_input)


func _on_mouse_entered() -> void:
	if tooltip_text.is_empty():
		return
	var pos: Vector2 = _parent_control.get_global_mouse_position()
	TooltipManager.show_tooltip(tooltip_text, pos)


func _on_mouse_exited() -> void:
	TooltipManager.hide_tooltip()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		TooltipManager.hide_tooltip()
