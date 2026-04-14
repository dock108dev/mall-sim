## Tests mall hallway scene structure and ISSUE-138 acceptance criteria.
extends GutTest


const EXPECTED_SLOT_COUNT: int = 5
const EXPECTED_SPACING: float = 8.0


func test_scene_has_storefront_slots_container() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	assert_not_null(scene, "Mall hallway scene should load")
	var state: SceneState = scene.get_state()
	var found: bool = false
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == &"StorefrontSlots":
			found = true
			break
	assert_true(found, "Scene should have StorefrontSlots node")


func test_scene_has_five_storefront_slots() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	var state: SceneState = scene.get_state()
	var slot_count: int = 0
	for i: int in range(state.get_node_count()):
		var name: StringName = state.get_node_name(i)
		if name.begins_with("Slot_"):
			slot_count += 1
	assert_eq(
		slot_count, EXPECTED_SLOT_COUNT,
		"Scene should have exactly 5 storefront slots"
	)


func test_scene_has_player_spawn() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	var state: SceneState = scene.get_state()
	var found: bool = false
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == &"PlayerSpawn":
			found = true
			break
	assert_true(found, "Scene should have PlayerSpawn Marker3D")


func test_scene_has_navigation_region() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	var state: SceneState = scene.get_state()
	var found: bool = false
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == &"NavigationRegion3D":
			found = true
			break
	assert_true(
		found, "Scene should have NavigationRegion3D"
	)


func test_scene_has_waypoint_graph() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	var state: SceneState = scene.get_state()
	var found: bool = false
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == &"WaypointGraph":
			found = true
			break
	assert_true(found, "Scene should have WaypointGraph node")


func test_scene_has_lighting_nodes() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	var state: SceneState = scene.get_state()
	var found_key: bool = false
	var found_fill: bool = false
	var found_accent: bool = false
	for i: int in range(state.get_node_count()):
		var name: StringName = state.get_node_name(i)
		if name == &"KeyLight":
			found_key = true
		elif name == &"FillOmniBank":
			found_fill = true
		elif name == &"AccentNeonStrip":
			found_accent = true
	assert_true(found_key, "Should have KeyLight")
	assert_true(found_fill, "Should have FillOmniBank")
	assert_true(found_accent, "Should have AccentNeonStrip")


func test_scene_has_no_world_environment() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	var state: SceneState = scene.get_state()
	for i: int in range(state.get_node_count()):
		var type: StringName = state.get_node_type(i)
		assert_ne(
			type, &"WorldEnvironment",
			"Scene must not contain WorldEnvironment"
		)


func test_storefront_spacing_constant() -> void:
	assert_eq(
		MallHallway.STOREFRONT_SPACING, EXPECTED_SPACING,
		"Storefront spacing should be 8m"
	)


func test_storefront_count_constant() -> void:
	assert_eq(
		MallHallway.STOREFRONT_COUNT, EXPECTED_SLOT_COUNT,
		"Storefront count should be 5"
	)


func test_waypoint_builder_spacing() -> void:
	assert_eq(
		MallWaypointGraphBuilder.STOREFRONT_SPACING,
		EXPECTED_SPACING,
		"Waypoint builder spacing should match hallway spacing"
	)


func test_waypoint_graph_has_minimum_nodes() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var store_ids: Array[StringName] = [
		&"sports", &"retro_games", &"rentals",
		&"pocket_creatures", &"electronics",
	]
	var graph: Node3D = MallWaypointGraphBuilder.build(
		parent, store_ids
	)
	var wp_count: int = 0
	for child: Node in graph.get_children():
		if child is MallWaypoint:
			wp_count += 1
	assert_true(
		wp_count >= 6,
		"WaypointGraph should have at least 6 waypoints, got %d"
		% wp_count
	)
