## Builds the waypoint navigation graph for the mall hallway.
class_name MallWaypointGraphBuilder
extends RefCounted

const HALLWAY_Z: float = 4.0
const STORE_ENTRANCE_Z: float = 1.5
const FOOD_COURT_Z: float = 6.5
const STOREFRONT_SPACING: float = 8.0
const STOREFRONT_COUNT: int = 5


## Builds the complete waypoint graph and adds it under parent.
## Returns the container node holding all waypoints.
static func build(
	parent: Node3D, store_ids: Array[StringName]
) -> Node3D:
	var start_x: float = (
		-float(STOREFRONT_COUNT - 1) * 0.5 * STOREFRONT_SPACING
	)

	var exit_a: MallWaypoint = _create_waypoint(
		parent, "Exit_A",
		Vector3(-21.0, 0.0, HALLWAY_Z),
		MallWaypoint.WaypointType.EXIT
	)
	var exit_b: MallWaypoint = _create_waypoint(
		parent, "Exit_B",
		Vector3(21.0, 0.0, HALLWAY_Z),
		MallWaypoint.WaypointType.EXIT
	)

	var hallway_nodes: Array[MallWaypoint] = []
	for i: int in range(STOREFRONT_COUNT):
		var x: float = start_x + float(i) * STOREFRONT_SPACING
		var wp: MallWaypoint = _create_waypoint(
			parent, "Hallway_%d" % i,
			Vector3(x, 0.0, HALLWAY_Z),
			MallWaypoint.WaypointType.HALLWAY
		)
		hallway_nodes.append(wp)

	_connect_bidirectional(exit_a, hallway_nodes[0])
	for i: int in range(hallway_nodes.size() - 1):
		_connect_bidirectional(hallway_nodes[i], hallway_nodes[i + 1])
	_connect_bidirectional(
		hallway_nodes[hallway_nodes.size() - 1], exit_b
	)

	var store_entrances: Array[MallWaypoint] = []
	for i: int in range(STOREFRONT_COUNT):
		var x: float = start_x + float(i) * STOREFRONT_SPACING
		var sid: StringName = &""
		if i < store_ids.size():
			sid = store_ids[i]
		var wp: MallWaypoint = _create_waypoint(
			parent, "StoreEntrance_%d" % i,
			Vector3(x, 0.0, STORE_ENTRANCE_Z),
			MallWaypoint.WaypointType.STORE_ENTRANCE,
			sid
		)
		store_entrances.append(wp)
		_connect_bidirectional(hallway_nodes[i], wp)

	var bench_left: MallWaypoint = _create_waypoint(
		parent, "Bench_Left",
		Vector3(-2.5, 0.0, HALLWAY_Z),
		MallWaypoint.WaypointType.BENCH
	)
	var bench_right: MallWaypoint = _create_waypoint(
		parent, "Bench_Right",
		Vector3(2.5, 0.0, HALLWAY_Z),
		MallWaypoint.WaypointType.BENCH
	)
	_connect_bidirectional(hallway_nodes[1], bench_left)
	_connect_bidirectional(bench_left, hallway_nodes[2])
	_connect_bidirectional(hallway_nodes[2], bench_right)
	_connect_bidirectional(bench_right, hallway_nodes[3])

	var food_hub: MallWaypoint = _create_waypoint(
		parent, "FoodCourt_Hub",
		Vector3(0.0, 0.0, 5.5),
		MallWaypoint.WaypointType.HALLWAY
	)
	_connect_bidirectional(hallway_nodes[2], food_hub)

	var seat_positions: Array[Vector3] = [
		Vector3(-2.0, 0.0, FOOD_COURT_Z),
		Vector3(0.0, 0.0, FOOD_COURT_Z),
		Vector3(2.0, 0.0, FOOD_COURT_Z),
	]
	for i: int in range(seat_positions.size()):
		var seat: MallWaypoint = _create_waypoint(
			parent, "FoodCourt_Seat_%d" % i,
			seat_positions[i],
			MallWaypoint.WaypointType.FOOD_COURT_SEAT
		)
		_connect_bidirectional(food_hub, seat)

	return parent


static func _create_waypoint(
	parent: Node3D, wp_name: String, pos: Vector3,
	type: MallWaypoint.WaypointType,
	store_id: StringName = &""
) -> MallWaypoint:
	var wp := MallWaypoint.new()
	wp.name = wp_name
	wp.position = pos
	wp.waypoint_type = type
	wp.associated_store_id = store_id
	parent.add_child(wp)
	return wp


static func _connect_bidirectional(
	a: MallWaypoint, b: MallWaypoint
) -> void:
	if not a.connected_waypoints.has(b):
		a.connected_waypoints.append(b)
	if not b.connected_waypoints.has(a):
		b.connected_waypoints.append(a)
