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
const SCALE_PUNCH_PEAK: float = 1.08
const SCALE_PUNCH_DURATION: float = 0.2

var is_valid: bool = false

var _meshes: Array[MeshInstance3D] = []
var _material: StandardMaterial3D = null
var _pulse_time: float = 0.0
var _is_pulsing: bool = false
var _grid: BuildModeGrid = null
var _shake_tween: Tween = null
var _scale_tween: Tween = null


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
	if cells.is_empty():
		hide_ghost()
		return
	is_valid = valid
	_update_color(valid)
	_rebuild_meshes(cells)
	visible = true


## Hides the ghost and stops pulsing.
func hide_ghost() -> void:
	visible = false
	_is_pulsing = false
	_pulse_time = 0.0
	_kill_tween(_shake_tween)
	_kill_tween(_scale_tween)
	position = Vector3.ZERO
	scale = Vector3.ONE


## Plays horizontal shake animation on invalid placement.
func play_shake() -> void:
	if not visible:
		return

	_kill_tween(_shake_tween)
	var original_pos: Vector3 = position
	_shake_tween = create_tween()
	var step_time: float = SHAKE_DURATION / (SHAKE_OSCILLATIONS * 2.0)

	for i: int in range(SHAKE_OSCILLATIONS):
		var direction: float = 1.0 if i % 2 == 0 else -1.0
		var offset: Vector3 = Vector3(
			SHAKE_MAGNITUDE * direction, 0.0, 0.0
		)
		_shake_tween.tween_property(
			self, "position",
			original_pos + offset,
			step_time
		).set_trans(Tween.TRANS_SINE)
		_shake_tween.tween_property(
			self, "position",
			original_pos - offset,
			step_time
		).set_trans(Tween.TRANS_SINE)

	_shake_tween.tween_property(
		self, "position", original_pos, step_time * 0.5
	).set_trans(Tween.TRANS_SINE)


## Plays a quick placement confirmation scale punch on the ghost footprint.
func play_scale_punch() -> void:
	if not visible:
		return

	_kill_tween(_scale_tween)
	scale = Vector3.ONE
	_scale_tween = create_tween()
	_scale_tween.tween_property(
		self,
		"scale",
		Vector3(SCALE_PUNCH_PEAK, SCALE_PUNCH_PEAK, SCALE_PUNCH_PEAK),
		SCALE_PUNCH_DURATION * 0.5
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_scale_tween.tween_property(
		self, "scale", Vector3.ONE, SCALE_PUNCH_DURATION * 0.5
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)


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
			remove_child(mesh)
			mesh.free()
	_meshes.clear()

	var anchor: Vector3 = _get_cells_center(cells)
	position = anchor

	for cell: Vector2i in cells:
		var inst: MeshInstance3D = _create_cell_quad(cell, anchor)
		add_child(inst)
		_meshes.append(inst)


func _create_cell_quad(cell: Vector2i, anchor: Vector3) -> MeshInstance3D:
	var quad: PlaneMesh = PlaneMesh.new()
	quad.size = Vector2(
		BuildModeGrid.CELL_SIZE * 0.95,
		BuildModeGrid.CELL_SIZE * 0.95
	)

	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = quad
	inst.set_surface_override_material(0, _material)
	var world_pos := Vector3(
		_grid.grid_origin.x + (cell.x + 0.5) * BuildModeGrid.CELL_SIZE,
		_grid.grid_origin.y + Y_OFFSET,
		_grid.grid_origin.z + (cell.y + 0.5) * BuildModeGrid.CELL_SIZE
	)
	inst.position = world_pos - anchor
	return inst


func _create_material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	return mat


func _get_cells_center(cells: Array[Vector2i]) -> Vector3:
	var sum := Vector3.ZERO
	for cell: Vector2i in cells:
		sum += Vector3(
			_grid.grid_origin.x + (cell.x + 0.5) * BuildModeGrid.CELL_SIZE,
			_grid.grid_origin.y + Y_OFFSET,
			_grid.grid_origin.z + (cell.y + 0.5) * BuildModeGrid.CELL_SIZE
		)
	return sum / float(cells.size())


func _kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()
