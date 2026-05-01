## Verifies PlayerController's pivot-collision contract: when keyboard
## movement would push the orbit pivot inside a fixture's StaticBody3D the
## controller must reject the embedded position and fall back to a single-axis
## slide, so the player cannot phase through the GlassCase, Checkout counter,
## CartRacks, ConsoleShelf, AccessoriesBin, or the consolidated testing zone
## (crt_demo_area, which now also covers the co-located testing_station).
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const PROBE_STEP: float = 1.5
# Probed positions sit just inside each fixture's body footprint. The pivot
# starts adjacent and steps toward the body; resolve_pivot_step must refuse
# to land at the embedded coordinate.
const FIXTURE_PROBES: Array[Dictionary] = [
	{"name": "GlassCase", "from": Vector3(0.0, 0.0, 0.0), "into": Vector3(0.0, 0.0, -1.0)},
	{"name": "CartRackLeft", "from": Vector3(-2.0, 0.0, -2.5), "into": Vector3(-2.0, 0.0, -3.2)},
	{"name": "CartRackRight", "from": Vector3(2.0, 0.0, -2.5), "into": Vector3(2.0, 0.0, -3.2)},
	{"name": "Checkout", "from": Vector3(2.5, 0.0, 1.7), "into": Vector3(2.5, 0.0, 2.5)},
	{"name": "ConsoleShelf", "from": Vector3(3.6, 0.0, -1.5), "into": Vector3(4.5, 0.0, -1.5)},
	{"name": "crt_demo_area", "from": Vector3(-3.0, 0.0, -1.5), "into": Vector3(-3.0, 0.0, -2.5)},
	{"name": "AccessoriesBin", "from": Vector3(-4.0, 0.0, 0.5), "into": Vector3(-4.7, 0.0, 0.5)},
]

var _root: Node3D = null
var _controller: Node = null


func before_all() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "Retro Games scene must load")
	if scene:
		_root = scene.instantiate() as Node3D
		add_child(_root)
		_controller = _root.get_node_or_null("PlayerController")


func after_all() -> void:
	if is_instance_valid(_root):
		_root.free()
	_root = null
	_controller = null


func _wait_one_physics_frame() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.physics_frame


func test_open_floor_position_is_not_blocked() -> void:
	assert_not_null(_controller, "PlayerController must be embedded in scene")
	if _controller == null:
		return
	await _wait_one_physics_frame()
	# Far from every fixture: front-center walking aisle.
	var open: Vector3 = Vector3(0.0, 0.0, 1.5)
	var resolved: Vector3 = _controller.call("resolve_pivot_step", open, Vector3.ZERO)
	assert_almost_eq(
		resolved.x, open.x, 0.001,
		"Open-floor pivot must not be displaced by the collision probe"
	)
	assert_almost_eq(
		resolved.z, open.z, 0.001,
		"Open-floor pivot must not be displaced by the collision probe"
	)


func test_pivot_step_into_fixture_is_rejected() -> void:
	assert_not_null(_controller, "PlayerController must be embedded in scene")
	if _controller == null:
		return
	await _wait_one_physics_frame()
	for probe: Dictionary in FIXTURE_PROBES:
		var fixture_name: String = probe["name"]
		var from_pos: Vector3 = probe["from"]
		var into_pos: Vector3 = probe["into"]
		var step: Vector3 = into_pos - from_pos
		var resolved: Vector3 = _controller.call(
			"resolve_pivot_step", from_pos, step
		)
		# Resolved position must NOT land at the embedded coordinate; either
		# stay put or slide on a single axis. Distance from the fixture
		# centre must be greater than the embedded distance.
		var penetration_distance: float = (resolved - into_pos).length()
		assert_gt(
			penetration_distance, 0.05,
			(
				"PlayerController must reject pivot step into %s. Step "
				+ "%s -> %s (Δ=%s) resolved to %s, only %.3f m away from "
				+ "the embedded coordinate."
			) % [
				fixture_name,
				str(from_pos), str(into_pos), str(step),
				str(resolved), penetration_distance,
			],
		)
