## Per-store node that exposes customer navigation waypoints as Marker3D children.
class_name CustomerNavConfig
extends Node

@export var entry_point: Marker3D
@export var browse_waypoints: Array[Marker3D] = []
@export var checkout_approach: Marker3D
@export var exit_point: Marker3D
@export var max_concurrent_customers: int = 4


func _ready() -> void:
	if entry_point == null:
		entry_point = get_node_or_null("EntryPoint") as Marker3D
	if browse_waypoints.is_empty():
		for child_name: String in [
			"BrowseWaypoint01",
			"BrowseWaypoint02",
			"BrowseWaypoint03",
			"BrowseWaypoint04",
		]:
			var waypoint: Marker3D = get_node_or_null(child_name) as Marker3D
			if waypoint:
				browse_waypoints.append(waypoint)
	if checkout_approach == null:
		checkout_approach = get_node_or_null("CheckoutApproach") as Marker3D
	if exit_point == null:
		exit_point = get_node_or_null("ExitPoint") as Marker3D


func get_entry_position() -> Vector3:
	if not entry_point:
		push_warning("CustomerNavConfig: entry_point not assigned")
		return Vector3.ZERO
	return entry_point.global_position


func get_browse_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for marker: Marker3D in browse_waypoints:
		if marker:
			positions.append(marker.global_position)
	return positions


func get_checkout_position() -> Vector3:
	if not checkout_approach:
		push_warning("CustomerNavConfig: checkout_approach not assigned")
		return Vector3.ZERO
	return checkout_approach.global_position


func get_exit_position() -> Vector3:
	if not exit_point:
		push_warning("CustomerNavConfig: exit_point not assigned")
		return Vector3.ZERO
	return exit_point.global_position
