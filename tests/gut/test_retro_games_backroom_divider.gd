## Verifies the back-left mid-floor area of retro_games.tscn does not contain
## a free-floating decorative partition. The partition formerly placed at
## (-3.5, 1.2, -1.5) read as floating block clutter from the 52° overhead
## camera. If a partition node is reintroduced, it must sit on the floor and
## be flush against a wall so it reads as a wall element rather than mid-room
## debug geometry.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const PARTITION_NODE: String = "BackroomDivider"

# Room walls live at x = ±8.05 (left/right) and z = -10.05 (back). A node is
# considered "flush" when its origin sits within ~0.6 m of a wall plane.
const WALL_PROXIMITY: float = 0.6
const LEFT_WALL_X: float = -8.05
const RIGHT_WALL_X: float = 8.05
const BACK_WALL_Z: float = -10.05
const FLOOR_TOLERANCE: float = 0.1

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


func test_backroom_divider_is_absent_or_flush_against_wall() -> void:
	var divider: Node3D = _root.get_node_or_null(PARTITION_NODE) as Node3D
	if divider == null:
		# Removal is an accepted fix — the back-left area now reads as open
		# store space.
		assert_true(true, "%s removed; nothing further to verify" % PARTITION_NODE)
		return

	var pos: Vector3 = divider.global_position
	var near_left: bool = absf(pos.x - LEFT_WALL_X) <= WALL_PROXIMITY
	var near_right: bool = absf(pos.x - RIGHT_WALL_X) <= WALL_PROXIMITY
	var near_back: bool = absf(pos.z - BACK_WALL_Z) <= WALL_PROXIMITY
	assert_true(
		near_left or near_right or near_back,
		(
			"%s at (%.2f, %.2f, %.2f) must be flush against a wall "
			+ "(within %.2f m of x=%.2f, x=%.2f, or z=%.2f) so it does not "
			+ "read as a floating mid-room partition"
		) % [
			PARTITION_NODE,
			pos.x, pos.y, pos.z,
			WALL_PROXIMITY, LEFT_WALL_X, RIGHT_WALL_X, BACK_WALL_Z,
		],
	)

	var mesh: MeshInstance3D = divider as MeshInstance3D
	if mesh and mesh.mesh is BoxMesh:
		var box: BoxMesh = mesh.mesh as BoxMesh
		var bottom_y: float = pos.y - box.size.y * 0.5
		assert_lte(
			bottom_y,
			FLOOR_TOLERANCE,
			(
				"%s mesh bottom at y=%.3f must rest on or near the floor "
				+ "(y <= %.2f) so the partition does not visually float"
			) % [PARTITION_NODE, bottom_y, FLOOR_TOLERANCE],
		)
