## Renders green/red cell overlays to indicate valid/invalid fixture placement.
class_name FixturePlacementOverlay
extends Node3D

const VALID_COLOR: Color = Color(0.0, 0.8, 0.0, 0.35)
const INVALID_COLOR: Color = Color(0.9, 0.0, 0.0, 0.35)
const CELL_Y_OFFSET: float = 0.02

var _cell_meshes: Array[MeshInstance3D] = []
var _cell_size: float = 0.5
var _grid_origin: Vector3 = Vector3.ZERO


## Configures the overlay with grid parameters.
func setup(cell_size: float, grid_origin: Vector3) -> void:
	_cell_size = cell_size
	_grid_origin = grid_origin


## Shows colored overlay on the given cells.
func show_cells(
	cells: Array[Vector2i], is_valid: bool
) -> void:
	clear()
	var color: Color = VALID_COLOR if is_valid else INVALID_COLOR
	for cell: Vector2i in cells:
		var mesh_inst: MeshInstance3D = _create_cell_mesh(cell, color)
		add_child(mesh_inst)
		_cell_meshes.append(mesh_inst)


## Removes all overlay meshes.
func clear() -> void:
	for mesh: MeshInstance3D in _cell_meshes:
		if is_instance_valid(mesh):
			mesh.queue_free()
	_cell_meshes.clear()


func _create_cell_mesh(
	cell: Vector2i, color: Color
) -> MeshInstance3D:
	var quad: PlaneMesh = PlaneMesh.new()
	quad.size = Vector2(_cell_size * 0.95, _cell_size * 0.95)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true

	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = quad
	inst.set_surface_override_material(0, mat)
	inst.position = _grid_to_world(cell)
	return inst


func _grid_to_world(cell: Vector2i) -> Vector3:
	return Vector3(
		_grid_origin.x + (cell.x + 0.5) * _cell_size,
		_grid_origin.y + CELL_Y_OFFSET,
		_grid_origin.z + (cell.y + 0.5) * _cell_size
	)
