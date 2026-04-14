## Per-store node that exposes customer navigation waypoints as Marker3D children.
class_name CustomerNavConfig
extends Node

@export var entry_point: Marker3D
@export var browse_waypoints: Array[Marker3D] = []
@export var checkout_approach: Marker3D
@export var exit_point: Marker3D
@export var max_concurrent_customers: int = 4


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
