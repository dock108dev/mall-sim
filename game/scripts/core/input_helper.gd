## Utility for input state queries. Keeps input logic out of player scripts.
class_name InputHelper
extends RefCounted


static func get_orbit_direction() -> float:
	return Input.get_axis("orbit_left", "orbit_right")
