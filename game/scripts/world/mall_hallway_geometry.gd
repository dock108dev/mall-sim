## Builds the static 3D geometry for the mall hallway environment.
class_name MallHallwayGeometry
extends RefCounted

const HALLWAY_LENGTH: float = 40.0
const HALLWAY_WIDTH: float = 8.0
const HALLWAY_HEIGHT: float = 4.0

static var _floor_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_floor_tile_textured.tres"
)
static var _wall_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_wall_surface_textured.tres"
)
static var _ceiling_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_wall_warm_white.tres"
)
static var _bench_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_wood_medium.tres"
)
static var _planter_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_wood_dark.tres"
)
static var _plant_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_plant_foliage.tres"
)
static var _panel_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_fluorescent_panel.tres"
)


## Builds all hallway geometry and adds it to the parent node.
static func build_all(parent: Node3D) -> void:
	_build_hallway_walls(parent)
	_build_common_area(parent)
	_build_lighting(parent)
	_build_neon_signage(parent)
	HallwayDecorationBuilder.build(
		parent, HALLWAY_WIDTH, HALLWAY_HEIGHT
	)


static func _build_hallway_walls(parent: Node3D) -> void:
	var floor_mat: StandardMaterial3D = _floor_mat
	var wall_mat: StandardMaterial3D = _wall_mat
	var ceiling_mat: StandardMaterial3D = _ceiling_mat
	var half_h: float = HALLWAY_HEIGHT * 0.5
	var half_w: float = HALLWAY_WIDTH * 0.5
	var hw: float = HALLWAY_WIDTH * 0.5

	_add_static_box(parent, "Floor",
		Vector3(HALLWAY_LENGTH, 0.1, HALLWAY_WIDTH),
		Vector3(0.0, -0.05, hw), floor_mat)
	_add_static_box(parent, "Ceiling",
		Vector3(HALLWAY_LENGTH, 0.1, HALLWAY_WIDTH),
		Vector3(0.0, HALLWAY_HEIGHT, hw), ceiling_mat)
	_add_static_box(parent, "BackWall",
		Vector3(HALLWAY_LENGTH, HALLWAY_HEIGHT, 0.2),
		Vector3(0.0, half_h, -0.1), wall_mat)
	_add_static_box(parent, "FrontWall",
		Vector3(HALLWAY_LENGTH, HALLWAY_HEIGHT, 0.2),
		Vector3(0.0, half_h, HALLWAY_WIDTH + 0.1), wall_mat)

	var half_len: float = HALLWAY_LENGTH * 0.5
	_add_static_box(parent, "LeftWall",
		Vector3(0.2, HALLWAY_HEIGHT, HALLWAY_WIDTH),
		Vector3(-half_len - 0.1, half_h, half_w), wall_mat)
	_add_static_box(parent, "RightWall",
		Vector3(0.2, HALLWAY_HEIGHT, HALLWAY_WIDTH),
		Vector3(half_len + 0.1, half_h, half_w), wall_mat)


static func _build_common_area(parent: Node3D) -> void:
	var bench_mat: StandardMaterial3D = _bench_mat
	var planter_mat: StandardMaterial3D = _planter_mat
	var center_z: float = HALLWAY_WIDTH * 0.5

	_add_static_box(parent, "BenchLeft",
		Vector3(2.0, 0.5, 0.6),
		Vector3(-2.5, 0.25, center_z), bench_mat)
	_add_static_box(parent, "BenchRight",
		Vector3(2.0, 0.5, 0.6),
		Vector3(2.5, 0.25, center_z), bench_mat)
	_add_static_box(parent, "Planter",
		Vector3(1.2, 0.8, 1.2),
		Vector3(0.0, 0.4, center_z), planter_mat)

	var plant_mesh := MeshInstance3D.new()
	plant_mesh.name = "PlantFoliage"
	plant_mesh.mesh = SphereMesh.new()
	(plant_mesh.mesh as SphereMesh).radius = 0.5
	(plant_mesh.mesh as SphereMesh).height = 1.0
	plant_mesh.position = Vector3(0.0, 1.2, center_z)
	plant_mesh.set_surface_override_material(0, _plant_mat)
	parent.add_child(plant_mesh)


static func _build_lighting(parent: Node3D) -> void:
	var panel_count: int = 5
	var spacing: float = HALLWAY_LENGTH / float(panel_count)
	var start_x: float = -HALLWAY_LENGTH * 0.5 + spacing * 0.5
	var center_z: float = HALLWAY_WIDTH * 0.5

	for i: int in range(panel_count):
		var x_pos: float = start_x + float(i) * spacing
		_add_light_panel(parent, i, x_pos, center_z, _panel_mat)
		_add_omni_light(parent, i, x_pos, center_z)


static func _add_light_panel(
	parent: Node3D, index: int, x_pos: float,
	z_pos: float, material: StandardMaterial3D
) -> void:
	var panel_mesh := MeshInstance3D.new()
	panel_mesh.name = "LightPanel_%d" % index
	panel_mesh.mesh = BoxMesh.new()
	(panel_mesh.mesh as BoxMesh).size = Vector3(1.5, 0.05, 0.4)
	panel_mesh.position = Vector3(
		x_pos, HALLWAY_HEIGHT - 0.05, z_pos
	)
	panel_mesh.set_surface_override_material(0, material)
	parent.add_child(panel_mesh)


static func _add_omni_light(
	parent: Node3D, index: int, x_pos: float,
	z_pos: float
) -> void:
	var light := OmniLight3D.new()
	light.name = "FluorescentLight_%d" % index
	light.light_color = Color(1.0, 0.94, 0.84)
	light.light_energy = 0.45
	light.omni_range = 4.0
	light.omni_attenuation = 2.4
	light.shadow_enabled = false
	light.position = Vector3(
		x_pos, HALLWAY_HEIGHT - 0.3, z_pos
	)
	parent.add_child(light)


static func _build_neon_signage(parent: Node3D) -> void:
	var center_z: float = HALLWAY_WIDTH * 0.5
	var sign_colors: Array[Color] = [
		Color(1.0, 0.2, 0.4),
		Color(0.2, 0.6, 1.0),
		Color(0.4, 1.0, 0.3),
		Color(1.0, 0.5, 0.1),
		Color(0.8, 0.2, 1.0),
	]
	var sign_positions: Array[Vector3] = [
		Vector3(-12.0, 3.2, 0.3),
		Vector3(-6.0, 3.2, HALLWAY_WIDTH - 0.3),
		Vector3(0.0, 3.2, 0.3),
		Vector3(6.0, 3.2, HALLWAY_WIDTH - 0.3),
		Vector3(12.0, 3.2, 0.3),
	]
	for i: int in range(sign_positions.size()):
		_add_neon_sign(
			parent, i, sign_positions[i],
			sign_colors[i], center_z
		)


static func _add_neon_sign(
	parent: Node3D, index: int, pos: Vector3,
	color: Color, _center_z: float
) -> void:
	var sign_mat := StandardMaterial3D.new()
	sign_mat.emission_enabled = true
	sign_mat.emission = color
	sign_mat.emission_energy_multiplier = 1.2
	sign_mat.albedo_color = color
	var sign_mesh := MeshInstance3D.new()
	sign_mesh.name = "NeonSign_%d" % index
	sign_mesh.mesh = BoxMesh.new()
	(sign_mesh.mesh as BoxMesh).size = Vector3(1.8, 0.4, 0.05)
	sign_mesh.position = pos
	sign_mesh.set_surface_override_material(0, sign_mat)
	parent.add_child(sign_mesh)
	var glow := OmniLight3D.new()
	glow.name = "NeonGlow_%d" % index
	glow.light_color = color
	glow.light_energy = 0.2
	glow.omni_range = 2.2
	glow.omni_attenuation = 2.0
	glow.position = Vector3(pos.x, pos.y - 0.3, pos.z)
	parent.add_child(glow)


static func _add_static_box(
	parent: Node3D, node_name: String,
	box_size: Vector3, pos: Vector3,
	material: StandardMaterial3D
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = BoxMesh.new()
	(mesh_inst.mesh as BoxMesh).size = box_size
	mesh_inst.set_surface_override_material(0, material)
	body.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	(col.shape as BoxShape3D).size = box_size
	body.add_child(col)

	parent.add_child(body)
	return body
