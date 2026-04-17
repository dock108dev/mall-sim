## Cursor lock/unlock, action press guards, and input event utilities.
class_name InputHelper
extends RefCounted


static var _warned_actions: Dictionary = {}
static var _requested_mouse_mode: int = Input.MOUSE_MODE_VISIBLE


## Captures the cursor and notifies listeners about the state change.
static func lock_cursor() -> void:
	_set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	EventBus.cursor_locked.emit()


## Releases the cursor and notifies listeners about the state change.
static func unlock_cursor() -> void:
	_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	EventBus.cursor_unlocked.emit()


## Returns whether the cursor is currently locked for gameplay input.
static func is_cursor_locked() -> bool:
	return _get_mouse_mode() == Input.MOUSE_MODE_CAPTURED


## Safely checks an input action without crashing on missing InputMap entries.
static func is_action_just_pressed(action: StringName) -> bool:
	if not InputMap.has_action(action):
		if not _warned_actions.has(action):
			push_warning("InputHelper: action '%s' not in InputMap" % action)
			_warned_actions[action] = true
		return false
	return Input.is_action_just_pressed(action)


## Returns true while keyboard focus is on a text entry control.
static func is_typing_focus_active() -> bool:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return false
	var root: Window = scene_tree.root
	if root == null:
		return false
	var focused: Control = root.gui_get_focus_owner()
	if focused == null:
		return false
	return focused is LineEdit or focused is TextEdit


## Returns axis input strength for paired negative and positive actions.
static func get_axis_strength(
	negative: StringName, positive: StringName
) -> float:
	return Input.get_axis(negative, positive)


static func _set_mouse_mode(mode: int) -> void:
	_requested_mouse_mode = mode
	Input.mouse_mode = mode


static func _get_mouse_mode() -> int:
	if DisplayServer.get_name() == "headless":
		return _requested_mouse_mode
	return Input.mouse_mode
