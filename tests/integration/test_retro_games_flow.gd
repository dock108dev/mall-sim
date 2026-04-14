## Integration test: Retro Games store flow — stock, test, refurbish, sell.
extends GutTest

var _inventory: InventorySystem
var _economy: EconomySystem
var _refurbishment: RefurbishmentSystem
var _controller: RetroGameStoreController
var _item_def: ItemDefinition
var _testing_slot: Node

const STORE_ID: StringName = &"retro_games"
const TEST_ITEM_ID: String = "retro_test_cartridge"
const TEST_BASE_PRICE: float = 25.0


func before_each() -> void:
	_register_store_in_content_registry()
	_item_def = _create_item_definition()
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(1000.0)

	_refurbishment = RefurbishmentSystem.new()
	add_child_autofree(_refurbishment)
	_refurbishment.initialize(_inventory, _economy)

	_testing_slot = Node.new()
	_testing_slot.add_to_group("shelf_slot")

	_controller = RetroGameStoreController.new()
	add_child_autofree(_controller)
	add_child_autofree(_testing_slot)

	_controller.set_inventory_system(_inventory)
	_controller.set_refurbishment_system(_refurbishment)
	_controller._testing_station_slot = _testing_slot


func after_each() -> void:
	_unregister_store_from_content_registry()


func test_full_retro_games_flow() -> void:
	var item: ItemInstance = ItemInstance.create(
		_item_def, "fair", 0, TEST_BASE_PRICE
	)
	assert_eq(item.condition, "fair", "Item starts in fair condition")

	_inventory.add_item(STORE_ID, item)
	var stocked: ItemInstance = _inventory.get_item(item.instance_id)
	assert_not_null(stocked, "Item exists in inventory after stocking")
	assert_eq(
		stocked.condition, "fair",
		"Stocked item retains fair condition"
	)

	var test_ok: bool = _controller.test_item(item.instance_id)
	assert_true(test_ok, "test_item returns true")
	assert_true(item.tested, "Item is marked as tested")

	item.test_result = "tested_not_working"
	item.current_location = "backroom"

	assert_true(
		_refurbishment.can_refurbish(item),
		"Item is eligible for refurbishment"
	)

	var cash_before_refurb: float = _economy.get_cash()
	var parts_cost: float = _refurbishment.get_parts_cost(item)
	var started: bool = _refurbishment.start_refurbishment(
		item.instance_id
	)
	assert_true(started, "Refurbishment started successfully")
	assert_eq(
		item.current_location, "refurbishing",
		"Item moved to refurbishing location"
	)
	assert_almost_eq(
		_economy.get_cash(),
		cash_before_refurb - parts_cost,
		0.01,
		"Parts cost deducted from cash"
	)

	var duration: int = _refurbishment.get_duration(item)
	for i: int in range(duration):
		EventBus.day_started.emit(i + 1)

	assert_eq(
		item.condition, "good",
		"Item condition advanced from fair to good after refurbishment"
	)
	assert_eq(
		item.current_location, "backroom",
		"Item returned to backroom after refurbishment"
	)

	var sale_price: float = item.get_current_value()
	assert_gt(sale_price, 0.0, "Post-refurbishment sale price is positive")

	var cash_before_sale: float = _economy.get_cash()
	var sold_signal_fired: bool = false
	var sold_price: float = 0.0
	var sold_category: String = ""

	var on_sold := func(
		_id: String, price: float, category: String
	) -> void:
		sold_signal_fired = true
		sold_price = price
		sold_category = category

	EventBus.item_sold.connect(on_sold)

	EventBus.item_sold.emit(
		item.instance_id, sale_price, _item_def.category
	)
	EventBus.customer_purchased.emit(
		STORE_ID, StringName(item.instance_id),
		sale_price, &"test_customer"
	)

	assert_true(sold_signal_fired, "item_sold signal fired")
	assert_almost_eq(
		sold_price, sale_price, 0.01,
		"item_sold carries post-refurbishment price"
	)
	assert_eq(
		sold_category, "cartridges",
		"item_sold carries correct category"
	)

	assert_almost_eq(
		_economy.get_cash(),
		cash_before_sale + sale_price,
		0.01,
		"Player cash increased by the sale price"
	)

	EventBus.item_sold.disconnect(on_sold)


func test_item_condition_fair_before_and_good_after_refurbishment() -> void:
	var item: ItemInstance = ItemInstance.create(
		_item_def, "fair", 0, TEST_BASE_PRICE
	)
	_inventory.add_item(STORE_ID, item)
	assert_eq(item.condition, "fair", "Condition is fair after stocking")

	item.tested = true
	item.test_result = "tested_not_working"
	item.current_location = "backroom"

	_refurbishment.start_refurbishment(item.instance_id)
	var duration: int = _refurbishment.get_duration(item)
	for i: int in range(duration):
		EventBus.day_started.emit(i + 1)

	assert_eq(
		item.condition, "good",
		"Condition advances to good after refurbishment"
	)


func test_tested_flag_set_after_test_item() -> void:
	var item: ItemInstance = ItemInstance.create(
		_item_def, "fair", 0, TEST_BASE_PRICE
	)
	_inventory.add_item(STORE_ID, item)

	assert_false(item.tested, "Item is not tested initially")
	_controller.test_item(item.instance_id)
	assert_true(item.tested, "Item is tested after test_item call")


func test_economy_cash_increases_on_sale() -> void:
	var item: ItemInstance = ItemInstance.create(
		_item_def, "good", 0, TEST_BASE_PRICE
	)
	var sale_price: float = item.get_current_value()
	var cash_before: float = _economy.get_cash()

	EventBus.customer_purchased.emit(
		STORE_ID, StringName(item.instance_id),
		sale_price, &"test_customer"
	)

	assert_almost_eq(
		_economy.get_cash(),
		cash_before + sale_price,
		0.01,
		"Cash increases by exact sale amount"
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


func _register_store_in_content_registry() -> void:
	if ContentRegistry.exists("retro_games"):
		return
	ContentRegistry.register_entry(
		{
			"id": "retro_games",
			"name": "Retro Games",
			"scene_path": "",
			"backroom_capacity": 50,
		},
		"store"
	)


func _unregister_store_from_content_registry() -> void:
	if not ContentRegistry.exists("retro_games"):
		return
	var entries: Dictionary = ContentRegistry._entries
	var aliases: Dictionary = ContentRegistry._aliases
	var types: Dictionary = ContentRegistry._types
	var display_names: Dictionary = ContentRegistry._display_names
	var scene_map: Dictionary = ContentRegistry._scene_map
	entries.erase(&"retro_games")
	types.erase(&"retro_games")
	display_names.erase(&"retro_games")
	scene_map.erase(&"retro_games")
	var alias_key: StringName = StringName("retro_games")
	for key: StringName in aliases.keys():
		if aliases[key] == alias_key:
			aliases.erase(key)
