## Per-store node that exposes staff position markers to the staff system.
class_name StoreStaffConfig
extends Node

@export var max_staff: int = 2
@export var register_points: Array[Marker3D] = []
@export var backroom_point: Marker3D = null
@export var greeter_point: Marker3D = null
@export var break_point: Marker3D = null


func _ready() -> void:
	if not backroom_point:
		backroom_point = get_node_or_null("BackroomPoint") as Marker3D
	if not greeter_point:
		greeter_point = get_node_or_null("GreeterPoint") as Marker3D
	if not break_point:
		break_point = get_node_or_null("StaffBreakPoint") as Marker3D
	if register_points.is_empty():
		var rp: Marker3D = get_node_or_null("RegisterPoint") as Marker3D
		if rp:
			register_points = [rp]


## Returns the first available register point, or null if none exist.
func get_register_point() -> Marker3D:
	if register_points.is_empty():
		return null
	return register_points[0]


## Returns the position for the given role, falling back to break_point.
func get_marker_for_role(role: StaffDefinition.StaffRole) -> Marker3D:
	match role:
		StaffDefinition.StaffRole.CASHIER:
			var point: Marker3D = get_register_point()
			if point:
				return point
		StaffDefinition.StaffRole.STOCKER:
			if backroom_point:
				return backroom_point
		StaffDefinition.StaffRole.GREETER:
			if greeter_point:
				return greeter_point
	if break_point:
		push_warning(
			"StoreStaffConfig: No marker for role %d, using break_point"
			% role
		)
		return break_point
	push_warning("StoreStaffConfig: No marker for role %d and no break_point" % role)
	return null
