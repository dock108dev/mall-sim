## Renders colored cell state overlay and fixture rim highlights for build mode.
class_name BuildModeCellOverlay
extends Node3D

const CELL_EMPTY_COLOR: Color = Color(1.0, 1.0, 1.0, 0.1)
const CELL_OCCUPIED_COLOR: Color = Color(0.5, 0.5, 0.5, 0.3)
const CELL_ENTRY_ZONE_COLOR: Color = Color(1.0, 1.0, 0.0, 0.2)
const CELL_Y_OFFSET: float = 0.015

const HIGHLIGHT_BLUE: Color = Color(0.2, 0.4, 1.0, 0.6)
const HIGHLIGHT_YELLOW: Color = Color(1.0, 0.9, 0.2, 0.5)
const HIGHLIGHT_Y_OFFSET: float = 0.04
var overlay_alpha: float = 0.0:
	set(value):
		_overlay_alpha = clampf(value, 0.0, 1.0)
		_apply_overlay_alpha()
	get:
		return _overlay_alpha

var _grid: BuildModeGrid = null
var _validator: FixturePlacementValidator = null
var _placement_system: FixturePlacementSystem = null

var _cells_container: Node3D = null
var _cell_meshes: Array[MeshInstance3D] = []
var _fade_tween: Tween = null
var _overlay_alpha: float = 0.0

var _highlight_meshes: Array[MeshInstance3D] = []
var _hovered_fixture_id: String = ""
var _selected_fixture_id: String = ""


## Sets up with grid, validator, and placement system references.
func setup(
	grid: BuildModeGrid,
	validator: FixturePlacementValidator,
	placement_system: FixturePlacementSystem
) -> void:
	_grid = grid
	_validator = validator
	_placement_system = placement_system

	_cells_container = Node3D.new()
	_cells_container.name = "CellsContainer"
	_cells_container.visible = false
	add_child(_cells_container)


## Builds cell state quads for the entire grid.
func build_overlay() -> void:
	_clear_cells()
	if not _grid or not _validator:
		return

	var occupied: Dictionary = _placement_system.get_all_occupied_cells()

	for x: int in range(_grid.grid_size.x):
		for y: int in range(_grid.grid_size.y):
			var cell := Vector2i(x, y)
			var state: FixturePlacementValidator.CellState = (
				_validator.get_cell_state(cell, occupied)
			)
			var color: Color = _state_to_color(state)
			if color.a <= 0.0:
				continue
			var mesh_inst: MeshInstance3D = _create_quad(
				cell, color, CELL_Y_OFFSET
			)
			_cells_container.add_child(mesh_inst)
			_cell_meshes.append(mesh_inst)
	_apply_overlay_alpha()


## Fades the cell overlay in (0.25s ease-out) or out (0.25s ease-in).
func fade(fade_in: bool) -> void:
	_kill_tween()

	if fade_in:
		var current_alpha: float = overlay_alpha
		if not _cells_container.visible:
			current_alpha = 0.0
		_cells_container.visible = true
		overlay_alpha = current_alpha
		_fade_tween = create_tween()
		_fade_tween.tween_property(
			self, "overlay_alpha", 1.0,
			PanelAnimator.BUILD_MODE_TRANSITION
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		_fade_tween = create_tween()
		_fade_tween.tween_property(
			self, "overlay_alpha", 0.0,
			PanelAnimator.BUILD_MODE_TRANSITION
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		_fade_tween.tween_callback(
			func() -> void:
				_cells_container.visible = false
				_clear_cells()
		)


## Updates highlight based on the hovered cell position.
func update_highlight(hovered_cell: Variant) -> void:
	if hovered_cell == null:
		_clear_highlights()
		return

	var cell: Vector2i = hovered_cell as Vector2i
	var fixture_id: String = _placement_system.get_fixture_at(cell)

	if fixture_id.is_empty():
		_clear_highlights()
		return

	if fixture_id == _selected_fixture_id:
		_show_fixture_highlight(fixture_id, HIGHLIGHT_BLUE)
	elif fixture_id != _hovered_fixture_id:
		_show_fixture_highlight(fixture_id, HIGHLIGHT_YELLOW)

	_hovered_fixture_id = fixture_id


## Sets the selected fixture ID for blue highlight.
func set_selected_fixture(fixture_id: String) -> void:
	_selected_fixture_id = fixture_id
	if not fixture_id.is_empty():
		_show_fixture_highlight(fixture_id, HIGHLIGHT_BLUE)


## Clears selection and highlight state.
func clear_selection() -> void:
	_selected_fixture_id = ""
	_hovered_fixture_id = ""
	_clear_highlights()


func _show_fixture_highlight(
	fixture_id: String, color: Color
) -> void:
	_clear_highlights()

	var data: Dictionary = _placement_system.get_fixture_data(
		fixture_id
	)
	if data.is_empty():
		return

	var cells: Array[Vector2i] = data.get(
		"cells", [] as Array[Vector2i]
	)

	for cell: Variant in cells:
		var cell_v: Vector2i = cell as Vector2i
		var rim: MeshInstance3D = _create_quad(
			cell_v, color, HIGHLIGHT_Y_OFFSET
		)
		rim.name = "RimHighlight_%d_%d" % [cell_v.x, cell_v.y]
		add_child(rim)
		_highlight_meshes.append(rim)


func _clear_highlights() -> void:
	_hovered_fixture_id = ""
	for mesh: MeshInstance3D in _highlight_meshes:
		if is_instance_valid(mesh):
			mesh.queue_free()
	_highlight_meshes.clear()


func _clear_cells() -> void:
	for mesh: MeshInstance3D in _cell_meshes:
		if is_instance_valid(mesh):
			mesh.queue_free()
	_cell_meshes.clear()


func _state_to_color(
	state: FixturePlacementValidator.CellState
) -> Color:
	match state:
		FixturePlacementValidator.CellState.EMPTY:
			return CELL_EMPTY_COLOR
		FixturePlacementValidator.CellState.OCCUPIED:
			return CELL_OCCUPIED_COLOR
		FixturePlacementValidator.CellState.ENTRY_ZONE:
			return CELL_ENTRY_ZONE_COLOR
		FixturePlacementValidator.CellState.WALL:
			return Color(0.0, 0.0, 0.0, 0.0)
	return Color(0.0, 0.0, 0.0, 0.0)


func _create_quad(
	cell: Vector2i, color: Color, y_offset: float
) -> MeshInstance3D:
	var quad: PlaneMesh = PlaneMesh.new()
	quad.size = Vector2(
		BuildModeGrid.CELL_SIZE * 0.92,
		BuildModeGrid.CELL_SIZE * 0.92
	)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true

	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = quad
	inst.set_surface_override_material(0, mat)
	inst.set_meta(&"base_color", color)
	inst.position = Vector3(
		_grid.grid_origin.x + (cell.x + 0.5) * BuildModeGrid.CELL_SIZE,
		_grid.grid_origin.y + y_offset,
		_grid.grid_origin.z + (cell.y + 0.5) * BuildModeGrid.CELL_SIZE
	)
	return inst


func _apply_overlay_alpha() -> void:
	for mesh: MeshInstance3D in _cell_meshes:
		if not is_instance_valid(mesh):
			continue
		var material := mesh.get_active_material(0) as StandardMaterial3D
		if material == null:
			continue
		var base_color: Color = mesh.get_meta(&"base_color", Color.WHITE) as Color
		material.albedo_color = Color(
			base_color.r,
			base_color.g,
			base_color.b,
			base_color.a * overlay_alpha,
		)


func _kill_tween() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
