## Resolves BFS paths between MallWaypoint nodes for NPC navigation.
class_name MallWaypointAgent
extends Node

var _current_path: Array[MallWaypoint] = []
var _path_index: int = 0


## Returns the BFS shortest path from one waypoint to another.
## Returns an empty array if no path exists.
func find_path(
	from: MallWaypoint, to: MallWaypoint
) -> Array[MallWaypoint]:
	if from == null or to == null:
		return []
	if from == to:
		var result: Array[MallWaypoint] = [from]
		return result

	var queue: Array[MallWaypoint] = [from]
	var came_from: Dictionary = {from: null}

	while queue.size() > 0:
		var current: MallWaypoint = queue.pop_front()
		if current == to:
			return _reconstruct_path(came_from, to)
		for neighbor: MallWaypoint in current.connected_waypoints:
			if came_from.has(neighbor):
				continue
			came_from[neighbor] = current
			queue.push_back(neighbor)

	return []


## Returns the nearest waypoint of the given type to a world position.
## Returns null if no waypoint of that type exists in the tree.
func get_nearest_waypoint_of_type(
	pos: Vector3, type: MallWaypoint.WaypointType
) -> MallWaypoint:
	var waypoints: Array[MallWaypoint] = _get_all_waypoints()
	var best: MallWaypoint = null
	var best_dist: float = INF

	for wp: MallWaypoint in waypoints:
		if wp.waypoint_type != type:
			continue
		var dist: float = pos.distance_squared_to(
			wp.global_position
		)
		if dist < best_dist:
			best_dist = dist
			best = wp

	return best


## Stores a path and resets the traversal index to the start.
func set_path(path: Array[MallWaypoint]) -> void:
	_current_path = path
	_path_index = 0


## Returns the next waypoint position along the stored path.
## Returns Vector3.ZERO and signals path completion when exhausted.
func next_position() -> Vector3:
	if _path_index >= _current_path.size():
		return Vector3.ZERO
	var wp: MallWaypoint = _current_path[_path_index]
	return wp.global_position


## Advances to the next waypoint in the stored path.
func advance() -> void:
	_path_index += 1


## Returns true if the stored path has been fully traversed.
func is_path_complete() -> bool:
	return _path_index >= _current_path.size()


## Returns the current waypoint in the stored path, or null.
func get_current_waypoint() -> MallWaypoint:
	if _path_index >= _current_path.size():
		return null
	return _current_path[_path_index]


func _reconstruct_path(
	came_from: Dictionary, to: MallWaypoint
) -> Array[MallWaypoint]:
	var path: Array[MallWaypoint] = []
	var current: MallWaypoint = to
	while current != null:
		path.push_front(current)
		current = came_from.get(current)
	return path


func _get_all_waypoints() -> Array[MallWaypoint]:
	var result: Array[MallWaypoint] = []
	var nodes: Array[Node] = get_tree().get_nodes_in_group(
		"mall_waypoints"
	)
	for node: Node in nodes:
		if node is MallWaypoint:
			result.append(node as MallWaypoint)
	return result
