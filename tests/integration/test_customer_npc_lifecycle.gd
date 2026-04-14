## Integration test: full customer NPC visual lifecycle using real NPCSpawnerSystem,
## CustomerNPC, CustomerNavConfig, and EventBus — no mocked systems.
extends GutTest

const TEST_STORE_ID: StringName = &"test_store"
const ENTRY_POS: Vector3 = Vector3(0.0, 0.0, 0.0)
const WAYPOINT_POS_1: Vector3 = Vector3(1.0, 0.0, 0.0)
const WAYPOINT_POS_2: Vector3 = Vector3(2.0, 0.0, 0.0)
const CHECKOUT_POS: Vector3 = Vector3(3.0, 0.0, 0.0)
const EXIT_POS: Vector3 = Vector3(4.0, 0.0, 0.0)
const POSITION_EPSILON: float = 0.01

var _npc_spawner: NPCSpawnerSystem
var _test_store_root: Node = null


func before_each() -> void:
	_test_store_root = null
	_npc_spawner = NPCSpawnerSystem.new()
	add_child_autofree(_npc_spawner)
	_npc_spawner.initialize()


func after_each() -> void:
	if _test_store_root and is_instance_valid(_test_store_root):
		_test_store_root.queue_free()
		_test_store_root = null


# ── Scenario 1 — spawn on customer_spawned ────────────────────────────────────


func test_spawn_adds_customer_npc_to_store_root_and_active_list() -> void:
	_setup_test_store()
	EventBus.store_entered.emit(TEST_STORE_ID)

	var dummy: Node = Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)

	assert_eq(
		_npc_spawner.get_active_count(), 1,
		"_active_customer_npcs.size() should be 1 after customer_spawned"
	)
	var npc: CustomerNPC = _get_first_active_npc()
	assert_not_null(npc, "A CustomerNPC instance should be tracked as active")
	assert_eq(
		npc.get_parent(), _test_store_root,
		"Spawned NPC should be a direct child of the store scene root"
	)


# ── Scenario 2 — NPC navigates to browse waypoints ───────────────────────────


func test_begin_visit_sets_browsing_state_and_first_waypoint_as_nav_target() -> void:
	_setup_test_store()
	EventBus.store_entered.emit(TEST_STORE_ID)

	var dummy: Node = Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)

	var npc: CustomerNPC = _get_first_active_npc()
	assert_not_null(npc, "Precondition: one active NPC is required")

	assert_eq(
		npc.get_visit_state(),
		CustomerNPC.CustomerVisitState.BROWSING,
		"NPC visit state should be BROWSING after begin_visit"
	)

	var nav_agent: NavigationAgent3D = npc.get_node("NavigationAgent3D") as NavigationAgent3D
	assert_not_null(nav_agent, "NPC must have a NavigationAgent3D child node")
	assert_true(
		nav_agent.target_position.distance_to(WAYPOINT_POS_1) < POSITION_EPSILON,
		"NavigationAgent3D target should equal first browse waypoint position"
	)


# ── Scenario 3 — send_to_checkout transition ──────────────────────────────────


func test_send_to_checkout_sets_approaching_state_and_checkout_nav_target() -> void:
	_setup_test_store()
	EventBus.store_entered.emit(TEST_STORE_ID)

	var dummy: Node = Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)

	var npc: CustomerNPC = _get_first_active_npc()
	assert_not_null(npc, "Precondition: one active NPC is required")

	npc.send_to_checkout()

	assert_eq(
		npc.get_visit_state(),
		CustomerNPC.CustomerVisitState.APPROACHING_CHECKOUT,
		"NPC visit state should be APPROACHING_CHECKOUT after send_to_checkout"
	)

	var nav_agent: NavigationAgent3D = npc.get_node("NavigationAgent3D") as NavigationAgent3D
	assert_not_null(nav_agent, "NPC must have a NavigationAgent3D child node")
	assert_true(
		nav_agent.target_position.distance_to(CHECKOUT_POS) < POSITION_EPSILON,
		"NavigationAgent3D target should equal checkout_approach position"
	)


# ── Scenario 4 — despawn on customer_left ────────────────────────────────────


func test_customer_left_removes_npc_from_active_list_and_begins_leave() -> void:
	_setup_test_store()
	EventBus.store_entered.emit(TEST_STORE_ID)

	var dummy: Node = Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)

	var npc: CustomerNPC = _get_first_active_npc()
	assert_not_null(npc, "Precondition: one active NPC is required")

	EventBus.customer_left.emit({})

	assert_eq(
		_npc_spawner.get_active_count(), 0,
		"_active_customer_npcs.size() should be 0 after customer_left"
	)
	assert_eq(
		npc.get_visit_state(),
		CustomerNPC.CustomerVisitState.LEAVING,
		"NPC should enter LEAVING state so it queue_frees on navigation finish"
	)


# ── Scenario 5 — store_exited clears all NPCs ────────────────────────────────


func test_store_exited_frees_all_npcs_and_clears_active_dictionary() -> void:
	_setup_test_store()
	EventBus.store_entered.emit(TEST_STORE_ID)

	for _i: int in range(2):
		var dummy: Node = Node.new()
		add_child_autofree(dummy)
		EventBus.customer_spawned.emit(dummy)

	assert_eq(
		_npc_spawner.get_active_count(), 2,
		"Precondition: 2 active NPCs before store_exited"
	)

	var npc_refs: Array[Node] = []
	for npc: Node in _npc_spawner._active_customer_npcs.keys():
		npc_refs.append(npc)

	EventBus.store_exited.emit(TEST_STORE_ID)

	# queue_free is processed at end of frame — yield one frame to flush.
	await get_tree().process_frame

	assert_eq(
		_npc_spawner.get_active_count(), 0,
		"Active NPC dictionary should be empty after store_exited"
	)
	assert_eq(
		_npc_spawner.get_queue_count(), 0,
		"Spawn queue should be cleared after store_exited"
	)
	for npc: Node in npc_refs:
		assert_false(
			is_instance_valid(npc),
			"All NPC nodes should be freed after store_exited"
		)


# ── Scenario 6 — missing CustomerNavConfig ────────────────────────────────────


func test_missing_nav_config_spawns_npc_at_zero_without_crash() -> void:
	var bare_store: Node = Node.new()
	bare_store.name = "test_store"
	get_tree().current_scene.add_child(bare_store)

	EventBus.store_entered.emit(TEST_STORE_ID)

	var dummy: Node = Node.new()
	add_child_autofree(dummy)

	# NPCSpawnerSystem.get_nav_config emits push_warning when config is absent.
	EventBus.customer_spawned.emit(dummy)

	assert_eq(
		_npc_spawner.get_active_count(), 1,
		"NPC should still spawn even without CustomerNavConfig"
	)

	var npc: CustomerNPC = _get_first_active_npc()
	assert_not_null(npc, "NPC instance must exist despite absent nav config")
	assert_true(
		npc.global_position.distance_to(Vector3.ZERO) < POSITION_EPSILON,
		"NPC should spawn at Vector3.ZERO when CustomerNavConfig is missing"
	)

	bare_store.queue_free()


# ── Helpers ───────────────────────────────────────────────────────────────────


func _setup_test_store() -> void:
	var root: Node = Node.new()
	root.name = "test_store"

	var nav: CustomerNavConfig = CustomerNavConfig.new()
	nav.max_concurrent_customers = 4

	var entry: Marker3D = Marker3D.new()
	entry.position = ENTRY_POS
	nav.entry_point = entry
	nav.add_child(entry)

	var wp1: Marker3D = Marker3D.new()
	wp1.position = WAYPOINT_POS_1
	nav.browse_waypoints.append(wp1)
	nav.add_child(wp1)

	var wp2: Marker3D = Marker3D.new()
	wp2.position = WAYPOINT_POS_2
	nav.browse_waypoints.append(wp2)
	nav.add_child(wp2)

	var checkout: Marker3D = Marker3D.new()
	checkout.position = CHECKOUT_POS
	nav.checkout_approach = checkout
	nav.add_child(checkout)

	var exit_marker: Marker3D = Marker3D.new()
	exit_marker.position = EXIT_POS
	nav.exit_point = exit_marker
	nav.add_child(exit_marker)

	root.add_child(nav)
	get_tree().current_scene.add_child(root)
	_test_store_root = root


func _get_first_active_npc() -> CustomerNPC:
	for npc: Node in _npc_spawner._active_customer_npcs.keys():
		if is_instance_valid(npc):
			return npc as CustomerNPC
	return null
