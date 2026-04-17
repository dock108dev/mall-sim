## Tests the ISSUE-064 ShopperAI waypoint FSM, signals, and movement helpers.
extends GutTest


class AlwaysBuyShopper:
	extends ShopperAI

	func _should_buy_item() -> bool:
		return true


var _root: Node3D
var _shopper: ShopperAI
var _exit_waypoint: MallWaypoint
var _hallway_a: MallWaypoint
var _hallway_b: MallWaypoint
var _store_waypoint: MallWaypoint
var _register_waypoint: MallWaypoint
var _captured_spawned: Array[Node] = []
var _captured_purchases: Array[Array] = []
var _captured_customer_left: Array[Dictionary] = []
var _captured_left_mall: Array[Array] = []


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)
	_captured_spawned.clear()
	_captured_purchases.clear()
	_captured_customer_left.clear()
	_captured_left_mall.clear()


func after_each() -> void:
	if EventBus.customer_spawned.is_connected(_on_customer_spawned):
		EventBus.customer_spawned.disconnect(_on_customer_spawned)
	if EventBus.customer_purchased.is_connected(_on_customer_purchased):
		EventBus.customer_purchased.disconnect(_on_customer_purchased)
	if EventBus.customer_left.is_connected(_on_customer_left):
		EventBus.customer_left.disconnect(_on_customer_left)
	if EventBus.customer_left_mall.is_connected(_on_customer_left_mall):
		EventBus.customer_left_mall.disconnect(_on_customer_left_mall)


func _on_customer_spawned(customer: Node) -> void:
	_captured_spawned.append(customer)


func _on_customer_purchased(
	store_id: StringName,
	item_id: StringName,
	price: float,
	emitted_customer_id: StringName
) -> void:
	_captured_purchases.append([
		store_id,
		item_id,
		price,
		emitted_customer_id,
	])


func _on_customer_left(customer_data: Dictionary) -> void:
	_captured_customer_left.append(customer_data)


func _on_customer_left_mall(customer: Node, satisfied: bool) -> void:
	_captured_left_mall.append([customer, satisfied])


func _make_waypoint(
	name_text: String,
	position_value: Vector3,
	wp_type: MallWaypoint.WaypointType,
	store_id: StringName = &""
) -> MallWaypoint:
	var waypoint := MallWaypoint.new()
	waypoint.name = name_text
	waypoint.position = position_value
	waypoint.waypoint_type = wp_type
	waypoint.associated_store_id = store_id
	_root.add_child(waypoint)
	return waypoint


func _connect_bidirectional(a: MallWaypoint, b: MallWaypoint) -> void:
	a.connected_waypoints.append(b)
	b.connected_waypoints.append(a)


func _build_graph() -> void:
	_exit_waypoint = _make_waypoint(
		"Exit",
		Vector3(-4.0, 0.0, 0.0),
		MallWaypoint.WaypointType.EXIT
	)
	_hallway_a = _make_waypoint(
		"HallwayA",
		Vector3(0.0, 0.0, 0.0),
		MallWaypoint.WaypointType.HALLWAY
	)
	_hallway_b = _make_waypoint(
		"HallwayB",
		Vector3(4.0, 0.0, 0.0),
		MallWaypoint.WaypointType.HALLWAY
	)
	_store_waypoint = _make_waypoint(
		"Store",
		Vector3(8.0, 0.0, 0.0),
		MallWaypoint.WaypointType.STORE_ENTRANCE,
		&"retro_games"
	)
	_register_waypoint = _make_waypoint(
		"Register",
		Vector3(12.0, 0.0, 0.0),
		MallWaypoint.WaypointType.REGISTER,
		&"retro_games"
	)

	_connect_bidirectional(_exit_waypoint, _hallway_a)
	_connect_bidirectional(_hallway_a, _hallway_b)
	_connect_bidirectional(_hallway_b, _store_waypoint)
	_connect_bidirectional(_store_waypoint, _register_waypoint)


func _create_shopper(scripted: ShopperAI = null) -> ShopperAI:
	var shopper: ShopperAI = scripted if scripted != null else ShopperAI.new()
	var agent := MallWaypointAgent.new()
	agent.name = "MallWaypointAgent"
	shopper.add_child(agent)
	_root.add_child(shopper)
	return shopper


func _step_physics(shopper: ShopperAI, steps: int, delta: float = 0.1) -> void:
	for _i: int in range(steps):
		if not is_instance_valid(shopper):
			return
		shopper._physics_process(delta)


func test_ready_emits_customer_spawned() -> void:
	EventBus.customer_spawned.connect(_on_customer_spawned)

	_shopper = _create_shopper()

	assert_eq(_captured_spawned.size(), 1)
	assert_eq(_captured_spawned[0], _shopper)
	EventBus.customer_spawned.disconnect(_on_customer_spawned)


func test_entering_moves_to_first_hallway_then_transitions_to_walking() -> void:
	_build_graph()
	_shopper = _create_shopper()
	_shopper.initialize(Vector3(-3.5, 0.0, 0.0))

	assert_eq(_shopper.current_state, ShopperAI.ShopperState.ENTERING)
	assert_eq(_shopper.target_waypoint, _hallway_a)

	_step_physics(_shopper, 20)

	assert_eq(_shopper.current_state, ShopperAI.ShopperState.WALKING)


func test_browsing_plays_idle_look_and_routes_to_register_on_buy_cycle() -> void:
	_build_graph()
	_shopper = _create_shopper(AlwaysBuyShopper.new())
	_shopper.initialize(_store_waypoint.global_position)
	_shopper.global_position = _store_waypoint.global_position
	_shopper._transition_to(ShopperAI.ShopperState.BROWSING)
	_shopper._look_timer = 0.0

	var animation_player: AnimationPlayer = _shopper.get_node("AnimationPlayer")
	assert_eq(animation_player.current_animation, "idle_look")

	_shopper._process_browsing(0.1)

	assert_eq(_shopper.current_state, ShopperAI.ShopperState.WALKING)
	assert_not_null(_shopper.target_waypoint)

	_step_physics(_shopper, 60)

	assert_true(
		_shopper.current_state in [
			ShopperAI.ShopperState.BUYING,
			ShopperAI.ShopperState.LEAVING,
		]
	)
	assert_eq(_shopper.purchase_store_id, &"retro_games")


func test_buying_emits_customer_purchased_then_transitions_to_leaving() -> void:
	_build_graph()
	_shopper = _create_shopper()
	_shopper.initialize(_register_waypoint.global_position)
	_shopper.global_position = _register_waypoint.global_position
	_shopper.purchase_store_id = &"retro_games"
	_shopper.purchase_item_id = &"test_cart_item"
	_shopper.purchase_price = 42.5
	_shopper._transition_to(ShopperAI.ShopperState.BUYING)
	_shopper.target_waypoint = null
	_shopper._nav.target_waypoint = null
	_shopper._waypoint_agent.set_path([])
	_shopper._state_timer = 0.0

	EventBus.customer_purchased.connect(_on_customer_purchased)

	_shopper._process_buying(0.1)

	assert_eq(_captured_purchases.size(), 1)
	assert_eq(_captured_purchases[0][0], &"retro_games")
	assert_eq(_captured_purchases[0][1], &"test_cart_item")
	assert_eq(_captured_purchases[0][2], 42.5)
	assert_eq(_shopper.current_state, ShopperAI.ShopperState.LEAVING)


func test_leaving_emits_customer_left_before_despawn() -> void:
	_build_graph()
	_shopper = _create_shopper()
	_shopper.initialize(_store_waypoint.global_position)
	_shopper.global_position = Vector3(-3.9, 0.0, 0.0)
	_shopper._made_purchase = true

	EventBus.customer_left.connect(_on_customer_left)
	EventBus.customer_left_mall.connect(_on_customer_left_mall)

	_shopper.request_leave()
	_step_physics(_shopper, 50)
	await get_tree().process_frame

	assert_eq(_captured_customer_left.size(), 1)
	assert_eq(_captured_customer_left[0].get("customer"), _shopper)
	assert_eq(_captured_customer_left[0].get("satisfied"), true)
	assert_eq(_captured_left_mall.size(), 1)
	assert_eq(_captured_left_mall[0][0], _shopper)
	assert_eq(_captured_left_mall[0][1], true)
	assert_false(is_instance_valid(_shopper))


func test_lane_offset_uses_expected_distance_on_hallway_segments() -> void:
	_build_graph()
	_shopper = _create_shopper()
	_shopper.initialize(_exit_waypoint.global_position)

	var adjusted: Vector3 = _shopper._nav._get_lane_adjusted_position(_hallway_a)
	var offset_distance: float = adjusted.distance_to(_hallway_a.global_position)

	assert_almost_eq(offset_distance, ShopperAI.LANE_OFFSET, 0.01)


func test_physics_process_applies_personal_space_separation() -> void:
	_build_graph()
	var shopper_a: ShopperAI = _create_shopper()
	var shopper_b: ShopperAI = _create_shopper()
	shopper_a.initialize(Vector3(-0.2, 0.0, 0.0))
	shopper_b.initialize(Vector3(0.2, 0.0, 0.0))
	shopper_a.global_position = Vector3(0.0, 0.0, 0.0)
	shopper_b.global_position = Vector3(0.4, 0.0, 0.0)
	shopper_a._transition_to(ShopperAI.ShopperState.WALKING)
	shopper_b._transition_to(ShopperAI.ShopperState.WALKING)
	shopper_a._utility_timer = 99.0
	shopper_b._utility_timer = 99.0
	shopper_a._nav.set_target(_hallway_b)
	shopper_b._nav.set_target(_hallway_b)
	shopper_a._sync_target()
	shopper_b._sync_target()

	var initial_distance: float = shopper_a.global_position.distance_to(
		shopper_b.global_position
	)

	shopper_a._physics_process(0.1)
	shopper_b._physics_process(0.1)

	var separated_distance: float = shopper_a.global_position.distance_to(
		shopper_b.global_position
	)
	assert_gt(separated_distance, initial_distance)
