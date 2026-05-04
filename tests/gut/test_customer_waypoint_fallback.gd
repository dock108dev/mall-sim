## Tests Customer waypoint-fallback navigation and FSM transition logging.
##
## The waypoint fallback drives move_and_slide directly toward the last target
## set via `_set_navigation_target`, bypassing NavigationAgent3D when the
## navmesh is missing or unbaked. FSM transitions are funnelled through
## `_set_state`, which emits `customer_state_changed` for every state change
## so the spawn → shelf → checkout → exit chain stays observable.
extends GutTest


func test_detect_navmesh_or_fallback_engages_when_no_nav_agent() -> void:
	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	customer._detect_navmesh_or_fallback()
	assert_true(
		customer._use_waypoint_fallback,
		"Customer without a NavigationAgent3D must engage waypoint fallback"
	)


func test_detect_navmesh_or_fallback_engages_when_no_nav_region() -> void:
	var customer: Customer = preload(
		"res://game/scenes/characters/customer.tscn"
	).instantiate() as Customer
	add_child_autofree(customer)
	customer._detect_navmesh_or_fallback()
	assert_true(
		customer._use_waypoint_fallback,
		"Customer with no NavigationRegion3D ancestor must engage fallback"
	)


func test_detect_navmesh_or_fallback_skips_when_baked_region_present() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var region := NavigationRegion3D.new()
	var nav_mesh := NavigationMesh.new()
	nav_mesh.vertices = PackedVector3Array([
		Vector3(-1.0, 0.0, -1.0),
		Vector3(1.0, 0.0, -1.0),
		Vector3(1.0, 0.0, 1.0),
		Vector3(-1.0, 0.0, 1.0),
	])
	nav_mesh.add_polygon(PackedInt32Array([0, 1, 2]))
	nav_mesh.add_polygon(PackedInt32Array([0, 2, 3]))
	region.navigation_mesh = nav_mesh
	parent.add_child(region)
	var customer: Customer = preload(
		"res://game/scenes/characters/customer.tscn"
	).instantiate() as Customer
	parent.add_child(customer)
	customer._detect_navmesh_or_fallback()
	assert_false(
		customer._use_waypoint_fallback,
		"Baked nav region in ancestor tree must keep NavigationAgent3D path"
	)


func test_enable_waypoint_fallback_marks_target_as_unreached_when_far() -> void:
	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	customer.global_position = Vector3.ZERO
	customer._fallback_target = Vector3(5.0, 0.0, 0.0)
	customer.enable_waypoint_fallback()
	assert_true(customer._use_waypoint_fallback)
	assert_false(
		customer._fallback_arrived,
		"Far target must mark the customer as not yet arrived"
	)


func test_enable_waypoint_fallback_marks_arrived_when_already_at_target() -> void:
	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	customer.global_position = Vector3.ZERO
	customer._fallback_target = Vector3(0.1, 0.0, 0.1)
	customer.enable_waypoint_fallback()
	assert_true(
		customer._fallback_arrived,
		"Target inside arrival radius must register as arrived immediately"
	)


func test_set_navigation_target_updates_fallback_target() -> void:
	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	customer.enable_waypoint_fallback()
	customer.global_position = Vector3.ZERO
	customer._set_navigation_target(Vector3(3.0, 0.0, 4.0))
	assert_eq(customer._fallback_target, Vector3(3.0, 0.0, 4.0))
	assert_false(
		customer._fallback_arrived,
		"New far target must reset arrival flag"
	)


func test_is_navigation_finished_reflects_fallback_state() -> void:
	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	customer.global_position = Vector3.ZERO
	customer._fallback_target = Vector3(5.0, 0.0, 0.0)
	customer.enable_waypoint_fallback()
	assert_false(
		customer._is_navigation_finished(),
		"Far fallback target should report navigation in progress"
	)
	customer._fallback_arrived = true
	assert_true(
		customer._is_navigation_finished(),
		"Arrived fallback should report navigation finished"
	)


func test_move_waypoint_fallback_advances_toward_target() -> void:
	var customer: Customer = preload(
		"res://game/scenes/characters/customer.tscn"
	).instantiate() as Customer
	add_child_autofree(customer)
	customer.global_position = Vector3.ZERO
	customer._fallback_target = Vector3(5.0, 0.0, 0.0)
	customer.enable_waypoint_fallback()
	customer._move_waypoint_fallback()
	assert_eq(
		customer.velocity.normalized(), Vector3.RIGHT,
		"Velocity should point at the fallback target"
	)
	assert_almost_eq(
		customer.velocity.length(), Customer.MOVE_SPEED, 0.01,
		"Fallback movement must use MOVE_SPEED"
	)
	assert_gt(
		customer.global_position.x, 0.0,
		"move_and_slide must integrate motion toward the target"
	)


func test_move_waypoint_fallback_marks_arrived_within_threshold() -> void:
	var customer: Customer = preload(
		"res://game/scenes/characters/customer.tscn"
	).instantiate() as Customer
	add_child_autofree(customer)
	customer.global_position = Vector3.ZERO
	customer._fallback_target = Vector3(0.2, 0.0, 0.2)
	customer.enable_waypoint_fallback()
	customer._fallback_arrived = false
	customer._move_waypoint_fallback()
	assert_true(
		customer._fallback_arrived,
		"Reaching within sqrt(WAYPOINT_ARRIVAL_DIST_SQ) flips arrived flag"
	)
	assert_eq(
		customer.velocity, Vector3.ZERO,
		"Arrival must zero velocity to stop the slide"
	)


func test_set_state_emits_customer_state_changed_for_every_transition() -> void:
	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	var observed: Array[int] = []
	var cb: Callable = func(emitter: Node, state: int) -> void:
		if emitter == customer:
			observed.append(state)
	EventBus.customer_state_changed.connect(cb)
	customer._set_state(Customer.State.BROWSING)
	customer._set_state(Customer.State.DECIDING)
	customer._set_state(Customer.State.LEAVING)
	EventBus.customer_state_changed.disconnect(cb)
	assert_eq(observed.size(), 3, "Each _set_state call must emit once")
	assert_eq(observed[0], Customer.State.BROWSING)
	assert_eq(observed[1], Customer.State.DECIDING)
	assert_eq(observed[2], Customer.State.LEAVING)


func test_enter_queue_routes_through_set_state() -> void:
	var customer: Customer = preload(
		"res://game/scenes/characters/customer.tscn"
	).instantiate() as Customer
	add_child_autofree(customer)
	customer.global_position = Vector3.ZERO
	var observed: Array[int] = []
	var cb: Callable = func(emitter: Node, state: int) -> void:
		if emitter == customer:
			observed.append(state)
	EventBus.customer_state_changed.connect(cb)
	customer.enter_queue(Vector3(2.0, 0.0, 0.0))
	EventBus.customer_state_changed.disconnect(cb)
	assert_eq(
		customer.current_state, Customer.State.WAITING_IN_QUEUE,
		"enter_queue must put the customer in WAITING_IN_QUEUE"
	)
	assert_eq(
		observed.size(), 1,
		"enter_queue emits exactly one state-change event"
	)
	assert_eq(observed[0], Customer.State.WAITING_IN_QUEUE)


func test_advance_to_register_routes_through_set_state() -> void:
	var customer: Customer = preload(
		"res://game/scenes/characters/customer.tscn"
	).instantiate() as Customer
	add_child_autofree(customer)
	customer.global_position = Vector3.ZERO
	var observed: Array[int] = []
	var cb: Callable = func(emitter: Node, state: int) -> void:
		if emitter == customer:
			observed.append(state)
	EventBus.customer_state_changed.connect(cb)
	customer.advance_to_register()
	EventBus.customer_state_changed.disconnect(cb)
	assert_eq(
		customer.current_state, Customer.State.PURCHASING,
		"advance_to_register must move customer to PURCHASING"
	)
	assert_eq(observed.size(), 1)
	assert_eq(observed[0], Customer.State.PURCHASING)
