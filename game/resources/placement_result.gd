## Result of a fixture placement validation containing validity, reason, and blocking cells.
class_name PlacementResult
extends Resource

var valid: bool = true
var reason: String = ""
var blocking_cells: Array[Vector2i] = []


static func success() -> PlacementResult:
	var result := PlacementResult.new()
	result.valid = true
	return result


static func failure(
	fail_reason: String,
	cells: Array[Vector2i] = []
) -> PlacementResult:
	var result := PlacementResult.new()
	result.valid = false
	result.reason = fail_reason
	result.blocking_cells = cells
	return result
