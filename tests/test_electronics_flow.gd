## GUT integration test: Consumer Electronics flow covering depreciation,
## demo wear, warranty offer, warranty upsell, and sale revenue.
extends GutTest

const STORE_ID: StringName = &"electronics"
const SOURCE_ITEM_ID: StringName = &"elec_portastation_console"
const STARTING_CASH: float = 500.0
const FLOAT_TOLERANCE: float = 0.01

var _saved_data_loader: DataLoader
var _data_loader: DataLoader
var _inventory: InventorySystem
var _economy: EconomySystem
var _controller: ElectronicsStoreController
var _demo_slot: DemoSlot
var _warranty_offer_ids: Array[String] = []
var _item_sold_signals: Array[Dictionary] = []


class DemoSlot extends Node:
	var slot_id: String = "demo_0"
	var fixture_id: String = ElectronicsStoreController.DEMO_STATION_FIXTURE_ID


func before_each() -> void:
	_saved_data_loader = GameManager.data_loader
	ContentRegistry.clear_for_testing()

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_data_loader.load_all_content()
	GameManager.data_loader = _data_loader

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)

	_controller = ElectronicsStoreController.new()
	add_child_autofree(_controller)
	_controller.set_inventory_system(_inventory)
	_controller.initialize(_data_loader, 1)
	_demo_slot = DemoSlot.new()
	add_child_autofree(_demo_slot)
	_controller._demo_station_slots = [_demo_slot]

	_warranty_offer_ids.clear()
	_item_sold_signals.clear()
	EventBus.warranty_offer_presented.connect(_on_warranty_offer_presented)
	EventBus.item_sold.connect(_on_item_sold)


func after_each() -> void:
	_safe_disconnect(EventBus.warranty_offer_presented, _on_warranty_offer_presented)
	_safe_disconnect(EventBus.item_sold, _on_item_sold)
	GameManager.data_loader = _saved_data_loader
	ContentRegistry.clear_for_testing()


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_warranty_offer_presented(item_id: String) -> void:
	_warranty_offer_ids.append(item_id)


func _on_item_sold(
	item_id: String, price: float, category: String
) -> void:
	_item_sold_signals.append({
		"item_id": item_id,
		"price": price,
		"category": category,
	})


func _make_console_definition() -> ItemDefinition:
	var source: ItemDefinition = ContentRegistry.get_item_definition(
		SOURCE_ITEM_ID
	)
	assert_not_null(
		source,
		"Electronics item definition should load from ContentRegistry"
	)

	var definition := ItemDefinition.new()
	definition.id = "test_%s" % String(SOURCE_ITEM_ID)
	definition.item_name = source.item_name
	definition.category = source.category
	definition.subcategory = source.subcategory
	definition.store_type = String(STORE_ID)
	definition.base_price = 200.0
	definition.rarity = source.rarity
	definition.product_line = (
		source.product_line if not source.product_line.is_empty()
		else "test_portastation_line"
	)
	definition.generation = maxi(source.generation, 1)
	definition.launch_day = 1
	definition.min_value_ratio = 0.20
	definition.condition_range = PackedStringArray(
		["good", "near_mint", "mint"]
	)
	return definition


func _stock_item(definition: ItemDefinition, condition: String) -> ItemInstance:
	var item: ItemInstance = ItemInstance.create_from_definition(
		definition, condition
	)
	_inventory.add_item(STORE_ID, item)
	return item


func test_consumer_electronics_flow_stock_demo_warranty_and_sale() -> void:
	var definition: ItemDefinition = _make_console_definition()
	var launch_price: float = definition.base_price
	var demo_item: ItemInstance = _stock_item(definition, "mint")
	var sale_item: ItemInstance = _stock_item(definition, "good")

	EventBus.day_started.emit(31)
	var depreciated_price: float = _controller.get_current_price(
		sale_item.instance_id
	)
	assert_lt(
		depreciated_price,
		launch_price,
		"Depreciation should drop price below the launch_price after 30 days"
	)

	var demo_started: bool = _controller.place_demo_item(demo_item.instance_id)
	assert_true(
		demo_started,
		"Demo unit should be designated successfully once a demo slot exists"
	)
	assert_eq(
		demo_item.condition,
		"mint",
		"Demo item should start at mint condition before wear is processed"
	)

	EventBus.day_started.emit(
		31 + ElectronicsStoreController.DEMO_DEGRADE_INTERVAL_DAYS
	)
	assert_eq(
		demo_item.condition,
		"near_mint",
		"Demo unit should degrade exactly one step after one demo cycle"
	)

	var sale_price: float = _controller.get_current_price(sale_item.instance_id)
	assert_true(
		WarrantyManager.is_eligible(sale_price),
		"Non-demo sale item should be eligible for warranty upsell"
	)

	var offer_presented: bool = _controller.present_warranty_offer(
		sale_item.instance_id, sale_price
	)
	assert_true(
		offer_presented,
		"Controller should present a warranty offer for an eligible sale"
	)
	assert_eq(
		_warranty_offer_ids,
		[String(sale_item.instance_id)],
		"warranty_offer_presented should carry the sold non-demo instance_id"
	)

	var warranty_fee: float = WarrantyManager.calculate_fee(
		sale_price, WarrantyDialog.DEFAULT_WARRANTY_PERCENT
	)
	var total_price: float = sale_price + warranty_fee
	var cash_before_sale: float = _economy.get_cash()
	var purchase_day: int = 41
	var warranty_record: Dictionary = _controller.get_warranty_manager().add_warranty(
		sale_item.instance_id,
		sale_price,
		warranty_fee,
		definition.base_price,
		purchase_day,
	)
	assert_eq(
		_controller.get_warranty_manager().get_active_count(),
		1,
		"Accepted warranty should add one active warranty record"
	)
	assert_almost_eq(
		float(warranty_record.get("warranty_fee", 0.0)),
		warranty_fee,
		FLOAT_TOLERANCE,
		"Warranty record should store the fee charged at checkout"
	)

	var removed: bool = _inventory.remove_item(sale_item.instance_id)
	assert_true(removed, "Sold non-demo unit should be removed from inventory")
	EventBus.item_sold.emit(
		sale_item.instance_id,
		total_price,
		String(sale_item.definition.category)
	)
	EventBus.customer_purchased.emit(
		STORE_ID,
		StringName(sale_item.instance_id),
		total_price,
		&"electronics_test_customer",
	)

	assert_eq(
		_item_sold_signals.size(),
		1,
		"item_sold should fire exactly once for the warranty sale"
	)
	assert_eq(
		_item_sold_signals[0]["item_id"],
		sale_item.instance_id,
		"item_sold should carry the sold non-demo item id"
	)
	assert_almost_eq(
		float(_item_sold_signals[0]["price"]),
		total_price,
		FLOAT_TOLERANCE,
		"item_sold should carry base sale price plus warranty fee"
	)
	assert_almost_eq(
		_economy.get_cash() - cash_before_sale,
		total_price,
		FLOAT_TOLERANCE,
		"EconomySystem should receive the combined sale price and warranty fee"
	)

	var expiry_day: int = int(warranty_record.get("expiry_day", 0))
	_controller.get_warranty_manager().purge_expired(expiry_day + 1)
	assert_eq(
		_controller.get_warranty_manager().get_active_count(),
		0,
		"Warranty should expire after WARRANTY_DURATION_DAYS has elapsed"
	)
