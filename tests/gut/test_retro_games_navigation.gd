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


# ── Navigation mesh covers the resized 16×20 floor ──────────────────────────

func test_navigation_mesh_spans_resized_floor() -> void:
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
	var vertices: PackedVector3Array = nav_mesh.vertices
	assert_eq(vertices.size(), 4, "Nav mesh quad must have 4 corner vertices")
	if vertices.size() != 4:
		return
	# Bounds: ±7.7 X, ±9.7 Z, Y=0.05 — leaves a small margin inside the walls
	# at ±8.05 / ±10.05 so agents do not clip through the geometry.
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for v: Vector3 in vertices:
		assert_almost_eq(v.y, 0.05, 0.001, "Nav vertex Y should be 0.05")
		min_x = minf(min_x, v.x)
		max_x = maxf(max_x, v.x)
		min_z = minf(min_z, v.z)
		max_z = maxf(max_z, v.z)
	assert_almost_eq(min_x, -7.7, 0.001, "Nav mesh min X")
	assert_almost_eq(max_x, 7.7, 0.001, "Nav mesh max X")
	assert_almost_eq(min_z, -9.7, 0.001, "Nav mesh min Z")
	assert_almost_eq(max_z, 9.7, 0.001, "Nav mesh max Z")


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
