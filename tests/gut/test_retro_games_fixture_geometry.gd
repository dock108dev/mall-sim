## Verifies retro_games.tscn fixture geometry meets visual recognizability criteria.
## Each fixture must be identifiable by shape and placement without labels.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"

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


# ── Back-wall shelves: tall, against back wall ────────────────────────────────

func test_cart_rack_left_is_tall_and_against_back_wall() -> void:
	var rack: Node3D = _root.get_node_or_null("CartRackLeft") as Node3D
	assert_not_null(rack, "CartRackLeft must exist")
	if not rack:
		return
	var mesh: MeshInstance3D = rack.get_node_or_null("RackMesh") as MeshInstance3D
	assert_not_null(mesh, "CartRackLeft/RackMesh must exist")
	if mesh and mesh.mesh is BoxMesh:
		var box: BoxMesh = mesh.mesh as BoxMesh
		assert_gt(box.size.y, 2.0, "CartRackLeft must be at least 2.0 m tall")
		assert_gt(box.size.y, box.size.z, "CartRackLeft height must exceed depth (shelf silhouette)")
	assert_lt(
		rack.global_position.z,
		-2.0,
		"CartRackLeft must be positioned against back wall (z < -2.0)"
	)


func test_cart_rack_right_is_tall_and_against_back_wall() -> void:
	var rack: Node3D = _root.get_node_or_null("CartRackRight") as Node3D
	assert_not_null(rack, "CartRackRight must exist")
	if not rack:
		return
	var mesh: MeshInstance3D = rack.get_node_or_null("RackMesh") as MeshInstance3D
	assert_not_null(mesh, "CartRackRight/RackMesh must exist")
	if mesh and mesh.mesh is BoxMesh:
		var box: BoxMesh = mesh.mesh as BoxMesh
		assert_gt(box.size.y, 2.0, "CartRackRight must be at least 2.0 m tall")
		assert_gt(box.size.y, box.size.z, "CartRackRight height must exceed depth (shelf silhouette)")
	assert_lt(
		rack.global_position.z,
		-2.0,
		"CartRackRight must be positioned against back wall (z < -2.0)"
	)


func test_console_shelf_is_tall_and_against_side_wall() -> void:
	var shelf: Node3D = _root.get_node_or_null("ConsoleShelf") as Node3D
	assert_not_null(shelf, "ConsoleShelf must exist")
	if not shelf:
		return
	var mesh: MeshInstance3D = shelf.get_node_or_null("ShelfMesh") as MeshInstance3D
	assert_not_null(mesh, "ConsoleShelf/ShelfMesh must exist")
	if mesh and mesh.mesh is BoxMesh:
		var box: BoxMesh = mesh.mesh as BoxMesh
		assert_gt(box.size.y, 2.0, "ConsoleShelf must be at least 2.0 m tall")
		assert_gt(box.size.y, box.size.x, "ConsoleShelf height must exceed width (narrow tower)")
	assert_gt(
		shelf.global_position.x,
		2.5,
		"ConsoleShelf must be positioned against right wall (x > 2.5)"
	)


# ── Shelf tiers: horizontal boards create visible levels ─────────────────────

func test_cart_rack_left_has_shelf_board_tiers() -> void:
	var rack: Node3D = _root.get_node_or_null("CartRackLeft") as Node3D
	assert_not_null(rack, "CartRackLeft must exist")
	if not rack:
		return
	var board_count: int = 0
	for child: Node in rack.get_children():
		if child is MeshInstance3D and child.name.begins_with("ShelfBoard"):
			board_count += 1
	assert_gte(
		board_count,
		2,
		"CartRackLeft must have at least 2 ShelfBoard children to read as shelving, not a box"
	)


func test_cart_rack_right_has_shelf_board_tiers() -> void:
	var rack: Node3D = _root.get_node_or_null("CartRackRight") as Node3D
	assert_not_null(rack, "CartRackRight must exist")
	if not rack:
		return
	var board_count: int = 0
	for child: Node in rack.get_children():
		if child is MeshInstance3D and child.name.begins_with("ShelfBoard"):
			board_count += 1
	assert_gte(
		board_count,
		2,
		"CartRackRight must have at least 2 ShelfBoard children to read as shelving, not a box"
	)


func test_console_shelf_has_shelf_board_tiers() -> void:
	var shelf: Node3D = _root.get_node_or_null("ConsoleShelf") as Node3D
	assert_not_null(shelf, "ConsoleShelf must exist")
	if not shelf:
		return
	var board_count: int = 0
	for child: Node in shelf.get_children():
		if child is MeshInstance3D and child.name.begins_with("ShelfBoard"):
			board_count += 1
	assert_gte(
		board_count,
		2,
		"ConsoleShelf must have at least 2 ShelfBoard children to read as shelving, not a box"
	)


# ── Display table: waist-height, wide flat top, center floor ─────────────────

func test_glass_case_is_waist_height_and_wider_than_tall() -> void:
	var case_node: Node3D = _root.get_node_or_null("GlassCase") as Node3D
	assert_not_null(case_node, "GlassCase display table must exist")
	if not case_node:
		return
	var mesh: MeshInstance3D = case_node.get_node_or_null("CaseMesh") as MeshInstance3D
	assert_not_null(mesh, "GlassCase/CaseMesh must exist")
	if mesh and mesh.mesh is BoxMesh:
		var box: BoxMesh = mesh.mesh as BoxMesh
		assert_gt(box.size.x, box.size.y, "Display table must be wider than tall (flat surface)")
		assert_lt(box.size.y, 1.1, "Display table height must be under 1.1 m (waist height)")
		assert_gt(box.size.y, 0.5, "Display table must be raised off the floor")


func test_glass_case_is_in_center_floor_area() -> void:
	var case_node: Node3D = _root.get_node_or_null("GlassCase") as Node3D
	assert_not_null(case_node, "GlassCase must exist")
	if not case_node:
		return
	var pos: Vector3 = case_node.global_position
	assert_lt(absf(pos.x), 1.5, "Display table must be near store center (|x| < 1.5)")
	assert_lt(absf(pos.z), 2.0, "Display table must be on the main sales floor (|z| < 2.0)")


# ── Counter: wide across front, register raised on top ───────────────────────

func test_checkout_counter_spans_front_of_store() -> void:
	var checkout: Node3D = _root.get_node_or_null("Checkout") as Node3D
	assert_not_null(checkout, "Checkout fixture node must exist")
	if not checkout:
		return
	var mesh: MeshInstance3D = checkout.get_node_or_null("CounterMesh") as MeshInstance3D
	assert_not_null(mesh, "Checkout/CounterMesh must exist")
	if mesh and mesh.mesh is BoxMesh:
		var box: BoxMesh = mesh.mesh as BoxMesh
		assert_gt(box.size.x, 3.0, "Counter must be wide enough to span the front (> 3.0 m)")
	assert_gt(
		checkout.global_position.z,
		1.0,
		"Checkout counter must be at the front of the store (z > 1.0)"
	)


func test_register_sits_at_counter_top() -> void:
	var checkout: Node3D = _root.get_node_or_null("Checkout") as Node3D
	assert_not_null(checkout, "Checkout must exist")
	if not checkout:
		return
	var register: Node3D = checkout.get_node_or_null("Register") as Node3D
	assert_not_null(register, "Checkout/Register must exist")
	var counter_mesh: MeshInstance3D = checkout.get_node_or_null("CounterMesh") as MeshInstance3D
	assert_not_null(counter_mesh, "Checkout/CounterMesh must exist")
	if not register or not counter_mesh:
		return
	var counter_top_y: float = counter_mesh.global_position.y
	if counter_mesh.mesh is BoxMesh:
		counter_top_y += (counter_mesh.mesh as BoxMesh).size.y * 0.5
	assert_gte(
		register.global_position.y,
		counter_top_y - 0.05,
		"Register must sit at or above the counter top surface"
	)


# ── Open floor: unobstructed gap between counter and display table ────────────

func test_open_floor_gap_between_counter_and_display_table() -> void:
	var checkout: Node3D = _root.get_node_or_null("Checkout") as Node3D
	var glass_case: Node3D = _root.get_node_or_null("GlassCase") as Node3D
	if not checkout or not glass_case:
		return
	var counter_back_z: float = checkout.global_position.z
	var counter_mesh: MeshInstance3D = checkout.get_node_or_null("CounterMesh") as MeshInstance3D
	if counter_mesh and counter_mesh.mesh is BoxMesh:
		counter_back_z -= (counter_mesh.mesh as BoxMesh).size.z * 0.5
	var table_front_z: float = glass_case.global_position.z
	var case_mesh: MeshInstance3D = glass_case.get_node_or_null("CaseMesh") as MeshInstance3D
	if case_mesh and case_mesh.mesh is BoxMesh:
		table_front_z += (case_mesh.mesh as BoxMesh).size.z * 0.5
	assert_gt(
		counter_back_z - table_front_z,
		1.0,
		"Customer path gap between counter and display table must be > 1.0 m"
	)
