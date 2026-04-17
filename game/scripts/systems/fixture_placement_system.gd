## Manages fixture placement, removal, and validation on the build mode grid.
class_name FixturePlacementSystem
extends Node

const FIXTURE_SIZES: Dictionary = {
	"wall_shelf": Vector2i(2, 1),
	"glass_case": Vector2i(2, 1),
	"floor_rack": Vector2i(1, 1),
	"counter": Vector2i(3, 1),
	"register": Vector2i(1, 1),
	"endcap": Vector2i(1, 2),
	"storage_unit": Vector2i(1, 2),
}

const FIXTURE_PRICES: Dictionary = {
	"wall_shelf": 30.0,
	"glass_case": 80.0,
	"floor_rack": 50.0,
	"counter": 120.0,
	"register": 90.0,
	"endcap": 60.0,
	"storage_unit": 40.0,
}

const SELLBACK_RATE: float = 0.5

var _grid: BuildModeGrid = null
var _validator: FixturePlacementValidator = null
var _overlay: FixturePlacementOverlay = null
var _inventory_system: InventorySystem = null
var _economy_system: EconomySystem = null
var _data_loader: DataLoader = null
var _upgrade_handler: FixtureUpgradeHandler = null

var _placed_fixtures: Dictionary = {}
var _occupied_cells: Dictionary = {}
var _selected_fixture_type: String = ""
var _current_rotation: int = 0
var _register_cells: Array[Vector2i] = []
var _register_fixture_id: String = ""
var needs_nav_rebake: bool = false


## Sets the DataLoader for fixture definition lookups.
func set_data_loader(loader: DataLoader) -> void:
	_data_loader = loader


## Returns the size of a fixture type from definitions or fallback.
func get_fixture_size(fixture_type: String) -> Vector2i:
	if _data_loader:
		var def: FixtureDefinition = (
			_data_loader.get_fixture(fixture_type)
		)
		if def:
			return def.grid_size
	return FIXTURE_SIZES.get(fixture_type, Vector2i(1, 1)) as Vector2i


## Returns the price of a fixture type from definitions or fallback.
func get_fixture_price(fixture_type: String) -> float:
	if _data_loader:
		var def: FixtureDefinition = (
			_data_loader.get_fixture(fixture_type)
		)
		if def:
			return def.price
	return FIXTURE_PRICES.get(fixture_type, 0.0) as float


## Returns whether a fixture type requires wall placement.
func is_wall_required(fixture_type: String) -> bool:
	if _data_loader:
		var def: FixtureDefinition = (
			_data_loader.get_fixture(fixture_type)
		)
		if def:
			return def.requires_wall
	return fixture_type.contains("shelf") or fixture_type.contains("wall")


## Returns the number of placed fixtures (excluding register).
func get_fixture_count() -> int:
	var count: int = 0
	for fixture_id: String in _placed_fixtures:
		var data: Dictionary = _placed_fixtures[fixture_id]
		if not data.get("is_register", false):
			count += 1
	return count


## Sets up the system with required references.
func initialize(
	grid: BuildModeGrid,
	inventory_system: InventorySystem,
	economy_system: EconomySystem,
	entry_edge_y: int,
	store_size: BuildModeGrid.StoreSize = BuildModeGrid.StoreSize.SMALL
) -> void:
	_grid = grid
	_inventory_system = inventory_system
	_economy_system = economy_system

	_validator = FixturePlacementValidator.new()
	_validator.setup(grid.grid_size, entry_edge_y, store_size)

	_overlay = FixturePlacementOverlay.new()
	_overlay.name = "FixturePlacementOverlay"
	add_child(_overlay)
	_overlay.setup(BuildModeGrid.CELL_SIZE, grid.grid_origin)


## Sets the ReputationSystem and initializes the upgrade handler.
func set_reputation_system(system: ReputationSystem) -> void:
	_upgrade_handler = FixtureUpgradeHandler.new()
	_upgrade_handler.initialize(
		_placed_fixtures, _data_loader,
		_economy_system, system
	)


## Registers an existing fixture on the grid (for initial store layout).
func register_existing_fixture(
	fixture_id: String,
	fixture_type: String,
	grid_pos: Vector2i,
	rotation: int,
	is_register: bool,
	purchase_price: float,
	tier: int = FixtureDefinition.TierLevel.BASIC,
	total_spent: float = -1.0
) -> void:
	var cells: Array[Vector2i] = _get_fixture_cells(
		fixture_type, grid_pos, rotation
	)
	var actual_total: float = (
		total_spent if total_spent >= 0.0 else purchase_price
	)
	var data: Dictionary = {
		"fixture_id": fixture_id,
		"fixture_type": fixture_type,
		"grid_position": grid_pos,
		"rotation": rotation,
		"is_register": is_register,
		"purchase_price": purchase_price,
		"tier": tier,
		"total_spent": actual_total,
		"cells": cells,
	}
	_placed_fixtures[fixture_id] = data
	for cell: Vector2i in cells:
		_occupied_cells[cell] = fixture_id

	if is_register:
		_register_fixture_id = fixture_id
		_register_cells = cells


## Selects a fixture type for placement.
func select_fixture(fixture_type: String) -> void:
	_selected_fixture_type = fixture_type
	_current_rotation = 0


## Clears the current fixture selection.
func deselect_fixture() -> void:
	_selected_fixture_type = ""
	_current_rotation = 0
	_overlay.clear()


## Rotates the selected fixture 90 degrees clockwise.
func rotate_fixture() -> void:
	_current_rotation = (_current_rotation + 1) % 4


## Returns the validator for external read-only queries.
func get_validator() -> FixturePlacementValidator:
	return _validator


## Returns the currently selected fixture type.
func get_selected_fixture_type() -> String:
	return _selected_fixture_type


## Returns the current rotation step (0-3).
func get_current_rotation() -> int:
	return _current_rotation


## Updates the placement preview overlay at the hovered cell.
func update_preview(hovered_cell: Variant) -> void:
	if _selected_fixture_type.is_empty():
		_overlay.clear()
		return

	if hovered_cell == null:
		_overlay.clear()
		return

	var cell: Vector2i = hovered_cell as Vector2i
	var cells: Array[Vector2i] = _get_fixture_cells(
		_selected_fixture_type, cell, _current_rotation
	)
	var result: PlacementResult = validate_placement(
		cells, _selected_fixture_type
	)
	_overlay.show_cells(cells, result.valid)


## Validates placement of cells for a given fixture type, returning a PlacementResult.
func validate_placement(
	cells: Array[Vector2i],
	fixture_type: String
) -> PlacementResult:
	return _validator.validate_placement(
		cells,
		_occupied_cells,
		_register_cells,
		get_fixture_count(),
		is_wall_required(fixture_type),
	)


## Checks whether a register exists for build mode exit validation.
func validate_register_exists() -> PlacementResult:
	return _validator.has_register(_register_fixture_id)


## Attempts to place the selected fixture at the given cell.
func try_place(grid_pos: Vector2i) -> bool:
	if _selected_fixture_type.is_empty():
		return false

	if _data_loader:
		var def: FixtureDefinition = _data_loader.get_fixture(_selected_fixture_type)
		if not def and not FIXTURE_SIZES.has(_selected_fixture_type):
			push_error("Unknown fixture type: %s" % _selected_fixture_type)
			return false

	var cells: Array[Vector2i] = _get_fixture_cells(
		_selected_fixture_type, grid_pos, _current_rotation
	)

	var result: PlacementResult = validate_placement(
		cells, _selected_fixture_type
	)
	if not result.valid:
		EventBus.fixture_placement_invalid.emit(result.reason)
		return false

	var price: float = get_fixture_price(_selected_fixture_type)
	if price > 0.0 and _economy_system:
		if not _economy_system.deduct_cash(
			price,
			"Fixture purchase: %s" % _selected_fixture_type
		):
			EventBus.fixture_placement_invalid.emit(
				"Insufficient funds"
			)
			return false

	var fixture_id: String = _generate_fixture_id()
	var is_register: bool = _selected_fixture_type == "register"
	register_existing_fixture(
		fixture_id,
		_selected_fixture_type,
		grid_pos,
		_current_rotation,
		is_register,
		price
	)

	needs_nav_rebake = true
	EventBus.fixture_placed.emit(fixture_id, grid_pos, _current_rotation)
	return true


## Attempts to remove the fixture at the given cell.
func try_remove(grid_pos: Vector2i) -> bool:
	if not _occupied_cells.has(grid_pos):
		return false

	var fixture_id: String = _occupied_cells[grid_pos] as String
	if fixture_id == _register_fixture_id:
		EventBus.fixture_placement_invalid.emit(
			"Cannot remove the register"
		)
		EventBus.notification_requested.emit(
			"Cannot remove the register fixture"
		)
		return false

	var data: Dictionary = _placed_fixtures.get(fixture_id, {})
	if data.is_empty():
		return false

	var cells: Array[Vector2i] = data.get(
		"cells", [] as Array[Vector2i]
	)

	var test_occupied: Dictionary = _occupied_cells.duplicate()
	for cell: Vector2i in cells:
		test_occupied.erase(cell)

	if not _validator.is_layout_connected(
		test_occupied, _register_cells
	):
		EventBus.fixture_placement_invalid.emit(
			"Removal would break connectivity"
		)
		return false

	_move_fixture_items_to_backroom(fixture_id)

	for cell: Vector2i in cells:
		_occupied_cells.erase(cell)
	_placed_fixtures.erase(fixture_id)

	var total_invested: float = data.get("total_spent", 0.0)
	var refund: float = total_invested * SELLBACK_RATE
	if refund > 0.0 and _economy_system:
		_economy_system.add_cash(refund, "Fixture removal refund")

	needs_nav_rebake = true
	EventBus.fixture_removed.emit(fixture_id, grid_pos)
	return true


## Returns the fixture ID at a grid cell, or empty string.
func get_fixture_at(grid_pos: Vector2i) -> String:
	if _occupied_cells.has(grid_pos):
		return _occupied_cells[grid_pos] as String
	return ""


## Returns data about a placed fixture, or empty dict.
func get_fixture_data(fixture_id: String) -> Dictionary:
	return _placed_fixtures.get(fixture_id, {})


## Returns all occupied cell positions.
func get_all_occupied_cells() -> Dictionary:
	return _occupied_cells


## Returns all placed fixtures as an Array[Dictionary] for external queries.
func get_placed_fixtures() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for fixture_id: String in _placed_fixtures:
		result.append(_placed_fixtures[fixture_id])
	return result


# -- Upgrade delegation --


## Returns the current tier of a placed fixture.
func get_fixture_tier(fixture_id: String) -> int:
	if _upgrade_handler:
		return _upgrade_handler.get_fixture_tier(fixture_id)
	return FixtureDefinition.TierLevel.BASIC


## Returns whether a fixture can be upgraded.
func can_upgrade(fixture_id: String) -> bool:
	if _upgrade_handler:
		return _upgrade_handler.can_upgrade(fixture_id)
	return false


## Returns the cost to upgrade a fixture to the next tier.
func get_upgrade_cost(fixture_id: String) -> float:
	if _upgrade_handler:
		return _upgrade_handler.get_upgrade_cost(fixture_id)
	return 0.0


## Returns the reason a fixture cannot be upgraded.
func get_upgrade_block_reason(fixture_id: String) -> String:
	if _upgrade_handler:
		return _upgrade_handler.get_upgrade_block_reason(
			fixture_id
		)
	return "Upgrade system not initialized"


## Attempts to upgrade a placed fixture to the next tier.
func try_upgrade(fixture_id: String) -> bool:
	if _upgrade_handler:
		return _upgrade_handler.try_upgrade(fixture_id)
	return false


## Returns the effective slot count (base + tier bonus).
func get_effective_slot_count(fixture_id: String) -> int:
	if _upgrade_handler:
		return _upgrade_handler.get_effective_slot_count(
			fixture_id
		)
	return 0


## Returns the purchase probability bonus for a fixture.
func get_fixture_prob_bonus(fixture_id: String) -> float:
	if _upgrade_handler:
		return _upgrade_handler.get_fixture_prob_bonus(fixture_id)
	return 0.0


# -- Save / Load --


## Serializes placed fixture state for saving.
func get_save_data() -> Dictionary:
	var fixtures_data: Array[Dictionary] = []
	for fixture_id: String in _placed_fixtures:
		var data: Dictionary = _placed_fixtures[fixture_id]
		var pos: Vector2i = data.get(
			"grid_position", Vector2i.ZERO
		) as Vector2i
		fixtures_data.append({
			"fixture_id": fixture_id,
			"fixture_type": data.get("fixture_type", ""),
			"grid_position": [pos.x, pos.y],
			"rotation": data.get("rotation", 0),
			"is_register": data.get("is_register", false),
			"purchase_price": data.get("purchase_price", 0.0),
			"tier": data.get(
				"tier", FixtureDefinition.TierLevel.BASIC
			),
			"total_spent": data.get("total_spent", 0.0),
		})
	return { "placed_fixtures": fixtures_data }


## Restores placed fixture state from saved data.
func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_placed_fixtures.clear()
	_occupied_cells.clear()
	_register_cells.clear()
	_register_fixture_id = ""

	var fixtures_arr: Variant = data.get("placed_fixtures", [])
	if fixtures_arr is not Array:
		return
	for entry: Variant in fixtures_arr:
		if entry is not Dictionary:
			continue
		var d: Dictionary = entry as Dictionary
		var pos: Vector2i = _parse_grid_pos(d)
		var tier: int = int(
			d.get("tier", FixtureDefinition.TierLevel.BASIC)
		)
		register_existing_fixture(
			str(d.get("fixture_id", "")),
			str(d.get("fixture_type", "")),
			pos,
			int(d.get("rotation", 0)),
			bool(d.get("is_register", false)),
			float(d.get("purchase_price", 0.0)),
			tier,
			float(d.get("total_spent", -1.0)),
		)
		if tier > FixtureDefinition.TierLevel.BASIC and _upgrade_handler:
			_upgrade_handler.update_fixture_visual(
				str(d.get("fixture_id", "")), tier
			)


# -- Private helpers --


func _get_fixture_cells(
	fixture_type: String,
	grid_pos: Vector2i,
	rotation: int
) -> Array[Vector2i]:
	var base_size: Vector2i = get_fixture_size(fixture_type)
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


func _move_fixture_items_to_backroom(
	fixture_id: String
) -> void:
	if not _inventory_system:
		return
	var shelf_items: Array[ItemInstance] = (
		_inventory_system.get_shelf_items()
	)
	for item: ItemInstance in shelf_items:
		if not item.current_location.begins_with("shelf:"):
			continue
		var shelf_id: String = item.current_location.substr(6)
		if shelf_id.begins_with(fixture_id):
			_inventory_system.move_item(
				item.instance_id, "backroom"
			)
			EventBus.item_removed_from_shelf.emit(
				item.instance_id, shelf_id
			)


func _generate_fixture_id() -> String:
	var timestamp: int = Time.get_ticks_msec()
	var rand_part: int = randi() % 10000
	return "fixture_%d_%04d" % [timestamp, rand_part]


func _parse_grid_pos(d: Dictionary) -> Vector2i:
	var pos_arr: Variant = d.get("grid_position", [0, 0])
	if pos_arr is Array:
		var arr: Array = pos_arr as Array
		if arr.size() >= 2:
			return Vector2i(int(arr[0]), int(arr[1]))
	return Vector2i.ZERO
