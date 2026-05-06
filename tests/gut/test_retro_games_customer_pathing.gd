## Verifies the three navigation gates exercised by Customer._detect_navmesh_or_fallback()
## for the retro_games store, plus the CustomerSystem parenting fix that ensures
## the NavigationRegion3D is reachable from a spawned customer's ancestor chain.
##
## Failing any gate silently engages the direct-line waypoint fallback per
## customer (see customer.gd §F-94), so the only runtime symptom is a per-spawn
## push_warning. These checks fail loudly at test time instead.
extends GutTest


const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const CUSTOMER_SCENE_PATH: String = "res://game/scenes/characters/customer.tscn"
const NAVMESH_PATH: String = "res://game/navigation/retro_games_navmesh.tres"

var _root: Node3D = null


func before_all() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "Retro Games scene should load")
	_root = scene.instantiate() as Node3D
	add_child(_root)


func after_all() -> void:
	if is_instance_valid(_root):
		_root.free()
	_root = null


# ── Gate 1: NavigationAgent3D direct child of customer ────────────────────────

func test_customer_scene_has_direct_navigation_agent_child() -> void:
	var customer_scene: PackedScene = load(CUSTOMER_SCENE_PATH)
	assert_not_null(customer_scene, "Customer scene should load")
	var customer: Node = customer_scene.instantiate()
	assert_not_null(
		customer.get_node_or_null("NavigationAgent3D"),
		"Gate 1: NavigationAgent3D must be a direct child of the customer scene "
		+ "(customer.gd reads it via get_node_or_null(\"NavigationAgent3D\"))"
	)
	customer.free()


# ── Gate 2: NavigationRegion3D ancestor reachability ──────────────────────────

func test_navigation_region_is_direct_child_of_store_root() -> void:
	var nav_region: NavigationRegion3D = (
		_root.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	)
	assert_not_null(
		nav_region,
		"Gate 2: NavigationRegion3D must be a direct child of the store root so "
		+ "any node parented anywhere under the store can reach it via ancestor walk"
	)


func test_npc_container_is_present_so_spawned_customers_share_store_ancestor() -> void:
	var container: Node = _root.get_node_or_null("npc_container")
	assert_not_null(
		container,
		"Gate 2: npc_container must exist under the store root so spawned "
		+ "customers share the NavigationRegion3D's parent chain"
	)


func test_find_navigation_region_walks_up_from_npc_container() -> void:
	# Mirrors customer.gd._find_navigation_region(): walk parents looking for
	# a child of any ancestor that is a NavigationRegion3D. A node parented
	# under npc_container must reach NavigationRegion3D as a sibling.
	var container: Node = _root.get_node_or_null("npc_container")
	assert_not_null(container, "precondition: npc_container exists")
	var probe := Node3D.new()
	container.add_child(probe)
	var found: NavigationRegion3D = _find_navigation_region_from(probe)
	probe.queue_free()
	assert_not_null(
		found,
		"Gate 2: a node under npc_container must find NavigationRegion3D by "
		+ "walking ancestors (the bug this fix targets)"
	)


# ── Gate 3: navmesh has baked polygons ────────────────────────────────────────

func test_external_navmesh_resource_has_baked_polygons() -> void:
	var nav_mesh: NavigationMesh = load(NAVMESH_PATH) as NavigationMesh
	assert_not_null(
		nav_mesh,
		"Gate 3: external navmesh resource must load from disk"
	)
	assert_gt(
		nav_mesh.get_polygon_count(), 0,
		"Gate 3: retro_games_navmesh.tres must have baked polygons; rebake via "
		+ "the NavigationRegion3D bake button if this fails"
	)


# ── Floor-plan coordinates: register & exit targets ──────────────────────────

func test_register_area_position_matches_floor_plan() -> void:
	var register_area: Area3D = (
		_root.get_node_or_null("RegisterArea") as Area3D
	)
	assert_not_null(register_area, "RegisterArea must exist at store root")
	if register_area == null:
		return
	assert_true(
		register_area.is_in_group("register_area"),
		"RegisterArea must be in 'register_area' group so StoreController._collect_areas finds it"
	)
	# Floor plan: register at (~+5.5, ~+8.0). Y is irrelevant for XZ pathing
	# but the trigger is authored at Y=1.0 to overlap the player capsule.
	assert_almost_eq(register_area.global_position.x, 5.5, 0.5)
	assert_almost_eq(register_area.global_position.z, 8.0, 0.5)


func test_entry_area_is_grouped_for_collection() -> void:
	var entry_area: Area3D = _root.get_node_or_null("EntryArea") as Area3D
	assert_not_null(entry_area, "EntryArea must exist at store root")
	if entry_area == null:
		return
	assert_true(
		entry_area.is_in_group("entry_area"),
		"EntryArea must be in 'entry_area' group so StoreController._collect_areas finds it"
	)
	# Floor plan: exit/entry near (~0, ~+9.35). EntryArea at the entrance
	# threshold seeds both the customer spawn position and the LEAVING target.
	assert_almost_eq(entry_area.global_position.x, 0.0, 0.5)
	assert_gt(
		entry_area.global_position.z, 8.5,
		"EntryArea must sit at the front of the store (positive Z, near entrance)"
	)


# ── CustomerNavConfig wiring ──────────────────────────────────────────────────

func test_customer_nav_config_present_with_all_markers() -> void:
	var config: Node = _root.get_node_or_null("CustomerNavConfig")
	assert_not_null(
		config,
		"CustomerNavConfig must exist at store root for spawner waypoint queries"
	)
	if config == null:
		return
	for marker_name: String in [
		"EntryPoint",
		"BrowseWaypoint01",
		"BrowseWaypoint02",
		"BrowseWaypoint03",
		"BrowseWaypoint04",
		"CheckoutApproach",
		"ExitPoint",
	]:
		var marker: Marker3D = config.get_node_or_null(marker_name) as Marker3D
		assert_not_null(
			marker,
			"CustomerNavConfig must expose Marker3D '%s'" % marker_name
		)


# ── CustomerSystem parenting: Gate 2 holds at runtime ────────────────────────

func test_customer_system_resolves_npc_container_from_store_controller() -> void:
	var stub_store: StoreController = StoreController.new()
	stub_store.name = "stub_store"
	add_child_autofree(stub_store)
	var container := Node3D.new()
	container.name = "npc_container"
	stub_store.add_child(container)

	var system := CustomerSystem.new()
	add_child_autofree(system)
	system._store_controller = stub_store
	assert_eq(
		system._resolve_npc_container(), container,
		"_resolve_npc_container must return the store's npc_container node"
	)


func test_customer_system_returns_null_container_without_controller() -> void:
	var system := CustomerSystem.new()
	add_child_autofree(system)
	assert_null(
		system._resolve_npc_container(),
		"_resolve_npc_container must return null when no store is bound (test-fixture path)"
	)


func test_spawned_customer_parents_under_store_npc_container() -> void:
	var stub_store: StoreController = StoreController.new()
	stub_store.name = "stub_store_pathing"
	add_child_autofree(stub_store)
	var container := Node3D.new()
	container.name = "npc_container"
	stub_store.add_child(container)

	var system := CustomerSystem.new()
	add_child_autofree(system)
	system._customer_scene = preload(
		"res://game/scenes/characters/customer.tscn"
	)
	system._store_controller = stub_store
	system._store_id = "stub_store_pathing"
	GameState.set_flag(&"first_sale_complete", true)  # bypass Day-1 gate
	system.spawn_customer(_make_profile(), system._store_id)

	var actives: Array[Customer] = system.get_active_customers()
	assert_eq(actives.size(), 1, "Stub store spawn should produce one customer")
	if actives.is_empty():
		return
	var customer: Customer = actives[0]
	assert_eq(
		customer.get_parent(), container,
		"Spawned customer must be parented under the store's npc_container so "
		+ "Customer._find_navigation_region() can reach the store ancestor chain"
	)
	system.despawn_customer(customer)


func test_released_customer_returns_to_customer_system_pool() -> void:
	var stub_store: StoreController = StoreController.new()
	stub_store.name = "stub_store_release"
	add_child_autofree(stub_store)
	var container := Node3D.new()
	container.name = "npc_container"
	stub_store.add_child(container)

	var system := CustomerSystem.new()
	add_child_autofree(system)
	system._customer_scene = preload(
		"res://game/scenes/characters/customer.tscn"
	)
	system._store_controller = stub_store
	system._store_id = "stub_store_release"
	GameState.set_flag(&"first_sale_complete", true)
	system.spawn_customer(_make_profile(), system._store_id)

	var actives: Array[Customer] = system.get_active_customers()
	assert_eq(actives.size(), 1, "precondition: one active customer")
	if actives.is_empty():
		return
	var customer: Customer = actives[0]
	system.despawn_customer(customer)
	assert_eq(
		customer.get_parent(), system,
		"Released customers must reparent to CustomerSystem so the next spawn "
		+ "can move them under the active store's npc_container"
	)


# ── helpers ───────────────────────────────────────────────────────────────────

func _find_navigation_region_from(node: Node) -> NavigationRegion3D:
	var current: Node = node.get_parent()
	while current != null:
		for child: Node in current.get_children():
			if child is NavigationRegion3D:
				return child as NavigationRegion3D
		current = current.get_parent()
	return null


func _make_profile() -> CustomerTypeDefinition:
	var p: CustomerTypeDefinition = CustomerTypeDefinition.new()
	p.id = "retro_games_pathing_test_customer"
	p.customer_name = "Pathing Test Customer"
	p.budget_range = [10.0, 100.0]
	p.patience = 0.5
	p.price_sensitivity = 0.5
	p.preferred_categories = PackedStringArray([])
	p.preferred_tags = PackedStringArray([])
	p.condition_preference = "good"
	p.browse_time_range = [1.0, 2.0]
	p.purchase_probability_base = 0.9
	p.impulse_buy_chance = 0.1
	p.mood_tags = PackedStringArray([])
	return p
