## Tests InputHelper cursor lock/unlock, action guards, and focus detection.
extends GutTest


var _cursor_locked_count: int = 0
var _cursor_unlocked_count: int = 0


func before_each() -> void:
	InputHelper._warned_actions.clear()
	InputHelper.unlock_cursor()
	_cursor_locked_count = 0
	_cursor_unlocked_count = 0
	EventBus.cursor_locked.connect(_on_cursor_locked)
	EventBus.cursor_unlocked.connect(_on_cursor_unlocked)


func after_each() -> void:
	if EventBus.cursor_locked.is_connected(_on_cursor_locked):
		EventBus.cursor_locked.disconnect(_on_cursor_locked)
	if EventBus.cursor_unlocked.is_connected(_on_cursor_unlocked):
		EventBus.cursor_unlocked.disconnect(_on_cursor_unlocked)
	InputHelper.unlock_cursor()
	InputHelper._warned_actions.clear()


func _on_cursor_locked() -> void:
	_cursor_locked_count += 1


func _on_cursor_unlocked() -> void:
	_cursor_unlocked_count += 1


func test_lock_cursor_sets_captured() -> void:
	InputHelper.lock_cursor()
	assert_true(InputHelper.is_cursor_locked(), "lock_cursor should capture")
	if DisplayServer.get_name() != "headless":
		assert_eq(
			Input.mouse_mode,
			Input.MOUSE_MODE_CAPTURED,
			"lock_cursor should set CAPTURED"
		)


func test_lock_cursor_emits_signal() -> void:
	InputHelper.lock_cursor()
	assert_eq(_cursor_locked_count, 1, "Should emit cursor_locked once")


func test_unlock_cursor_sets_visible() -> void:
	InputHelper.lock_cursor()
	InputHelper.unlock_cursor()
	assert_false(InputHelper.is_cursor_locked(), "unlock_cursor should release")
	if DisplayServer.get_name() != "headless":
		assert_eq(
			Input.mouse_mode,
			Input.MOUSE_MODE_VISIBLE,
			"unlock_cursor should set VISIBLE"
		)


func test_unlock_cursor_emits_signal() -> void:
	InputHelper.unlock_cursor()
	assert_eq(_cursor_unlocked_count, 1, "Should emit cursor_unlocked once")


func test_is_cursor_locked_true_when_captured() -> void:
	InputHelper.lock_cursor()
	assert_true(InputHelper.is_cursor_locked(), "Should be true when CAPTURED")


func test_is_cursor_locked_false_when_visible() -> void:
	InputHelper.unlock_cursor()
	assert_false(InputHelper.is_cursor_locked(), "Should be false when VISIBLE")


func test_is_action_just_pressed_missing_action_returns_false() -> void:
	var result: bool = InputHelper.is_action_just_pressed(
		&"__nonexistent_test_action__"
	)
	assert_false(result, "Missing action should return false, not crash")


func test_is_action_just_pressed_warns_once_per_missing_action() -> void:
	var action: StringName = &"__warn_once_missing_action__"
	InputHelper.is_action_just_pressed(action)
	assert_eq(InputHelper._warned_actions.size(), 1, "Should record one warning")
	InputHelper.is_action_just_pressed(action)
	assert_eq(
		InputHelper._warned_actions.size(),
		1,
		"Should not add duplicate warnings for the same action"
	)


func test_get_axis_strength_returns_float() -> void:
	var value: float = InputHelper.get_axis_strength(
		&"move_left", &"move_right"
	)
	assert_typeof(value, TYPE_FLOAT, "get_axis_strength should return float")


func test_is_typing_focus_active_false_when_no_focus() -> void:
	assert_false(
		InputHelper.is_typing_focus_active(),
		"Should be false when nothing has focus"
	)


func test_is_typing_focus_active_true_for_line_edit() -> void:
	var line_edit := LineEdit.new()
	add_child_autofree(line_edit)
	line_edit.grab_focus()
	assert_true(
		InputHelper.is_typing_focus_active(),
		"Should be true when LineEdit has focus"
	)


func test_is_typing_focus_active_true_for_text_edit() -> void:
	var text_edit := TextEdit.new()
	add_child_autofree(text_edit)
	text_edit.grab_focus()
	assert_true(
		InputHelper.is_typing_focus_active(),
		"Should be true when TextEdit has focus"
	)


func test_is_typing_focus_active_false_for_button() -> void:
	var button := Button.new()
	add_child_autofree(button)
	button.grab_focus()
	assert_false(
		InputHelper.is_typing_focus_active(),
		"Should be false when Button has focus"
	)
