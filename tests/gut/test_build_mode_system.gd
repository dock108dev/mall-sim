## Tests for BuildModeSystem state machine, grid initialization, and signal emission.
extends GutTest


var _system: BuildModeSystem
var _saved_game_state: GameManager.GameState
var _saved_active_camera: Camera3D = null


func before_each() -> void:
	_saved_game_state = GameManager.current_state
	_saved_active_camera = CameraManager.active_camera
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	_system = BuildModeSystem.new()
	add_child_autofree(_system)


func after_each() -> void:
	GameManager.current_state = _saved_game_state
	CameraManager.register_camera(_saved_active_camera)


func test_initial_state() -> void:
	assert_false(_system.is_active)
	assert_eq(_system.current_state, BuildModeSystem.State.IDLE)


func test_state_enum_values() -> void:
	assert_eq(BuildModeSystem.State.IDLE, 0)
	assert_eq(BuildModeSystem.State.PLACEMENT, 1)
	assert_eq(BuildModeSystem.State.MOVING, 2)
	assert_eq(BuildModeSystem.State.SELECTED, 3)
	assert_eq(BuildModeSystem.State.ROTATING, 4)
	assert_eq(BuildModeSystem.State.CONFIRMED, 5)


func test_six_states_defined() -> void:
	assert_eq(
		BuildModeSystem.State.size(), 6,
		"State machine should have exactly 6 states"
	)


func test_initialize_creates_grid() -> void:
	var floor_center := Vector3(0.0, 0.05, 0.0)
	_system.initialize(null, BuildModeGrid.StoreSize.SMALL, floor_center)
	var grid: BuildModeGrid = _system.get_grid()
	assert_not_null(grid, "Grid should be created after initialize")
	assert_eq(grid.grid_size, Vector2i(14, 10))


func test_grid_dimensions_small() -> void:
	_system.initialize(
		null, BuildModeGrid.StoreSize.SMALL, Vector3.ZERO
	)
	var grid: BuildModeGrid = _system.get_grid()
	assert_eq(grid.grid_size, Vector2i(14, 10))


func test_grid_dimensions_medium() -> void:
	_system.initialize(
		null, BuildModeGrid.StoreSize.MEDIUM, Vector3.ZERO
	)
	var grid: BuildModeGrid = _system.get_grid()
	assert_eq(grid.grid_size, Vector2i(18, 12))


func test_grid_dimensions_large() -> void:
	_system.initialize(
		null, BuildModeGrid.StoreSize.LARGE, Vector3.ZERO
	)
	var grid: BuildModeGrid = _system.get_grid()
	assert_eq(grid.grid_size, Vector2i(24, 16))


func test_cell_size_is_half_meter() -> void:
	assert_eq(
		BuildModeGrid.CELL_SIZE, 0.5,
		"Cell size should be 0.5 meters"
	)


func test_grid_world_dimensions_small() -> void:
	_system.initialize(
		null, BuildModeGrid.StoreSize.SMALL, Vector3.ZERO
	)
	var grid: BuildModeGrid = _system.get_grid()
	var dims: Vector2 = grid.get_world_dimensions()
	assert_almost_eq(dims.x, 7.0, 0.01, "Small grid width = 14 * 0.5")
	assert_almost_eq(dims.y, 5.0, 0.01, "Small grid depth = 10 * 0.5")


func test_get_hovered_cell_default_null() -> void:
	assert_null(_system.get_hovered_cell())


func test_get_grid_state_empty_without_placement() -> void:
	var state: Array[Dictionary] = _system.get_grid_state()
	assert_eq(state.size(), 0)


func test_deselect_returns_to_idle() -> void:
	_system.deselect_fixture()
	assert_eq(_system.current_state, BuildModeSystem.State.IDLE)


func test_camera_transition_duration() -> void:
	assert_eq(
		BuildModeCamera.TRANSITION_DURATION, 0.4,
		"Camera transition should be 0.4 seconds"
	)


func test_camera_zoom_range() -> void:
	assert_eq(BuildModeCamera.ZOOM_MIN, 3.0, "Min zoom altitude = 3m")
	assert_eq(BuildModeCamera.ZOOM_MAX, 15.0, "Max zoom altitude = 15m")


func test_fixture_placed_signal_has_rotation() -> void:
	var placed_args: Array = []
	var handler := func(
		fid: String, pos: Vector2i, rot: int
	) -> void:
		placed_args.clear()
		placed_args.append(fid)
		placed_args.append(pos)
		placed_args.append(rot)
	EventBus.fixture_placed.connect(handler)
	EventBus.fixture_placed.emit("test_fixture", Vector2i(3, 4), 2)
	assert_eq(placed_args.size(), 3)
	assert_eq(placed_args[0], "test_fixture")
	assert_eq(placed_args[1], Vector2i(3, 4))
	assert_eq(placed_args[2], 2)
	EventBus.fixture_placed.disconnect(handler)


func test_fixture_placement_invalid_signal() -> void:
	var reason_received: Array = [""]
	var handler := func(reason: String) -> void:
		reason_received[0] = reason
	EventBus.fixture_placement_invalid.connect(handler)
	EventBus.fixture_placement_invalid.emit("Test rejection")
	assert_eq(reason_received[0], "Test rejection")
	EventBus.fixture_placement_invalid.disconnect(handler)


func test_confirmation_duration_positive() -> void:
	assert_gt(
		BuildModeSystem.CONFIRMATION_DURATION, 0.0,
		"Confirmation duration should be positive"
	)


func test_build_mode_system_relies_on_eventbus_for_grid_transitions() -> void:
	var script: GDScript = _system.get_script()
	var source: String = script.source_code
	assert_false(
		source.contains("_grid.show_grid()"),
		"Grid visuals should react to EventBus, not direct show_grid calls"
	)
	assert_false(
		source.contains("_grid.hide_grid()"),
		"Grid visuals should react to EventBus, not direct hide_grid calls"
	)


func test_state_machine_advances_from_placement_to_rotating_to_confirmed() -> void:
	_system.initialize(null, BuildModeGrid.StoreSize.SMALL, Vector3.ZERO)
	var placement: FixturePlacementSystem = _create_placement_system()
	_system.set_placement_system(placement)
	_system.enter_build_mode()

	_system.select_fixture_for_placement("floor_rack")
	assert_eq(_system.get_state(), BuildModeSystem.State.PLACEMENT)

	_system.rotate_selected_fixture()
	assert_eq(_system.get_state(), BuildModeSystem.State.ROTATING)

	var confirmed: bool = _system.confirm_selected_fixture(Vector2i(4, 4))
	assert_true(confirmed, "Valid placement should confirm successfully")
	assert_eq(_system.get_state(), BuildModeSystem.State.CONFIRMED)


func test_confirm_selected_fixture_emits_invalid_reason_for_rejected_cells() -> void:
	_system.initialize(null, BuildModeGrid.StoreSize.SMALL, Vector3.ZERO)
	var placement: FixturePlacementSystem = _create_placement_system()
	_system.set_placement_system(placement)
	_system.enter_build_mode()
	_system.select_fixture_for_placement("floor_rack")

	var invalid_reason: Array = [""]
	var handler := func(reason: String) -> void:
		invalid_reason[0] = reason
	EventBus.fixture_placement_invalid.connect(handler)

	var confirmed: bool = _system.confirm_selected_fixture(Vector2i(14, 0))

	assert_false(confirmed, "Out-of-bounds placements should be rejected")
	assert_eq(invalid_reason[0], "out_of_bounds")
	EventBus.fixture_placement_invalid.disconnect(handler)


func test_exit_build_mode_without_register_emits_no_register() -> void:
	_system.initialize(null, BuildModeGrid.StoreSize.SMALL, Vector3.ZERO)
	var placement: FixturePlacementSystem = _create_placement_system()
	_system.set_placement_system(placement)
	_system.enter_build_mode()

	var invalid_reason: Array = [""]
	var handler := func(reason: String) -> void:
		invalid_reason[0] = reason
	EventBus.fixture_placement_invalid.connect(handler)

	_system.exit_build_mode()

	assert_true(_system.is_active)
	assert_eq(invalid_reason[0], "no_register")
	EventBus.fixture_placement_invalid.disconnect(handler)


func test_camera_transitions_follow_build_mode_events() -> void:
	var camera: Camera3D = _create_active_camera(
		Vector3(6.0, 7.0, 8.0),
		Vector3(deg_to_rad(-20.0), deg_to_rad(15.0), 0.0)
	)
	_system.initialize(null, BuildModeGrid.StoreSize.SMALL, Vector3.ZERO)

	_system.enter_build_mode()
	await get_tree().create_timer(
		BuildModeCamera.TRANSITION_DURATION + 0.05
	).timeout

	assert_true(_system.is_active)
	assert_eq(camera.projection, Camera3D.PROJECTION_ORTHOGONAL)
	assert_almost_eq(camera.global_position.y, BuildModeCamera.TOP_DOWN_HEIGHT, 0.01)
	assert_almost_eq(camera.global_rotation.x, deg_to_rad(-90.0), 0.01)

	_system.exit_build_mode()
	await get_tree().create_timer(
		BuildModeCamera.TRANSITION_DURATION + 0.05
	).timeout

	assert_false(_system.is_active)
	assert_eq(camera.projection, Camera3D.PROJECTION_PERSPECTIVE)
	assert_almost_eq(camera.global_position.x, 6.0, 0.01)
	assert_almost_eq(camera.global_position.y, 7.0, 0.01)
	assert_almost_eq(camera.global_position.z, 8.0, 0.01)
	assert_almost_eq(camera.global_rotation.x, deg_to_rad(-20.0), 0.01)
	assert_almost_eq(camera.global_rotation.y, deg_to_rad(15.0), 0.01)


func test_zoom_and_pan_controls_clamp_to_store_bounds() -> void:
	var camera: Camera3D = _create_active_camera(
		Vector3(0.0, 9.0, 0.0),
		Vector3.ZERO
	)
	_system.initialize(null, BuildModeGrid.StoreSize.SMALL, Vector3.ZERO)
	_system.enter_build_mode()
	await get_tree().create_timer(
		BuildModeCamera.TRANSITION_DURATION + 0.05
	).timeout

	for _i: int in range(20):
		_system.zoom_camera_in()
	assert_eq(camera.global_position.y, BuildModeCamera.ZOOM_MIN)

	for _i: int in range(20):
		_system.zoom_camera_out()
	assert_eq(camera.global_position.y, BuildModeCamera.ZOOM_MAX)

	_system.pan_camera(Vector2(-10000.0, -10000.0))
	var dims: Vector2 = _system.get_grid().get_world_dimensions()
	var center: Vector3 = _system.get_grid().get_world_center()
	assert_almost_eq(camera.global_position.x, center.x + dims.x * 0.5, 0.01)
	assert_almost_eq(camera.global_position.z, center.z + dims.y * 0.5, 0.01)

	_system.pan_camera(Vector2(10000.0, 10000.0))
	assert_almost_eq(camera.global_position.x, center.x - dims.x * 0.5, 0.01)
	assert_almost_eq(camera.global_position.z, center.z - dims.y * 0.5, 0.01)


func test_grid_state_round_trips_as_array_of_dictionaries() -> void:
	_system.initialize(null, BuildModeGrid.StoreSize.SMALL, Vector3.ZERO)
	var placement: FixturePlacementSystem = _create_placement_system()
	_system.set_placement_system(placement)
	_system.enter_build_mode()
	_system.select_fixture_for_placement("floor_rack")

	var confirmed: bool = _system.confirm_selected_fixture(Vector2i(3, 2))
	assert_true(confirmed)

	var grid_state: Array[Dictionary] = _system.get_grid_state()
	assert_eq(grid_state.size(), 1)
	assert_eq(grid_state[0].get("grid_position"), [3, 2])
	assert_eq(grid_state[0].get("rotation"), 0)

	var fresh_system: BuildModeSystem = BuildModeSystem.new()
	add_child_autofree(fresh_system)
	fresh_system.initialize(null, BuildModeGrid.StoreSize.SMALL, Vector3.ZERO)
	var fresh_placement: FixturePlacementSystem = FixturePlacementSystem.new()
	add_child_autofree(fresh_placement)
	fresh_placement.initialize(
		fresh_system.get_grid(), null, null, 8,
		BuildModeGrid.StoreSize.SMALL
	)
	fresh_system.set_placement_system(fresh_placement)
	fresh_system.load_grid_state(grid_state)

	assert_false(
		fresh_placement.get_fixture_at(Vector2i(3, 2)).is_empty(),
		"Loading grid state should restore the placed fixture"
	)


func _create_placement_system() -> FixturePlacementSystem:
	var placement: FixturePlacementSystem = FixturePlacementSystem.new()
	add_child_autofree(placement)
	placement.initialize(
		_system.get_grid(), null, null, 8,
		BuildModeGrid.StoreSize.SMALL
	)
	return placement


func _create_active_camera(
	position: Vector3,
	rotation: Vector3
) -> Camera3D:
	var pivot: Node3D = Node3D.new()
	add_child_autofree(pivot)
	var camera: Camera3D = Camera3D.new()
	pivot.add_child(camera)
	camera.current = true
	camera.global_position = position
	camera.global_rotation = rotation
	camera.fov = 70.0
	CameraManager.register_camera(camera)
	return camera
