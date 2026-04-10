## Validates fixture placement against aisle, entry zone, and connectivity rules.
class_name FixturePlacementValidator
extends RefCounted

const MIN_AISLE_GAP: int = 2

var _grid_size: Vector2i = Vector2i.ZERO
var _entry_depth: int = 2
var _entry_edge: int = 0


## Configures the validator for a specific grid size and entry location.
## entry_edge: the grid row index where the doorway starts (lowest y).
func setup(grid_size: Vector2i, entry_edge_y: int) -> void:
	_grid_size = grid_size
	_entry_edge = entry_edge_y


## Returns true if the fixture cells avoid the entry zone.
func is_outside_entry_zone(
	cells: Array[Vector2i]
) -> bool:
	for cell: Vector2i in cells:
		if _is_in_entry_zone(cell):
			return false
	return true


## Returns true if minimum aisle width is maintained between the new
## fixture cells and all existing occupied cells.
func has_valid_aisles(
	new_cells: Array[Vector2i],
	occupied_cells: Dictionary
) -> bool:
	for new_cell: Vector2i in new_cells:
		for occ_key: Variant in occupied_cells:
			var occ_cell: Vector2i = occ_key as Vector2i
			var dx: int = absi(new_cell.x - occ_cell.x)
			var dy: int = absi(new_cell.y - occ_cell.y)
			# Fixtures must have >= MIN_AISLE_GAP cells between them
			if dx == 0 and dy > 0 and dy <= MIN_AISLE_GAP:
				return false
			if dy == 0 and dx > 0 and dx <= MIN_AISLE_GAP:
				return false
			if dx > 0 and dy > 0 and dx <= MIN_AISLE_GAP and dy <= MIN_AISLE_GAP:
				return false
			# Overlapping cell
			if dx == 0 and dy == 0:
				return false
	return true


## BFS from entry zone through empty cells. Returns true if all fixture
## cells have at least one adjacent reachable empty cell.
func is_layout_connected(
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

	# BFS through empty cells
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

	# Every fixture cell must be adjacent to a reachable empty cell
	for occ_key: Variant in all_occupied:
		var occ_cell: Vector2i = occ_key as Vector2i
		if not _has_reachable_neighbor(occ_cell, reachable):
			return false

	# Register must specifically be reachable
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
