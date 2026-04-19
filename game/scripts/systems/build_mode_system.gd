## Manages build mode: 6-state machine, grid overlay, camera transitions, and fixture placement.
class_name BuildModeSystem
extends Node

enum State { IDLE, PLACEMENT, MOVING, SELECTED, ROTATING, CONFIRMED }

const CONFIRMATION_DURATION: float = 0.3

var is_active: bool = false
var current_state: State = State.IDLE

var _grid: BuildModeGrid = null
var _camera_controller: BuildModeCamera = null
var _camera: Camera3D = null
var _player_node: Node = null
var _placement_system: FixturePlacementSystem = null
var _visuals: BuildModeVisuals = null

var _hovered_cell: Variant = null
var _selected_fixture_id: String = ""
var _move_fixture_data: Dictionary = {}
var _confirmation_timer: float = 0.0
var _grid_state: Array[Dictionary] = []


func _ready() -> void:
	EventBus.active_camera_changed.connect(_on_active_camera_changed)
	EventBus.build_mode_entered.connect(_on_build_mode_entered)
	EventBus.build_mode_exited.connect(_on_build_mode_exited)
	EventBus.fixture_catalog_requested.connect(
		_on_fixture_catalog_requested
	)
	EventBus.fixture_placed.connect(_on_fixture_placed)
	EventBus.fixture_removed.connect(_on_fixture_removed)
	if is_instance_valid(CameraManager.active_camera):
		_camera = CameraManager.active_camera


## Sets up build mode with required references.
func initialize(
	player_node: Node,
	store_size: BuildModeGrid.StoreSize,
	floor_center: Vector3
) -> void:
	_player_node = player_node
	_hovered_cell = null
	_selected_fixture_id = ""
	_move_fixture_data = {}
	_confirmation_timer = 0.0
	current_state = State.IDLE
	is_active = false

	if is_instance_valid(CameraManager.active_camera):
		_camera = CameraManager.active_camera

	if is_instance_valid(_grid):
		_grid.queue_free()
	_grid = BuildModeGrid.new()
	_grid.name = "BuildModeGrid"
	add_child(_grid)
	_grid.initialize(store_size, floor_center)

	if is_instance_valid(_camera_controller):
		_camera_controller.queue_free()
	_camera_controller = BuildModeCamera.new()
	_camera_controller.name = "BuildModeCamera"
	add_child(_camera_controller)
	_camera_controller.initialize(_grid.get_world_center())

	var dims: Vector2 = _grid.get_world_dimensions()
	var center: Vector3 = _grid.get_world_center()
	_camera_controller.set_store_bounds(
		Vector3(center.x - dims.x * 0.5, 0.0, center.z - dims.y * 0.5),
		Vector3(center.x + dims.x * 0.5, 0.0, center.z + dims.y * 0.5)
	)


## Sets the placement system reference.
func set_placement_system(system: FixturePlacementSystem) -> void:
	_placement_system = system
	_setup_visuals()
	if _grid_state.is_empty():
		_sync_grid_state_from_placement()
		return
	if _placement_system:
		_placement_system.load_save_data({
			"placed_fixtures": _duplicate_grid_state(_grid_state)
		})

## Returns the currently hovered grid cell, or null if none.
func get_hovered_cell() -> Variant:
	return _hovered_cell


## Returns the grid sub-system for external coordinate queries.
func get_grid() -> BuildModeGrid:
	return _grid


## Returns the build mode camera controller.
func get_camera_controller() -> BuildModeCamera:
	return _camera_controller


## Returns the build mode visual feedback layer.
func get_visuals() -> BuildModeVisuals:
	return _visuals


## Returns the current build state.
func get_state() -> State:
	return current_state


## Returns all grid state as Array[Dictionary] for save/load.
func get_grid_state() -> Array[Dictionary]:
	_sync_grid_state_from_placement()
	return _duplicate_grid_state(_grid_state)


## Loads grid state from Array[Dictionary].
func load_grid_state(state: Array[Dictionary]) -> void:
	_grid_state = _normalize_grid_state(state)
	if _placement_system:
		_placement_system.load_save_data({
			"placed_fixtures": _duplicate_grid_state(_grid_state)
		})


## Selects a fixture type for placement from the catalog.
func select_fixture_for_placement(fixture_type: String) -> void:
	if not is_active or not _placement_system:
		return
	_placement_system.select_fixture(fixture_type)
	_selected_fixture_id = fixture_type
	_transition_to(State.PLACEMENT)
	_update_visual_feedback()


## Deselects the current fixture type.
func deselect_fixture() -> void:
	if _placement_system:
		_placement_system.deselect_fixture()
	_selected_fixture_id = ""
	_transition_to(State.IDLE)
	_update_visual_feedback()


## Rotates the selected fixture clockwise and moves into ROTATING state.
func rotate_selected_fixture() -> void:
	_handle_rotate()


## Attempts to confirm the current placement state at a grid cell.
func confirm_selected_fixture(cell: Vector2i) -> bool:
	if not _placement_system:
		return false

	match current_state:
		State.PLACEMENT, State.ROTATING:
			return _try_place_fixture(cell)
		State.MOVING:
			return _try_place_moved_fixture(cell)
		_:
			return false


## Zooms the active build camera in while build mode is active.
func zoom_camera_in() -> void:
	if not is_active or not _camera_controller:
		return
	_camera_controller.zoom_in()


## Zooms the active build camera out while build mode is active.
func zoom_camera_out() -> void:
	if not is_active or not _camera_controller:
		return
	_camera_controller.zoom_out()


## Pans the active build camera while build mode is active.
func pan_camera(mouse_delta: Vector2) -> void:
	if not is_active or not _camera_controller:
		return
	_camera_controller.pan(mouse_delta)


func _process(delta: float) -> void:
	if current_state != State.CONFIRMED:
		return
	_confirmation_timer -= delta
	if _confirmation_timer <= 0.0:
		if _placement_system and not _placement_system.get_selected_fixture_type().is_empty():
			_transition_to(State.PLACEMENT)
		else:
			_transition_to(State.IDLE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_build_mode"):
		_toggle_build_mode()
		get_viewport().set_input_as_handled()
		return

	if not is_active:
		return

	if _camera_controller and _camera_controller.is_transitioning:
		return

	if event is InputEventMouseMotion:
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		if _is_middle_mouse_held(event):
			_camera_controller.pan(mouse_event.relative)
			get_viewport().set_input_as_handled()
			return
		_update_hovered_cell(mouse_event)

	if event is InputEventMouseButton:
		var btn: InputEventMouseButton = event as InputEventMouseButton
		if btn.button_index == MOUSE_BUTTON_WHEEL_UP and btn.pressed:
			zoom_camera_in()
			get_viewport().set_input_as_handled()
			return
		if btn.button_index == MOUSE_BUTTON_WHEEL_DOWN and btn.pressed:
			zoom_camera_out()
			get_viewport().set_input_as_handled()
			return
		_handle_mouse_button(btn)

	if event.is_action_pressed("rotate_fixture"):
		_handle_rotate()
		get_viewport().set_input_as_handled()


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
		push_warning("BuildModeSystem: failed to transition to BUILD state")
		return

	is_active = true
	current_state = State.IDLE

	if _player_node and _player_node.has_method("set_build_mode"):
		_player_node.set_build_mode(true)

	EventBus.build_mode_entered.emit()


func exit_build_mode() -> void:
	if not is_active:
		return

	if _placement_system:
		var reg_result: PlacementResult = (
			_placement_system.validate_register_exists()
		)
		if not reg_result.valid:
			EventBus.fixture_placement_invalid.emit(
				reg_result.reason
			)
			return

	is_active = false
	_hovered_cell = null
	_selected_fixture_id = ""
	current_state = State.IDLE

	if _placement_system:
		_placement_system.deselect_fixture()

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

	match current_state:
		State.IDLE:
			_try_select_fixture(cell)
		State.PLACEMENT, State.ROTATING:
			confirm_selected_fixture(cell)
		State.SELECTED:
			_try_select_fixture(cell)
		State.MOVING:
			confirm_selected_fixture(cell)
		State.CONFIRMED:
			pass


func _handle_right_click(cell: Vector2i) -> void:
	if not _placement_system:
		return

	match current_state:
		State.PLACEMENT, State.ROTATING:
			deselect_fixture()
		State.SELECTED:
			_placement_system.try_remove(cell)
			_selected_fixture_id = ""
			_transition_to(State.IDLE)
		State.MOVING:
			_cancel_move()
		State.IDLE:
			_placement_system.try_remove(cell)
		State.CONFIRMED:
			pass


func _handle_rotate() -> void:
	if not _placement_system:
		return
	if current_state not in [State.PLACEMENT, State.ROTATING, State.MOVING]:
		return

	_transition_to(State.ROTATING)
	_placement_system.rotate_fixture()
	if _hovered_cell != null:
		_placement_system.update_preview(_hovered_cell)
	_update_visual_feedback()


func _try_select_fixture(cell: Vector2i) -> void:
	var fixture_id: String = _placement_system.get_fixture_at(cell)
	if fixture_id.is_empty():
		if current_state == State.SELECTED:
			_selected_fixture_id = ""
			_transition_to(State.IDLE)
			_update_visual_feedback()
		return

	_selected_fixture_id = fixture_id
	_transition_to(State.SELECTED)
	EventBus.fixture_selected.emit(fixture_id)
	_update_visual_feedback()


func _try_place_fixture(cell: Vector2i) -> bool:
	if _placement_system.try_place(cell):
		_transition_to(State.CONFIRMED)
		_confirmation_timer = CONFIRMATION_DURATION
		_sync_grid_state_from_placement()
		return true
	return false


func _try_place_moved_fixture(cell: Vector2i) -> bool:
	if _move_fixture_data.is_empty():
		_transition_to(State.IDLE)
		return false
	if _placement_system.try_place(cell):
		_move_fixture_data = {}
		_transition_to(State.CONFIRMED)
		_confirmation_timer = CONFIRMATION_DURATION
		_sync_grid_state_from_placement()
		return true
	return false


func _cancel_move() -> void:
	_move_fixture_data = {}
	_placement_system.deselect_fixture()
	_transition_to(State.IDLE)
	_update_visual_feedback()


func _transition_to(new_state: State) -> void:
	current_state = new_state


func _update_hovered_cell(event: InputEventMouseMotion) -> void:
	if not is_instance_valid(_camera) or _grid == null:
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
	_update_visual_feedback()


func _is_middle_mouse_held(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		return (motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0
	return false


func _on_active_camera_changed(camera: Camera3D) -> void:
	_camera = camera
	if _camera_controller:
		_camera_controller.update_camera(camera)


func _on_build_mode_entered() -> void:
	if _camera_controller:
		_camera_controller.transition_to_top_down()


func _on_build_mode_exited() -> void:
	if _camera_controller:
		_camera_controller.transition_to_orbit()


func _on_fixture_placed(
	_fixture_id: String, _grid_pos: Vector2i, _rotation: int
) -> void:
	_sync_grid_state_from_placement()


func _on_fixture_removed(_fixture_id: String, _grid_pos: Vector2i) -> void:
	_sync_grid_state_from_placement()
	_update_visual_feedback()


func _on_fixture_catalog_requested(fixture_id: String) -> void:
	if fixture_id.is_empty():
		return
	select_fixture_for_placement(fixture_id)


func _setup_visuals() -> void:
	if not _grid or not _placement_system:
		return
	if is_instance_valid(_visuals):
		_visuals.queue_free()

	_visuals = BuildModeVisuals.new()
	_visuals.name = "BuildModeVisuals"
	add_child(_visuals)
	_visuals.initialize(
		_grid, _placement_system.get_validator(), _placement_system
	)


func _update_visual_feedback() -> void:
	if not _visuals or not _placement_system:
		return

	var fixture_type: String = _placement_system.get_selected_fixture_type()
	if not fixture_type.is_empty():
		_visuals.update_ghost(
			_hovered_cell,
			fixture_type,
			_placement_system.get_current_rotation()
		)
		return

	_visuals.hide_ghost()
	_visuals.update_highlight(_hovered_cell)


func _sync_grid_state_from_placement() -> void:
	if not _placement_system:
		return
	_grid_state.clear()
	for entry: Dictionary in _placement_system.get_placed_fixtures():
		_grid_state.append(_normalize_grid_entry(entry))


func _duplicate_grid_state(state: Array[Dictionary]) -> Array[Dictionary]:
	var state_copy: Array[Dictionary] = []
	for entry: Dictionary in state:
		state_copy.append(_normalize_grid_entry(entry))
	return state_copy


func _normalize_grid_state(state: Array[Dictionary]) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for entry: Dictionary in state:
		normalized.append(_normalize_grid_entry(entry))
	return normalized


func _normalize_grid_entry(entry: Dictionary) -> Dictionary:
	var grid_position: Vector2i = _coerce_grid_position(
		entry.get("grid_position", Vector2i.ZERO)
	)
	return {
		"fixture_id": str(entry.get("fixture_id", "")),
		"fixture_type": str(entry.get("fixture_type", "")),
		"grid_position": [grid_position.x, grid_position.y],
		"rotation": clampi(int(entry.get("rotation", 0)), 0, 3),
		"is_register": bool(entry.get("is_register", false)),
		"purchase_price": float(entry.get("purchase_price", 0.0)),
		"tier": int(entry.get("tier", FixtureDefinition.TierLevel.BASIC)),
		"total_spent": float(entry.get("total_spent", 0.0)),
	}


func _coerce_grid_position(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value as Vector2i
	if value is Array:
		var raw: Array = value as Array
		if raw.size() >= 2:
			return Vector2i(int(raw[0]), int(raw[1]))
	return Vector2i.ZERO
