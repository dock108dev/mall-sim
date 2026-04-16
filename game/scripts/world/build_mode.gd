## Orchestrates build mode: grid overlay, camera transition, and fixture placement.
class_name BuildMode
extends Node

var is_active: bool = false

var _grid: BuildModeGrid = null
var _camera_controller: BuildModeCamera = null
var _camera: Camera3D = null
var _player_node: Node = null
var _placement_system: FixturePlacementSystem = null
var _nav_region: NavigationRegion3D = null
var _visuals: BuildModeVisuals = null

var _hovered_cell: Variant = null


func _ready() -> void:
	EventBus.active_camera_changed.connect(_on_active_camera_changed)
	if is_instance_valid(CameraManager.active_camera):
		_camera = CameraManager.active_camera


## Sets up build mode with required references.
func initialize(
	player_node: Node,
	store_size: BuildModeGrid.StoreSize,
	floor_center: Vector3
) -> void:
	_player_node = player_node

	if is_instance_valid(CameraManager.active_camera):
		_camera = CameraManager.active_camera

	_grid = BuildModeGrid.new()
	_grid.name = "BuildModeGrid"
	add_child(_grid)
	_grid.initialize(store_size, floor_center)

	_camera_controller = BuildModeCamera.new()
	_camera_controller.name = "BuildModeCamera"
	add_child(_camera_controller)
	_camera_controller.initialize(_grid.get_world_center())


## Sets the placement system reference and initializes visuals.
func set_placement_system(
	system: FixturePlacementSystem
) -> void:
	_placement_system = system
	_setup_visuals()


## Sets the NavigationRegion3D for rebaking on exit.
func set_nav_region(region: NavigationRegion3D) -> void:
	_nav_region = region


## Returns the visuals sub-system for external access.
func get_visuals() -> BuildModeVisuals:
	return _visuals


func _setup_visuals() -> void:
	if not _grid or not _placement_system:
		return
	if _visuals:
		_visuals.queue_free()

	_visuals = BuildModeVisuals.new()
	_visuals.name = "BuildModeVisuals"
	add_child(_visuals)
	_visuals.initialize(
		_grid, _placement_system.get_validator(), _placement_system
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_build_mode"):
		_toggle_build_mode()
		get_viewport().set_input_as_handled()
		return

	if not is_active:
		return

	if event is InputEventMouseMotion:
		_update_hovered_cell(event as InputEventMouseMotion)

	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)

	if event.is_action_pressed("rotate_fixture"):
		_handle_rotate()
		get_viewport().set_input_as_handled()


## Returns the currently hovered grid cell, or null if none.
func get_hovered_cell() -> Variant:
	return _hovered_cell


## Returns the grid sub-system for external coordinate queries.
func get_grid() -> BuildModeGrid:
	return _grid


func _on_active_camera_changed(camera: Camera3D) -> void:
	_camera = camera
	if _camera_controller:
		_camera_controller.update_camera(camera)


func _toggle_build_mode() -> void:
	if _camera_controller and _camera_controller.is_transitioning:
		return

	if is_active:
		exit_build_mode()
	else:
		_try_enter_build_mode()


func _try_enter_build_mode() -> void:
	var state: int = GameManager.current_state
	var can_enter: bool = (
		state == GameManager.GameState.GAMEPLAY
		or state == GameManager.GameState.PAUSED
	)
	if not can_enter:
		return

	enter_build_mode()


func enter_build_mode() -> void:
	if is_active:
		return

	var changed: bool = GameManager.change_state(
		GameManager.GameState.BUILD
	)
	if not changed:
		push_warning("BuildMode: failed to transition to BUILD state")
		return

	is_active = true
	_grid.show_grid()
	_camera_controller.transition_to_top_down()

	if _player_node and _player_node.has_method("set_build_mode"):
		_player_node.set_build_mode(true)

	EventBus.build_mode_entered.emit()


func exit_build_mode() -> void:
	if not is_active:
		return

	is_active = false
	_hovered_cell = null
	_grid.hide_grid()
	_camera_controller.transition_to_orbit()

	if _placement_system:
		_placement_system.deselect_fixture()
		if _placement_system.needs_nav_rebake and _nav_region:
			_nav_region.bake_navigation_mesh()
			_placement_system.needs_nav_rebake = false

	if _player_node and _player_node.has_method("set_build_mode"):
		_player_node.set_build_mode(false)

	GameManager.change_state(GameManager.GameState.GAMEPLAY)
	EventBus.build_mode_exited.emit()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return

	if _hovered_cell == null:
		return

	var cell: Vector2i = _hovered_cell as Vector2i

	if event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(cell)
		get_viewport().set_input_as_handled()

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click(cell)
		get_viewport().set_input_as_handled()


func _handle_left_click(cell: Vector2i) -> void:
	if not _placement_system:
		return

	if _placement_system.get_selected_fixture_type().is_empty():
		var fixture_id: String = _placement_system.get_fixture_at(
			cell
		)
		if not fixture_id.is_empty():
			EventBus.fixture_selected.emit(fixture_id)
		return

	_placement_system.try_place(cell)


func _handle_right_click(cell: Vector2i) -> void:
	if not _placement_system:
		return

	_placement_system.try_remove(cell)


func _handle_rotate() -> void:
	if not _placement_system:
		return

	if _placement_system.get_selected_fixture_type().is_empty():
		return

	_placement_system.rotate_fixture()
	if _hovered_cell != null:
		_placement_system.update_preview(_hovered_cell)
		if _visuals:
			_visuals.update_ghost(
				_hovered_cell,
				_placement_system.get_selected_fixture_type(),
				_placement_system.get_current_rotation()
			)


func _update_hovered_cell(event: InputEventMouseMotion) -> void:
	if not is_instance_valid(_camera):
		return

	var mouse_pos: Vector2 = event.position
	var from: Vector3 = _camera.project_ray_origin(mouse_pos)
	var dir: Vector3 = _camera.project_ray_normal(mouse_pos)

	if absf(dir.y) < 0.001:
		_hovered_cell = null
		return

	var t: float = (_grid.grid_origin.y - from.y) / dir.y
	if t < 0.0:
		_hovered_cell = null
		return

	var hit_point := from + dir * t
	_hovered_cell = _grid.world_to_grid(hit_point)

	if _placement_system:
		_placement_system.update_preview(_hovered_cell)

	if _visuals:
		var fixture_type: String = ""
		var rotation: int = 0
		if _placement_system:
			fixture_type = _placement_system.get_selected_fixture_type()
			rotation = _placement_system.get_current_rotation()
		if not fixture_type.is_empty():
			_visuals.update_ghost(
				_hovered_cell, fixture_type, rotation
			)
		else:
			_visuals.update_ghost(null, "", 0)
			_visuals.update_highlight(_hovered_cell)
