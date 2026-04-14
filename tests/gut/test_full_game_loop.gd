## Integration test covering the full new-game loop: lease → stock → sale → daily report.
extends GutTest


const STORE_ID: StringName = &"retro_games"
const SLOT_INDEX: int = 0
const SALE_PRICE: float = 30.0
const DAILY_RENT: float = 50.0

var _economy: EconomySystem
var _store_state: StoreStateManager
var _inventory: InventorySystem
var _time_system: TimeSystem
var _perf_report: PerformanceReportSystem

var _lease_results: Array[Dictionary] = []
var _items_sold: Array[Dictionary] = []
var _day_ended_days: Array[int] = []
var _reports: Array[PerformanceReport] = []
var _saved_owned_stores: Array[StringName] = []
var _saved_current_store_id: StringName = &""
var _saved_data_loader: DataLoader = null


func before_each() -> void:
	_lease_results.clear()
	_items_sold.clear()
	_day_ended_days.clear()
	_reports.clear()

	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_current_store_id = GameManager.current_store_id
	_saved_data_loader = GameManager.data_loader
	GameManager.owned_stores = []
	GameManager.current_store_id = &""
	GameManager.data_loader = null

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(Constants.STARTING_CASH)
	_economy.set_daily_rent(DAILY_RENT)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_store_state = StoreStateManager.new()
	add_child_autofree(_store_state)

	_time_system = TimeSystem.new()
	add_child_autofree(_time_system)
	_time_system.initialize()
	_time_system.set_process(false)

	_perf_report = PerformanceReportSystem.new()
	add_child_autofree(_perf_report)
	_perf_report.initialize()

	EventBus.lease_completed.connect(_on_lease_completed)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.performance_report_ready.connect(_on_report_ready)


func after_each() -> void:
	if EventBus.lease_completed.is_connected(_on_lease_completed):
		EventBus.lease_completed.disconnect(_on_lease_completed)
	if EventBus.item_sold.is_connected(_on_item_sold):
		EventBus.item_sold.disconnect(_on_item_sold)
	if EventBus.day_ended.is_connected(_on_day_ended):
		EventBus.day_ended.disconnect(_on_day_ended)
	if EventBus.performance_report_ready.is_connected(_on_report_ready):
		EventBus.performance_report_ready.disconnect(_on_report_ready)

	GameManager.owned_stores = _saved_owned_stores
	GameManager.current_store_id = _saved_current_store_id
	GameManager.data_loader = _saved_data_loader


func test_full_new_game_lease_stock_sale_report() -> void:
	_verify_starting_cash()
	_lease_store()
	_enter_store()
	var item: ItemInstance = _stock_item()
	_simulate_sale(item)
	_end_day_and_verify_report()


func _verify_starting_cash() -> void:
	assert_eq(
		_economy.get_cash(), Constants.STARTING_CASH,
		"Player cash should start at Constants.STARTING_CASH"
	)


func _lease_store() -> void:
	var cash_before: float = _economy.get_cash()
	var result: bool = _store_state.lease_store(
		SLOT_INDEX, STORE_ID, STORE_ID
	)
	GameManager.owned_stores.append(STORE_ID)

	assert_true(result, "lease_store should succeed for empty slot")
	assert_true(
		_store_state.owned_slots.has(SLOT_INDEX),
		"owned_slots should contain leased slot"
	)
	assert_eq(
		_store_state.owned_slots[SLOT_INDEX], STORE_ID,
		"Slot should map to the correct store_id"
	)
	assert_eq(
		_lease_results.size(), 1,
		"Should emit exactly one lease_completed signal"
	)
	assert_true(
		_lease_results[0]["success"] as bool,
		"lease_completed should report success"
	)
	assert_eq(
		_lease_results[0]["message"], "",
		"Successful lease should have empty message"
	)

	var lease_fee: float = 0.0
	if GameManager.owned_stores.size() > 1:
		lease_fee = _economy.get_cash() - cash_before
	assert_eq(
		_economy.get_cash(), cash_before - lease_fee,
		"Player cash should decrease by lease fee (if any)"
	)


func _enter_store() -> void:
	_store_state.set_active_store(STORE_ID)
	assert_eq(
		_store_state.active_store_id, STORE_ID,
		"active_store_id should match entered store"
	)


func _stock_item() -> ItemInstance:
	var item_def := ItemDefinition.new()
	item_def.id = "test_retro_cartridge"
	item_def.item_name = "Test Retro Cartridge"
	item_def.category = "retro_games"
	item_def.store_type = "retro_games"
	item_def.base_price = 25.0
	item_def.rarity = "common"

	var item: ItemInstance = ItemInstance.create(
		item_def, "good", 1, 15.0
	)
	item.current_location = "shelf:slot_0"
	item.player_set_price = SALE_PRICE

	_register_test_store_in_content_registry()
	_inventory.add_item(STORE_ID, item)

	var stock: Array[ItemInstance] = _inventory.get_stock(STORE_ID)
	assert_eq(stock.size(), 1, "Inventory should contain one item")
	assert_eq(
		stock[0].instance_id, item.instance_id,
		"Stocked item should match added item"
	)
	return item


func _simulate_sale(item: ItemInstance) -> void:
	var cash_before: float = _economy.get_cash()
	var category: String = item.definition.category

	_economy.add_cash(SALE_PRICE, "Item sale: %s" % item.instance_id)
	_inventory.remove_item(item.instance_id)
	EventBus.item_sold.emit(item.instance_id, SALE_PRICE, category)

	assert_eq(
		_items_sold.size(), 1,
		"item_sold signal should fire exactly once"
	)
	assert_eq(
		_items_sold[0]["price"], SALE_PRICE,
		"Sold price should match expected sale price"
	)

	var remaining: Array[ItemInstance] = _inventory.get_stock(STORE_ID)
	assert_eq(
		remaining.size(), 0,
		"Stock should be empty after sale"
	)
	assert_eq(
		_economy.get_cash(), cash_before + SALE_PRICE,
		"Player cash should increase by sale price"
	)


func _end_day_and_verify_report() -> void:
	var cash_before_day_end: float = _economy.get_cash()

	EventBus.day_ended.emit(_time_system.current_day)

	assert_eq(
		_day_ended_days.size(), 1,
		"day_ended should fire exactly once"
	)
	assert_eq(
		_day_ended_days[0], _time_system.current_day,
		"day_ended should carry the correct day number"
	)

	assert_eq(
		_reports.size(), 1,
		"performance_report_ready should fire once after day end"
	)

	var report: PerformanceReport = _reports[0]
	assert_eq(
		report.day, _time_system.current_day,
		"Report day should match current day"
	)
	assert_true(
		report.revenue > 0.0,
		"Report revenue should be positive after a sale"
	)

	var expected_profit: float = report.revenue - report.expenses
	assert_almost_eq(
		report.profit, expected_profit, 0.01,
		"Report profit should equal revenue minus expenses"
	)

	assert_true(
		_economy.get_cash() < cash_before_day_end,
		"Cash should decrease after rent deduction at day end"
	)


func _register_test_store_in_content_registry() -> void:
	if ContentRegistry.exists("retro_games"):
		return
	ContentRegistry.register_entry(
		{"id": "retro_games", "name": "Retro Games"}, "store"
	)


func _on_lease_completed(
	store_id: StringName, success: bool, message: String
) -> void:
	_lease_results.append({
		"store_id": store_id,
		"success": success,
		"message": message,
	})


func _on_item_sold(
	item_id: String, price: float, category: String
) -> void:
	_items_sold.append({
		"item_id": item_id,
		"price": price,
		"category": category,
	})


func _on_day_ended(day: int) -> void:
	_day_ended_days.append(day)


func _on_report_ready(report: PerformanceReport) -> void:
	_reports.append(report)
