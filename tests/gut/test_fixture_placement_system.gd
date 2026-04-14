## Tests for FixturePlacementSystem grid snapping, collision, placement, and serialization.
extends GutTest


var _system: FixturePlacementSystem
var _grid: BuildModeGrid
var _validator: FixturePlacementValidator
var _grid_size: Vector2i = Vector2i(14, 10)
var _entry_edge_y: int = 8


func before_each() -> void:
	_system = FixturePlacementSystem.new()
	add_child_autofree(_system)

	_grid = BuildModeGrid.new()
	add_child_autofree(_grid)
	_grid.initialize(
		BuildModeGrid.StoreSize.SMALL, Vector3.ZERO
	)

	_system.initialize(
		_grid, null, null, _entry_edge_y,
		BuildModeGrid.StoreSize.SMALL
	)

	_validator = FixturePlacementValidator.new()
	_validator.setup(
		_grid_size, _entry_edge_y, BuildModeGrid.StoreSize.SMALL
	)


# -- Grid snapping via BuildModeGrid.world_to_grid --


func test_snap_to_grid_rounds_to_nearest_cell() -> void:
	var origin: Vector3 = _grid.grid_origin
	var cell_size: float = BuildModeGrid.CELL_SIZE
	var world_pos := Vector3(
		origin.x + 1.3 * cell_size,
		0.0,
		origin.z + 2.7 * cell_size
	)
	var result: Variant = _grid.world_to_grid(world_pos)
	assert_not_null(result, "Should return valid grid coords")
	assert_eq(result, Vector2i(1, 2))


func test_snap_to_grid_handles_negative_coordinates() -> void:
	var world_pos := Vector3(
		_grid.grid_origin.x - 1.0,
		0.0,
		_grid.grid_origin.z - 1.0
	)
	var result: Variant = _grid.world_to_grid(world_pos)
	assert_null(result, "Negative coords outside grid return null")


func test_snap_to_grid_at_origin() -> void:
	var origin: Vector3 = _grid.grid_origin
	var result: Variant = _grid.world_to_grid(
		Vector3(origin.x + 0.01, 0.0, origin.z + 0.01)
	)
	assert_eq(result, Vector2i(0, 0))


func test_snap_to_grid_at_max_boundary() -> void:
	var origin: Vector3 = _grid.grid_origin
	var cell_size: float = BuildModeGrid.CELL_SIZE
	var world_pos := Vector3(
		origin.x + _grid_size.x * cell_size + 0.1,
		0.0,
		origin.z + 0.1
	)
	var result: Variant = _grid.world_to_grid(world_pos)
	assert_null(result, "Beyond max boundary returns null")


# -- Placement validation (can_place) --


func test_can_place_returns_true_for_empty_cells() -> void:
	_system.select_fixture("glass_case")
	var cells: Array[Vector2i] = [Vector2i(3, 3), Vector2i(4, 3)]
	var result: PlacementResult = _system.validate_placement(
		cells, "glass_case"
	)
	assert_true(
		result.valid, "2x1 on empty grid should be placeable"
	)


func test_can_place_returns_false_when_cell_occupied() -> void:
	_system.register_existing_fixture(
		"existing_01", "floor_rack", Vector2i(4, 3),
		0, false, 50.0
	)
	var cells: Array[Vector2i] = [Vector2i(3, 3), Vector2i(4, 3)]
	var result: PlacementResult = _system.validate_placement(
		cells, "glass_case"
	)
	assert_false(
		result.valid,
		"Placement overlapping occupied cell should fail"
	)


func test_can_place_returns_false_out_of_bounds() -> void:
	var cells: Array[Vector2i] = [Vector2i(13, 3), Vector2i(14, 3)]
	var result: PlacementResult = _system.validate_placement(
		cells, "glass_case"
	)
	assert_false(result.valid, "Out of bounds should fail")
	assert_eq(result.reason, "out_of_bounds")


# -- Fixture registry (place / remove / query) --


func test_place_fixture_registers_all_occupied_cells() -> void:
	_system.register_existing_fixture(
		"f_001", "glass_case", Vector2i(3, 3),
		0, false, 80.0
	)
	var occupied: Dictionary = _system.get_all_occupied_cells()
	assert_true(
		occupied.has(Vector2i(3, 3)),
		"First cell should be occupied"
	)
	assert_true(
		occupied.has(Vector2i(4, 3)),
		"Second cell of 2x1 should be occupied"
	)


func test_remove_fixture_frees_all_occupied_cells() -> void:
	_system.register_existing_fixture(
		"reg_01", "register", Vector2i(0, 0),
		0, true, 90.0
	)
	_system.register_existing_fixture(
		"f_002", "glass_case", Vector2i(3, 3),
		0, false, 80.0
	)
	var removed: bool = _system.try_remove(Vector2i(3, 3))
	assert_true(removed, "Removal should succeed")
	var occupied: Dictionary = _system.get_all_occupied_cells()
	assert_false(
		occupied.has(Vector2i(3, 3)),
		"First cell should be freed"
	)
	assert_false(
		occupied.has(Vector2i(4, 3)),
		"Second cell should be freed"
	)


func test_get_fixtures_at_position_returns_correct_fixture() -> void:
	_system.register_existing_fixture(
		"f_003", "floor_rack", Vector2i(5, 5),
		0, false, 50.0
	)
	assert_eq(
		_system.get_fixture_at(Vector2i(5, 5)), "f_003"
	)
	assert_eq(
		_system.get_fixture_at(Vector2i(6, 6)), "",
		"Empty cell should return empty string"
	)


func test_placed_fixture_list_is_serializable() -> void:
	_system.register_existing_fixture(
		"f_004", "wall_shelf", Vector2i(0, 3),
		1, false, 30.0
	)
	var save_data: Dictionary = _system.get_save_data()
	assert_has(save_data, "placed_fixtures")
	var fixtures: Array = save_data["placed_fixtures"]
	assert_eq(fixtures.size(), 1)

	var entry: Dictionary = fixtures[0]
	assert_has(entry, "fixture_id")
	assert_has(entry, "fixture_type")
	assert_has(entry, "grid_position")
	assert_has(entry, "rotation")
	assert_eq(entry["fixture_id"], "f_004")
	assert_eq(entry["fixture_type"], "wall_shelf")
	assert_eq(entry["rotation"], 1)
	assert_true(
		entry["grid_position"] is Array,
		"grid_position should be serialized as Array"
	)


func test_placement_exceeds_max_fixtures_cap_returns_false() -> void:
	for i: int in range(6):
		_system.register_existing_fixture(
			"cap_%d" % i, "floor_rack",
			Vector2i(i * 3, 0), 0, false, 50.0
		)
	var cells: Array[Vector2i] = [Vector2i(3, 5)]
	var result: PlacementResult = _system.validate_placement(
		cells, "floor_rack"
	)
	assert_false(result.valid, "Should reject when at max cap")
	assert_eq(result.reason, "max_fixtures_reached")


# -- Additional edge cases --


func test_register_fixture_cannot_be_removed() -> void:
	_system.register_existing_fixture(
		"reg_main", "register", Vector2i(5, 5),
		0, true, 90.0
	)
	var removed: bool = _system.try_remove(Vector2i(5, 5))
	assert_false(removed, "Register should not be removable")


func test_fixture_count_excludes_register() -> void:
	_system.register_existing_fixture(
		"reg_01", "register", Vector2i(0, 0),
		0, true, 90.0
	)
	_system.register_existing_fixture(
		"f_010", "floor_rack", Vector2i(5, 5),
		0, false, 50.0
	)
	assert_eq(
		_system.get_fixture_count(), 1,
		"Count should exclude register"
	)


func test_rotated_fixture_swaps_dimensions() -> void:
	_system.register_existing_fixture(
		"f_011", "endcap", Vector2i(3, 3),
		1, false, 60.0
	)
	var occupied: Dictionary = _system.get_all_occupied_cells()
	assert_true(occupied.has(Vector2i(3, 3)))
	assert_true(occupied.has(Vector2i(4, 3)))
	assert_false(
		occupied.has(Vector2i(3, 4)),
		"Rotation 1 should swap 1x2 to 2x1"
	)


func test_save_data_round_trip() -> void:
	_system.register_existing_fixture(
		"reg_rt", "register", Vector2i(0, 0),
		0, true, 90.0
	)
	_system.register_existing_fixture(
		"f_rt1", "glass_case", Vector2i(5, 3),
		0, false, 80.0
	)
	var save_data: Dictionary = _system.get_save_data()

	var loaded_system := FixturePlacementSystem.new()
	add_child_autofree(loaded_system)
	var loaded_grid := BuildModeGrid.new()
	add_child_autofree(loaded_grid)
	loaded_grid.initialize(
		BuildModeGrid.StoreSize.SMALL, Vector3.ZERO
	)
	loaded_system.initialize(
		loaded_grid, null, null, _entry_edge_y,
		BuildModeGrid.StoreSize.SMALL
	)
	loaded_system.load_save_data(save_data)

	assert_eq(
		loaded_system.get_fixture_at(Vector2i(5, 3)), "f_rt1"
	)
	assert_eq(
		loaded_system.get_fixture_at(Vector2i(6, 3)), "f_rt1"
	)
	assert_eq(
		loaded_system.get_fixture_at(Vector2i(0, 0)), "reg_rt"
	)


# -- Validator unit tests --


func test_placement_result_success() -> void:
	var result: PlacementResult = PlacementResult.success()
	assert_true(result.valid)
	assert_eq(result.reason, "")
	assert_eq(result.blocking_cells.size(), 0)


func test_placement_result_failure() -> void:
	var cells: Array[Vector2i] = [Vector2i(1, 2)]
	var result: PlacementResult = PlacementResult.failure(
		"test_reason", cells
	)
	assert_false(result.valid)
	assert_eq(result.reason, "test_reason")
	assert_eq(result.blocking_cells[0], Vector2i(1, 2))


func test_entry_zone_blocked() -> void:
	var cells: Array[Vector2i] = [Vector2i(3, 8)]
	var result: PlacementResult = _validator.validate_placement(
		cells, {}, [], 0, false
	)
	assert_false(result.valid)
	assert_eq(result.reason, "entry_zone_blocked")


func test_wall_required_shelf_in_center() -> void:
	var cells: Array[Vector2i] = [Vector2i(5, 5)]
	var result: PlacementResult = _validator.validate_placement(
		cells, {}, [], 0, true
	)
	assert_false(result.valid)
	assert_eq(result.reason, "wall_required")


func test_wall_shelf_against_wall_valid() -> void:
	var cells: Array[Vector2i] = [Vector2i(0, 5)]
	var result: PlacementResult = _validator.validate_placement(
		cells, {}, [], 0, true
	)
	assert_true(result.valid)


func test_cell_state_enum() -> void:
	assert_eq(
		_validator.get_cell_state(Vector2i(5, 5), {}),
		FixturePlacementValidator.CellState.EMPTY
	)
	assert_eq(
		_validator.get_cell_state(
			Vector2i(5, 5), {Vector2i(5, 5): "f1"}
		),
		FixturePlacementValidator.CellState.OCCUPIED
	)
	assert_eq(
		_validator.get_cell_state(Vector2i(-1, 5), {}),
		FixturePlacementValidator.CellState.WALL
	)
	assert_eq(
		_validator.get_cell_state(Vector2i(5, 8), {}),
		FixturePlacementValidator.CellState.ENTRY_ZONE
	)
