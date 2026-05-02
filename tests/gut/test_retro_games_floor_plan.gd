## Verifies retro_games.tscn matches the BRAINDUMP retail floor plan:
## testing zone on the left, register on the right, central walking aisle
## clear except for the central display table, and customer waypoints
## scattered to track the new fixture quadrants.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
# Aisle width: any fixture with |center.x| < CENTER_AISLE_HALF_WIDTH that is
# not the central display table (GlassCase) violates the open-floor contract.
const CENTER_AISLE_HALF_WIDTH: float = 1.0
const CENTRAL_DISPLAY_NODE: String = "GlassCase"
# Fixtures that must occupy the named quadrant per the floor plan.
const LEFT_FIXTURES: Array[String] = [
	"testing_station", "crt_demo_area", "AccessoriesBin", "refurb_bench",
]
const RIGHT_FIXTURES: Array[String] = [
	"Checkout", "checkout_counter", "ConsoleShelf",
]
const BACK_FIXTURES: Array[String] = ["CartRackLeft", "CartRackRight"]

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


# ── Quadrant placement matches BRAINDUMP floor plan ──────────────────────────

func test_testing_zone_is_on_left_side() -> void:
	for fixture_name: String in ["testing_station", "crt_demo_area"]:
		var fixture: Node3D = _root.get_node_or_null(fixture_name) as Node3D
		assert_not_null(fixture, "%s must exist" % fixture_name)
		if fixture == null:
			continue
		assert_lt(
			fixture.global_position.x, 0.0,
			(
				"%s must sit on the LEFT side of the store (x < 0) per the "
				+ "BRAINDUMP floor plan; found x=%.2f"
			) % [fixture_name, fixture.global_position.x],
		)


func test_register_is_on_right_side() -> void:
	for fixture_name: String in ["Checkout", "checkout_counter"]:
		var fixture: Node3D = _root.get_node_or_null(fixture_name) as Node3D
		assert_not_null(fixture, "%s must exist" % fixture_name)
		if fixture == null:
			continue
		assert_gt(
			fixture.global_position.x, 0.0,
			(
				"%s must sit on the RIGHT side of the store (x > 0) per the "
				+ "BRAINDUMP floor plan; found x=%.2f"
			) % [fixture_name, fixture.global_position.x],
		)


func test_back_wall_shelves_remain_along_back_wall() -> void:
	# Back wall sits at z=-10.05 in the resized 16×20 interior; cart racks
	# must hug it within ~2 m so they read as wall-mounted shelving.
	for fixture_name: String in BACK_FIXTURES:
		var fixture: Node3D = _root.get_node_or_null(fixture_name) as Node3D
		assert_not_null(fixture, "%s must exist" % fixture_name)
		if fixture == null:
			continue
		assert_lt(
			fixture.global_position.z, -8.0,
			(
				"%s must remain against the back wall (z < -8.0); found z=%.2f"
			) % [fixture_name, fixture.global_position.z],
		)


# ── Open floor: center aisle clear except for the central display table ─────

func test_center_aisle_is_clear_except_central_display() -> void:
	for fixture_name: String in (
		LEFT_FIXTURES + RIGHT_FIXTURES + BACK_FIXTURES
	):
		var fixture: Node3D = _root.get_node_or_null(fixture_name) as Node3D
		if fixture == null:
			continue
		assert_gte(
			absf(fixture.global_position.x),
			CENTER_AISLE_HALF_WIDTH,
			(
				"%s at x=%.2f intrudes into the center walking aisle "
				+ "(|x| < %.2f). Only %s may sit in the aisle."
			) % [
				fixture_name,
				fixture.global_position.x,
				CENTER_AISLE_HALF_WIDTH,
				CENTRAL_DISPLAY_NODE,
			],
		)


func test_central_display_remains_in_aisle_center() -> void:
	var glass: Node3D = _root.get_node_or_null(CENTRAL_DISPLAY_NODE) as Node3D
	assert_not_null(glass, "%s must exist" % CENTRAL_DISPLAY_NODE)
	if glass == null:
		return
	assert_lt(
		absf(glass.global_position.x),
		CENTER_AISLE_HALF_WIDTH,
		"Central display table must remain near x=0 (currently x=%.2f)"
		% glass.global_position.x,
	)


# ── Testing zone clear: refurb_bench must not block the left-mid area ───────

func test_refurb_bench_clear_of_testing_zone() -> void:
	# Testing zone target footprint after the resize: x∈[-5.6,-4.0],
	# z∈[-7.9,-6.4]. refurb_bench must sit outside that footprint so the
	# player can approach the testing station without being blocked.
	var refurb: Node3D = _root.get_node_or_null("refurb_bench") as Node3D
	assert_not_null(refurb, "refurb_bench must exist")
	if refurb == null:
		return
	var pos: Vector3 = refurb.global_position
	var inside_zone: bool = (
		pos.x >= -5.6 and pos.x <= -4.0
		and pos.z >= -7.9 and pos.z <= -6.4
	)
	assert_false(
		inside_zone,
		(
			"refurb_bench at (%.2f, %.2f) must not sit inside the new testing "
			+ "zone footprint x∈[-5.6,-4.0], z∈[-7.9,-6.4]"
		) % [pos.x, pos.z],
	)


# ── Customer waypoints track repositioned fixtures ──────────────────────────

func test_checkout_approach_tracks_register_quadrant() -> void:
	var marker: Marker3D = (
		_root.get_node_or_null("CustomerNavConfig/CheckoutApproach")
		as Marker3D
	)
	assert_not_null(marker, "CustomerNavConfig/CheckoutApproach must exist")
	if marker == null:
		return
	assert_gt(
		marker.global_position.x, 0.0,
		(
			"CheckoutApproach must follow the register to the right side "
			+ "(x > 0); found x=%.2f"
		) % marker.global_position.x,
	)


func test_browse_waypoints_scatter_across_fixture_quadrants() -> void:
	# After repositioning, the four browse waypoints should not all bunch on
	# one half of the store. Verify that waypoints exist in both x<0 and
	# x>0 halves so customers visit testing zone (left) and right shelves.
	var any_left: bool = false
	var any_right: bool = false
	for i: int in range(1, 5):
		var marker: Marker3D = (
			_root.get_node_or_null("CustomerNavConfig/BrowseWaypoint%02d" % i)
			as Marker3D
		)
		assert_not_null(
			marker,
			"CustomerNavConfig/BrowseWaypoint%02d must exist" % i,
		)
		if marker == null:
			continue
		if marker.global_position.x < 0.0:
			any_left = true
		if marker.global_position.x > 0.0:
			any_right = true
	assert_true(
		any_left,
		"At least one BrowseWaypoint must visit the left (testing-zone) half"
	)
	assert_true(
		any_right,
		"At least one BrowseWaypoint must visit the right (shelf/console) half"
	)


# ── NavZone snap targets: ZoneRegister must follow the new register ─────────

func test_nav_zone_register_follows_new_register_position() -> void:
	var zone: Area3D = (
		_root.get_node_or_null("NavZones/ZoneRegister") as Area3D
	)
	assert_not_null(zone, "NavZones/ZoneRegister must exist")
	if zone == null:
		return
	var checkout: Node3D = _root.get_node_or_null("Checkout") as Node3D
	assert_not_null(checkout, "Checkout must exist")
	if checkout == null:
		return
	# Snap target should land within ~1.5 m of the register fixture so Shift+4
	# frames the counter rather than the old left-side coordinate.
	var lateral_offset: float = absf(
		zone.global_position.x - checkout.global_position.x
	)
	assert_lte(
		lateral_offset, 1.5,
		(
			"ZoneRegister x=%.2f must sit within 1.5 m of Checkout x=%.2f so "
			+ "Shift+4 snaps the camera onto the register"
		) % [zone.global_position.x, checkout.global_position.x],
	)
