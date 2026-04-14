## Cursor lock/unlock, action press guards, and input event utilities.
class_name InputHelper
extends RefCounted


static var _warned_actions: Dictionary = {}


static func lock_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.cursor_locked.emit()


static func unlock_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.cursor_unlocked.emit()


static func is_cursor_locked() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


static func is_action_just_pressed(action: StringName) -> bool:
	if not InputMap.has_action(action):
		if not _warned_actions.has(action):
			push_warning("InputHelper: action '%s' not in InputMap" % action)
			_warned_actions[action] = true
		return false
	return Input.is_action_just_pressed(action)


static func is_typing_focus_active() -> bool:
	var viewport: Viewport = Engine.get_main_loop().root
	var focused: Control = viewport.gui_get_focus_owner()
	if focused == null:
		return false
	return focused is LineEdit or focused is TextEdit


static func get_axis_strength(
	negative: StringName, positive: StringName
) -> float:
	return Input.get_axis(negative, positive)


static func get_orbit_direction() -> float:
	return Input.get_axis("orbit_left", "orbit_right")
