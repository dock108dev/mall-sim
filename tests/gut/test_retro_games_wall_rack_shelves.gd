## Verifies CartRackLeft/CartRackRight read as open shelving rather than solid
## slabs: shelf boards must protrude beyond the rack body, use a material
## distinct from the rack body, and align with the slot rows so placed items
## visually rest on shelves.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const SLOT_TOP_ROW_Y: float = 1.45
const SLOT_BOTTOM_ROW_Y: float = 1.05
const Y_TOLERANCE: float = 0.02

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


func _shelf_top_y(board: MeshInstance3D) -> float:
	var box: BoxMesh = board.mesh as BoxMesh
	return board.position.y + box.size.y * 0.5


func _check_rack(rack_name: String) -> void:
	var rack: Node3D = _root.get_node_or_null(rack_name) as Node3D
	assert_not_null(rack, "%s must exist" % rack_name)
	if not rack:
		return
	var rack_mesh: MeshInstance3D = (
		rack.get_node_or_null("RackMesh") as MeshInstance3D
	)
	assert_not_null(rack_mesh, "%s/RackMesh must exist" % rack_name)
	if not rack_mesh or not (rack_mesh.mesh is BoxMesh):
		return
	var rack_box: BoxMesh = rack_mesh.mesh as BoxMesh
	var rack_mat: Material = rack_mesh.get_surface_override_material(0)

	var top_row_supported: bool = false
	var bottom_row_supported: bool = false
	var any_protrudes: bool = false
	for child: Node in rack.get_children():
		if not (child is MeshInstance3D):
			continue
		if not String(child.name).begins_with("ShelfBoard"):
			continue
		var board: MeshInstance3D = child as MeshInstance3D
		if not (board.mesh is BoxMesh):
			continue
		var box: BoxMesh = board.mesh as BoxMesh
		var top_y: float = _shelf_top_y(board)
		if absf(top_y - SLOT_TOP_ROW_Y) <= Y_TOLERANCE:
			top_row_supported = true
		if absf(top_y - SLOT_BOTTOM_ROW_Y) <= Y_TOLERANCE:
			bottom_row_supported = true
		if box.size.x > rack_box.size.x or box.size.z > rack_box.size.z:
			any_protrudes = true
		var shelf_mat: Material = board.get_surface_override_material(0)
		assert_ne(
			shelf_mat,
			rack_mat,
			(
				"%s/%s shelf material must differ from rack body material so "
				+ "shelves are visually distinguishable"
			) % [rack_name, child.name],
		)

	assert_true(
		top_row_supported,
		(
			"%s must have a shelf whose top surface meets the top slot row "
			+ "Y=%.2f so placed items appear seated"
		) % [rack_name, SLOT_TOP_ROW_Y],
	)
	assert_true(
		bottom_row_supported,
		(
			"%s must have a shelf whose top surface meets the bottom slot row "
			+ "Y=%.2f so placed items appear seated"
		) % [rack_name, SLOT_BOTTOM_ROW_Y],
	)
	assert_true(
		any_protrudes,
		(
			"%s shelves must protrude beyond the rack body on at least one "
			+ "axis so they read as shelves, not painted lines on a slab"
		) % rack_name,
	)


func test_cart_rack_left_shelves_support_slot_rows() -> void:
	_check_rack("CartRackLeft")


func test_cart_rack_right_shelves_support_slot_rows() -> void:
	_check_rack("CartRackRight")
