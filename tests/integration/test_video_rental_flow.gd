## Integration test: Video Rental store flow — rent, overdue, return, late fee, reputation.
extends GutTest

var _data_loader: DataLoader
var _previous_data_loader: DataLoader
var _inventory: InventorySystem
var _economy: EconomySystem
var _reputation: ReputationSystem
var _controller: VideoRentalStoreController
var _item_def: ItemDefinition

const STORE_ID: StringName = &"rentals"
const CATALOG_ITEM_ID: String = "rental_cosmic_battles_4_vhs"
const CHECKOUT_DAY: int = 1
const RETURN_DAY_ONE_OVERDUE: int = 4
const RETURN_DAY_TWO_OVERDUE: int = 5
const RETURN_DAY_THREE_OVERDUE: int = 6
const STARTING_CASH: float = 1000.0
const RNG_SEED: int = 42
const FLOAT_EPSILON: float = 0.001


func before_each() -> void:
	_previous_data_loader = GameManager.data_loader
	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_data_loader.load_all_content()
	GameManager.data_loader = _data_loader
	_item_def = _data_loader.get_item(CATALOG_ITEM_ID)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)
	_reputation.initialize_store(String(STORE_ID))

	_controller = VideoRentalStoreController.new()
	add_child_autofree(_controller)
	_controller.set_inventory_system(_inventory)
	_controller.set_economy_system(_economy)
	_controller.set_reputation_system(_reputation)
	_controller.set_late_fee_policy(
		VideoRentalStoreController.LateFeePolicy.STANDARD
	)


func after_each() -> void:
	GameManager.data_loader = _previous_data_loader


func test_full_rental_overdue_return_flow() -> void:
	assert_true(
		ContentRegistry.exists(String(STORE_ID)),
		"DataLoader should register the rentals store before the flow runs"
	)
	assert_true(
		_item_def != null,
		"DataLoader should load a video rental catalog item for the test"
	)

	var item: ItemInstance = _create_and_stock_item()
	var returned_signal_fired: Array = [false]
	var returned_item_id: Array = [""]
	var late_fee_signal_fired: Array = [false]
	var late_fee_amount: Array = [0.0]
	var late_fee_days: Array = [0]

	var on_returned := func(
		item_id: String, _degraded: bool
	) -> void:
		returned_signal_fired[0] = true
		returned_item_id[0] = item_id

	var on_late_fee := func(
		item_id: String, late_fee: float, days_late: int
	) -> void:
		if item_id != item.instance_id:
			return
		late_fee_signal_fired[0] = true
		late_fee_amount[0] = late_fee
		late_fee_days[0] = days_late

	EventBus.rental_returned.connect(on_returned)
	EventBus.rental_late_fee.connect(on_late_fee)

	var record: Dictionary = _rent_item(item)

	assert_true(
		_has_active_rental(item.instance_id),
		"Item appears in active rentals after rental is issued"
	)
	assert_eq(
		int(record["return_day"]),
		CHECKOUT_DAY + _overnight_duration_days(),
		"Overnight rental should use the overnight duration"
	)

	var cash_before_return: float = _economy.get_cash()
	var reputation_before_return: float = _reputation.get_reputation(String(STORE_ID))
	var expected_days_overdue: int = _expected_days_overdue(record, RETURN_DAY_ONE_OVERDUE)
	var expected_late_fee: float = _expected_late_fee(expected_days_overdue)

	_process_return_day(RETURN_DAY_ONE_OVERDUE)

	assert_false(
		_has_active_rental(item.instance_id),
		"Item is removed from active rentals after return is processed"
	)
	assert_true(
		returned_signal_fired[0],
		"rental_returned should fire when the rental is returned"
	)
	assert_eq(
		returned_item_id[0],
		item.instance_id,
		"rental_returned should carry the returned item_id"
	)
	assert_true(
		late_fee_signal_fired[0],
		"rental_late_fee should report the late fee for the overdue return"
	)
	assert_eq(
		late_fee_days[0],
		expected_days_overdue,
		"Late fee signal should report the overdue day count"
	)
	assert_almost_eq(
		late_fee_amount[0],
		expected_late_fee,
		FLOAT_EPSILON,
		"Late fee should match the controller's STANDARD-policy calculation"
	)
	assert_almost_eq(
		_economy.get_cash(),
		cash_before_return + expected_late_fee,
		FLOAT_EPSILON,
		"EconomySystem should receive the late fee amount"
	)
	assert_almost_eq(
		_reputation.get_reputation(String(STORE_ID)),
		reputation_before_return + _expected_reputation_delta(),
		FLOAT_EPSILON,
		"ReputationSystem should receive the STANDARD policy reputation adjustment"
	)

	EventBus.rental_returned.disconnect(on_returned)
	EventBus.rental_late_fee.disconnect(on_late_fee)


func test_item_in_active_rentals_after_rental() -> void:
	var item: ItemInstance = _create_and_stock_item()

	_rent_item(item)

	assert_true(
		_has_active_rental(item.instance_id),
		"Active rentals should include the rented item"
	)
	assert_eq(
		_controller.get_active_rentals().size(),
		1,
		"Exactly one active rental should exist after issuing a rental"
	)


func test_item_removed_from_active_rentals_after_return() -> void:
	var item: ItemInstance = _create_and_stock_item()
	_rent_item(item)

	assert_true(
		_has_active_rental(item.instance_id),
		"Rental should be active before the return day is processed"
	)

	_process_return_day(RETURN_DAY_ONE_OVERDUE)

	assert_false(
		_has_active_rental(item.instance_id),
		"Returned rental should no longer appear in active rentals"
	)
	assert_eq(
		_controller.get_active_rentals().size(),
		0,
		"No active rentals should remain after the only item is returned"
	)


func test_late_fee_calculation_standard_policy() -> void:
	var item: ItemInstance = _create_and_stock_item()
	var late_fee_amount: Array = [0.0]
	var late_fee_days: Array = [0]

	var on_late_fee := func(
		item_id: String, late_fee: float, days_late: int
	) -> void:
		if item_id != item.instance_id:
			return
		late_fee_amount[0] = late_fee
		late_fee_days[0] = days_late

	EventBus.rental_late_fee.connect(on_late_fee)

	var record: Dictionary = _rent_item(item)
	var expected_days_overdue: int = _expected_days_overdue(record, RETURN_DAY_THREE_OVERDUE)

	_process_return_day(RETURN_DAY_THREE_OVERDUE)

	assert_eq(
		late_fee_days[0],
		expected_days_overdue,
		"Late fee signal should report the expected overdue day count"
	)
	assert_almost_eq(
		late_fee_amount[0],
		_expected_late_fee(expected_days_overdue),
		FLOAT_EPSILON,
		"Late fee should match the STANDARD-policy controller formula"
	)

	EventBus.rental_late_fee.disconnect(on_late_fee)


func test_economy_receives_late_fee() -> void:
	var item: ItemInstance = _create_and_stock_item()
	var record: Dictionary = _rent_item(item)
	var cash_before_return: float = _economy.get_cash()
	var expected_days_overdue: int = _expected_days_overdue(record, RETURN_DAY_TWO_OVERDUE)

	_process_return_day(RETURN_DAY_TWO_OVERDUE)

	assert_almost_eq(
		_economy.get_cash(),
		cash_before_return + _expected_late_fee(expected_days_overdue),
		FLOAT_EPSILON,
		"Cash should increase by the collected late fee amount"
	)


func test_reputation_adjustment_standard_policy() -> void:
	var item: ItemInstance = _create_and_stock_item()
	_rent_item(item)
	var reputation_before_return: float = _reputation.get_reputation(String(STORE_ID))

	_process_return_day(RETURN_DAY_ONE_OVERDUE)

	assert_almost_eq(
		_reputation.get_reputation(String(STORE_ID)),
		reputation_before_return + _expected_reputation_delta(),
		FLOAT_EPSILON,
		"STANDARD late-fee policy should apply the configured reputation delta"
	)


func test_rental_returned_signal_fires() -> void:
	var item: ItemInstance = _create_and_stock_item()
	var signal_fired: Array = [false]
	var signal_item_id: Array = [""]

	var on_returned := func(
		item_id: String, _degraded: bool
	) -> void:
		signal_fired[0] = true
		signal_item_id[0] = item_id

	EventBus.rental_returned.connect(on_returned)

	_rent_item(item)
	_process_return_day(RETURN_DAY_ONE_OVERDUE)

	assert_true(signal_fired[0], "rental_returned should fire on return")
	assert_eq(
		signal_item_id[0],
		item.instance_id,
		"rental_returned should carry the returned item_id"
	)

	EventBus.rental_returned.disconnect(on_returned)


func test_no_late_fee_within_grace_period() -> void:
	var item: ItemInstance = _create_and_stock_item()
	var late_fee_fired: Array = [false]

	var on_late_fee := func(
		item_id: String, _late_fee: float, _days_late: int
	) -> void:
		if item_id == item.instance_id:
			late_fee_fired[0] = true

	EventBus.rental_late_fee.connect(on_late_fee)

	var record: Dictionary = _rent_item(item)
	var deadline: int = int(record["return_day"]) + _controller._grace_period_days

	_process_return_day(deadline)

	assert_false(
		late_fee_fired[0],
		"No late fee should fire while the rental is still within the grace period"
	)

	EventBus.rental_late_fee.disconnect(on_late_fee)


func _rent_item(item: ItemInstance) -> Dictionary:
	return _controller.process_rental(
		item.instance_id,
		_item_def.category,
		"overnight",
		_item_def.rental_fee,
		CHECKOUT_DAY,
	)


func _create_and_stock_item() -> ItemInstance:
	var item: ItemInstance = ItemInstance.create(
		_item_def,
		"good",
		0,
		_item_def.base_price,
	)
	_inventory.add_item(STORE_ID, item)
	return item


func _has_active_rental(instance_id: String) -> bool:
	for record: Dictionary in _controller.get_active_rentals():
		if str(record.get("instance_id", "")) == instance_id:
			return true
	return false


func _expected_days_overdue(record: Dictionary, current_day: int) -> int:
	var deadline: int = int(record["return_day"]) + _controller._grace_period_days
	return maxi(0, current_day - deadline)


func _expected_late_fee(days_overdue: int) -> float:
	var raw_fee: float = _controller._base_late_fee + (
		float(days_overdue) * _controller._per_day_rate
	)
	return minf(raw_fee, _controller._max_late_fee)


func _expected_reputation_delta() -> float:
	var multiplier: float = float(
		VideoRentalStoreController.POLICY_REP_MULTIPLIERS[
			VideoRentalStoreController.LateFeePolicy.STANDARD
		]
	)
	return VideoRentalStoreController.RENTAL_REP_GAIN * multiplier


func _overnight_duration_days() -> int:
	return int(VideoRentalStoreController.RENTAL_DURATIONS["overnight"])


func _process_return_day(day: int) -> void:
	seed(RNG_SEED)
	_controller._on_day_started(day)
