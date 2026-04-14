## Unit tests for TooltipManager: delay behavior, show/hide, and dismiss rules.
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


func test_show_tooltip_sets_pending_state() -> void:
	_manager.show_tooltip("Test text", Vector2(100, 100))
	assert_false(
		_manager._is_visible,
		"Tooltip should not be visible before delay elapses"
	)
	assert_eq(_manager._pending_text, "Test text")
	assert_true(
		_manager._delay_timer > 0.0,
		"Delay timer should be running"
	)


func test_hide_tooltip_cancels_pending() -> void:
	_manager.show_tooltip("Test", Vector2.ZERO)
	_manager.hide_tooltip()
	assert_eq(_manager._pending_text, "")
	assert_true(
		_manager._delay_timer < 0.0,
		"Delay timer should be cancelled"
	)
	assert_false(_manager._is_visible)


func test_show_empty_text_calls_hide() -> void:
	_manager.show_tooltip("Hello", Vector2.ZERO)
	_manager.show_tooltip("", Vector2.ZERO)
	assert_eq(_manager._pending_text, "")
	assert_true(_manager._delay_timer < 0.0)


func test_tooltip_appears_after_delay() -> void:
	_manager.show_tooltip("Delayed text", Vector2(50, 50))
	var steps: int = ceili(
		PanelAnimator.TOOLTIP_HOVER_DELAY / 0.05
	) + 1
	for i: int in range(steps):
		_manager._process(0.05)
	assert_true(
		_manager._is_visible,
		"Tooltip should be visible after delay"
	)
	assert_eq(_manager._label.text, "Delayed text")


func test_hide_during_delay_prevents_display() -> void:
	_manager.show_tooltip("Should not appear", Vector2.ZERO)
	_manager._process(0.1)
	_manager.hide_tooltip()
	_manager._process(0.3)
	assert_false(
		_manager._is_visible,
		"Tooltip should not appear after hide during delay"
	)


func test_panel_opened_dismisses_tooltip() -> void:
	_manager.show_tooltip("Will dismiss", Vector2.ZERO)
	for i: int in range(10):
		_manager._process(0.05)
	assert_true(_manager._is_visible)
	EventBus.panel_opened.emit("some_panel")
	assert_false(
		_manager._is_visible,
		"Panel open should dismiss tooltip"
	)
