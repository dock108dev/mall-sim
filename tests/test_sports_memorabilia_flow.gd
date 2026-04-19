## GUT integration test: sports flow from condition grading to boosted sale.
extends GutTest


const STORE_ID: StringName = &"sports"
const MARKET_EVENT_ID: String = "spm_sports_win"
const ITEM_DEFINITION_ID: StringName = &"sports_signed_baseball_sledge"
const STARTING_CASH: float = 500.0
const FLOAT_TOLERANCE: float = 0.001

var _saved_data_loader: DataLoader
var _data_loader: DataLoader
var _inventory: InventorySystem
var _economy: EconomySystem
var _controller: SportsMemorabiliaController
var _item_sold_signals: Array[Dictionary] = []


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

	_controller = SportsMemorabiliaController.new()
	add_child_autofree(_controller)
	_controller.set_inventory_system(_inventory)
	_controller.initialize(1)

	_item_sold_signals.clear()
	EventBus.item_sold.connect(_on_item_sold)


func after_each() -> void:
	_safe_disconnect(EventBus.item_sold, _on_item_sold)
	GameManager.data_loader = _saved_data_loader
	ContentRegistry.clear_for_testing()


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_item_sold(
	item_id: String, price: float, category: String
) -> void:
	_item_sold_signals.append({
		"item_id": item_id,
		"price": price,
		"category": category,
	})


func _stock_test_item(condition: String = "good") -> ItemInstance:
	var definition: ItemDefinition = ContentRegistry.get_item_definition(
		ITEM_DEFINITION_ID
	)
	assert_not_null(
		definition,
		"Sports autograph definition should load from ContentRegistry"
	)
	var item: ItemInstance = ItemInstance.create_from_definition(
		definition, condition
	)
	_inventory.add_item(STORE_ID, item)
	return item


func _enter_store() -> void:
	_controller.call_deferred("_on_store_entered", STORE_ID)


func test_sports_memorabilia_flow_condition_grading_and_boosted_sale() -> void:
	_enter_store()
	await get_tree().process_frame

	var store_entry: Dictionary = ContentRegistry.get_entry(STORE_ID)
	assert_false(
		store_entry.is_empty(),
		"Sports store data should load from ContentRegistry"
	)

	var item: ItemInstance = _stock_test_item("good")
	var base_price: float = item.definition.base_price

	# Good condition → ×1.0 multiplier
	var good_price: float = _controller.get_item_price(
		StringName(item.instance_id)
	)
	assert_almost_eq(
		good_price,
		base_price * 1.0,
		FLOAT_TOLERANCE,
		"Good condition price should be exactly base_price × 1.0"
	)

	# Mint condition → ×2.0 multiplier
	EventBus.card_condition_selected.emit(
		StringName(item.instance_id), "mint"
	)
	var mint_price: float = _controller.get_item_price(
		StringName(item.instance_id)
	)
	assert_almost_eq(
		mint_price,
		base_price * 2.0,
		FLOAT_TOLERANCE,
		"Mint condition price should be exactly base_price × 2.0"
	)

	EventBus.market_event_started.emit(MARKET_EVENT_ID)

	var memorabilia_multiplier: float = _controller.get_demand_multiplier(
		&"memorabilia"
	)
	var autograph_multiplier: float = _controller.get_demand_multiplier(
		&"autograph"
	)
	assert_gte(
		memorabilia_multiplier, 1.5,
		"sports_win should activate at least a 1.5x demand multiplier for memorabilia"
	)
	assert_gte(
		autograph_multiplier, 1.5,
		"sports_win should activate at least a 1.5x demand multiplier for autograph"
	)

	var boosted_price: float = _controller.get_item_price(
		StringName(item.instance_id)
	)
	var cash_before: float = _economy.get_cash()
	EventBus.item_sold.emit(
		item.instance_id,
		boosted_price,
		String(item.definition.category)
	)
	EventBus.customer_purchased.emit(
		STORE_ID,
		StringName(item.instance_id),
		boosted_price,
		&"sports_test_customer"
	)

	assert_eq(
		_item_sold_signals.size(), 1,
		"item_sold should fire exactly once for the boosted sale"
	)
	assert_eq(
		_item_sold_signals[0]["item_id"],
		String(item.instance_id),
		"item_sold should carry the sold item instance_id"
	)
	assert_almost_eq(
		float(_item_sold_signals[0]["price"]),
		base_price * 2.0 * memorabilia_multiplier,
		FLOAT_TOLERANCE,
		"item_sold should carry base_price × mint_multiplier × season_multiplier"
	)
	assert_almost_eq(
		_economy.get_cash() - cash_before,
		boosted_price,
		FLOAT_TOLERANCE,
		"EconomySystem cash should increase by the boosted sale price"
	)

	EventBus.market_event_ended.emit(MARKET_EVENT_ID)

	assert_almost_eq(
		_controller.get_demand_multiplier(&"memorabilia"),
		1.0,
		FLOAT_TOLERANCE,
		"Season boost should deactivate after market_event_ended"
	)
	assert_almost_eq(
		_controller.get_demand_multiplier(&"autograph"),
		1.0,
		FLOAT_TOLERANCE,
		"Autograph demand should return to 1.0 after market_event_ended"
	)
