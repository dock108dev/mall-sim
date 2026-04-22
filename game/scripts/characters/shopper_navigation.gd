## Handles ShopperAI waypoint navigation, pathfinding, and lane-offset movement.
class_name ShopperNavigation
extends RefCounted

const BASE_WALK_SPEED: float = 2.5
const ARRIVAL_THRESHOLD_SQ: float = 0.25
const LANE_OFFSET: float = 0.6
const PERSONAL_SPACE_RADIUS: float = 1.5
const SEPARATION_FORCE: float = 2.0

var target_waypoint: MallWaypoint = null
var lane_side: float = 0.0

var _agent: MallWaypointAgent
var _body: CharacterBody3D


func setup(
	agent: MallWaypointAgent, body: CharacterBody3D
) -> void:
	_agent = agent
	_body = body
	lane_side = LANE_OFFSET if randf() > 0.5 else -LANE_OFFSET


func move_toward_target(delta: float) -> void:
	if not target_waypoint or _body == null:
		return
	var target_pos: Vector3 = _get_lane_adjusted_position(
		target_waypoint
	)
	var direction: Vector3 = target_pos - _body.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		_body.velocity = Vector3.ZERO
		return
	direction = direction.normalized()
	_body.velocity = direction * BASE_WALK_SPEED
	# Use move_and_collide with an explicit motion vector instead of
	# move_and_slide. move_and_slide multiplies velocity by the engine's
	# physics_process_delta_time, which is 0 when tests drive _physics_process
	# manually before the physics server ever ticks — leaving the body
	# stationary on CI even though the test simulates multiple frames.
	_body.move_and_collide(_body.velocity * delta)


func has_arrived_at_target() -> bool:
	if not target_waypoint or _body == null:
		return true
	var target_pos: Vector3 = _get_lane_adjusted_position(
		target_waypoint
	)
	var diff: Vector3 = target_pos - _body.global_position
	diff.y = 0.0
	return diff.length_squared() < ARRIVAL_THRESHOLD_SQ


func set_target(wp: MallWaypoint) -> void:
	target_waypoint = wp
	var path: Array[MallWaypoint] = [wp]
	if _agent != null:
		_agent.set_path(path)


func advance_along_path() -> void:
	if _agent == null:
		target_waypoint = null
		return
	if _agent.is_path_complete():
		target_waypoint = null
		return
	target_waypoint = _agent.get_current_waypoint()


func navigate_to_waypoint(dest: MallWaypoint) -> void:
	if _agent == null or _body == null:
		set_target(dest)
		return
	var nearest: MallWaypoint = _agent.get_nearest_waypoint_of_type(
		_body.global_position, MallWaypoint.WaypointType.HALLWAY
	)
	if not nearest:
		set_target(dest)
		return
	var path: Array[MallWaypoint] = _agent.find_path(nearest, dest)
	if path.is_empty():
		set_target(dest)
		return
	_agent.set_path(path)
	advance_along_path()


func pick_next_walking_destination() -> void:
	if _body == null or _agent == null:
		return
	var candidates: Array[MallWaypoint] = []
	var waypoints: Array[Node] = (
		_body.get_tree().get_nodes_in_group("mall_waypoints")
	)
	for node: Node in waypoints:
		var wp: MallWaypoint = node as MallWaypoint
		if not wp:
			continue
		if wp.waypoint_type in [
			MallWaypoint.WaypointType.STORE_ENTRANCE,
			MallWaypoint.WaypointType.HALLWAY
		]:
			candidates.append(wp)
	if candidates.is_empty():
		return
	var dest: MallWaypoint = candidates.pick_random()
	var nearest: MallWaypoint = _agent.get_nearest_waypoint_of_type(
		_body.global_position, MallWaypoint.WaypointType.HALLWAY
	)
	if not nearest:
		return
	var path: Array[MallWaypoint] = _agent.find_path(nearest, dest)
	if path.is_empty():
		return
	_agent.set_path(path)
	advance_along_path()


func pick_exit_path() -> bool:
	if _agent == null or _body == null:
		push_error("ShopperNavigation: navigation not initialized.")
		return false
	var exit_wp: MallWaypoint = _agent.get_nearest_waypoint_of_type(
		_body.global_position, MallWaypoint.WaypointType.EXIT
	)
	if not exit_wp:
		push_error("ShopperNavigation: No EXIT waypoint found.")
		return false
	navigate_to_waypoint(exit_wp)
	return true


func apply_separation(delta: float) -> void:
	if _body == null:
		return
	var steer: Vector3 = Vector3.ZERO
	var nearby: Array[Node] = (
		_body.get_tree().get_nodes_in_group("shoppers")
	)
	for node: Node in nearby:
		if node == _body:
			continue
		var other: Node3D = node as Node3D
		if not other:
			continue
		var away: Vector3 = (
			_body.global_position - other.global_position
		)
		away.y = 0.0
		var dist_sq: float = away.length_squared()
		if dist_sq > PERSONAL_SPACE_RADIUS * PERSONAL_SPACE_RADIUS:
			continue
		if dist_sq < 0.001:
			continue
		steer += away.normalized() / away.length()
	if steer.length_squared() > 0.001:
		var sep: Vector3 = (
			steer.normalized() * SEPARATION_FORCE * delta
		)
		_body.global_position += sep


func get_nearest_of_type(
	wp_type: MallWaypoint.WaypointType
) -> MallWaypoint:
	if _agent == null or _body == null:
		return null
	return _agent.get_nearest_waypoint_of_type(
		_body.global_position, wp_type
	)


func waypoint_proximity(
	wp_type: MallWaypoint.WaypointType
) -> float:
	if _body == null:
		return 0.0
	var wp: MallWaypoint = get_nearest_of_type(wp_type)
	if not wp:
		return 0.0
	var dist: float = _body.global_position.distance_to(
		wp.global_position
	)
	return clampf(1.0 - dist / 50.0, 0.1, 1.0)


func _get_lane_adjusted_position(wp: MallWaypoint) -> Vector3:
	if wp.waypoint_type != MallWaypoint.WaypointType.HALLWAY:
		return wp.global_position
	if _agent == null:
		return wp.global_position
	var next_pos: Vector3 = _agent.next_position()
	if next_pos == Vector3.ZERO:
		next_pos = wp.global_position + Vector3.FORWARD
	var forward: Vector3 = (
		next_pos - wp.global_position
	).normalized()
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	return wp.global_position + right * lane_side
