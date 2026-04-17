## Tests for BuildModeVisuals ghost preview, cell overlay, and feedback animations.
extends GutTest


var _visuals: BuildModeVisuals
var _grid: BuildModeGrid
var _validator: FixturePlacementValidator
var _placement: FixturePlacementSystem


func before_each() -> void:
	_grid = BuildModeGrid.new()
	add_child_autofree(_grid)
	_grid.initialize(
		BuildModeGrid.StoreSize.SMALL, Vector3.ZERO
	)

	_validator = FixturePlacementValidator.new()
	_validator.setup(
		_grid.grid_size, 0, BuildModeGrid.StoreSize.SMALL
	)

	_placement = FixturePlacementSystem.new()
	add_child_autofree(_placement)
	_placement.initialize(
		_grid, null, null, 0, BuildModeGrid.StoreSize.SMALL
	)

	_visuals = BuildModeVisuals.new()
	add_child_autofree(_visuals)
	_visuals.initialize(_grid, _validator, _placement)


func test_ghost_colors_match_spec() -> void:
	assert_eq(
		BuildModeGhost.VALID_COLOR,
		Color(0.2, 0.8, 0.2, 0.4)
	)
	assert_eq(
		BuildModeGhost.INVALID_COLOR,
		Color(0.8, 0.2, 0.2, 0.4)
	)


func test_cell_overlay_colors_match_spec() -> void:
	assert_eq(
		BuildModeCellOverlay.CELL_EMPTY_COLOR,
		Color(1.0, 1.0, 1.0, 0.1)
	)
	assert_eq(
		BuildModeCellOverlay.CELL_OCCUPIED_COLOR,
		Color(0.5, 0.5, 0.5, 0.3)
	)
	assert_eq(
		BuildModeCellOverlay.CELL_ENTRY_ZONE_COLOR,
		Color(1.0, 1.0, 0.0, 0.2)
	)


func test_highlight_colors_match_spec() -> void:
	assert_eq(
		BuildModeCellOverlay.HIGHLIGHT_BLUE,
		Color(0.2, 0.4, 1.0, 0.6)
	)
	assert_eq(
		BuildModeCellOverlay.HIGHLIGHT_YELLOW,
		Color(1.0, 0.9, 0.2, 0.5)
	)


func test_ghost_hidden_by_default() -> void:
	var ghost: Node3D = _visuals.get_node("GhostPreview")
	assert_not_null(ghost)
	assert_false(ghost.visible)


func test_cell_overlay_container_hidden_by_default() -> void:
	var overlay: Node3D = _visuals.get_node("CellOverlay")
	assert_not_null(overlay)
	var container: Node3D = overlay.get_node("CellsContainer")
	assert_not_null(container)
	assert_false(container.visible)


func test_update_ghost_null_hides() -> void:
	_visuals.update_ghost(null, "floor_rack", 0)
	var ghost: Node3D = _visuals.get_node("GhostPreview")
	assert_false(ghost.visible)


func test_update_ghost_empty_type_hides() -> void:
	_visuals.update_ghost(Vector2i(5, 5), "", 0)
	var ghost: Node3D = _visuals.get_node("GhostPreview")
	assert_false(ghost.visible)


func test_update_ghost_shows_for_valid_input() -> void:
	_placement.select_fixture("floor_rack")
	_visuals.update_ghost(Vector2i(5, 5), "floor_rack", 0)
	var ghost: Node3D = _visuals.get_node("GhostPreview")
	assert_true(ghost.visible)


func test_update_ghost_snaps_to_grid_cell_center() -> void:
	_placement.select_fixture("floor_rack")
	_visuals.update_ghost(Vector2i(5, 5), "floor_rack", 0)
	var ghost: Node3D = _visuals.get_node("GhostPreview")
	var expected: Vector3 = _grid.grid_to_world(Vector2i(5, 5))
	assert_almost_eq(ghost.position.x, expected.x, 0.001)
	assert_almost_eq(
		ghost.position.y,
		expected.y + BuildModeGhost.Y_OFFSET,
		0.001
	)
	assert_almost_eq(ghost.position.z, expected.z, 0.001)


func test_update_ghost_marks_invalid_when_validator_rejects() -> void:
	_placement.select_fixture("floor_rack")
	_visuals.update_ghost(Vector2i(5, 0), "floor_rack", 0)
	var ghost: BuildModeGhost = _visuals.get_node("GhostPreview")
	assert_true(ghost.visible)
	assert_false(ghost.is_valid)


func test_ghost_creates_mesh_children() -> void:
	_placement.select_fixture("floor_rack")
	_visuals.update_ghost(Vector2i(5, 5), "floor_rack", 0)
	var ghost: Node3D = _visuals.get_node("GhostPreview")
	assert_gt(ghost.get_child_count(), 0)


func test_ghost_multi_cell_fixture() -> void:
	_placement.select_fixture("wall_shelf")
	_visuals.update_ghost(Vector2i(0, 5), "wall_shelf", 0)
	var ghost: Node3D = _visuals.get_node("GhostPreview")
	assert_eq(ghost.get_child_count(), 2)


func test_ghost_rotation_preserves_cell_count() -> void:
	_placement.select_fixture("wall_shelf")
	_visuals.update_ghost(Vector2i(5, 5), "wall_shelf", 0)
	var ghost: Node3D = _visuals.get_node("GhostPreview")
	var count_r0: int = ghost.get_child_count()

	_visuals.update_ghost(Vector2i(5, 5), "wall_shelf", 1)
	var count_r1: int = ghost.get_child_count()
	assert_eq(count_r0, count_r1)


func test_scale_punch_constants() -> void:
	assert_almost_eq(
		BuildModeVisuals.SCALE_PUNCH_PEAK, 1.08, 0.001
	)
	assert_almost_eq(
		BuildModeVisuals.SCALE_PUNCH_DURATION, 0.2, 0.001
	)


func test_shake_constants() -> void:
	assert_eq(BuildModeGhost.SHAKE_OSCILLATIONS, 3)
	assert_almost_eq(
		BuildModeGhost.SHAKE_DURATION, 0.2, 0.001
	)


func test_grid_cell_size_half_meter() -> void:
	assert_almost_eq(BuildModeGrid.CELL_SIZE, 0.5, 0.001)


func test_pulse_constants() -> void:
	assert_almost_eq(
		BuildModeGhost.PULSE_SPEED, 4.0, 0.001
	)
	assert_almost_eq(
		BuildModeGhost.PULSE_MIN_ALPHA, 0.2, 0.001
	)
	assert_almost_eq(
		BuildModeGhost.PULSE_MAX_ALPHA, 0.5, 0.001
	)
