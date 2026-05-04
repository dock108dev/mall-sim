## Verifies ISSUE-128 Retro Games store scene acceptance criteria.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const SCRIPT_PATH: String = "res://game/scripts/stores/retro_games.gd"
const GRID_CELL_SIZE: float = 0.5

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


func test_root_navigation_and_required_children_exist() -> void:
	assert_not_null(_root, "Scene should instantiate as Node3D")
	assert_eq(_root.name, "RetroGames")
	assert_eq(_root.get_script().resource_path, SCRIPT_PATH)
	assert_not_null(
		_root.get_node_or_null("NavigationRegion3D"),
		"Scene should include NavigationRegion3D"
	)
	assert_not_null(
		_root.get_node_or_null("npc_container"),
		"Scene should include direct npc_container child"
	)
	assert_not_null(
		_root.get_node_or_null("entrance_marker"),
		"Scene should include entrance_marker"
	)
	assert_not_null(
		_root.get_node_or_null("AudioZone"),
		"Scene should include AudioZone"
	)
	assert_not_null(
		_root.get_node_or_null("crt_demo_area"),
		"Scene should include a CRT demo area node"
	)


func test_nav_mesh_covers_fixture_and_work_nodes() -> void:
	var nav_region: NavigationRegion3D = (
		_root.get_node("NavigationRegion3D") as NavigationRegion3D
	)
	assert_not_null(nav_region.navigation_mesh)
	assert_gt(
		nav_region.navigation_mesh.get_polygon_count(), 0,
		"NavigationRegion3D should have baked polygons"
	)

	# Baked nav mesh inserts a 0.4m agent radius inset around walls and
	# obstacles, so fixtures placed flush against walls (AccessoriesBin,
	# refurb_bench) sit just past the baked surface. Allow a 1.0m tolerance
	# so the bounds sanity check remains meaningful for fixtures floating
	# in the middle of the room without flagging the deliberate insets.
	const FIXTURE_BOUNDS_TOLERANCE: float = 1.0
	var bounds: Rect2 = _get_nav_xz_bounds(nav_region.navigation_mesh).grow(
		FIXTURE_BOUNDS_TOLERANCE
	)
	var targets: Array[Node3D] = []
	for zone: Marker3D in _get_fixture_zones():
		targets.append(zone)
	targets.append(_root.get_node("testing_station") as Node3D)
	targets.append(_root.get_node("refurb_bench") as Node3D)
	targets.append(_root.get_node("entrance_marker") as Node3D)

	for target: Node3D in targets:
		var point := Vector2(target.global_position.x, target.global_position.z)
		assert_true(
			bounds.has_point(point),
			"%s should be inside the baked NavMesh bounds" % target.name
		)


func test_checkout_testing_and_refurb_nodes_are_interactable() -> void:
	var checkout: Node3D = _root.get_node("checkout_counter") as Node3D
	var checkout_interactable := (
		checkout.get_node("Interactable") as Interactable
	)
	assert_eq(
		checkout_interactable.interaction_type,
		Interactable.InteractionType.REGISTER
	)
	# checkout_counter ships an empty authored prompt_text so the
	# InteractionPrompt never advertises a "Press E to checkout" cue —
	# Day 1 customers auto-complete checkout via PlayerCheckout, so a
	# player-driven verb on the counter would be a dead prompt. The base
	# Interactable._ready fills empty prompt_text from PROMPT_VERBS, so the
	# runtime value is the REGISTER default ("Use"); RetroGames overwrites
	# it back to "" via _refresh_checkout_prompt() on store_entered.
	assert_eq(
		checkout_interactable.prompt_text,
		Interactable.PROMPT_VERBS[Interactable.InteractionType.REGISTER],
		"Authored prompt_text is empty; Interactable._ready resolves to the "
		+ "REGISTER default until RetroGames._refresh_checkout_prompt clears it"
	)

	var testing_station: Node3D = _root.get_node("testing_station") as Node3D
	var testing_interactable := (
		testing_station.get_node("Interactable") as Interactable
	)
	assert_eq(
		testing_interactable.interaction_type,
		Interactable.InteractionType.ITEM
	)
	assert_eq(testing_interactable.prompt_text, "Coming Soon")
	assert_false(
		testing_interactable.enabled,
		"Testing station Interactable must ship disabled until the testing flow is wired up"
	)

	var refurb_bench: Node3D = _root.get_node("refurb_bench") as Node3D
	var refurb_interactable := (
		refurb_bench.get_node("Interactable") as Interactable
	)
	assert_eq(
		refurb_interactable.interaction_type,
		Interactable.InteractionType.BACKROOM
	)
	assert_eq(refurb_interactable.prompt_text, "Refurbish Gear")


func test_checkout_register_node_is_disabled() -> void:
	var register: Interactable = (
		_root.get_node_or_null("Checkout/Register") as Interactable
	)
	assert_not_null(register, "Checkout/Register must exist in the scene")
	if register:
		assert_false(
			register.enabled,
			"Checkout/Register must be disabled to prevent double-firing interactable_interacted"
		)


func test_only_checkout_counter_register_is_enabled() -> void:
	var enabled_registers: Array[Interactable] = []
	_collect_enabled_register_interactables(_root, enabled_registers)
	assert_eq(
		enabled_registers.size(), 1,
		"Exactly one REGISTER interactable must be enabled in the scene"
	)
	if enabled_registers.size() == 1:
		assert_eq(
			enabled_registers[0].get_parent().name,
			"checkout_counter",
			"The sole enabled REGISTER interactable must be checkout_counter/Interactable"
		)


func test_checkout_counter_has_no_duplicate_mesh() -> void:
	var counter: Node3D = _root.get_node_or_null("checkout_counter") as Node3D
	assert_not_null(counter, "checkout_counter must exist")
	if not counter:
		return
	var mesh_children: Array[Node] = []
	for child: Node in counter.get_children():
		if child is MeshInstance3D:
			mesh_children.append(child)
	assert_eq(
		mesh_children.size(), 0,
		"checkout_counter must not contain a duplicate CounterMesh (visual provided by Checkout)"
	)


func test_queue_markers_fixture_zones_and_scene_layout_match_issue() -> void:
	var queue_markers: Array[Node] = _root.get_tree().get_nodes_in_group(
		"queue_markers"
	)
	assert_gte(
		queue_markers.size(), 3,
		"Scene should expose at least 3 checkout queue markers"
	)

	var fixture_zones: Array[Marker3D] = _get_fixture_zones()
	assert_gte(
		fixture_zones.size(), 6,
		"Scene should expose at least 6 FixtureZones markers"
	)
	for i: int in range(fixture_zones.size()):
		var zone: Marker3D = fixture_zones[i]
		assert_eq(zone.get_meta("zone_index"), i + 1)
		_assert_grid_aligned(zone.global_position, zone.name)

	var testing_station: Node3D = _root.get_node("testing_station") as Node3D
	var refurb_bench: Node3D = _root.get_node("refurb_bench") as Node3D
	var crt_demo_area: Node3D = _root.get_node("crt_demo_area") as Node3D
	assert_lt(
		testing_station.global_position.distance_to(crt_demo_area.global_position),
		1.25,
		"testing_station should stay in the CRT demo area"
	)
	assert_lt(
		refurb_bench.global_position.x,
		-2.0,
		"refurb_bench should sit in the back-left work area"
	)
	assert_lt(
		refurb_bench.global_position.z,
		-1.25,
		"refurb_bench should stay behind the main sales floor"
	)


func test_emissive_panels_and_lighting_budget_match_retro_vibe() -> void:
	var light_nodes: Array[Light3D] = _collect_lights(_root)
	var world_environments: Array[Node] = _root.find_children(
		"*", "WorldEnvironment", true, false
	)
	assert_lte(
		light_nodes.size(), 4,
		"Scene should use at most 4 light nodes"
	)
	assert_eq(
		world_environments.size(), 0,
		"EnvironmentManager owns WorldEnvironment, not store scenes"
	)

	var sign_backing: MeshInstance3D = (
		_root.get_node("Storefront/SignBacking") as MeshInstance3D
	)
	var warm_panel: MeshInstance3D = (
		_root.get_node("crt_demo_area/WarmNeonPanel") as MeshInstance3D
	)
	var green_panel: MeshInstance3D = (
		_root.get_node("crt_demo_area/GreenNeonPanel") as MeshInstance3D
	)

	for panel: MeshInstance3D in [sign_backing, warm_panel, green_panel]:
		var material := panel.get_surface_override_material(0)
		assert_true(
			material is StandardMaterial3D,
			"%s should use a StandardMaterial3D override" % panel.name
		)
		if material is StandardMaterial3D:
			assert_true(
				(material as StandardMaterial3D).emission_enabled,
				"%s should remain emissive" % panel.name
			)


func _collect_enabled_register_interactables(
	root: Node, out: Array[Interactable]
) -> void:
	for node: Node in root.get_tree().get_nodes_in_group("interactables"):
		if not root.is_ancestor_of(node) and node != root:
			continue
		if not node is Interactable:
			continue
		var interactable := node as Interactable
		if (
			interactable.interaction_type == Interactable.InteractionType.REGISTER
			and interactable.enabled
		):
			out.append(interactable)


func _get_fixture_zones() -> Array[Marker3D]:
	var zones: Array[Marker3D] = []
	for node: Node in _root.get_tree().get_nodes_in_group("FixtureZones"):
		if _root.is_ancestor_of(node) and node is Marker3D:
			zones.append(node as Marker3D)
	zones.sort_custom(func(a: Marker3D, b: Marker3D) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0
	)
	return zones


func _get_nav_xz_bounds(nav_mesh: NavigationMesh) -> Rect2:
	var vertices: PackedVector3Array = nav_mesh.get_vertices()
	assert_gt(vertices.size(), 0, "NavigationMesh should have vertices")

	var min_x: float = vertices[0].x
	var max_x: float = vertices[0].x
	var min_z: float = vertices[0].z
	var max_z: float = vertices[0].z
	for vertex: Vector3 in vertices:
		min_x = minf(min_x, vertex.x)
		max_x = maxf(max_x, vertex.x)
		min_z = minf(min_z, vertex.z)
		max_z = maxf(max_z, vertex.z)
	return Rect2(min_x, min_z, max_x - min_x, max_z - min_z)


func _collect_lights(root: Node) -> Array[Light3D]:
	var lights: Array[Light3D] = []
	_collect_lights_recursive(root, lights)
	return lights


func _collect_lights_recursive(node: Node, lights: Array[Light3D]) -> void:
	if node is Light3D:
		lights.append(node as Light3D)
	for child: Node in node.get_children():
		_collect_lights_recursive(child, lights)


func _assert_grid_aligned(position: Vector3, marker_name: String) -> void:
	assert_almost_eq(
		position.x / GRID_CELL_SIZE,
		roundf(position.x / GRID_CELL_SIZE),
		0.001,
		"%s x position should align to build grid" % marker_name
	)
	assert_almost_eq(
		position.z / GRID_CELL_SIZE,
		roundf(position.z / GRID_CELL_SIZE),
		0.001,
		"%s z position should align to build grid" % marker_name
	)
