## Utility for input state queries. Keeps input logic out of player scripts.
class_name InputHelper
extends RefCounted


static func get_movement_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


static func is_interact_just_pressed() -> bool:
	return Input.is_action_just_pressed("interact")
