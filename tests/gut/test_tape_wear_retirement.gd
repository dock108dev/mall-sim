## Tests tape wear retirement: degradation detection, backroom routing, and retire actions.
extends GutTest


var _controller: VideoRentalStoreController
var _inventory: InventorySystem
var _economy: EconomySystem


func before_each() -> void:
	_controller = VideoRentalStoreController.new()
	_inventory = InventorySystem.new()
	_economy = EconomySystem.new()
	add_child_autofree(_controller)
	add_child_autofree(_inventory)
	add_child_autofree(_economy)
	_controller.set_inventory_system(_inventory)
	_controller.set_economy_system(_economy)


func test_is_worn_out_poor_condition() -> void:
	var item: ItemInstance = _make_item("tape_1", "poor")
	assert_true(
		_controller.is_worn_out(item),
		"Poor condition tape should be worn out"
	)


func test_is_worn_out_good_condition() -> void:
	var item: ItemInstance = _make_item("tape_1", "good")
	assert_false(
		_controller.is_worn_out(item),
		"Good condition tape should not be worn out"
	)


func test_is_worn_out_null_item() -> void:
	assert_false(
		_controller.is_worn_out(null),
		"Null item should not be worn out"
	)


func test_is_rentable_false_for_poor() -> void:
	var item: ItemInstance = _make_item("tape_1", "poor")
	assert_false(
		_controller.is_rentable(item),
		"Poor condition tape should not be rentable"
	)


func test_is_rentable_true_for_fair() -> void:
	var item: ItemInstance = _make_item("tape_1", "fair")
	assert_true(
		_controller.is_rentable(item),
		"Fair condition tape should be rentable"
	)


func test_retire_tape_sell_adds_cash() -> void:
	var item: ItemInstance = _make_item("tape_sell", "poor")
	item.definition.base_price = 10.0
	_inventory.add_item(&"rentals", item)
	var starting_cash: float = _economy.get_cash()
	var expected_value: float = item.get_current_value()
	_controller.retire_tape("tape_sell", true)
	var cash_gained: float = _economy.get_cash() - starting_cash
	assert_almost_eq(
		cash_gained, expected_value, 0.01,
		"Selling worn tape should add poor-condition value"
	)


func test_retire_tape_sell_removes_item() -> void:
	var item: ItemInstance = _make_item("tape_sell_rm", "poor")
	_inventory.add_item(&"rentals", item)
	_controller.retire_tape("tape_sell_rm", true)
	assert_null(
		_inventory.get_item("tape_sell_rm"),
		"Sold tape should be removed from inventory"
	)


func test_retire_tape_writeoff_no_cash() -> void:
	var item: ItemInstance = _make_item("tape_wo", "poor")
	item.definition.base_price = 10.0
	_inventory.add_item(&"rentals", item)
	var starting_cash: float = _economy.get_cash()
	_controller.retire_tape("tape_wo", false)
	assert_almost_eq(
		_economy.get_cash(), starting_cash, 0.01,
		"Write-off should not add cash"
	)


func test_retire_tape_writeoff_removes_item() -> void:
	var item: ItemInstance = _make_item("tape_wo_rm", "poor")
	_inventory.add_item(&"rentals", item)
	_controller.retire_tape("tape_wo_rm", false)
	assert_null(
		_inventory.get_item("tape_wo_rm"),
		"Written-off tape should be removed from inventory"
	)


func test_retire_tape_clears_wear_tracking() -> void:
	var item: ItemInstance = _make_item("tape_clear", "poor")
	_inventory.add_item(&"rentals", item)
	_controller._wear_tracker.initialize_item("tape_clear", "poor")
	assert_gt(
		_controller.get_tape_wear("tape_clear"), 0.0,
		"Wear should be tracked before retire"
	)
	_controller.retire_tape("tape_clear", false)
	assert_eq(
		_controller.get_tape_wear("tape_clear"), 0.0,
		"Wear tracking should be cleared after retire"
	)


func test_retire_tape_fails_for_good_condition() -> void:
	var item: ItemInstance = _make_item("tape_good", "good")
	_inventory.add_item(&"rentals", item)
	var result: bool = _controller.retire_tape("tape_good", false)
	assert_false(result, "Cannot retire a non-worn-out tape")
	assert_not_null(
		_inventory.get_item("tape_good"),
		"Non-worn-out tape should remain in inventory"
	)


func test_retire_tape_fails_for_missing_item() -> void:
	var result: bool = _controller.retire_tape("nonexistent", false)
	assert_false(result, "Cannot retire a nonexistent item")


func test_save_load_preserves_wear() -> void:
	_controller._wear_tracker.initialize_item("tape_save", "good")
	_controller._wear_tracker.apply_degradation("tape_save", "vhs_tapes")
	var wear_before: float = _controller.get_tape_wear("tape_save")
	var save_data: Dictionary = _controller.get_save_data()
	_controller._wear_tracker.load_save_data({})
	assert_eq(
		_controller.get_tape_wear("tape_save"), 0.0,
		"Wear should be cleared after resetting tracker"
	)
	_controller.load_save_data(save_data)
	assert_almost_eq(
		_controller.get_tape_wear("tape_save"), wear_before, 0.001,
		"Wear should be restored after load"
	)


func _make_item(
	instance_id: String, condition: String
) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = instance_id
	def.item_name = "Test Tape"
	def.category = "vhs_tapes"
	def.store_type = "rentals"
	def.base_price = 5.0
	def.rarity = "common"
	var item := ItemInstance.new()
	item.definition = def
	item.condition = condition
	item.instance_id = instance_id
	item.current_location = "backroom"
	return item
