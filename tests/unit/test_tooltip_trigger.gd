## Unit tests for TooltipTrigger hover delay and cancellation behavior.
extends GutTest


const TooltipTriggerScript: GDScript = preload("res://game/scripts/ui/tooltip_trigger.gd")

var _control: Control
var _trigger: TooltipTrigger


func before_each() -> void:
	TooltipManager.hide_tooltip()
	_control = Control.new()
	add_child_autofree(_control)
	_trigger = TooltipTriggerScript.new() as TooltipTrigger
	_trigger.tooltip_text = "Tooltip body"
	_control.add_child(_trigger)


func after_each() -> void:
	TooltipManager.hide_tooltip()


func test_hover_timer_uses_spec_delay() -> void:
	assert_eq(
		_trigger._hover_timer.wait_time,
		PanelAnimator.TOOLTIP_HOVER_DELAY,
		"Tooltip trigger should wait the spec delay before showing"
	)


func test_mouse_enter_starts_pending_timer_without_showing_tooltip() -> void:
	_trigger._on_mouse_entered()
	assert_false(TooltipManager._is_visible)
	assert_false(TooltipManager._panel.visible)
	assert_false(
		_trigger._hover_timer.is_stopped(),
		"Hovering should start the pending tooltip timer"
	)


func test_tooltip_appears_after_hover_delay() -> void:
	_trigger._on_mouse_entered()
	await get_tree().create_timer(
		PanelAnimator.TOOLTIP_HOVER_DELAY + 0.05
	).timeout
	assert_true(TooltipManager._is_visible, "Tooltip should appear after the delay")
	assert_eq(TooltipManager._label.text, "Tooltip body")


func test_mouse_exit_cancels_pending_timer() -> void:
	_trigger._on_mouse_entered()
	await get_tree().create_timer(0.1).timeout
	_trigger._on_mouse_exited()
	await get_tree().create_timer(
		PanelAnimator.TOOLTIP_HOVER_DELAY + 0.05
	).timeout
	assert_true(
		_trigger._hover_timer.is_stopped(),
		"Mouse exit should stop the pending timer"
	)
	assert_false(
		TooltipManager._is_visible,
		"Tooltip should stay hidden when hover ends before timeout"
	)


func test_click_cancels_pending_timer() -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	_trigger._on_mouse_entered()
	await get_tree().create_timer(0.1).timeout
	_trigger._on_gui_input(event)
	await get_tree().create_timer(
		PanelAnimator.TOOLTIP_HOVER_DELAY + 0.05
	).timeout
	assert_true(
		_trigger._hover_timer.is_stopped(),
		"Clicking the control should stop the pending timer"
	)
	assert_false(
		TooltipManager._is_visible,
		"Tooltip should stay hidden after a click cancels the pending hover"
	)
