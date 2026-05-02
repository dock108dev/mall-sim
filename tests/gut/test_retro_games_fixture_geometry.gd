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
		-8.0,
		"CartRackLeft must be positioned against back wall (z < -8.0)"
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
		-8.0,
		"CartRackRight must be positioned against back wall (z < -8.0)"
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
		5.0,
		"ConsoleShelf must be positioned against right wall (x > 5.0)"
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
	assert_lt(absf(pos.z), 6.0, "Display table must be on the main sales floor (|z| < 6.0)")


# ── Glass material: visible from overhead, not near-transparent ──────────────
#
# The store uses a fixed isometric/orthographic camera at ~52° pitch (see
# PlayerController.pitch_default_deg). Glass alpha below ~0.6 reads as
# near-invisible from that angle, leaving the case as just a floating
# silhouette of slot meshes. The case must still look like glass (alpha < 1.0),
# but be opaque enough to register as a solid display surface.

func test_glass_case_material_is_visible_from_overhead() -> void:
	var case_node: Node3D = _root.get_node_or_null("GlassCase") as Node3D
	assert_not_null(case_node, "GlassCase must exist")
	if not case_node:
		return
	var mesh: MeshInstance3D = case_node.get_node_or_null("CaseMesh") as MeshInstance3D
	assert_not_null(mesh, "GlassCase/CaseMesh must exist")
	if not mesh:
		return
	var mat: StandardMaterial3D = mesh.get_surface_override_material(0) as StandardMaterial3D
	assert_not_null(mat, "GlassCase/CaseMesh must have a StandardMaterial3D override")
	if not mat:
		return
	assert_gte(
		mat.albedo_color.a, 0.6,
		"Glass display alpha must be >= 0.6 so the case reads as a solid surface from the overhead camera"
	)
	assert_lt(
		mat.albedo_color.a, 1.0,
		"Glass display must remain translucent (alpha < 1.0) to read as glass, not painted wood"
	)


# ── Slot heights: items rest on the case top, not floating above ─────────────
#
# CaseMesh is offset by Y=0.425 with BoxMesh height 0.85, so the top surface
# is at local Y=0.85. Slot Y must sit on that top (within a small tolerance)
# so spawned item placeholders rest on the case rather than hovering.

func test_glass_case_slots_rest_on_case_top() -> void:
	var case_node: Node3D = _root.get_node_or_null("GlassCase") as Node3D
	assert_not_null(case_node, "GlassCase must exist")
	if not case_node:
		return
	var case_mesh: MeshInstance3D = case_node.get_node_or_null("CaseMesh") as MeshInstance3D
	assert_not_null(case_mesh, "GlassCase/CaseMesh must exist")
	if not case_mesh or not (case_mesh.mesh is BoxMesh):
		return
	var box: BoxMesh = case_mesh.mesh as BoxMesh
	var case_top_y: float = case_mesh.position.y + box.size.y * 0.5
	for i: int in range(1, 7):
		var slot: Node3D = case_node.get_node_or_null("Slot%d" % i) as Node3D
		assert_not_null(slot, "GlassCase/Slot%d must exist" % i)
		if not slot:
			continue
		assert_almost_eq(
			slot.position.y, case_top_y, 0.05,
			"GlassCase/Slot%d Y (%.3f) must sit on the case top (%.3f) so items don't float"
			% [i, slot.position.y, case_top_y]
		)


# ── Counter: narrow checkout area at front-right, register raised on top ────

func test_checkout_counter_does_not_span_front_of_store() -> void:
	# The counter must read as a checkout pocket on the right side, not a
	# barrier wall spanning the storefront. Width is capped at 2.0 m so the
	# entrance sightline (front opening at x∈[-1.5, 1.5]) stays clear.
	var checkout: Node3D = _root.get_node_or_null("Checkout") as Node3D
	assert_not_null(checkout, "Checkout fixture node must exist")
	if not checkout:
		return
	var mesh: MeshInstance3D = checkout.get_node_or_null("CounterMesh") as MeshInstance3D
	assert_not_null(mesh, "Checkout/CounterMesh must exist")
	if mesh and mesh.mesh is BoxMesh:
		var box: BoxMesh = mesh.mesh as BoxMesh
		assert_lte(
			box.size.x, 2.0,
			"Counter must be at most 2.0 m wide so it reads as a checkout area, not a barrier"
		)
		var counter_left_x: float = checkout.global_position.x - box.size.x * 0.5
		assert_gte(
			counter_left_x, 1.5,
			"Counter left edge x=%.2f must clear the entrance opening (x >= 1.5)"
			% counter_left_x
		)
	assert_gt(
		checkout.global_position.z,
		3.0,
		"Checkout counter must be at the front of the store (z > 3.0)"
	)
	assert_gt(
		checkout.global_position.x, 0.0,
		"Checkout counter must sit on the front-right side of the store (x > 0)"
	)


func test_counter_top_is_visually_distinct_from_counter_body() -> void:
	# A contrasting top trim (lighter / different finish) helps the counter
	# read as a checkout surface rather than a uniform wood block, and gives
	# the register a clear backdrop from the overhead camera.
	var checkout: Node3D = _root.get_node_or_null("Checkout") as Node3D
	if not checkout:
		return
	var body: MeshInstance3D = checkout.get_node_or_null("CounterMesh") as MeshInstance3D
	var top: MeshInstance3D = checkout.get_node_or_null("CounterTop") as MeshInstance3D
	assert_not_null(top, "Checkout/CounterTop trim mesh must exist")
	if not body or not top:
		return
	var body_mat: StandardMaterial3D = (
		body.get_surface_override_material(0) as StandardMaterial3D
	)
	var top_mat: StandardMaterial3D = (
		top.get_surface_override_material(0) as StandardMaterial3D
	)
	assert_not_null(body_mat, "CounterMesh must carry a StandardMaterial3D override")
	assert_not_null(top_mat, "CounterTop must carry a StandardMaterial3D override")
	if body_mat == null or top_mat == null:
		return
	var diff: float = (
		absf(body_mat.albedo_color.r - top_mat.albedo_color.r)
		+ absf(body_mat.albedo_color.g - top_mat.albedo_color.g)
		+ absf(body_mat.albedo_color.b - top_mat.albedo_color.b)
	)
	assert_gt(
		diff, 0.3,
		"Counter top trim must contrast counter body (sum |ΔRGB| > 0.3) so the surface reads as a distinct top, not a single block"
	)


func test_register_is_readable_from_overhead_camera() -> void:
	# The overhead orthographic camera (~52° pitch) needs the register mesh to
	# project a footprint at least as large as a small impulse slot so the
	# checkout point is identifiable without a label.
	var checkout: Node3D = _root.get_node_or_null("Checkout") as Node3D
	if not checkout:
		return
	var register_mesh: MeshInstance3D = (
		checkout.get_node_or_null("Register/RegisterMesh") as MeshInstance3D
	)
	assert_not_null(register_mesh, "Checkout/Register/RegisterMesh must exist")
	if register_mesh == null or not (register_mesh.mesh is BoxMesh):
		return
	var size: Vector3 = (register_mesh.mesh as BoxMesh).size
	assert_gte(
		size.x, 0.5,
		"Register mesh width (x=%.2f) must be >= 0.5 m so it reads from overhead"
		% size.x
	)
	assert_gte(
		size.z, 0.4,
		"Register mesh depth (z=%.2f) must be >= 0.4 m so it reads from overhead"
		% size.z
	)
	assert_gte(
		size.y, 0.35,
		"Register mesh height (y=%.2f) must be >= 0.35 m so the silhouette reads at 52° pitch"
		% size.y
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


# ── Register identity: terminal monitor + glowing screen + checkout sign ─────
#
# A bare box with the same finish as the counter reads as generic chrome from
# the overhead camera. The register has to break that cube silhouette with a
# raised monitor element, carry an emissive screen so it reads as a powered
# terminal even under cool fluorescent key lighting, and label the checkout
# area so the pay point is unmistakable.

func test_register_has_terminal_monitor_silhouette() -> void:
	var checkout: Node3D = _root.get_node_or_null("Checkout") as Node3D
	if not checkout:
		return
	var base_mesh: MeshInstance3D = (
		checkout.get_node_or_null("Register/RegisterMesh") as MeshInstance3D
	)
	var monitor: MeshInstance3D = (
		checkout.get_node_or_null("Register/TerminalMonitor") as MeshInstance3D
	)
	assert_not_null(
		monitor,
		"Checkout/Register/TerminalMonitor must exist so the register reads as a terminal, not a generic box"
	)
	if monitor == null or not (monitor.mesh is BoxMesh):
		return
	var monitor_size: Vector3 = (monitor.mesh as BoxMesh).size
	assert_gte(
		monitor_size.y, 0.20,
		"TerminalMonitor height (y=%.2f) must be >= 0.20 m so the two-tier register silhouette reads at 52° pitch"
		% monitor_size.y
	)
	if base_mesh and base_mesh.mesh is BoxMesh:
		var base_top_y: float = base_mesh.position.y + (base_mesh.mesh as BoxMesh).size.y * 0.5
		var monitor_bottom_y: float = monitor.position.y - monitor_size.y * 0.5
		assert_almost_eq(
			monitor_bottom_y, base_top_y, 0.05,
			"TerminalMonitor must sit on the register base top (monitor bottom %.3f vs base top %.3f)"
			% [monitor_bottom_y, base_top_y]
		)


func test_register_has_glowing_terminal_screen() -> void:
	var checkout: Node3D = _root.get_node_or_null("Checkout") as Node3D
	if not checkout:
		return
	var screen: MeshInstance3D = (
		checkout.get_node_or_null("Register/TerminalScreen") as MeshInstance3D
	)
	assert_not_null(
		screen,
		"Checkout/Register/TerminalScreen must exist for the checkout to read as a powered terminal"
	)
	if screen == null:
		return
	var mat: StandardMaterial3D = screen.get_surface_override_material(0) as StandardMaterial3D
	assert_not_null(mat, "TerminalScreen must carry a StandardMaterial3D override")
	if mat == null:
		return
	assert_true(
		mat.emission_enabled,
		"TerminalScreen material must have emission_enabled so the screen glows under store lighting"
	)


func test_checkout_register_has_overhead_label() -> void:
	var checkout: Node3D = _root.get_node_or_null("Checkout") as Node3D
	if not checkout:
		return
	var sign_label: Label3D = (
		checkout.get_node_or_null("Register/CheckoutSign") as Label3D
	)
	assert_not_null(
		sign_label,
		"Checkout/Register/CheckoutSign Label3D must exist so the pay point is unmistakable from overhead"
	)
	if sign_label == null:
		return
	assert_true(
		sign_label.text.to_upper().contains("CHECKOUT"),
		"CheckoutSign text must contain 'CHECKOUT' (current: '%s')" % sign_label.text
	)
	assert_gt(
		sign_label.position.y, 0.5,
		"CheckoutSign (y=%.2f) must sit above the register so it's visible at 52° pitch"
		% sign_label.position.y
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


# ── Fixture solidity: each fixture body blocks the player ──────────────────
#
# Required fixtures must carry a StaticBody3D on the `store_fixtures` layer
# (named layer 2 in `project.godot` -> bit value 2) with a BoxShape3D whose
# extents approximate the visible mesh. Without this, the player camera
# pivot and any CharacterBody3D visitor pass straight through the fixture
# mesh and the store reads as a "debug plane". The Area3D children (shelf
# slots, register, interactables) live on `Interactable.INTERACTABLE_LAYER`
# — those are verified separately in test_retro_games_scene_issue_006.gd.

const _REQUIRED_COLLIDABLE_FIXTURES: Array[String] = [
	"CartRackLeft",
	"CartRackRight",
	"GlassCase",
	"ConsoleShelf",
	"AccessoriesBin",
	"Checkout",
]


func test_required_fixtures_have_static_body_on_store_fixtures_layer() -> void:
	for fixture_name: String in _REQUIRED_COLLIDABLE_FIXTURES:
		var fixture: Node = _root.get_node_or_null(fixture_name)
		assert_not_null(fixture, "%s must exist" % fixture_name)
		if fixture == null:
			continue
		var body: StaticBody3D = fixture.get_node_or_null("StaticBody3D") as StaticBody3D
		assert_not_null(
			body,
			"%s must have a StaticBody3D child so the player and customers cannot pass through it"
			% fixture_name
		)
		if body == null:
			continue
		assert_eq(
			body.collision_layer, 2,
			"%s/StaticBody3D.collision_layer must equal 2 (store_fixtures layer)"
			% fixture_name
		)


func test_required_fixtures_collision_shape_approximates_mesh_bounds() -> void:
	# Map fixture name → primary visible mesh child name.
	var mesh_child_by_fixture: Dictionary = {
		"CartRackLeft": "RackMesh",
		"CartRackRight": "RackMesh",
		"GlassCase": "CaseMesh",
		"ConsoleShelf": "ShelfMesh",
		"AccessoriesBin": "BinMesh",
		"Checkout": "CounterMesh",
	}
	for fixture_name: String in _REQUIRED_COLLIDABLE_FIXTURES:
		var fixture: Node = _root.get_node_or_null(fixture_name)
		if fixture == null:
			continue
		var body: StaticBody3D = fixture.get_node_or_null("StaticBody3D") as StaticBody3D
		if body == null:
			continue
		var coll: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		assert_not_null(coll, "%s/StaticBody3D must have a CollisionShape3D child" % fixture_name)
		if coll == null or not (coll.shape is BoxShape3D):
			assert_true(
				coll != null and coll.shape is BoxShape3D,
				"%s collision shape must be BoxShape3D" % fixture_name
			)
			continue
		var box_size: Vector3 = (coll.shape as BoxShape3D).size
		var mesh_child_name: String = mesh_child_by_fixture[fixture_name]
		var mesh: MeshInstance3D = fixture.get_node_or_null(mesh_child_name) as MeshInstance3D
		if mesh == null or not (mesh.mesh is BoxMesh):
			continue
		var mesh_size: Vector3 = (mesh.mesh as BoxMesh).size
		# Collision must approximate mesh bounds: no axis can be more than 25% over
		# the mesh extent (no large empty collision volumes), and no axis can be
		# under 50% of the mesh extent (otherwise gaps appear at the silhouette).
		for axis: int in range(3):
			assert_lte(
				box_size[axis], mesh_size[axis] * 1.25,
				"%s collision %s-axis (%.3f) must not exceed mesh extent (%.3f) by >25%%"
				% [fixture_name, ["x", "y", "z"][axis], box_size[axis], mesh_size[axis]]
			)
			assert_gte(
				box_size[axis], mesh_size[axis] * 0.5,
				"%s collision %s-axis (%.3f) must cover at least 50%% of mesh extent (%.3f)"
				% [fixture_name, ["x", "y", "z"][axis], box_size[axis], mesh_size[axis]]
			)


func test_shelf_slot_areas_remain_on_interactable_layer() -> void:
	# Adding fixture-body collision must not steal the interactable_triggers
	# bit from the Interactable / shelf slot Area3D children — they must
	# continue to register hover/click via the InteractionRay raycast.
	var slots: Array[Node] = _root.get_tree().get_nodes_in_group("shelf_slot")
	assert_gt(
		slots.size(), 0,
		"Scene must have at least one shelf slot to verify interactable layer"
	)
	for slot: Node in slots:
		var area: Area3D = slot.get_node_or_null("InteractionArea") as Area3D
		assert_not_null(area, "%s must retain its InteractionArea child" % slot.name)
		if area:
			assert_eq(
				area.collision_layer, Interactable.INTERACTABLE_LAYER,
				"%s/InteractionArea must remain on Interactable.INTERACTABLE_LAYER"
				% slot.name
			)
