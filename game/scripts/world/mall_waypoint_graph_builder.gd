## Builds the waypoint navigation graph for the mall hallway.
class_name MallWaypointGraphBuilder
extends RefCounted

const HALLWAY_Z: float = 4.0
const STORE_ENTRANCE_Z: float = 1.5
const REGISTER_Z: float = 0.2
const FOOD_COURT_Z: float = 6.5
const STOREFRONT_SPACING: float = 8.0
const STOREFRONT_COUNT: int = 5
const EXIT_OFFSET: float = 8.0
const ENTRANCE_OFFSET: float = 4.0


## Builds the complete waypoint graph and adds it under parent.
## Returns the container node holding all waypoints.
static func build(
	parent: Node3D, store_ids: Array[StringName]
) -> Node3D:
	var start_x: float = (
		-float(STOREFRONT_COUNT - 1) * 0.5 * STOREFRONT_SPACING
	)
	var hallway_left_x: float = start_x + 0.5 * STOREFRONT_SPACING
	var hallway_right_x: float = start_x + 3.5 * STOREFRONT_SPACING

	var exit_a: MallWaypoint = _create_waypoint(
		parent, "Exit_A",
		Vector3(start_x - EXIT_OFFSET, 0.0, HALLWAY_Z),
		MallWaypoint.WaypointType.EXIT
	)
	var entrance_a: MallWaypoint = _create_waypoint(
		parent, "Entrance_A",
		Vector3(start_x - ENTRANCE_OFFSET, 0.0, HALLWAY_Z),
		MallWaypoint.WaypointType.HALLWAY
	)
	var exit_b: MallWaypoint = _create_waypoint(
		parent, "Exit_B",
		Vector3(-start_x + EXIT_OFFSET, 0.0, HALLWAY_Z),
		MallWaypoint.WaypointType.EXIT
	)
	var entrance_b: MallWaypoint = _create_waypoint(
		parent, "Entrance_B",
		Vector3(-start_x + ENTRANCE_OFFSET, 0.0, HALLWAY_Z),
		MallWaypoint.WaypointType.HALLWAY
	)

	var junction_west: MallWaypoint = _create_waypoint(
		parent, "Junction_West",
		Vector3(hallway_left_x, 0.0, HALLWAY_Z),
		MallWaypoint.WaypointType.HALLWAY
	)
	var junction_center: MallWaypoint = _create_waypoint(
		parent, "Junction_Center",
		Vector3(0.0, 0.0, HALLWAY_Z),
		MallWaypoint.WaypointType.HALLWAY
	)
	var junction_east: MallWaypoint = _create_waypoint(
		parent, "Junction_East",
		Vector3(hallway_right_x, 0.0, HALLWAY_Z),
		MallWaypoint.WaypointType.HALLWAY
	)

	_connect_bidirectional(exit_a, entrance_a)
	_connect_bidirectional(entrance_a, junction_west)
	_connect_bidirectional(junction_west, junction_center)
	_connect_bidirectional(junction_center, junction_east)
	_connect_bidirectional(junction_east, entrance_b)
	_connect_bidirectional(entrance_b, exit_b)

	var entrance_junctions: Array[MallWaypoint] = [
		junction_west,
		junction_west,
		junction_center,
		junction_east,
		junction_east,
	]
	for i: int in range(STOREFRONT_COUNT):
		var x: float = start_x + float(i) * STOREFRONT_SPACING
		var sid: StringName = &""
		if i < store_ids.size():
			sid = store_ids[i]
		var entrance: MallWaypoint = _create_waypoint(
			parent, "StoreEntrance_%d" % i,
			Vector3(x, 0.0, STORE_ENTRANCE_Z),
			MallWaypoint.WaypointType.STORE_ENTRANCE,
			sid
		)
		var register: MallWaypoint = _create_waypoint(
			parent, "Register_%d" % i,
			Vector3(x, 0.0, REGISTER_Z),
			MallWaypoint.WaypointType.REGISTER,
			sid
		)
		_connect_bidirectional(entrance_junctions[i], entrance)
		_connect_bidirectional(entrance, register)

	var bench_left: MallWaypoint = _create_waypoint(
		parent, "Bench_Row_Left",
		Vector3(-2.5, 0.0, 5.2),
		MallWaypoint.WaypointType.BENCH
	)
	var bench_right: MallWaypoint = _create_waypoint(
		parent, "Bench_Row_Right",
		Vector3(2.5, 0.0, 5.2),
		MallWaypoint.WaypointType.BENCH
	)
	_connect_bidirectional(junction_west, bench_left)
	_connect_bidirectional(bench_left, junction_center)
	_connect_bidirectional(junction_center, bench_right)
	_connect_bidirectional(bench_right, junction_east)

	var food_hub: MallWaypoint = _create_waypoint(
		parent, "FoodCourt_Hub",
		Vector3(0.0, 0.0, 5.8),
		MallWaypoint.WaypointType.HALLWAY
	)
	_connect_bidirectional(junction_center, food_hub)

	var seat_positions: Array[Vector3] = [
		Vector3(-2.4, 0.0, FOOD_COURT_Z),
		Vector3(-0.8, 0.0, FOOD_COURT_Z + 0.4),
		Vector3(0.8, 0.0, FOOD_COURT_Z + 0.4),
		Vector3(2.4, 0.0, FOOD_COURT_Z),
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
