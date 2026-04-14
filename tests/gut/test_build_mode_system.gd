## Tests for BuildModeSystem state machine, grid initialization, and signal emission.
extends GutTest


var _system: BuildModeSystem


func before_each() -> void:
	_system = BuildModeSystem.new()
	add_child_autofree(_system)


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
		placed_args = [fid, pos, rot]
	EventBus.fixture_placed.connect(handler)
	EventBus.fixture_placed.emit("test_fixture", Vector2i(3, 4), 2)
	assert_eq(placed_args.size(), 3)
	assert_eq(placed_args[0], "test_fixture")
	assert_eq(placed_args[1], Vector2i(3, 4))
	assert_eq(placed_args[2], 2)
	EventBus.fixture_placed.disconnect(handler)


func test_fixture_placement_invalid_signal() -> void:
	var reason_received: String = ""
	var handler := func(reason: String) -> void:
		reason_received = reason
	EventBus.fixture_placement_invalid.connect(handler)
	EventBus.fixture_placement_invalid.emit("Test rejection")
	assert_eq(reason_received, "Test rejection")
	EventBus.fixture_placement_invalid.disconnect(handler)


func test_confirmation_duration_positive() -> void:
	assert_gt(
		BuildModeSystem.CONFIRMATION_DURATION, 0.0,
		"Confirmation duration should be positive"
	)
