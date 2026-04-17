## Unit tests for VideoRentalStoreController lifecycle hooks and late-fee math.
extends GutTest


var _controller: VideoRentalStoreController
var _inventory: InventorySystem
var _economy: EconomySystem
var _data_loader: DataLoader
var _previous_data_loader: DataLoader

var _base_late_fee: float = 1.0
var _per_day_rate: float = 0.5
var _max_late_fee: float = 20.0
var _grace_period_days: int = 1
var _late_fee_signals: Array[Dictionary] = []


func before_each() -> void:
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()
	_previous_data_loader = GameManager.data_loader
	GameManager.data_loader = _data_loader

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(500.0)

	_controller = VideoRentalStoreController.new()
	add_child_autofree(_controller)
	_controller.set_inventory_system(_inventory)
	_controller.set_economy_system(_economy)
	_controller._base_late_fee = _base_late_fee
	_controller._per_day_rate = _per_day_rate
	_controller._max_late_fee = _max_late_fee
	_controller._grace_period_days = _grace_period_days

	_late_fee_signals = []
	EventBus.rental_late_fee.connect(_on_rental_late_fee)


func after_each() -> void:
	GameManager.data_loader = _previous_data_loader
	_disconnect_if_needed(EventBus.rental_late_fee, _on_rental_late_fee)


func test_store_entry_initializes_tracker_from_inventory() -> void:
	var item: ItemInstance = _register_item("tape_entry", "fair")

	_controller._on_store_entered(&"rentals")

	assert_eq(
		_controller.get_tape_wear(item.instance_id),
		0,
		"Store entry should initialize tape progress for existing inventory"
	)
	assert_true(
		_controller.is_rentable(item),
		"Existing fair-condition tapes should remain rentable after initialization"
	)


func test_overdue_return_accrues_late_fee() -> void:
	var rental: Dictionary = _make_rental_dict("tape_late", 1, 4)
	var days_overdue: int = 3
	var expected_fee: float = _base_late_fee + (float(days_overdue) * _per_day_rate)

	_controller._daily_late_fee_total = 0.0
	_controller._collect_late_fee(rental, days_overdue)

	assert_almost_eq(
		_controller._daily_late_fee_total,
		expected_fee,
		0.001,
		"Late fee should equal base_late_fee + (days_overdue * per_day_rate)"
	)
	assert_eq(
		_late_fee_signals.size(),
		1,
		"rental_late_fee signal should fire once for the overdue return"
	)


func test_retire_tape_missing_item_returns_false() -> void:
	var result: bool = _controller.retire_tape("nonexistent_id", false)

	assert_false(result, "retire_tape with an unknown id should return false")


func test_get_overdue_rentals_respects_grace_period() -> void:
	_controller.rental_records["tape_r04"] = _make_rental_dict("tape_r04", 1, 3)
	_controller.rental_records["tape_r05"] = _make_rental_dict("tape_r05", 2, 5)
	_controller.rental_records["tape_r06"] = _make_rental_dict("tape_r06", 3, 10)

	var overdue: Array[Dictionary] = _controller.get_overdue_rentals(9)

	assert_eq(
		overdue.size(),
		2,
		"Only records beyond return_day + grace_period should be overdue"
	)


func _register_item(instance_id: String, condition: String) -> ItemInstance:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = "%s_def" % instance_id
	def.item_name = "Test VHS Tape"
	def.category = "vhs_tapes"
	def.store_type = "rentals"
	def.base_price = 8.0
	def.rental_fee = 2.99
	def.rental_period_days = 3
	def.rental_tier = "three_day"
	var inst: ItemInstance = ItemInstance.new()
	inst.definition = def
	inst.instance_id = instance_id
	inst.condition = condition
	inst.current_location = "backroom"
	_inventory.register_item(inst)
	return inst


func _make_rental_dict(
	instance_id: String,
	checkout_day: int,
	return_day: int
) -> Dictionary:
	return {
		"instance_id": instance_id,
		"customer_id": "cust_test",
		"category": "vhs_tapes",
		"rental_fee": 2.99,
		"rental_tier": "three_day",
		"checkout_day": checkout_day,
		"return_day": return_day,
	}


func _on_rental_late_fee(instance_id: String, late_fee: float, days_late: int) -> void:
	_late_fee_signals.append({
		"instance_id": instance_id,
		"late_fee": late_fee,
		"days_late": days_late,
	})


func _disconnect_if_needed(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)
