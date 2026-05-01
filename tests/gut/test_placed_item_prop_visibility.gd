## Verifies placed item props (cartridges, consoles, glass-case items) are
## visible from the fixed isometric/orthographic store camera at pitch=52°,
## ortho_size_default=10. Slots must sit outside fixture body silhouettes so
## spawned props are not occluded by the rack/shelf body, the Label3D must be
## large enough to read at default zoom, and the cartridge placeholder must
## be scaled enough to register at overhead distance.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const CARTRIDGE_PROP_PATH: String = (
	"res://game/assets/models/props/placeholder_prop_game_cartridge.tscn"
)
const ROOM_X_MIN: float = -4.95
const ROOM_X_MAX: float = 4.95
const Z_FRONT_TOLERANCE: float = 0.01
const MIN_LABEL_FONT_SIZE: int = 36
const MIN_LABEL_PIXEL_SIZE: float = 0.0045
const MIN_CARTRIDGE_SCALE: float = 1.25

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


func _body_front_z(fixture: Node3D, mesh_child_name: String) -> float:
	var mesh: MeshInstance3D = fixture.get_node_or_null(mesh_child_name) as MeshInstance3D
	if mesh == null or not (mesh.mesh is BoxMesh):
		return 0.0
	var box: BoxMesh = mesh.mesh as BoxMesh
	return mesh.position.z + box.size.z * 0.5


func _check_slots_in_front_of_body(
	fixture_name: String, mesh_child_name: String, slot_count: int
) -> void:
	var fixture: Node3D = _root.get_node_or_null(fixture_name) as Node3D
	assert_not_null(fixture, "%s must exist" % fixture_name)
	if fixture == null:
		return
	var front_z: float = _body_front_z(fixture, mesh_child_name)
	for i: int in range(1, slot_count + 1):
		var slot: Node3D = fixture.get_node_or_null("Slot%d" % i) as Node3D
		assert_not_null(slot, "%s/Slot%d must exist" % [fixture_name, i])
		if slot == null:
			continue
		assert_gt(
			slot.position.z,
			front_z - Z_FRONT_TOLERANCE,
			(
				"%s/Slot%d Z (%.3f) must sit at or in front of the body's front "
				+ "face (%.3f) so spawned props are not occluded by the body mesh"
			) % [fixture_name, i, slot.position.z, front_z],
		)


func _check_slots_inside_room(fixture_name: String, slot_count: int) -> void:
	var fixture: Node3D = _root.get_node_or_null(fixture_name) as Node3D
	if fixture == null:
		return
	for i: int in range(1, slot_count + 1):
		var slot: Node3D = fixture.get_node_or_null("Slot%d" % i) as Node3D
		if slot == null:
			continue
		var world_x: float = slot.global_position.x
		assert_between(
			world_x,
			ROOM_X_MIN,
			ROOM_X_MAX,
			(
				"%s/Slot%d world X (%.3f) must lie inside the playable room "
				+ "(%.2f..%.2f) so spawned props are not embedded in a wall"
			) % [fixture_name, i, world_x, ROOM_X_MIN, ROOM_X_MAX],
		)


# ── CartRack: cartridge props must not be embedded in the rack body ──────────

func test_cart_rack_left_slots_sit_in_front_of_rack_body() -> void:
	_check_slots_in_front_of_body("CartRackLeft", "RackMesh", 10)


func test_cart_rack_right_slots_sit_in_front_of_rack_body() -> void:
	_check_slots_in_front_of_body("CartRackRight", "RackMesh", 10)


# ── ConsoleShelf: console props must sit in front of the shelf body and
#    not project beyond the right side wall.

func test_console_shelf_slots_sit_in_front_of_shelf_body() -> void:
	_check_slots_in_front_of_body("ConsoleShelf", "ShelfMesh", 4)


func test_console_shelf_slots_stay_inside_room() -> void:
	_check_slots_inside_room("ConsoleShelf", 4)


# ── GlassCase: items spawn at slot Y, must sit at or above the case top so
#    placed items read as displayed on the case rather than buried inside.

func test_glass_case_slots_sit_at_or_above_case_top() -> void:
	var case_node: Node3D = _root.get_node_or_null("GlassCase") as Node3D
	assert_not_null(case_node, "GlassCase must exist")
	if case_node == null:
		return
	var case_mesh: MeshInstance3D = (
		case_node.get_node_or_null("CaseMesh") as MeshInstance3D
	)
	assert_not_null(case_mesh, "GlassCase/CaseMesh must exist")
	if case_mesh == null or not (case_mesh.mesh is BoxMesh):
		return
	var box: BoxMesh = case_mesh.mesh as BoxMesh
	var case_top_y: float = case_mesh.position.y + box.size.y * 0.5
	for i: int in range(1, 7):
		var slot: Node3D = case_node.get_node_or_null("Slot%d" % i) as Node3D
		assert_not_null(slot, "GlassCase/Slot%d must exist" % i)
		if slot == null:
			continue
		assert_gte(
			slot.position.y,
			case_top_y - 0.01,
			(
				"GlassCase/Slot%d Y (%.3f) must sit at or above the case top "
				+ "(%.3f) so placed items appear on top of the glass surface"
			) % [i, slot.position.y, case_top_y],
		)


# ── Cartridge prop: scaled enough to register from the overhead camera ──────

func test_cartridge_prop_has_visibility_scale() -> void:
	var scene: PackedScene = load(CARTRIDGE_PROP_PATH)
	assert_not_null(scene, "Cartridge prop scene must load")
	if scene == null:
		return
	var inst: Node3D = scene.instantiate() as Node3D
	add_child_autofree(inst)
	var cartridge_mesh: Node3D = inst.get_node_or_null("CartridgeMesh") as Node3D
	assert_not_null(cartridge_mesh, "CartridgeMesh child must exist")
	if cartridge_mesh == null:
		return
	var scale_x: float = cartridge_mesh.scale.x
	assert_gte(
		scale_x,
		MIN_CARTRIDGE_SCALE,
		(
			"CartridgeMesh scale (%.2f) must be at least %.2f so the prop "
			+ "registers as a distinct object from the overhead camera"
		) % [scale_x, MIN_CARTRIDGE_SCALE],
	)


# ── Shelf-slot info label: large enough to read at default zoom ──────────────

func test_shelf_slot_info_label_is_legible() -> void:
	var slot := ShelfSlot.new()
	add_child_autofree(slot)
	slot.set_display_data("Sample Cart", "good", 24.0)
	var label: Label3D = null
	for child: Node in slot.get_children():
		if child is Label3D:
			label = child as Label3D
			break
	assert_not_null(label, "set_display_data must create a Label3D child")
	if label == null:
		return
	assert_gte(
		label.font_size,
		MIN_LABEL_FONT_SIZE,
		(
			"Shelf-slot Label3D font_size (%d) must be >= %d to read from the "
			+ "fixed overhead camera at default zoom"
		) % [label.font_size, MIN_LABEL_FONT_SIZE],
	)
	assert_gte(
		label.pixel_size,
		MIN_LABEL_PIXEL_SIZE,
		(
			"Shelf-slot Label3D pixel_size (%.4f) must be >= %.4f so glyphs "
			+ "do not collapse to a sub-pixel smudge from overhead distance"
		) % [label.pixel_size, MIN_LABEL_PIXEL_SIZE],
	)
	assert_eq(
		label.billboard,
		BaseMaterial3D.BILLBOARD_ENABLED,
		"Shelf-slot Label3D must billboard so it always faces the camera",
	)
