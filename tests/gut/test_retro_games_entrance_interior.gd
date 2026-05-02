## Verifies the retro_games scene exposes an interior-side entrance
## indicator (`EntranceInterior`) at the root level. Storefront geometry
## ships hidden so the camera does not look through the rear of the door
## frame; the interior threshold strip is what tells the player where the
## entrance/exit gap is from inside the store.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"

# Front wall segments sit at z=10.05 with width 6.55, leaving a ~3 m gap
# from x≈-1.5 to x≈+1.5. Interior threshold should be inside the store
# (positive z but well clear of the wall plane) and within the gap
# horizontally.
const ENTRANCE_GAP_HALF_WIDTH: float = 1.5
const ENTRANCE_Z_MIN: float = 8.5
const ENTRANCE_Z_MAX: float = 10.0
const FLOOR_TOP_Y: float = 0.05

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


func _aabb_in_world(mesh_inst: MeshInstance3D) -> AABB:
	var local: AABB = mesh_inst.mesh.get_aabb()
	return mesh_inst.global_transform * local


func test_entrance_interior_exists_at_root() -> void:
	var entrance: Node3D = _root.get_node_or_null("EntranceInterior") as Node3D
	assert_not_null(
		entrance,
		"EntranceInterior must be a direct child of the retro_games root "
		+ "(sibling of Storefront, not a child of it)"
	)


func test_entrance_interior_is_visible() -> void:
	var entrance: Node3D = _root.get_node_or_null("EntranceInterior") as Node3D
	assert_not_null(entrance)
	if entrance == null:
		return
	assert_true(
		entrance.is_visible_in_tree(),
		"EntranceInterior must render during interior gameplay so the "
		+ "player can see the entrance gap from the overhead camera"
	)


func test_entrance_interior_not_under_storefront() -> void:
	var storefront: Node3D = _root.get_node_or_null("Storefront") as Node3D
	assert_not_null(storefront)
	if storefront == null:
		return
	assert_null(
		storefront.get_node_or_null("EntranceInterior"),
		"EntranceInterior must NOT be parented under Storefront — Storefront "
		+ "ships hidden, which would suppress the interior indicator"
	)


func test_entrance_interior_has_distinct_floor_strip() -> void:
	var entrance: Node3D = _root.get_node_or_null("EntranceInterior") as Node3D
	assert_not_null(entrance)
	if entrance == null:
		return

	var floor_inst: MeshInstance3D = (
		_root.get_node_or_null("Floor/MeshInstance3D") as MeshInstance3D
	)
	assert_not_null(floor_inst, "Floor/MeshInstance3D must exist")
	var floor_mat: Material = (
		floor_inst.get_surface_override_material(0) if floor_inst else null
	)

	var found_strip: bool = false
	for child: Node in entrance.get_children():
		if not (child is MeshInstance3D):
			continue
		var mesh_inst: MeshInstance3D = child as MeshInstance3D
		if mesh_inst.mesh == null:
			continue
		var strip_mat: Material = mesh_inst.get_surface_override_material(0)
		assert_not_null(
			strip_mat,
			"%s must declare a surface material override so it reads "
			+ "distinctly from the floor" % mesh_inst.name
		)
		if floor_mat != null:
			assert_ne(
				strip_mat,
				floor_mat,
				"EntranceInterior strip material must differ from the "
				+ "Floor material so the threshold is visually distinct"
			)
		var aabb: AABB = _aabb_in_world(mesh_inst)
		var center: Vector3 = aabb.position + aabb.size * 0.5
		assert_almost_eq(
			center.x,
			0.0,
			ENTRANCE_GAP_HALF_WIDTH,
			"%s must sit horizontally within the entrance gap" % mesh_inst.name
		)
		assert_true(
			center.z >= ENTRANCE_Z_MIN and center.z <= ENTRANCE_Z_MAX,
			(
				"%s must sit between z=%.2f and z=%.2f to mark the "
				+ "entrance area"
			) % [mesh_inst.name, ENTRANCE_Z_MIN, ENTRANCE_Z_MAX]
		)
		assert_true(
			aabb.position.x > -ENTRANCE_GAP_HALF_WIDTH
				and aabb.end.x < ENTRANCE_GAP_HALF_WIDTH,
			"%s must not overlap the front wall segments at x=±1.0"
				% mesh_inst.name
		)
		assert_true(
			aabb.position.y >= FLOOR_TOP_Y - 0.001,
			"%s must sit at or above the floor top (y=%.2f) to avoid "
			+ "z-fighting" % [mesh_inst.name, FLOOR_TOP_Y]
		)
		assert_true(
			aabb.size.y <= 0.15,
			"%s must stay low-profile (<=15 cm tall) so it does not "
			+ "occlude the walking path" % mesh_inst.name
		)
		found_strip = true

	assert_true(
		found_strip,
		"EntranceInterior must contain at least one MeshInstance3D acting "
		+ "as the floor threshold strip"
	)


func test_storefront_remains_hidden() -> void:
	# Safety net: adding EntranceInterior must not flip Storefront visibility.
	var storefront: Node3D = _root.get_node_or_null("Storefront") as Node3D
	assert_not_null(storefront)
	if storefront == null:
		return
	assert_false(
		storefront.visible,
		"Storefront must remain visible=false; the new interior strip "
		+ "is what marks the entrance from inside the store"
	)
