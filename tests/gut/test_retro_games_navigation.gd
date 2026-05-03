## Verifies retro_games.tscn navigation: nav mesh covers the resized floor,
## CustomerNavConfig markers sit at their authored positions, and each
## furniture fixture carries a NavigationObstacle3D so customers steer
## around shelves and counters instead of clipping through them.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"

const EXPECTED_WAYPOINTS: Dictionary = {
	"EntryPoint": Vector3(0.0, 0.05, 9.0),
	"BrowseWaypoint01": Vector3(-3.5, 0.05, -8.5),
	"BrowseWaypoint02": Vector3(3.5, 0.05, -8.5),
	"BrowseWaypoint03": Vector3(0.0, 0.05, -4.0),
	"BrowseWaypoint04": Vector3(-6.0, 0.05, 0.0),
	"CheckoutApproach": Vector3(5.5, 0.05, 7.0),
	"ExitPoint": Vector3(0.0, 0.05, 10.5),
}

# Fixture root path -> expected NavigationObstacle3D radius. Path encodes
# whether the obstacle hangs off the StaticBody3D (preferred when a static
# body exists) or directly off the fixture root (testing_station and
# refurb_bench have no StaticBody3D).
const EXPECTED_OBSTACLES: Dictionary = {
	"CartRackLeft/StaticBody3D/NavigationObstacle3D": 1.3,
	"CartRackRight/StaticBody3D/NavigationObstacle3D": 1.3,
	"GlassCase/StaticBody3D/NavigationObstacle3D": 1.2,
	"ConsoleShelf/StaticBody3D/NavigationObstacle3D": 0.5,
	"AccessoriesBin/StaticBody3D/NavigationObstacle3D": 0.85,
	"Checkout/StaticBody3D/NavigationObstacle3D": 1.0,
	"testing_station/NavigationObstacle3D": 0.8,
	"refurb_bench/NavigationObstacle3D": 0.9,
}

var _root: Node3D = null


func before_all() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "Retro Games scene must load")
	if scene:
		_root = scene.instantiate() as Node3D
		add_child(_root)


func after_all() -> void:
	if is_instance_valid(_root):
		_root.free()
	_root = null


# ── Baked navigation mesh has obstacle cutouts and covers the floor ─────────

func test_navigation_mesh_is_baked_with_obstacle_cutouts() -> void:
	var region: NavigationRegion3D = (
		_root.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	)
	assert_not_null(region, "NavigationRegion3D must exist")
	if region == null:
		return
	var nav_mesh: NavigationMesh = region.navigation_mesh
	assert_not_null(nav_mesh, "NavigationRegion3D must carry a NavigationMesh")
	if nav_mesh == null:
		return
	# A baked mesh with furniture cutouts must contain many polygons rather
	# than the prior single-quad stub that let customers walk through fixtures.
	assert_gt(
		nav_mesh.get_polygon_count(), 1,
		"Baked nav mesh must have more than one polygon (got %d)"
		% nav_mesh.get_polygon_count()
	)
	var vertices: PackedVector3Array = nav_mesh.vertices
	assert_gt(
		vertices.size(), 4,
		"Baked nav mesh must have more than 4 vertices (got %d)"
		% vertices.size()
	)
	# The bake walks just above the floor (Y ≈ 0.20 with cell_height = 0.1).
	# Confirm the surface is at ground level rather than sitting on the
	# ceiling slab or a floating platform.
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for v: Vector3 in vertices:
		min_x = minf(min_x, v.x)
		max_x = maxf(max_x, v.x)
		min_y = minf(min_y, v.y)
		max_y = maxf(max_y, v.y)
		min_z = minf(min_z, v.z)
		max_z = maxf(max_z, v.z)
	assert_lt(min_y, 1.0, "Nav mesh min Y must be near ground (got %f)" % min_y)
	assert_lt(max_y, 2.0, "Nav mesh max Y must stay below ceiling (got %f)" % max_y)
	# The bake covers the full ±7.7 × ±9.7 footprint, allowing a small inset
	# from the agent radius (0.4m) and walkable region pull-in.
	assert_lt(min_x, -6.5, "Nav mesh must extend toward left wall")
	assert_gt(max_x, 6.5, "Nav mesh must extend toward right wall")
	assert_lt(min_z, -8.5, "Nav mesh must extend toward back wall")
	assert_gt(max_z, 8.5, "Nav mesh must extend toward front wall")


func test_navigation_mesh_is_external_resource() -> void:
	var scene_text: String = FileAccess.get_file_as_string(SCENE_PATH)
	assert_string_contains(
		scene_text,
		"path=\"res://game/navigation/retro_games_navmesh.tres\"",
		"retro_games.tscn must reference the external baked nav mesh"
	)
	assert_false(
		scene_text.contains("sub_resource type=\"NavigationMesh\""),
		"retro_games.tscn must not embed the nav mesh inline"
	)


# ── Customer waypoints ──────────────────────────────────────────────────────

func test_all_seven_customer_markers_exist_with_authored_positions() -> void:
	var nav_config: Node = _root.get_node_or_null("CustomerNavConfig")
	assert_not_null(nav_config, "CustomerNavConfig node must exist")
	if nav_config == null:
		return
	for marker_name: String in EXPECTED_WAYPOINTS:
		var marker: Marker3D = (
			nav_config.get_node_or_null(marker_name) as Marker3D
		)
		assert_not_null(
			marker,
			"CustomerNavConfig/%s must exist with exact case-matching name"
			% marker_name,
		)
		if marker == null:
			continue
		var expected: Vector3 = EXPECTED_WAYPOINTS[marker_name]
		assert_almost_eq(
			marker.global_position.x, expected.x, 0.001,
			"%s X position" % marker_name,
		)
		assert_almost_eq(
			marker.global_position.y, expected.y, 0.001,
			"%s Y position" % marker_name,
		)
		assert_almost_eq(
			marker.global_position.z, expected.z, 0.001,
			"%s Z position" % marker_name,
		)


func test_customer_nav_config_getters_return_authored_positions() -> void:
	var nav_config: CustomerNavConfig = (
		_root.get_node_or_null("CustomerNavConfig") as CustomerNavConfig
	)
	assert_not_null(nav_config, "CustomerNavConfig must resolve to script type")
	if nav_config == null:
		return
	# Auto-discovery runs in _ready(); the scene was added to the tree in
	# before_all, so the markers should be wired up by now.
	assert_eq(
		nav_config.get_entry_position(),
		EXPECTED_WAYPOINTS["EntryPoint"],
		"get_entry_position() must return EntryPoint world position",
	)
	assert_eq(
		nav_config.get_checkout_position(),
		EXPECTED_WAYPOINTS["CheckoutApproach"],
		"get_checkout_position() must return CheckoutApproach world position",
	)
	assert_eq(
		nav_config.get_exit_position(),
		EXPECTED_WAYPOINTS["ExitPoint"],
		"get_exit_position() must return ExitPoint world position",
	)
	var browse: Array[Vector3] = nav_config.get_browse_positions()
	assert_eq(
		browse.size(), 4,
		"get_browse_positions() must return all 4 BrowseWaypoints",
	)
	for pos: Vector3 in browse:
		assert_ne(
			pos, Vector3.ZERO,
			"Browse position must not fall back to ZERO (missing marker)",
		)


# ── Furniture obstacle avoidance ────────────────────────────────────────────

func test_each_furniture_carries_navigation_obstacle_with_expected_radius() -> void:
	for path: String in EXPECTED_OBSTACLES:
		var obstacle: NavigationObstacle3D = (
			_root.get_node_or_null(path) as NavigationObstacle3D
		)
		assert_not_null(
			obstacle,
			"%s must exist so customers steer around the fixture" % path,
		)
		if obstacle == null:
			continue
		var expected_radius: float = EXPECTED_OBSTACLES[path]
		assert_almost_eq(
			obstacle.radius, expected_radius, 0.001,
			"%s radius" % path,
		)
		assert_gt(
			obstacle.height, 0.0,
			"%s height must be positive so it covers customer extents" % path,
		)
