## Lightweight waypoint node for mall hallway NPC navigation.
class_name MallWaypoint
extends Marker3D

enum WaypointType {
	HALLWAY,
	STORE_ENTRANCE,
	REGISTER,
	FOOD_COURT_SEAT,
	BENCH,
	EXIT,
}

var connected_waypoints: Array[MallWaypoint] = []
@export var connected_waypoint_paths: Array[NodePath] = []
@export var waypoint_type: WaypointType = WaypointType.HALLWAY
@export var associated_store_id: StringName = &""


func _ready() -> void:
	add_to_group("mall_waypoints")
	if connected_waypoint_paths.is_empty():
		return
	connected_waypoints.clear()
	for waypoint_path: NodePath in connected_waypoint_paths:
		var waypoint: MallWaypoint = get_node_or_null(
			waypoint_path
		) as MallWaypoint
		if waypoint == null:
			push_error(
				"MallWaypoint: missing connected waypoint %s for %s"
				% [waypoint_path, name]
			)
			continue
		connected_waypoints.append(waypoint)
