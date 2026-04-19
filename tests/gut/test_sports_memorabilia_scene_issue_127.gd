## Verifies ISSUE-127 Sports Memorabilia store scene acceptance criteria.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/sports_memorabilia.tscn"
const SCRIPT_PATH: String = "res://game/scripts/stores/sports_memorabilia_controller.gd"
const GRID_CELL_SIZE: float = 0.5

var _root: Node3D = null


func before_each() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "Sports Memorabilia scene should load")
	_root = scene.instantiate() as Node3D
	add_child_autofree(_root)


func test_root_script_and_required_direct_children() -> void:
	assert_not_null(_root, "Scene should instantiate as Node3D")
	assert_eq(_root.name, "SportsMemorabilia")
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


func test_navigation_mesh_covers_fixture_zones() -> void:
	var nav_region := (
		_root.get_node("NavigationRegion3D") as NavigationRegion3D
	)
	assert_not_null(nav_region.navigation_mesh)
	assert_gt(
		nav_region.navigation_mesh.get_polygon_count(), 0,
		"NavigationRegion3D should have baked polygons"
	)

	var bounds: Rect2 = _get_nav_xz_bounds(nav_region.navigation_mesh)
	for zone: Marker3D in _get_fixture_zones():
		var pos := Vector2(zone.global_position.x, zone.global_position.z)
		assert_true(
			bounds.has_point(pos),
			"%s should be inside the baked NavMesh bounds" % zone.name
		)


func test_queue_markers_checkout_and_fixture_zones() -> void:
	var queue_markers: Array[Node] = _root.get_tree().get_nodes_in_group(
		"queue_markers"
	)
	assert_gte(
		queue_markers.size(), 3,
		"Scene should expose at least 3 checkout queue markers"
	)

	var checkout := _root.get_node_or_null("checkout_counter")
	assert_not_null(checkout, "checkout_counter should exist")
	var interactable := checkout.get_node_or_null("Interactable") as Interactable
	assert_not_null(
		interactable,
		"checkout_counter should have an Interactable component"
	)
	assert_eq(interactable.interaction_type, Interactable.InteractionType.REGISTER)
	assert_eq(interactable.prompt_text, "Checkout")

	var fixture_zones: Array[Marker3D] = _get_fixture_zones()
	assert_gte(
		fixture_zones.size(), 6,
		"Scene should expose at least 6 FixtureZones markers"
	)
	for i: int in range(fixture_zones.size()):
		var zone: Marker3D = fixture_zones[i]
		assert_eq(zone.get_meta("zone_index"), i + 1)
		_assert_grid_aligned(zone.global_position, zone.name)


func test_lighting_uses_only_limited_omni_lights() -> void:
	var omni_lights: Array[Node] = _root.find_children(
		"*", "OmniLight3D", true, false
	)
	var spot_lights: Array[Node] = _root.find_children(
		"*", "SpotLight3D", true, false
	)
	var world_environments: Array[Node] = _root.find_children(
		"*", "WorldEnvironment", true, false
	)

	assert_lte(
		omni_lights.size(), 4,
		"Scene should have at most 4 OmniLight3D nodes"
	)
	assert_eq(spot_lights.size(), 0, "Scene should not stack SpotLight3D nodes")
	assert_eq(
		world_environments.size(), 0,
		"EnvironmentManager owns WorldEnvironment, not store scenes"
	)
	assert_not_null(_root.get_node_or_null("KeyLight"))
	assert_not_null(_root.get_node_or_null("FillLight"))
	assert_not_null(_root.get_node_or_null("CaseAccentLight"))


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
