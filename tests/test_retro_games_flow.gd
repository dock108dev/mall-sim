## Integration test: Retro Games store flow covering item testing,
## condition upgrade via refurbishment, price recalculation, and sale.
extends GutTest

const STORE_ID: StringName = &"retro_games"
const TEST_ITEM_ID: String = "test_retro_cartridge"
const TEST_BASE_PRICE: float = 20.0
const STARTING_CASH: float = 1000.0

var _inventory: InventorySystem
var _economy: EconomySystem
var _testing_system: TestingSystem
var _refurbishment: RefurbishmentSystem
var _market_value: MarketValueSystem
var _item_def: ItemDefinition
var _item: ItemInstance
var _registered_store_entry: bool = false


func before_each() -> void:
	_ensure_store_registry_entry()

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)

	_testing_system = TestingSystem.new()
	add_child_autofree(_testing_system)
	_testing_system.initialize(_inventory)

	_refurbishment = RefurbishmentSystem.new()
	add_child_autofree(_refurbishment)
	_refurbishment.initialize(_inventory, _economy)

	_market_value = MarketValueSystem.new()
	add_child_autofree(_market_value)
	_market_value.initialize(_inventory, null, null)
	_market_value.set_testing_system(_testing_system)

	_item_def = _create_item_definition()
	# Condition "poor" represents an item of unknown/unverified quality
	# before it has been tested or refurbished.
	_item = ItemInstance.create(_item_def, "poor", 0, TEST_BASE_PRICE)
	_item.current_location = "backroom"
	_inventory.add_item(STORE_ID, _item)


func after_each() -> void:
	_cleanup_registry()


func test_full_retro_games_flow() -> void:
	# Step 1: Item exists with unknown (poor) condition and is untested.
	assert_not_null(
		_inventory.get_item(_item.instance_id),
		"Item exists in inventory after stocking"
	)
	assert_eq(_item.condition, "poor", "Item starts with poor condition")
	assert_false(_item.tested, "Item starts untested")

	# Step 2: Run the testing station workflow.
	# Force a not-working result so the refurbishment path is exercised.
	_testing_system._working_chance = 0.0

	var test_signals: Array[Dictionary] = []
	var test_cb: Callable = func(
		instance_id: String, result: String
	) -> void:
		test_signals.append({"instance_id": instance_id, "result": result})
	EventBus.item_test_completed.connect(test_cb)

	var started: bool = _testing_system.start_test(_item.instance_id)
	assert_true(started, "start_test returns true for a valid item")
	_testing_system._on_test_timer_timeout()

	EventBus.item_test_completed.disconnect(test_cb)

	assert_eq(
		test_signals.size(), 1,
		"item_test_completed fires exactly once"
	)
	assert_eq(
		test_signals[0]["result"], "tested_not_working",
		"Test result is tested_not_working"
	)
	assert_eq(
		test_signals[0]["instance_id"], _item.instance_id,
		"Signal carries the correct instance_id"
	)
	assert_true(_item.tested, "Item is marked as tested after test completes")
	assert_eq(
		_item.test_result, "tested_not_working",
		"Item test_result set to tested_not_working"
	)

	# Step 3: Record price before refurbishment for comparison.
	var price_before: float = _market_value.calculate_item_value(_item)
	assert_gt(price_before, 0.0, "Pre-refurbishment price is positive")

	# Step 4: Refurbish the failed item; condition should advance to fair.
	_item.current_location = "backroom"
	assert_true(
		_refurbishment.can_refurbish(_item),
		"Item is eligible for refurbishment after failing test"
	)

	var refurb_signals: Array[Dictionary] = []
	var refurb_cb: Callable = func(
		item_id: String, success: bool, new_condition: String
	) -> void:
		refurb_signals.append({
			"item_id": item_id,
			"success": success,
			"new_condition": new_condition,
		})
	EventBus.refurbishment_completed.connect(refurb_cb)

	var cash_before_refurb: float = _economy.get_cash()
	var parts_cost: float = _refurbishment.get_parts_cost(_item)
	var refurb_started: bool = _refurbishment.start_refurbishment(
		_item.instance_id
	)
	assert_true(refurb_started, "Refurbishment started successfully")
	assert_almost_eq(
		_economy.get_cash(), cash_before_refurb - parts_cost, 0.01,
		"Parts cost deducted from player cash"
	)

	var duration: int = _refurbishment.get_duration(_item)
	for i: int in range(duration):
		EventBus.day_started.emit(i + 1)

	EventBus.refurbishment_completed.disconnect(refurb_cb)

	assert_eq(
		refurb_signals.size(), 1, "refurbishment_completed fires exactly once"
	)
	assert_true(refurb_signals[0]["success"], "Refurbishment succeeded")
	assert_eq(
		_item.condition, "fair",
		"Item condition upgrades from poor to fair after refurbishment"
	)

	# Step 5: Verify MarketValueSystem recalculates a different price.
	var price_after: float = _market_value.calculate_item_value(_item)
	assert_gt(
		price_after, price_before,
		"Post-refurbishment price is higher than pre-refurbishment price"
	)

	# Step 6: Simulate customer purchase at the new price.
	var sold_signals: Array[Dictionary] = []
	var sold_cb: Callable = func(
		item_id: String, price: float, category: String
	) -> void:
		sold_signals.append({
			"item_id": item_id,
			"price": price,
			"category": category,
		})
	EventBus.item_sold.connect(sold_cb)

	var sale_price: float = price_after
	var cash_before_sale: float = _economy.get_cash()

	EventBus.item_sold.emit(
		_item.instance_id, sale_price, _item_def.category
	)
	EventBus.customer_purchased.emit(
		STORE_ID, StringName(_item.instance_id),
		sale_price, &"test_customer"
	)

	EventBus.item_sold.disconnect(sold_cb)

	assert_eq(sold_signals.size(), 1, "item_sold fires exactly once")
	assert_eq(
		sold_signals[0]["item_id"], _item.instance_id,
		"item_sold carries the correct item_id"
	)
	assert_almost_eq(
		sold_signals[0]["price"] as float, sale_price, 0.01,
		"item_sold carries the final post-refurbishment price"
	)

	# Step 7: Verify EconomySystem records the revenue.
	assert_almost_eq(
		_economy.get_cash(), cash_before_sale + sale_price, 0.01,
		"Player cash increases by the sale price after transaction"
	)

	# Step 8: Verify item is removed from inventory after sale.
	assert_null(
		_inventory.get_item(_item.instance_id),
		"Item is no longer in inventory after sale"
	)


func test_test_completed_signal_fires_on_begin_test() -> void:
	_testing_system._working_chance = 1.0

	var fired: Array = [false]
	var received_result: Array = [""]
	var test_cb: Callable = func(
		_id: String, result: String
	) -> void:
		fired[0] = true
		received_result[0] = result
	EventBus.item_test_completed.connect(test_cb)

	_testing_system.start_test(_item.instance_id)
	_testing_system._on_test_timer_timeout()

	EventBus.item_test_completed.disconnect(test_cb)

	assert_true(fired[0], "item_test_completed signal fires after begin_test")
	assert_eq(
		received_result[0], "tested_working",
		"Test result is tested_working when working_chance is 1.0"
	)


func test_condition_upgrades_from_poor_to_fair_after_refurbishment() -> void:
	_item.tested = true
	_item.test_result = "tested_not_working"
	_item.current_location = "backroom"

	_refurbishment.start_refurbishment(_item.instance_id)
	var duration: int = _refurbishment.get_duration(_item)
	for i: int in range(duration):
		EventBus.day_started.emit(i + 1)

	assert_eq(
		_item.condition, "fair",
		"Condition advances from poor to fair after one refurbishment cycle"
	)


func test_market_value_differs_before_and_after_refurbishment() -> void:
	_item.tested = true
	_item.test_result = "tested_not_working"
	_item.current_location = "backroom"

	var price_before: float = _market_value.calculate_item_value(_item)

	_refurbishment.start_refurbishment(_item.instance_id)
	var duration: int = _refurbishment.get_duration(_item)
	for i: int in range(duration):
		EventBus.day_started.emit(i + 1)

	var price_after: float = _market_value.calculate_item_value(_item)

	assert_ne(
		price_before, price_after,
		"MarketValueSystem produces a different price after condition change"
	)
	assert_gt(
		price_after, price_before,
		"Post-refurbishment price is higher than pre-refurbishment price"
	)


func test_economy_cash_increases_by_sale_price() -> void:
	var item: ItemInstance = ItemInstance.create(
		_item_def, "fair", 0, TEST_BASE_PRICE
	)
	var sale_price: float = item.get_current_value()
	var cash_before: float = _economy.get_cash()

	EventBus.customer_purchased.emit(
		STORE_ID, StringName(item.instance_id),
		sale_price, &"test_customer"
	)

	assert_almost_eq(
		_economy.get_cash(), cash_before + sale_price, 0.01,
		"Economy records revenue equal to the sale price"
	)


func test_inventory_does_not_contain_item_after_sale() -> void:
	var item: ItemInstance = ItemInstance.create(
		_item_def, "good", 0, TEST_BASE_PRICE
	)
	_inventory.add_item(STORE_ID, item)
	assert_not_null(
		_inventory.get_item(item.instance_id),
		"Item is in inventory before sale"
	)

	EventBus.customer_purchased.emit(
		STORE_ID, StringName(item.instance_id),
		item.get_current_value(), &"test_customer"
	)

	assert_null(
		_inventory.get_item(item.instance_id),
		"Item is removed from inventory after customer_purchased"
	)


func _create_item_definition() -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = TEST_ITEM_ID
	def.item_name = "Test Cartridge"
	def.category = "cartridges"
	def.store_type = "retro_games"
	def.base_price = TEST_BASE_PRICE
	def.rarity = "common"
	def.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)
	return def


func _ensure_store_registry_entry() -> void:
	if ContentRegistry.exists("retro_games"):
		_registered_store_entry = false
		return
	ContentRegistry.register_entry(
		{
			"id": "retro_games",
			"name": "Retro Game Store",
			"scene_path": "",
			"backroom_capacity": 120,
		},
		"store"
	)
	_registered_store_entry = true


func _cleanup_registry() -> void:
	if not _registered_store_entry:
		return
	if not ContentRegistry.exists("retro_games"):
		return
	var entries: Dictionary = ContentRegistry._entries
	var types: Dictionary = ContentRegistry._types
	var display_names: Dictionary = ContentRegistry._display_names
	var scene_map: Dictionary = ContentRegistry._scene_map
	var aliases: Dictionary = ContentRegistry._aliases
	entries.erase(&"retro_games")
	types.erase(&"retro_games")
	display_names.erase(&"retro_games")
	scene_map.erase(&"retro_games")
	for key: StringName in aliases.keys():
		if aliases[key] == &"retro_games":
			aliases.erase(key)
