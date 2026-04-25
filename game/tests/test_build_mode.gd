## GUT unit tests for BuildModeSystem enter/exit and FixturePlacementSystem workflow.
extends GutTest


var _build: BuildModeSystem
var _placement: FixturePlacementSystem
var _grid: BuildModeGrid
var _entry_edge_y: int = 8


func before_each() -> void:
	_build = BuildModeSystem.new()
	add_child_autofree(_build)

	_build.initialize(
		null, BuildModeGrid.StoreSize.SMALL, Vector3.ZERO
	)

	_grid = _build.get_grid()

	_placement = FixturePlacementSystem.new()
	add_child_autofree(_placement)
	_placement.initialize(
		_grid, null, null, _entry_edge_y,
		BuildModeGrid.StoreSize.SMALL
	)
	_build.set_placement_system(_placement)

	GameManager.current_state = GameManager.State.GAMEPLAY


func test_enter_build_mode_sets_active_and_emits_signal() -> void:
	watch_signals(EventBus)
	_build.enter_build_mode()

	assert_true(
		_build.is_active,
		"is_active should be true after entering build mode"
	)
	assert_signal_emitted(
		EventBus, "build_mode_entered",
		"Should emit build_mode_entered on enter"
	)


func test_exit_build_mode_clears_active_and_emits_signal() -> void:
	_placement.register_existing_fixture(
		"reg_01", "register", Vector2i(0, 0), 0, true, 90.0
	)
	_build.enter_build_mode()
	watch_signals(EventBus)

	_build.exit_build_mode()

	assert_false(
		_build.is_active,
		"is_active should be false after exiting build mode"
	)
	assert_signal_emitted(
		EventBus, "build_mode_exited",
		"Should emit build_mode_exited on exit"
	)


func test_place_fixture_valid_cell_succeeds_and_emits() -> void:
	watch_signals(EventBus)
	_placement.select_fixture("floor_rack")
	var placed: bool = _placement.try_place(Vector2i(5, 5))

	assert_true(placed, "Placement on empty valid cell should succeed")
	assert_signal_emitted(
		EventBus, "fixture_placed",
		"Should emit fixture_placed on success"
	)


func test_place_fixture_occupied_cell_fails_no_signal() -> void:
	_placement.register_existing_fixture(
		"blocker", "floor_rack", Vector2i(5, 5), 0, false, 50.0
	)
	watch_signals(EventBus)
	_placement.select_fixture("floor_rack")
	var placed: bool = _placement.try_place(Vector2i(5, 5))

	assert_false(placed, "Placement on occupied cell should fail")
	assert_signal_not_emitted(
		EventBus, "fixture_placed",
		"Should not emit fixture_placed on failure"
	)


func test_remove_fixture_occupied_cell_succeeds_and_emits() -> void:
	_placement.register_existing_fixture(
		"reg_01", "register", Vector2i(0, 0), 0, true, 90.0
	)
	_placement.register_existing_fixture(
		"target", "floor_rack", Vector2i(5, 5), 0, false, 50.0
	)
	watch_signals(EventBus)
	var removed: bool = _placement.try_remove(Vector2i(5, 5))

	assert_true(removed, "Removal of placed fixture should succeed")
	assert_signal_emitted(
		EventBus, "fixture_removed",
		"Should emit fixture_removed on success"
	)


func test_remove_fixture_empty_cell_is_noop() -> void:
	watch_signals(EventBus)
	var removed: bool = _placement.try_remove(Vector2i(7, 7))

	assert_false(removed, "Removal on empty cell should return false")
	assert_signal_not_emitted(
		EventBus, "fixture_removed",
		"Should not emit fixture_removed for empty cell"
	)


func test_validate_placement_outside_boundary_fails() -> void:
	var out_of_bounds: Array[Vector2i] = [
		Vector2i(13, 3), Vector2i(14, 3)
	]
	var result: PlacementResult = _placement.validate_placement(
		out_of_bounds, "glass_case"
	)

	assert_false(
		result.valid,
		"Placement outside store boundary should be invalid"
	)
	assert_eq(result.reason, "out_of_bounds")


func test_fixture_count_after_place_and_remove_sequence() -> void:
	_placement.register_existing_fixture(
		"reg_01", "register", Vector2i(0, 0), 0, true, 90.0
	)
	assert_eq(
		_placement.get_fixture_count(), 0,
		"Count should be 0 with only register"
	)

	_placement.select_fixture("floor_rack")
	_placement.try_place(Vector2i(3, 3))
	assert_eq(
		_placement.get_fixture_count(), 1,
		"Count should be 1 after placing one fixture"
	)

	_placement.try_place(Vector2i(5, 5))
	assert_eq(
		_placement.get_fixture_count(), 2,
		"Count should be 2 after placing two fixtures"
	)

	_placement.try_remove(Vector2i(3, 3))
	assert_eq(
		_placement.get_fixture_count(), 1,
		"Count should be 1 after removing one fixture"
	)
