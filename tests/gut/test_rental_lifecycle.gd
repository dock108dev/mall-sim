## Tests VideoRentalStoreController rental lifecycle: rent, return, save/load.
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


func _make_item(
	item_id: String, category: String, rental_fee: float
) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = item_id
	def.item_name = "Test Tape"
	def.category = category
	def.store_type = "rentals"
	def.base_price = 10.0
	def.rental_fee = rental_fee
	def.rental_period_days = 3
	def.rental_tier = "three_day"
	var inst := ItemInstance.new()
	inst.definition = def
	inst.instance_id = item_id + "_1"
	inst.condition = "good"
	inst.current_location = "shelf:slot_1"
	return inst


func _register_item(item: ItemInstance) -> void:
	_inventory._items[item.instance_id] = item


func test_rental_records_is_dictionary() -> void:
	assert_typeof(
		_controller.rental_records, TYPE_DICTIONARY,
		"rental_records should be a Dictionary"
	)


func test_process_rental_creates_record() -> void:
	var item: ItemInstance = _make_item("tape_a", "vhs_tapes", 2.0)
	_register_item(item)
	var record: Dictionary = _controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day", 2.0, 5, "cust_1"
	)
	assert_true(
		_controller.rental_records.has(item.instance_id),
		"rental_records should contain the rented copy_id"
	)
	assert_eq(
		record["customer_id"], "cust_1",
		"Record should store customer_id"
	)
	assert_eq(
		record["return_day"], 8,
		"Return day should be checkout_day + duration"
	)


func test_rental_moves_item_to_rented_location() -> void:
	var item: ItemInstance = _make_item("tape_b", "vhs_tapes", 2.0)
	_register_item(item)
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day", 2.0, 1
	)
	assert_eq(
		item.current_location, "rented",
		"Rented item should be at 'rented' location"
	)


func test_rental_sets_due_day_on_item() -> void:
	var item: ItemInstance = _make_item("tape_c", "vhs_tapes", 2.0)
	_register_item(item)
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day", 2.0, 10
	)
	assert_eq(
		item.rental_due_day, 13,
		"Item rental_due_day should be set to return_day"
	)


func test_rental_fee_added_to_cash() -> void:
	var starting_cash: float = _economy.get_cash()
	var item: ItemInstance = _make_item("tape_d", "vhs_tapes", 3.50)
	_register_item(item)
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "overnight", 3.50, 1
	)
	assert_gt(
		_economy.get_cash(), starting_cash,
		"Player cash should increase by rental fee"
	)


func test_day_started_returns_due_items() -> void:
	var item: ItemInstance = _make_item("tape_e", "vhs_tapes", 2.0)
	_register_item(item)
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "overnight", 2.0, 1
	)
	assert_true(
		_controller.rental_records.has(item.instance_id),
		"Record should exist before return"
	)
	_controller._on_day_started(2)
	assert_false(
		_controller.rental_records.has(item.instance_id),
		"Record should be removed after return day"
	)


func test_returned_item_moves_to_returns_bin() -> void:
	var item: ItemInstance = _make_item("tape_f", "vhs_tapes", 2.0)
	_register_item(item)
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "overnight", 2.0, 1
	)
	_controller._on_day_started(2)
	assert_eq(
		item.current_location, "returns_bin",
		"Returned item should be in returns_bin"
	)


func test_returned_item_clears_due_day() -> void:
	var item: ItemInstance = _make_item("tape_g", "vhs_tapes", 2.0)
	_register_item(item)
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "overnight", 2.0, 1
	)
	_controller._on_day_started(2)
	assert_eq(
		item.rental_due_day, -1,
		"Returned item rental_due_day should be cleared"
	)


func test_not_yet_due_items_stay_rented() -> void:
	var item: ItemInstance = _make_item("tape_h", "vhs_tapes", 2.0)
	_register_item(item)
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "weekly", 2.0, 1
	)
	_controller._on_day_started(3)
	assert_true(
		_controller.rental_records.has(item.instance_id),
		"Item not yet due should remain in rental_records"
	)
	assert_eq(
		item.current_location, "rented",
		"Item not yet due should stay at rented location"
	)


func test_get_active_rentals_returns_records() -> void:
	var item: ItemInstance = _make_item("tape_i", "vhs_tapes", 2.0)
	_register_item(item)
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day", 2.0, 1
	)
	var active: Array[Dictionary] = _controller.get_active_rentals()
	assert_eq(
		active.size(), 1,
		"get_active_rentals should return one record"
	)


func test_get_overdue_rentals() -> void:
	var item: ItemInstance = _make_item("tape_j", "vhs_tapes", 2.0)
	_register_item(item)
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "overnight", 2.0, 1
	)
	var overdue: Array[Dictionary] = (
		_controller.get_overdue_rentals(5)
	)
	assert_eq(
		overdue.size(), 1,
		"Should report overdue rental"
	)
	var not_overdue: Array[Dictionary] = (
		_controller.get_overdue_rentals(1)
	)
	assert_eq(
		not_overdue.size(), 0,
		"Should not report non-overdue rental"
	)


func test_is_rental_item_categories() -> void:
	assert_true(
		_controller.is_rental_item("vhs_tapes"),
		"vhs_tapes should be a rental category"
	)
	assert_true(
		_controller.is_rental_item("dvd_titles"),
		"dvd_titles should be a rental category"
	)
	assert_false(
		_controller.is_rental_item("snacks"),
		"snacks should not be a rental category"
	)
	assert_false(
		_controller.is_rental_item("merchandise"),
		"merchandise should not be a rental category"
	)


func test_rented_count_and_available_count() -> void:
	var item: ItemInstance = _make_item("tape_k", "vhs_tapes", 2.0)
	_register_item(item)
	assert_eq(
		_controller.get_rented_count(), 0,
		"No rentals initially"
	)
	assert_eq(
		_controller.get_available_count(), 1,
		"One available initially"
	)
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day", 2.0, 1
	)
	assert_eq(
		_controller.get_rented_count(), 1,
		"One rented after rental"
	)
	assert_eq(
		_controller.get_available_count(), 0,
		"None available after rental"
	)


func test_save_load_round_trip() -> void:
	var item: ItemInstance = _make_item("tape_l", "vhs_tapes", 2.0)
	_register_item(item)
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day", 2.0, 5, "cust_99"
	)
	var save_data: Dictionary = _controller.get_save_data()
	_controller.rental_records.clear()
	assert_eq(
		_controller.rental_records.size(), 0,
		"Records cleared before load"
	)
	_controller.load_save_data(save_data)
	assert_true(
		_controller.rental_records.has(item.instance_id),
		"Rental record should survive save/load"
	)
	var restored: Dictionary = _controller.rental_records[
		item.instance_id
	]
	assert_eq(
		restored["customer_id"], "cust_99",
		"customer_id should survive save/load"
	)
	assert_eq(
		restored["return_day"], 8,
		"return_day should survive save/load"
	)


func test_save_load_backward_compat_active_rentals() -> void:
	var legacy_data: Dictionary = {
		"active_rentals": [
			{
				"instance_id": "old_tape_1",
				"return_day": 10,
				"returned": false,
				"category": "vhs_tapes",
				"rental_fee": 2.0,
				"rental_tier": "three_day",
				"checkout_day": 7,
			},
			{
				"instance_id": "old_tape_2",
				"return_day": 8,
				"returned": true,
				"category": "vhs_tapes",
				"rental_fee": 2.0,
				"rental_tier": "overnight",
				"checkout_day": 7,
			},
		],
	}
	_controller.load_save_data(legacy_data)
	assert_true(
		_controller.rental_records.has("old_tape_1"),
		"Should load unreturned legacy records"
	)
	assert_false(
		_controller.rental_records.has("old_tape_2"),
		"Should skip returned legacy records"
	)


func test_rental_durations() -> void:
	var item: ItemInstance = _make_item("tape_m", "vhs_tapes", 2.0)
	_register_item(item)
	var record: Dictionary = _controller.process_rental(
		item.instance_id, "vhs_tapes", "overnight", 2.0, 10
	)
	assert_eq(record["return_day"], 11, "Overnight: 1 day")
	_controller.rental_records.clear()
	record = _controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day", 2.0, 10
	)
	assert_eq(record["return_day"], 13, "Three day: 3 days")
	_controller.rental_records.clear()
	record = _controller.process_rental(
		item.instance_id, "vhs_tapes", "weekly", 2.0, 10
	)
	assert_eq(record["return_day"], 17, "Weekly: 7 days")
