## Integration test: Video Rental store flow — rent, overdue, return, late fee, reputation.
extends GutTest

var _inventory: InventorySystem
var _economy: EconomySystem
var _reputation: ReputationSystem
var _controller: VideoRentalStoreController
var _item_def: ItemDefinition

const STORE_ID: StringName = &"rentals"
const TEST_ITEM_ID: String = "vhs_test_tape"
const TEST_BASE_PRICE: float = 10.0
const TEST_RENTAL_FEE: float = 2.0
const BASE_LATE_FEE: float = 1.0
const PER_DAY_RATE: float = 0.5
const GRACE_PERIOD_DAYS: int = 1
const STARTING_CASH: float = 1000.0


func before_each() -> void:
	_register_store_in_content_registry()
	_item_def = _create_item_definition()

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

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
	_controller._base_late_fee = BASE_LATE_FEE
	_controller._per_day_rate = PER_DAY_RATE
	_controller._max_late_fee = 15.0
	_controller._grace_period_days = GRACE_PERIOD_DAYS


func after_each() -> void:
	_unregister_store_from_content_registry()


func test_full_rental_overdue_return_flow() -> void:
	var item: ItemInstance = _create_and_stock_item()

	var record: Dictionary = _controller.process_rental(
		item.instance_id, "vhs_tapes", "overnight", TEST_RENTAL_FEE, 1
	)

	assert_true(
		_controller.rental_records.has(item.instance_id),
		"Item appears in rental_records after rental is issued"
	)
	assert_eq(
		item.current_location, "rented",
		"Item location set to rented"
	)
	assert_eq(
		int(record["return_day"]), 2,
		"Overnight rental due on day 2"
	)

	var cash_after_rental: float = _economy.get_cash()
	assert_almost_eq(
		cash_after_rental,
		STARTING_CASH + TEST_RENTAL_FEE,
		0.01,
		"Rental fee added to cash"
	)

	var returned_signal_fired: bool = false
	var returned_item_id: String = ""
	var late_fee_signal_fired: bool = false
	var late_fee_amount: float = 0.0
	var late_fee_days: int = 0

	var on_returned := func(
		iid: String, degraded: bool
	) -> void:
		returned_signal_fired = true
		returned_item_id = iid

	var on_late_fee := func(
		iid: String, fee: float, days: int
	) -> void:
		late_fee_signal_fired = true
		late_fee_amount = fee
		late_fee_days = days

	EventBus.rental_returned.connect(on_returned)
	EventBus.rental_late_fee.connect(on_late_fee)

	var rep_before: float = _reputation.get_reputation(String(STORE_ID))
	var cash_before_return: float = _economy.get_cash()

	# Day 4: return_day=2, grace=1, so deadline=3. Day 4 means 1 day overdue.
	_controller._on_day_started(4)

	assert_false(
		_controller.rental_records.has(item.instance_id),
		"Item removed from rental_records after return"
	)

	assert_true(returned_signal_fired, "rental_returned signal fired")
	assert_eq(
		returned_item_id, item.instance_id,
		"rental_returned carries correct item_id"
	)

	assert_true(late_fee_signal_fired, "rental_late_fee signal fired")
	var expected_fee: float = BASE_LATE_FEE + (1.0 * PER_DAY_RATE)
	assert_almost_eq(
		late_fee_amount, expected_fee, 0.01,
		"Late fee equals base + (overdue_days × per_day_rate)"
	)
	assert_eq(late_fee_days, 1, "Late fee reports 1 day overdue")

	assert_almost_eq(
		_economy.get_cash(),
		cash_before_return + expected_fee,
		0.01,
		"EconomySystem received the late fee amount"
	)

	var rep_after: float = _reputation.get_reputation(String(STORE_ID))
	var expected_rep_delta: float = (
		VideoRentalStoreController.RENTAL_REP_GAIN
		* VideoRentalStoreController.POLICY_REP_MULTIPLIERS[
			VideoRentalStoreController.LateFeePolicy.STANDARD
		]
	)
	assert_almost_eq(
		rep_after,
		rep_before + expected_rep_delta,
		0.01,
		"ReputationSystem received STANDARD policy reputation adjustment"
	)

	EventBus.rental_returned.disconnect(on_returned)
	EventBus.rental_late_fee.disconnect(on_late_fee)


func test_item_in_active_rentals_after_rental() -> void:
	var item: ItemInstance = _create_and_stock_item()

	_controller.process_rental(
		item.instance_id, "vhs_tapes", "overnight", TEST_RENTAL_FEE, 1
	)

	var active: Array[Dictionary] = _controller.get_active_rentals()
	assert_eq(active.size(), 1, "One active rental after issuing rental")
	assert_eq(
		active[0]["instance_id"], item.instance_id,
		"Active rental matches issued item"
	)


func test_item_removed_from_active_rentals_after_return() -> void:
	var item: ItemInstance = _create_and_stock_item()

	_controller.process_rental(
		item.instance_id, "vhs_tapes", "overnight", TEST_RENTAL_FEE, 1
	)
	assert_eq(
		_controller.get_active_rentals().size(), 1,
		"One active rental before return"
	)

	_controller._on_day_started(4)

	assert_eq(
		_controller.get_active_rentals().size(), 0,
		"No active rentals after return processed"
	)


func test_late_fee_calculation_standard_policy() -> void:
	var item: ItemInstance = _create_and_stock_item()

	_controller.process_rental(
		item.instance_id, "vhs_tapes", "overnight", TEST_RENTAL_FEE, 1
	)

	var late_fee_amount: float = 0.0
	var on_late_fee := func(
		_iid: String, fee: float, _days: int
	) -> void:
		late_fee_amount = fee

	EventBus.rental_late_fee.connect(on_late_fee)

	# return_day=2, grace=1, deadline=3. Day 6 means 3 days overdue.
	_controller._on_day_started(6)

	var expected: float = BASE_LATE_FEE + (3.0 * PER_DAY_RATE)
	assert_almost_eq(
		late_fee_amount, expected, 0.01,
		"Late fee = base($1) + 3 days × $0.50 = $2.50"
	)

	EventBus.rental_late_fee.disconnect(on_late_fee)


func test_economy_receives_late_fee() -> void:
	var item: ItemInstance = _create_and_stock_item()

	_controller.process_rental(
		item.instance_id, "vhs_tapes", "overnight", TEST_RENTAL_FEE, 1
	)
	var cash_before: float = _economy.get_cash()

	# 2 days overdue
	_controller._on_day_started(5)

	var expected_fee: float = BASE_LATE_FEE + (2.0 * PER_DAY_RATE)
	assert_almost_eq(
		_economy.get_cash(),
		cash_before + expected_fee,
		0.01,
		"Cash increased by late fee amount"
	)


func test_reputation_adjustment_standard_policy() -> void:
	var item: ItemInstance = _create_and_stock_item()

	_controller.process_rental(
		item.instance_id, "vhs_tapes", "overnight", TEST_RENTAL_FEE, 1
	)

	var rep_before: float = _reputation.get_reputation(String(STORE_ID))

	_controller._on_day_started(4)

	var expected_delta: float = (
		VideoRentalStoreController.RENTAL_REP_GAIN * 1.0
	)
	assert_almost_eq(
		_reputation.get_reputation(String(STORE_ID)),
		rep_before + expected_delta,
		0.01,
		"Reputation increases by RENTAL_REP_GAIN × STANDARD multiplier (1.0)"
	)


func test_rental_returned_signal_fires() -> void:
	var item: ItemInstance = _create_and_stock_item()

	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day", TEST_RENTAL_FEE, 1
	)

	var signal_fired: bool = false
	var signal_item_id: String = ""
	var on_returned := func(
		iid: String, _degraded: bool
	) -> void:
		signal_fired = true
		signal_item_id = iid

	EventBus.rental_returned.connect(on_returned)

	_controller._on_day_started(4)

	assert_true(signal_fired, "rental_returned signal fires on return")
	assert_eq(
		signal_item_id, item.instance_id,
		"Signal carries correct item_id"
	)

	EventBus.rental_returned.disconnect(on_returned)


func test_no_late_fee_within_grace_period() -> void:
	var item: ItemInstance = _create_and_stock_item()

	# Overnight rental on day 1, return_day=2, grace=1, deadline=3
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "overnight", TEST_RENTAL_FEE, 1
	)

	var late_fee_fired: bool = false
	var on_late_fee := func(
		_iid: String, _fee: float, _days: int
	) -> void:
		late_fee_fired = true

	EventBus.rental_late_fee.connect(on_late_fee)

	# Day 3 = exactly at deadline, not overdue
	_controller._on_day_started(3)

	assert_false(
		late_fee_fired,
		"No late fee within grace period"
	)

	EventBus.rental_late_fee.disconnect(on_late_fee)


func _create_and_stock_item() -> ItemInstance:
	var item: ItemInstance = ItemInstance.create(
		_item_def, "good", 0, TEST_BASE_PRICE
	)
	_inventory.add_item(STORE_ID, item)
	return item


func _create_item_definition() -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = TEST_ITEM_ID
	def.item_name = "Test VHS Tape"
	def.category = "vhs_tapes"
	def.store_type = "rentals"
	def.base_price = TEST_BASE_PRICE
	def.rarity = "common"
	def.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)
	return def


func _register_store_in_content_registry() -> void:
	if ContentRegistry.exists("rentals"):
		return
	ContentRegistry.register_entry(
		{
			"id": "rentals",
			"name": "Video Rental",
			"scene_path": "",
			"backroom_capacity": 150,
		},
		"store"
	)


func _unregister_store_from_content_registry() -> void:
	if not ContentRegistry.exists("rentals"):
		return
	var entries: Dictionary = ContentRegistry._entries
	var aliases: Dictionary = ContentRegistry._aliases
	var types: Dictionary = ContentRegistry._types
	var display_names: Dictionary = ContentRegistry._display_names
	var scene_map: Dictionary = ContentRegistry._scene_map
	entries.erase(&"rentals")
	types.erase(&"rentals")
	display_names.erase(&"rentals")
	scene_map.erase(&"rentals")
	var alias_key: StringName = StringName("rentals")
	for key: StringName in aliases.keys():
		if aliases[key] == alias_key:
			aliases.erase(key)
