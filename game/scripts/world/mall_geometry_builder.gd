## Builds the 3D geometry for the mall hallway environment.
class_name MallGeometryBuilder
extends RefCounted

static var _floor_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_hallway_floor.tres"
)
static var _wall_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_hallway_wall.tres"
)
static var _ceiling_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_ceiling_warm.tres"
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

var _parent: Node3D
var _length: float
var _width: float
var _height: float


func _init(
	parent: Node3D, length: float,
	width: float, height: float
) -> void:
	_parent = parent
	_length = length
	_width = width
	_height = height


## Builds all hallway walls, floor, and ceiling.
func build_hallway() -> void:
	var half_h: float = _height * 0.5
	var half_w: float = _width * 0.5

	_build_floor_and_ceiling(_floor_mat, _ceiling_mat)
	_build_long_walls(_wall_mat, half_h)
	_build_end_walls(_wall_mat, half_h, half_w)


## Builds the common area with benches and planter.
func build_common_area() -> void:
	var center_z: float = _width * 0.5

	_add_box("BenchLeft", Vector3(2.0, 0.5, 0.6),
		Vector3(-2.5, 0.25, center_z), _bench_mat)
	_add_box("BenchRight", Vector3(2.0, 0.5, 0.6),
		Vector3(2.5, 0.25, center_z), _bench_mat)
	_add_box("Planter", Vector3(1.2, 0.8, 1.2),
		Vector3(0.0, 0.4, center_z), _planter_mat)

	_add_plant_foliage(center_z, _plant_mat)


## Builds environment and fluorescent ceiling lights.
func build_lighting() -> void:
	_build_environment()
	_build_fluorescent_panels()


func _build_floor_and_ceiling(
	floor_mat: StandardMaterial3D,
	ceiling_mat: StandardMaterial3D
) -> void:
	var hw: float = _width * 0.5
	_add_box("Floor",
		Vector3(_length, 0.1, _width),
		Vector3(0.0, -0.05, hw), floor_mat)
	_add_box("Ceiling",
		Vector3(_length, 0.1, _width),
		Vector3(0.0, _height, hw), ceiling_mat)


func _build_long_walls(
	wall_mat: StandardMaterial3D, half_h: float
) -> void:
	_add_box("BackWall",
		Vector3(_length, _height, 0.2),
		Vector3(0.0, half_h, -0.1), wall_mat)
	_add_box("FrontWall",
		Vector3(_length, _height, 0.2),
		Vector3(0.0, half_h, _width + 0.1), wall_mat)


func _build_end_walls(
	wall_mat: StandardMaterial3D,
	half_h: float,
	half_w: float
) -> void:
	var half_len: float = _length * 0.5
	_add_box("LeftWall",
		Vector3(0.2, _height, _width),
		Vector3(-half_len - 0.1, half_h, half_w), wall_mat)
	_add_box("RightWall",
		Vector3(0.2, _height, _width),
		Vector3(half_len + 0.1, half_h, half_w), wall_mat)


func _add_plant_foliage(
	center_z: float, material: StandardMaterial3D
) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "PlantFoliage"
	mesh.mesh = SphereMesh.new()
	(mesh.mesh as SphereMesh).radius = 0.5
	(mesh.mesh as SphereMesh).height = 1.0
	mesh.position = Vector3(0.0, 1.2, center_z)
	mesh.set_surface_override_material(0, material)
	_parent.add_child(mesh)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.28, 0.25)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.88, 0.72)
	env.ambient_light_energy = 0.4

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	_parent.add_child(world_env)


func _build_fluorescent_panels() -> void:
	var panel_count: int = 7
	var spacing: float = _length / float(panel_count)
	var start_x: float = -_length * 0.5 + spacing * 0.5
	var center_z: float = _width * 0.5

	for i: int in range(panel_count):
		var x_pos: float = start_x + float(i) * spacing
		_add_light_panel(i, x_pos, center_z, _panel_mat)
		_add_omni_light(i, x_pos, center_z)


func _add_light_panel(
	index: int, x_pos: float, z_pos: float,
	material: StandardMaterial3D
) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "LightPanel_%d" % index
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = Vector3(1.5, 0.05, 0.4)
	mesh.position = Vector3(x_pos, _height - 0.05, z_pos)
	mesh.set_surface_override_material(0, material)
	_parent.add_child(mesh)


func _add_omni_light(
	index: int, x_pos: float, z_pos: float
) -> void:
	var light := OmniLight3D.new()
	light.name = "FluorescentLight_%d" % index
	light.light_color = Color(1.0, 0.93, 0.78)
	light.light_energy = 1.2
	light.omni_range = 6.0
	light.omni_attenuation = 1.5
	light.shadow_enabled = index % 2 == 0
	light.position = Vector3(x_pos, _height - 0.3, z_pos)
	_parent.add_child(light)


func _add_box(
	node_name: String, box_size: Vector3,
	pos: Vector3, material: StandardMaterial3D
) -> void:
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

	_parent.add_child(body)
