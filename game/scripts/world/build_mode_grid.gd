## Grid overlay system for build mode with 0.5m cells and coordinate queries.
class_name BuildModeGrid
extends Node3D

enum StoreSize { SMALL, MEDIUM, LARGE }

const CELL_SIZE: float = 0.5

const GRID_DIMENSIONS: Dictionary = {
	StoreSize.SMALL: Vector2i(14, 10),
	StoreSize.MEDIUM: Vector2i(18, 12),
	StoreSize.LARGE: Vector2i(24, 16),
}

const GRID_LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.3)
const GRID_LINE_WIDTH: float = 0.005

var grid_size: Vector2i = Vector2i.ZERO
var grid_origin: Vector3 = Vector3.ZERO

var _mesh_instance: MeshInstance3D = null
var _material: StandardMaterial3D = null
var _fade_tween: Tween
var _is_visible: bool = false


func _ready() -> void:
	EventBus.build_mode_entered.connect(_on_build_mode_entered)
	EventBus.build_mode_exited.connect(_on_build_mode_exited)


## Sets up the grid for the given store size and floor center position.
func initialize(store_size: StoreSize, floor_center: Vector3) -> void:
	grid_size = GRID_DIMENSIONS.get(store_size, Vector2i(14, 10))
	var world_width: float = grid_size.x * CELL_SIZE
	var world_depth: float = grid_size.y * CELL_SIZE
	grid_origin = Vector3(
		floor_center.x - world_width * 0.5,
		floor_center.y,
		floor_center.z - world_depth * 0.5
	)
	_build_grid_mesh()


## Converts a world position to grid coordinates, or null if outside grid.
func world_to_grid(world_pos: Vector3) -> Variant:
	var local_x: float = world_pos.x - grid_origin.x
	var local_z: float = world_pos.z - grid_origin.z
	var grid_x: int = floori(local_x / CELL_SIZE)
	var grid_y: int = floori(local_z / CELL_SIZE)
	if grid_x < 0 or grid_x >= grid_size.x:
		return null
	if grid_y < 0 or grid_y >= grid_size.y:
		return null
	return Vector2i(grid_x, grid_y)


## Converts grid coordinates to world position (center of cell).
func grid_to_world(grid_coords: Vector2i) -> Vector3:
	return Vector3(
		grid_origin.x + (grid_coords.x + 0.5) * CELL_SIZE,
		grid_origin.y,
		grid_origin.z + (grid_coords.y + 0.5) * CELL_SIZE
	)


## Returns true if grid coordinates are within bounds.
func is_valid_cell(grid_coords: Vector2i) -> bool:
	return (
		grid_coords.x >= 0
		and grid_coords.x < grid_size.x
		and grid_coords.y >= 0
		and grid_coords.y < grid_size.y
	)


## Returns the world-space dimensions of the grid.
func get_world_dimensions() -> Vector2:
	return Vector2(
		grid_size.x * CELL_SIZE,
		grid_size.y * CELL_SIZE
	)


## Returns the world-space center of the grid.
func get_world_center() -> Vector3:
	var dims: Vector2 = get_world_dimensions()
	return Vector3(
		grid_origin.x + dims.x * 0.5,
		grid_origin.y,
		grid_origin.z + dims.y * 0.5
	)


func show_grid() -> void:
	_kill_fade_tween()
	if _mesh_instance and _material:
		var current_alpha: float = _material.albedo_color.a
		if not _mesh_instance.visible:
			current_alpha = 0.0
		_material.albedo_color = _grid_line_color(current_alpha)
		_mesh_instance.visible = true
		_fade_tween = create_tween()
		_fade_tween.tween_property(
			_material, "albedo_color", _grid_line_color(1.0),
			PanelAnimator.BUILD_MODE_TRANSITION
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	elif _mesh_instance:
		_mesh_instance.visible = true
	_is_visible = true


func hide_grid() -> void:
	_kill_fade_tween()
	if _mesh_instance and _material:
		var fade_target: Color = _grid_line_color(0.0)
		_fade_tween = create_tween()
		_fade_tween.tween_property(
			_material, "albedo_color", fade_target,
			PanelAnimator.BUILD_MODE_TRANSITION
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		_fade_tween.tween_callback(
			func() -> void: _mesh_instance.visible = false
		)
	elif _mesh_instance:
		_mesh_instance.visible = false
	_is_visible = false


func _build_grid_mesh() -> void:
	if _mesh_instance:
		_mesh_instance.queue_free()

	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	_material = mat
	mat.albedo_color = GRID_LINE_COLOR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true

	var world_w: float = grid_size.x * CELL_SIZE
	var world_d: float = grid_size.y * CELL_SIZE
	var y_offset: float = grid_origin.y + 0.01

	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)

	for col: int in range(grid_size.x + 1):
		var x: float = grid_origin.x + col * CELL_SIZE
		im.surface_add_vertex(Vector3(x, y_offset, grid_origin.z))
		im.surface_add_vertex(
			Vector3(x, y_offset, grid_origin.z + world_d)
		)

	for row: int in range(grid_size.y + 1):
		var z: float = grid_origin.z + row * CELL_SIZE
		im.surface_add_vertex(Vector3(grid_origin.x, y_offset, z))
		im.surface_add_vertex(
			Vector3(grid_origin.x + world_w, y_offset, z)
		)

	im.surface_end()

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = im
	_mesh_instance.visible = _is_visible
	add_child(_mesh_instance)


func _on_build_mode_entered() -> void:
	show_grid()


func _on_build_mode_exited() -> void:
	hide_grid()


func _grid_line_color(alpha: float) -> Color:
	return Color(
		GRID_LINE_COLOR.r,
		GRID_LINE_COLOR.g,
		GRID_LINE_COLOR.b,
		alpha,
	)


func _kill_fade_tween() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
