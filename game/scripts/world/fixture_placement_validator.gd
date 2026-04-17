## Validates fixture placement against aisle, entry zone, wall, count, and connectivity rules.
class_name FixturePlacementValidator
extends RefCounted

enum CellState { EMPTY, OCCUPIED, WALL, ENTRY_ZONE }

const MIN_AISLE_GAP: int = 2

const MAX_FIXTURES: Dictionary = {
	BuildModeGrid.StoreSize.SMALL: 6,
	BuildModeGrid.StoreSize.MEDIUM: 8,
	BuildModeGrid.StoreSize.LARGE: 12,
}

var _grid_size: Vector2i = Vector2i.ZERO
var _entry_depth: int = 2
var _entry_edge: int = 0
var _store_size: BuildModeGrid.StoreSize = BuildModeGrid.StoreSize.SMALL


## Configures the validator for a specific grid size and entry location.
func setup(
	grid_size: Vector2i,
	entry_edge_y: int,
	store_size: BuildModeGrid.StoreSize = BuildModeGrid.StoreSize.SMALL
) -> void:
	_grid_size = grid_size
	_entry_edge = entry_edge_y
	_store_size = store_size


## Returns the CellState for a given cell position.
func get_cell_state(
	cell: Vector2i, occupied_cells: Dictionary
) -> CellState:
	if not _is_in_bounds(cell):
		return CellState.WALL
	if _is_in_entry_zone(cell):
		return CellState.ENTRY_ZONE
	if occupied_cells.has(cell):
		return CellState.OCCUPIED
	return CellState.EMPTY


## Full validation returning a PlacementResult.
func validate_placement(
	cells: Array[Vector2i],
	occupied_cells: Dictionary,
	register_cells: Array[Vector2i],
	fixture_count: int,
	requires_wall: bool
) -> PlacementResult:
	for cell: Vector2i in cells:
		if not _is_in_bounds(cell):
			return PlacementResult.failure(
				"out_of_bounds", [cell]
			)

	var entry_blocked: Array[Vector2i] = _get_entry_zone_conflicts(cells)
	if not entry_blocked.is_empty():
		return PlacementResult.failure(
			"entry_zone_blocked", entry_blocked
		)

	var max_allowed: int = MAX_FIXTURES.get(_store_size, 6)
	if fixture_count >= max_allowed:
		return PlacementResult.failure("max_fixtures_reached", cells)

	if requires_wall and not _is_against_wall(cells):
		return PlacementResult.failure("wall_required", cells)

	var narrow_cells: Array[Vector2i] = _get_narrow_aisle_cells(
		cells, occupied_cells
	)
	if not narrow_cells.is_empty():
		return PlacementResult.failure(
			"aisle_too_narrow", narrow_cells
		)

	var test_occupied: Dictionary = occupied_cells.duplicate()
	for cell: Vector2i in cells:
		test_occupied[cell] = "pending"

	if not _is_layout_connected(test_occupied, register_cells):
		return PlacementResult.failure("not_reachable", cells)

	return PlacementResult.success()


## Returns true if the fixture cells avoid the entry zone.
func is_outside_entry_zone(cells: Array[Vector2i]) -> bool:
	for cell: Vector2i in cells:
		if _is_in_entry_zone(cell):
			return false
	return true


## Returns true if minimum aisle width is maintained.
func has_valid_aisles(
	new_cells: Array[Vector2i],
	occupied_cells: Dictionary
) -> bool:
	return _get_narrow_aisle_cells(new_cells, occupied_cells).is_empty()


## BFS from entry zone through empty cells. Returns true if every empty cell and
## every occupied fixture/register cell remains reachable from the entrance.
func is_layout_connected(
	all_occupied: Dictionary,
	register_cells: Array[Vector2i]
) -> bool:
	return _is_layout_connected(all_occupied, register_cells)


## Checks whether a register fixture exists.
func has_register(register_fixture_id: String) -> PlacementResult:
	if register_fixture_id.is_empty():
		return PlacementResult.failure("no_register")
	return PlacementResult.success()


## Returns true if any cell in the set is on the grid boundary (wall-adjacent).
func _is_against_wall(cells: Array[Vector2i]) -> bool:
	for cell: Vector2i in cells:
		if (
			cell.x == 0
			or cell.x == _grid_size.x - 1
			or cell.y == 0
			or cell.y == _grid_size.y - 1
		):
			return true
	return false


func _get_entry_zone_conflicts(
	cells: Array[Vector2i]
) -> Array[Vector2i]:
	var conflicts: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if _is_in_entry_zone(cell):
			conflicts.append(cell)
	return conflicts


func _get_narrow_aisle_cells(
	new_cells: Array[Vector2i],
	occupied_cells: Dictionary
) -> Array[Vector2i]:
	var narrow: Array[Vector2i] = []
	for new_cell: Vector2i in new_cells:
		for occ_key: Variant in occupied_cells:
			var occ_cell: Vector2i = occ_key as Vector2i
			var dx: int = absi(new_cell.x - occ_cell.x)
			var dy: int = absi(new_cell.y - occ_cell.y)
			if dx == 0 and dy == 0:
				if new_cell not in narrow:
					narrow.append(new_cell)
				continue
			if dx == 0 and dy > 0 and dy <= MIN_AISLE_GAP:
				if new_cell not in narrow:
					narrow.append(new_cell)
			elif dy == 0 and dx > 0 and dx <= MIN_AISLE_GAP:
				if new_cell not in narrow:
					narrow.append(new_cell)
	return narrow


func _is_layout_connected(
	all_occupied: Dictionary,
	register_cells: Array[Vector2i]
) -> bool:
	var entry_cells: Array[Vector2i] = _get_entry_zone_cells()
	if entry_cells.is_empty():
		return true

	var reachable: Dictionary = {}
	var queue: Array[Vector2i] = []

	for cell: Vector2i in entry_cells:
		if not all_occupied.has(cell):
			reachable[cell] = true
			queue.append(cell)

	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for offset: Vector2i in _cardinal_offsets():
			var neighbor: Vector2i = current + offset
			if not _is_in_bounds(neighbor):
				continue
			if reachable.has(neighbor):
				continue
			if all_occupied.has(neighbor):
				continue
			reachable[neighbor] = true
			queue.append(neighbor)

	for x: int in range(_grid_size.x):
		for y: int in range(_grid_size.y):
			var cell := Vector2i(x, y)
			if all_occupied.has(cell):
				continue
			if not reachable.has(cell):
				return false

	for occ_key: Variant in all_occupied:
		var occ_cell: Vector2i = occ_key as Vector2i
		if not _has_reachable_neighbor(occ_cell, reachable):
			return false

	for reg_cell: Vector2i in register_cells:
		if not _has_reachable_neighbor(reg_cell, reachable):
			return false

	return true


func _is_in_entry_zone(cell: Vector2i) -> bool:
	return (
		cell.y >= _entry_edge
		and cell.y < _entry_edge + _entry_depth
		and cell.x >= 0
		and cell.x < _grid_size.x
	)


func _get_entry_zone_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x: int in range(_grid_size.x):
		for y: int in range(_entry_edge, _entry_edge + _entry_depth):
			if _is_in_bounds(Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	return cells


func _is_in_bounds(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.x < _grid_size.x
		and cell.y >= 0
		and cell.y < _grid_size.y
	)


func _has_reachable_neighbor(
	cell: Vector2i, reachable: Dictionary
) -> bool:
	for offset: Vector2i in _cardinal_offsets():
		var neighbor: Vector2i = cell + offset
		if reachable.has(neighbor):
			return true
	return false


func _cardinal_offsets() -> Array[Vector2i]:
	return [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
	]
