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

@export var connected_waypoints: Array[MallWaypoint] = []
@export var waypoint_type: WaypointType = WaypointType.HALLWAY
@export var associated_store_id: StringName = &""


func _ready() -> void:
	add_to_group("mall_waypoints")
