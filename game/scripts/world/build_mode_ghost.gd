## Ghost preview mesh that tracks cursor position and shows placement validity.
class_name BuildModeGhost
extends Node3D

const VALID_COLOR: Color = Color(0.2, 0.8, 0.2, 0.4)
const INVALID_COLOR: Color = Color(0.8, 0.2, 0.2, 0.4)
const Y_OFFSET: float = 0.03

const PULSE_SPEED: float = 4.0
const PULSE_MIN_ALPHA: float = 0.2
const PULSE_MAX_ALPHA: float = 0.5

const SHAKE_OSCILLATIONS: int = 3
const SHAKE_DURATION: float = 0.2
const SHAKE_MAGNITUDE: float = 0.03

var is_valid: bool = false

var _meshes: Array[MeshInstance3D] = []
var _material: StandardMaterial3D = null
var _pulse_time: float = 0.0
var _is_pulsing: bool = false
var _grid: BuildModeGrid = null


func _ready() -> void:
	visible = false
	_material = _create_material(VALID_COLOR)


## Stores grid reference for coordinate conversion.
func setup(grid: BuildModeGrid) -> void:
	_grid = grid


func _process(delta: float) -> void:
	if not _is_pulsing:
		return
	_pulse_time += delta
	var alpha: float = lerp(
		PULSE_MIN_ALPHA, PULSE_MAX_ALPHA,
		(sin(_pulse_time * PULSE_SPEED * TAU) + 1.0) * 0.5
	)
	_material.albedo_color.a = alpha


## Shows ghost at the given cells with validity coloring.
func show_at_cells(
	cells: Array[Vector2i], valid: bool
) -> void:
	is_valid = valid
	_update_color(valid)
	_rebuild_meshes(cells)
	visible = true


## Hides the ghost and stops pulsing.
func hide_ghost() -> void:
	visible = false
	_is_pulsing = false
	_pulse_time = 0.0


## Plays horizontal shake animation on invalid placement.
func play_shake() -> void:
	if not visible:
		return

	var original_pos: Vector3 = position
	var tween: Tween = create_tween()
	var step_time: float = SHAKE_DURATION / (SHAKE_OSCILLATIONS * 2.0)

	for i: int in range(SHAKE_OSCILLATIONS):
		var direction: float = 1.0 if i % 2 == 0 else -1.0
		var offset: Vector3 = Vector3(
			SHAKE_MAGNITUDE * direction, 0.0, 0.0
		)
		tween.tween_property(
			self, "position",
			original_pos + offset,
			step_time
		).set_trans(Tween.TRANS_SINE)
		tween.tween_property(
			self, "position",
			original_pos - offset,
			step_time
		).set_trans(Tween.TRANS_SINE)

	tween.tween_property(
		self, "position", original_pos, step_time * 0.5
	).set_trans(Tween.TRANS_SINE)


func _update_color(valid: bool) -> void:
	if valid:
		_material.albedo_color = VALID_COLOR
		_is_pulsing = false
		_pulse_time = 0.0
	else:
		_material.albedo_color = INVALID_COLOR
		_is_pulsing = true


func _rebuild_meshes(cells: Array[Vector2i]) -> void:
	for mesh: MeshInstance3D in _meshes:
		if is_instance_valid(mesh):
			mesh.queue_free()
	_meshes.clear()

	for cell: Vector2i in cells:
		var inst: MeshInstance3D = _create_cell_quad(cell)
		add_child(inst)
		_meshes.append(inst)


func _create_cell_quad(cell: Vector2i) -> MeshInstance3D:
	var quad: PlaneMesh = PlaneMesh.new()
	quad.size = Vector2(
		BuildModeGrid.CELL_SIZE * 0.95,
		BuildModeGrid.CELL_SIZE * 0.95
	)

	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = quad
	inst.set_surface_override_material(0, _material)
	inst.position = Vector3(
		_grid.grid_origin.x + (cell.x + 0.5) * BuildModeGrid.CELL_SIZE,
		_grid.grid_origin.y + Y_OFFSET,
		_grid.grid_origin.z + (cell.y + 0.5) * BuildModeGrid.CELL_SIZE
	)
	return inst


func _create_material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	return mat
