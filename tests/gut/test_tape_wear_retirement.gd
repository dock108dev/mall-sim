## Tests tape retirement rules, sale/write-off outcomes, and wear save/load.
extends GutTest


var _controller: VideoRentalStoreController
var _inventory: InventorySystem
var _economy: EconomySystem
var _data_loader: DataLoader
var _previous_data_loader: DataLoader


func before_each() -> void:
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()
	_previous_data_loader = GameManager.data_loader
	GameManager.data_loader = _data_loader
	_controller = VideoRentalStoreController.new()
	_inventory = InventorySystem.new()
	_economy = EconomySystem.new()
	add_child_autofree(_controller)
	add_child_autofree(_inventory)
	add_child_autofree(_economy)
	_inventory.initialize(_data_loader)
	_economy.initialize(100.0)
	_controller.set_inventory_system(_inventory)
	_controller.set_economy_system(_economy)


func after_each() -> void:
	GameManager.data_loader = _previous_data_loader


func test_is_worn_out_only_after_tracker_marks_written_off() -> void:
	var item: ItemInstance = _make_item("tape_1", "poor")
	_inventory.register_item(item)
	_controller._wear_tracker.initialize_item(item.instance_id, item.condition)

	assert_false(
		_controller.is_worn_out(item),
		"Poor tapes should remain rentable until they cross the final threshold"
	)

	for _i: int in range(TapeWearTracker.RENTALS_PER_CONDITION_DROP):
		_controller._wear_tracker.record_return(item.instance_id)

	assert_true(
		_controller.is_worn_out(item),
		"Written-off tapes should be eligible for retirement"
	)


func test_retire_tape_sell_uses_poor_value_and_removes_item() -> void:
	var item: ItemInstance = _make_written_off_item("tape_sell")
	item.definition.base_price = 10.0
	var starting_cash: float = _economy.get_cash()

	var success: bool = _controller.retire_tape(item.instance_id, true)

	assert_true(success, "Selling a written-off tape should succeed")
	assert_almost_eq(
		_economy.get_cash() - starting_cash,
		2.5,
		0.01,
		"Retirement sale should use poor-condition value"
	)
	assert_null(
		_inventory.get_item(item.instance_id),
		"Retirement sale should remove the tape from inventory"
	)


func test_retire_tape_writeoff_removes_item_without_cash() -> void:
	var item: ItemInstance = _make_written_off_item("tape_writeoff")
	var starting_cash: float = _economy.get_cash()

	var success: bool = _controller.retire_tape(item.instance_id, false)

	assert_true(success, "Writing off a written-off tape should succeed")
	assert_almost_eq(
		_economy.get_cash(),
		starting_cash,
		0.01,
		"Write-off should not add any cash"
	)
	assert_null(
		_inventory.get_item(item.instance_id),
		"Write-off should remove the tape from inventory"
	)


func test_retire_tape_clears_tracker_state() -> void:
	var item: ItemInstance = _make_written_off_item("tape_clear")

	_controller.retire_tape(item.instance_id, false)

	assert_eq(
		_controller.get_tape_wear(item.instance_id),
		0,
		"Retiring a tape should clear its saved play-count progress"
	)
	assert_false(
		_controller._wear_tracker.is_rentable(item.instance_id),
		"Removed tracker entries should no longer appear as rentable"
	)


func test_retire_tape_fails_for_still_rentable_poor_tape() -> void:
	var item: ItemInstance = _make_item("tape_good", "poor")
	_inventory.register_item(item)
	_controller._wear_tracker.initialize_item(item.instance_id, item.condition)

	var result: bool = _controller.retire_tape(item.instance_id, false)

	assert_false(result, "Poor-but-rentable tapes should not be retired yet")
	assert_not_null(
		_inventory.get_item(item.instance_id),
		"Still-rentable tapes should remain in inventory"
	)


func test_save_load_preserves_partial_play_progress() -> void:
	var item: ItemInstance = _make_item("tape_save", "poor")
	_inventory.register_item(item)
	_controller._wear_tracker.initialize_item(item.instance_id, item.condition)
	for _i: int in range(TapeWearTracker.RENTALS_PER_CONDITION_DROP - 1):
		_controller._wear_tracker.record_return(item.instance_id)
	var save_data: Dictionary = _controller.get_save_data()

	_controller.load_save_data(save_data)

	assert_eq(
		_controller.get_tape_wear(item.instance_id),
		TapeWearTracker.RENTALS_PER_CONDITION_DROP - 1,
		"A tape with 4/5 plays should restore with the same progress"
	)
	assert_true(
		_controller.is_rentable(item),
		"Partial play progress should remain rentable after reload"
	)


func _make_written_off_item(instance_id: String) -> ItemInstance:
	var item: ItemInstance = _make_item(instance_id, "poor")
	_inventory.register_item(item)
	_controller._wear_tracker.initialize_item(item.instance_id, item.condition)
	for _i: int in range(TapeWearTracker.RENTALS_PER_CONDITION_DROP):
		_controller._wear_tracker.record_return(item.instance_id)
	return item


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
