## Unit tests for TooltipManager show/hide, layout, and dismiss rules.
extends GutTest


var _manager: Node


func before_each() -> void:
	_manager = Node.new()
	_manager.set_script(
		preload("res://game/autoload/tooltip_manager.gd")
	)
	add_child_autofree(_manager)


func test_initial_state_panel_hidden() -> void:
	assert_false(_manager._is_visible, "Tooltip should start hidden")
	assert_false(_manager._panel.visible, "Panel should start invisible")


func test_show_tooltip_shows_panel_immediately() -> void:
	_manager.show_tooltip("Test text", Vector2(100, 100))
	assert_true(_manager._is_visible, "Tooltip should become visible immediately")
	assert_true(_manager._panel.visible, "Tooltip panel should be visible after show")
	assert_eq(_manager._label.text, "Test text")


func test_hide_tooltip_hides_panel() -> void:
	_manager.show_tooltip("Test", Vector2.ZERO)
	_manager.hide_tooltip()
	assert_false(_manager._is_visible)
	assert_false(_manager._panel.visible)


func test_show_empty_text_calls_hide() -> void:
	_manager.show_tooltip("Hello", Vector2.ZERO)
	_manager.show_tooltip("", Vector2.ZERO)
	assert_false(_manager._is_visible)
	assert_false(_manager._panel.visible)


func test_show_tooltip_applies_max_width_and_wrap() -> void:
	var long_text: String = (
		"This is a long tooltip sentence that should wrap before the panel "
		+ "grows wider than the specified cap."
	)
	_manager.show_tooltip(long_text, Vector2.ZERO)
	await get_tree().process_frame
	assert_true(
		_manager._panel.size.x <= TooltipManager.MAX_WIDTH,
		"Tooltip panel width should not exceed the maximum width"
	)
	assert_eq(
		_manager._label.autowrap_mode,
		TextServer.AUTOWRAP_WORD_SMART,
		"Tooltip label should wrap long text"
	)


func test_show_tooltip_clamps_to_viewport_bounds() -> void:
	var viewport_size: Vector2 = _manager.get_viewport().get_visible_rect().size
	var edge_position: Vector2 = viewport_size - Vector2(1.0, 1.0)
	_manager.show_tooltip("Edge", edge_position)
	await get_tree().process_frame
	assert_true(
		_manager._panel.global_position.x + _manager._panel.size.x
			<= viewport_size.x - TooltipManager.SCREEN_MARGIN,
		"Tooltip should remain within the viewport on the x axis"
	)
	assert_true(
		_manager._panel.global_position.y + _manager._panel.size.y
			<= viewport_size.y - TooltipManager.SCREEN_MARGIN,
		"Tooltip should remain within the viewport on the y axis"
	)


func test_panel_opened_dismisses_tooltip() -> void:
	_manager.show_tooltip("Will dismiss", Vector2.ZERO)
	assert_true(_manager._is_visible)
	EventBus.panel_opened.emit("some_panel")
	assert_false(
		_manager._is_visible,
		"Panel open should dismiss tooltip"
	)


func test_escape_dismisses_tooltip() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	_manager.show_tooltip("Dismiss me", Vector2.ZERO)
	_manager._unhandled_input(event)
	assert_false(_manager._is_visible, "Escape should dismiss the tooltip")


func test_click_dismisses_tooltip() -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	_manager.show_tooltip("Dismiss me", Vector2.ZERO)
	_manager._unhandled_input(event)
	assert_false(_manager._is_visible, "Click should dismiss the tooltip")
