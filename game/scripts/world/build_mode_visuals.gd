## Coordinates build mode visual feedback: ghost preview, cell overlay, and animations.
class_name BuildModeVisuals
extends Node3D

const SCALE_PUNCH_PEAK: float = 1.08
const SCALE_PUNCH_DURATION: float = 0.2

var _grid: BuildModeGrid = null
var _placement_system: FixturePlacementSystem = null
var _ghost: BuildModeGhost = null
var _cell_overlay: BuildModeCellOverlay = null


## Initializes visuals with required references.
func initialize(
	grid: BuildModeGrid,
	validator: FixturePlacementValidator,
	placement_system: FixturePlacementSystem
) -> void:
	_grid = grid
	_placement_system = placement_system

	_ghost = BuildModeGhost.new()
	_ghost.name = "GhostPreview"
	add_child(_ghost)
	_ghost.setup(grid)

	_cell_overlay = BuildModeCellOverlay.new()
	_cell_overlay.name = "CellOverlay"
	add_child(_cell_overlay)
	_cell_overlay.setup(grid, validator, placement_system)

	EventBus.build_mode_entered.connect(_on_build_mode_entered)
	EventBus.build_mode_exited.connect(_on_build_mode_exited)
	EventBus.fixture_placed.connect(_on_fixture_placed)
	EventBus.fixture_placement_invalid.connect(
		_on_fixture_placement_invalid
	)
	EventBus.fixture_selected.connect(_on_fixture_selected)


## Updates ghost preview position, rotation, and validity color.
func update_ghost(
	grid_pos: Variant,
	fixture_type: String,
	rotation: int
) -> void:
	if grid_pos == null or fixture_type.is_empty():
		_ghost.hide_ghost()
		return

	var cell: Vector2i = grid_pos as Vector2i
	var cells: Array[Vector2i] = _get_fixture_cells(
		fixture_type, cell, rotation
	)

	var result: PlacementResult = _placement_system.validate_placement(
		cells, fixture_type
	)

	_ghost.show_at_cells(cells, result.valid)


## Updates the fixture highlight based on hovered cell.
func update_highlight(hovered_cell: Variant) -> void:
	_cell_overlay.update_highlight(hovered_cell)


func _on_build_mode_entered() -> void:
	_cell_overlay.build_overlay()
	_cell_overlay.fade(true)


func _on_build_mode_exited() -> void:
	_ghost.hide_ghost()
	_cell_overlay.clear_selection()
	_cell_overlay.fade(false)


func _on_fixture_placed(
	fixture_id: String, grid_pos: Vector2i, _rotation: int
) -> void:
	_play_scale_punch(grid_pos)
	_cell_overlay.build_overlay()


func _on_fixture_placement_invalid(_reason: String) -> void:
	_ghost.play_shake()


func _on_fixture_selected(fixture_id: String) -> void:
	_cell_overlay.set_selected_fixture(fixture_id)


func _play_scale_punch(grid_pos: Vector2i) -> void:
	var world_pos: Vector3 = _grid.grid_to_world(grid_pos)
	var punch_node: Node3D = Node3D.new()
	punch_node.position = world_pos
	add_child(punch_node)

	var tween: Tween = create_tween()
	tween.tween_property(
		punch_node, "scale",
		Vector3(SCALE_PUNCH_PEAK, SCALE_PUNCH_PEAK, SCALE_PUNCH_PEAK),
		SCALE_PUNCH_DURATION * 0.5
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(
		punch_node, "scale",
		Vector3.ONE,
		SCALE_PUNCH_DURATION * 0.5
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(punch_node.queue_free)


func _get_fixture_cells(
	fixture_type: String,
	grid_pos: Vector2i,
	rotation: int
) -> Array[Vector2i]:
	var base_size: Vector2i = _placement_system.get_fixture_size(
		fixture_type
	)
	var size: Vector2i = base_size
	if rotation % 2 == 1:
		size = Vector2i(base_size.y, base_size.x)

	var cells: Array[Vector2i] = []
	for dx: int in range(size.x):
		for dy: int in range(size.y):
			cells.append(
				Vector2i(grid_pos.x + dx, grid_pos.y + dy)
			)
	return cells
