## Tests MallWaypoint, MallWaypointAgent BFS pathfinding, and
## MallWaypointGraphBuilder bidirectional connections.
extends GutTest


var _agent: MallWaypointAgent


func before_each() -> void:
	_agent = MallWaypointAgent.new()
	add_child_autofree(_agent)


func _make_waypoint(
	wp_name: String,
	pos: Vector3 = Vector3.ZERO,
	type: MallWaypoint.WaypointType = MallWaypoint.WaypointType.HALLWAY,
	store_id: StringName = &""
) -> MallWaypoint:
	var wp := MallWaypoint.new()
	wp.name = wp_name
	wp.position = pos
	wp.waypoint_type = type
	wp.associated_store_id = store_id
	add_child_autofree(wp)
	return wp


func _connect_bi(a: MallWaypoint, b: MallWaypoint) -> void:
	a.connected_waypoints.append(b)
	b.connected_waypoints.append(a)


func test_waypoint_type_enum_values() -> void:
	assert_eq(
		MallWaypoint.WaypointType.HALLWAY, 0,
		"HALLWAY should be 0"
	)
	assert_eq(
		MallWaypoint.WaypointType.STORE_ENTRANCE, 1,
		"STORE_ENTRANCE should be 1"
	)
	assert_eq(
		MallWaypoint.WaypointType.REGISTER, 2,
		"REGISTER should be 2"
	)
	assert_eq(
		MallWaypoint.WaypointType.FOOD_COURT_SEAT, 3,
		"FOOD_COURT_SEAT should be 3"
	)
	assert_eq(
		MallWaypoint.WaypointType.BENCH, 4,
		"BENCH should be 4"
	)
	assert_eq(
		MallWaypoint.WaypointType.EXIT, 5,
		"EXIT should be 5"
	)


func test_waypoint_stores_associated_store_id() -> void:
	var wp: MallWaypoint = _make_waypoint(
		"test", Vector3.ZERO,
		MallWaypoint.WaypointType.STORE_ENTRANCE, &"sports"
	)
	assert_eq(wp.associated_store_id, &"sports")


func test_find_path_same_node() -> void:
	var wp: MallWaypoint = _make_waypoint("A")
	var path: Array[MallWaypoint] = _agent.find_path(wp, wp)
	assert_eq(path.size(), 1)
	assert_eq(path[0], wp)


func test_find_path_direct_connection() -> void:
	var a: MallWaypoint = _make_waypoint("A", Vector3(0, 0, 0))
	var b: MallWaypoint = _make_waypoint("B", Vector3(5, 0, 0))
	_connect_bi(a, b)
	var path: Array[MallWaypoint] = _agent.find_path(a, b)
	assert_eq(path.size(), 2)
	assert_eq(path[0], a)
	assert_eq(path[1], b)


func test_find_path_multi_hop() -> void:
	var a: MallWaypoint = _make_waypoint("A")
	var b: MallWaypoint = _make_waypoint("B")
	var c: MallWaypoint = _make_waypoint("C")
	var d: MallWaypoint = _make_waypoint("D")
	_connect_bi(a, b)
	_connect_bi(b, c)
	_connect_bi(c, d)
	var path: Array[MallWaypoint] = _agent.find_path(a, d)
	assert_eq(path.size(), 4)
	assert_eq(path[0], a)
	assert_eq(path[3], d)


func test_find_path_shortest_route() -> void:
	var a: MallWaypoint = _make_waypoint("A")
	var b: MallWaypoint = _make_waypoint("B")
	var c: MallWaypoint = _make_waypoint("C")
	var d: MallWaypoint = _make_waypoint("D")
	_connect_bi(a, b)
	_connect_bi(b, c)
	_connect_bi(c, d)
	_connect_bi(a, d)
	var path: Array[MallWaypoint] = _agent.find_path(a, d)
	assert_eq(path.size(), 2, "BFS should find direct shortcut")


func test_find_path_no_connection() -> void:
	var a: MallWaypoint = _make_waypoint("A")
	var b: MallWaypoint = _make_waypoint("B")
	var path: Array[MallWaypoint] = _agent.find_path(a, b)
	assert_eq(path.size(), 0, "Disconnected nodes should return empty")


func test_find_path_null_args() -> void:
	var a: MallWaypoint = _make_waypoint("A")
	assert_eq(_agent.find_path(null, a).size(), 0)
	assert_eq(_agent.find_path(a, null).size(), 0)
	assert_eq(_agent.find_path(null, null).size(), 0)


func test_path_is_bidirectional() -> void:
	var a: MallWaypoint = _make_waypoint("A")
	var b: MallWaypoint = _make_waypoint("B")
	var c: MallWaypoint = _make_waypoint("C")
	_connect_bi(a, b)
	_connect_bi(b, c)
	var forward: Array[MallWaypoint] = _agent.find_path(a, c)
	var backward: Array[MallWaypoint] = _agent.find_path(c, a)
	assert_eq(forward.size(), backward.size())


func test_get_nearest_waypoint_of_type() -> void:
	var bench_far: MallWaypoint = _make_waypoint(
		"BenchFar", Vector3(10, 0, 0),
		MallWaypoint.WaypointType.BENCH
	)
	var bench_near: MallWaypoint = _make_waypoint(
		"BenchNear", Vector3(1, 0, 0),
		MallWaypoint.WaypointType.BENCH
	)
	var hallway: MallWaypoint = _make_waypoint(
		"Hallway", Vector3(0.5, 0, 0),
		MallWaypoint.WaypointType.HALLWAY
	)
	var result: MallWaypoint = _agent.get_nearest_waypoint_of_type(
		Vector3.ZERO, MallWaypoint.WaypointType.BENCH
	)
	assert_eq(result, bench_near)


func test_get_nearest_waypoint_of_type_no_match() -> void:
	var _hw: MallWaypoint = _make_waypoint(
		"H", Vector3.ZERO, MallWaypoint.WaypointType.HALLWAY
	)
	var result: MallWaypoint = _agent.get_nearest_waypoint_of_type(
		Vector3.ZERO, MallWaypoint.WaypointType.REGISTER
	)
	assert_null(result)


func test_path_traversal_api() -> void:
	var a: MallWaypoint = _make_waypoint("A", Vector3(0, 0, 0))
	var b: MallWaypoint = _make_waypoint("B", Vector3(5, 0, 0))
	var c: MallWaypoint = _make_waypoint("C", Vector3(10, 0, 0))
	_connect_bi(a, b)
	_connect_bi(b, c)

	var path: Array[MallWaypoint] = _agent.find_path(a, c)
	_agent.set_path(path)

	assert_false(_agent.is_path_complete())
	assert_eq(_agent.get_current_waypoint(), a)
	assert_eq(_agent.next_position(), Vector3(0, 0, 0))

	_agent.advance()
	assert_eq(_agent.get_current_waypoint(), b)

	_agent.advance()
	assert_eq(_agent.get_current_waypoint(), c)

	_agent.advance()
	assert_true(_agent.is_path_complete())
	assert_null(_agent.get_current_waypoint())
	assert_eq(_agent.next_position(), Vector3.ZERO)


func test_graph_builder_creates_all_waypoints() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var store_ids: Array[StringName] = [
		&"sports", &"retro_games", &"rentals",
		&"pocket_creatures", &"electronics",
	]
	var container: Node3D = MallWaypointGraphBuilder.build(
		parent, store_ids
	)

	var waypoints: Array[MallWaypoint] = []
	for child: Node in container.get_children():
		if child is MallWaypoint:
			waypoints.append(child as MallWaypoint)

	var exits: int = 0
	var store_entrances: int = 0
	var benches: int = 0
	var food_seats: int = 0
	var hallway_nodes: int = 0

	for wp: MallWaypoint in waypoints:
		match wp.waypoint_type:
			MallWaypoint.WaypointType.EXIT:
				exits += 1
			MallWaypoint.WaypointType.STORE_ENTRANCE:
				store_entrances += 1
			MallWaypoint.WaypointType.BENCH:
				benches += 1
			MallWaypoint.WaypointType.FOOD_COURT_SEAT:
				food_seats += 1
			MallWaypoint.WaypointType.HALLWAY:
				hallway_nodes += 1

	assert_eq(exits, 2, "Should have 2 exit waypoints")
	assert_eq(
		store_entrances, 5,
		"Should have 5 store entrance waypoints"
	)
	assert_true(benches >= 2, "Should have at least 2 bench waypoints")
	assert_true(
		food_seats >= 3,
		"Should have at least 3 food court seats"
	)


func test_graph_builder_bidirectional_connections() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var store_ids: Array[StringName] = [
		&"sports", &"retro_games", &"rentals",
		&"pocket_creatures", &"electronics",
	]
	var container: Node3D = MallWaypointGraphBuilder.build(
		parent, store_ids
	)

	for child: Node in container.get_children():
		if not child is MallWaypoint:
			continue
		var wp: MallWaypoint = child as MallWaypoint
		for neighbor: MallWaypoint in wp.connected_waypoints:
			assert_true(
				neighbor.connected_waypoints.has(wp),
				"Connection from %s to %s should be bidirectional"
				% [wp.name, neighbor.name]
			)


func test_graph_builder_store_entrance_ids() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var store_ids: Array[StringName] = [
		&"sports", &"retro_games", &"rentals",
		&"pocket_creatures", &"electronics",
	]
	var container: Node3D = MallWaypointGraphBuilder.build(
		parent, store_ids
	)
	for child: Node in container.get_children():
		if not child is MallWaypoint:
			continue
		var wp: MallWaypoint = child as MallWaypoint
		if wp.waypoint_type != MallWaypoint.WaypointType.STORE_ENTRANCE:
			continue
		assert_ne(
			wp.associated_store_id, &"",
			"Store entrance %s should have a store ID" % wp.name
		)


func test_graph_builder_exit_to_exit_path() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var store_ids: Array[StringName] = [
		&"sports", &"retro_games", &"rentals",
		&"pocket_creatures", &"electronics",
	]
	var container: Node3D = MallWaypointGraphBuilder.build(
		parent, store_ids
	)

	var exit_a: MallWaypoint = null
	var exit_b: MallWaypoint = null
	for child: Node in container.get_children():
		if not child is MallWaypoint:
			continue
		var wp: MallWaypoint = child as MallWaypoint
		if wp.name == "Exit_A":
			exit_a = wp
		elif wp.name == "Exit_B":
			exit_b = wp

	assert_not_null(exit_a)
	assert_not_null(exit_b)

	var path: Array[MallWaypoint] = _agent.find_path(exit_a, exit_b)
	assert_true(
		path.size() > 0,
		"Should find a path between exits"
	)
	assert_eq(path[0], exit_a)
	assert_eq(path[path.size() - 1], exit_b)
