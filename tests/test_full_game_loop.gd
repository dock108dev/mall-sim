## Integration test covering the lease → stock → sale → day-end report loop.
extends GutTest


const STORE_ID: StringName = &"retro_games"
const SLOT_INDEX: int = 1
const SALE_PRICE: float = 75.0
const FLOAT_EPSILON: float = 0.01

var _data_loader: DataLoader
var _economy: EconomySystem
var _store_state: StoreStateManager
var _inventory: InventorySystem
var _reputation: ReputationSystem
var _progression: ProgressionSystem
var _order_system: OrderSystem
var _time_system: TimeSystem
var _performance_report: PerformanceReportSystem
var _checkout: PlayerCheckout

var _lease_results: Array[Dictionary] = []
var _store_entered_ids: Array[StringName] = []
var _sold_items: Array[Dictionary] = []
var _day_end_payloads: Array[Dictionary] = []
var _reports: Array[PerformanceReport] = []

var _saved_state: GameManager.State
var _saved_store_id: StringName = &""
var _saved_owned_stores: Array[StringName] = []
var _saved_day: int = 1
var _saved_data_loader: DataLoader = null
var _saved_difficulty_tier: StringName = &""


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_day = GameManager.current_day
	_saved_data_loader = GameManager.data_loader
	_saved_difficulty_tier = DifficultySystemSingleton.get_current_tier_id()

	EventBus.clear_day_end_summary()
	_lease_results.clear()
	_store_entered_ids.clear()
	_sold_items.clear()
	_day_end_payloads.clear()
	_reports.clear()

	GameManager.current_state = GameManager.State.GAMEPLAY
	GameManager.current_store_id = &""
	GameManager.owned_stores = []
	GameManager.current_day = 1
	DifficultySystemSingleton.set_tier(&"normal")

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_data_loader.load_all_content()

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(Constants.STARTING_CASH)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)
	_economy.set_inventory_system(_inventory)

	_store_state = StoreStateManager.new()
	add_child_autofree(_store_state)
	_store_state.initialize(_inventory, _economy)

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)
	_reputation.initialize_store(String(STORE_ID))

	_progression = ProgressionSystem.new()
	add_child_autofree(_progression)

	_order_system = OrderSystem.new()
	add_child_autofree(_order_system)
	_order_system.initialize(_inventory, _reputation, _progression)

	_time_system = TimeSystem.new()
	add_child_autofree(_time_system)
	_time_system.initialize()
	_time_system.set_day_end_summary_provider(
		Callable(_economy, "get_day_end_summary")
	)

	_performance_report = PerformanceReportSystem.new()
	add_child_autofree(_performance_report)
	_performance_report.initialize()

	_checkout = PlayerCheckout.new()
	add_child_autofree(_checkout)
	_checkout.initialize(_economy, _inventory, null, _reputation)

	EventBus.lease_completed.connect(_on_lease_completed)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.performance_report_ready.connect(_on_performance_report_ready)


func after_each() -> void:
	if EventBus.lease_completed.is_connected(_on_lease_completed):
		EventBus.lease_completed.disconnect(_on_lease_completed)
	if EventBus.store_entered.is_connected(_on_store_entered):
		EventBus.store_entered.disconnect(_on_store_entered)
	if EventBus.item_sold.is_connected(_on_item_sold):
		EventBus.item_sold.disconnect(_on_item_sold)
	if EventBus.day_ended.is_connected(_on_day_ended):
		EventBus.day_ended.disconnect(_on_day_ended)
	if EventBus.performance_report_ready.is_connected(_on_performance_report_ready):
		EventBus.performance_report_ready.disconnect(_on_performance_report_ready)

	EventBus.clear_day_end_summary()
	GameManager.current_state = _saved_state
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores
	GameManager.current_day = _saved_day
	GameManager.data_loader = _saved_data_loader
	DifficultySystemSingleton.set_tier(_saved_difficulty_tier)


func test_full_new_game_loop_lease_stock_sale_and_daily_report() -> void:
	var store_def: StoreDefinition = _data_loader.get_store(String(STORE_ID))
	assert_not_null(store_def, "retro_games store definition must exist")

	var setup_fee: float = StoreStateManager.get_setup_fee_for_slot_index(
		SLOT_INDEX
	)
	var daily_rent: float = store_def.daily_rent

	assert_almost_eq(
		_economy.get_cash(),
		Constants.STARTING_CASH,
		FLOAT_EPSILON,
		"Player cash should begin at Constants.STARTING_CASH"
	)

	var cash_before_lease: float = _economy.get_cash()
	EventBus.lease_requested.emit(STORE_ID, SLOT_INDEX, "")

	assert_eq(
		_lease_results.size(),
		1,
		"lease_completed should fire exactly once for a successful lease"
	)
	assert_eq(_lease_results[0]["store_id"], STORE_ID)
	assert_true(
		_lease_results[0]["success"] as bool,
		"lease_completed should report success"
	)
	assert_eq(
		_lease_results[0]["message"],
		"",
		"Successful lease should return an empty message"
	)
	assert_true(
		_store_state.owned_slots.has(SLOT_INDEX),
		"owned_slots should contain the leased storefront slot"
	)
	assert_eq(
		_store_state.owned_slots[SLOT_INDEX],
		STORE_ID,
		"owned_slots should map the slot to the leased store"
	)
	assert_almost_eq(
		_economy.get_cash(),
		cash_before_lease - setup_fee,
		FLOAT_EPSILON,
		"Player cash should decrease by the lease setup fee"
	)

	_store_state.set_active_store(STORE_ID)

	assert_eq(
		_store_entered_ids,
		[STORE_ID],
		"set_active_store should emit store_entered for the active store"
	)
	assert_eq(
		_store_state.active_store_id,
		STORE_ID,
		"active_store_id should match the entered store"
	)

	var stocked_item: ItemInstance = _stock_real_item()

	var cash_before_sale: float = _economy.get_cash()
	var customer := Customer.new()
	add_child_autofree(customer)
	_checkout.initiate_sale(customer, stocked_item, SALE_PRICE)
	_force_complete_checkout()

	assert_eq(
		_sold_items.size(),
		1,
		"item_sold should fire once for the completed checkout"
	)
	assert_eq(
		_sold_items[0]["item_id"],
		stocked_item.instance_id,
		"item_sold should report the sold item instance"
	)
	assert_almost_eq(
		_sold_items[0]["price"] as float,
		SALE_PRICE,
		FLOAT_EPSILON,
		"item_sold should report the agreed sale price"
	)
	assert_eq(
		_inventory.get_stock(STORE_ID).size(),
		0,
		"Inventory stock should decrement to 0 after the sale"
	)
	assert_almost_eq(
		_economy.get_cash(),
		cash_before_sale + SALE_PRICE,
		FLOAT_EPSILON,
		"EconomySystem should receive the sale revenue"
	)
	assert_almost_eq(
		_economy.get_store_daily_revenue(String(STORE_ID)),
		SALE_PRICE,
		FLOAT_EPSILON,
		"Store revenue should track the completed sale"
	)

	advance_to_day_end()

	assert_eq(
		_day_end_payloads.size(),
		1,
		"day_ended should fire exactly once at the end of the day"
	)
	assert_false(
		(_day_end_payloads[0]["summary"] as Dictionary).is_empty(),
		"day_ended should publish a non-empty summary dictionary"
	)

	assert_eq(
		_reports.size(),
		1,
		"performance_report_ready should fire once at day end"
	)

	var expected_expenses: float = setup_fee + daily_rent
	var expected_profit: float = SALE_PRICE - expected_expenses
	var report: PerformanceReport = _reports[0]
	assert_almost_eq(
		report.revenue,
		SALE_PRICE,
		FLOAT_EPSILON,
		"PerformanceReport revenue should equal the completed sale"
	)
	assert_almost_eq(
		report.expenses,
		expected_expenses,
		FLOAT_EPSILON,
		"PerformanceReport expenses should include lease fee and daily rent"
	)
	assert_almost_eq(
		report.profit,
		expected_profit,
		FLOAT_EPSILON,
		"PerformanceReport profit should equal revenue minus expenses"
	)

	var daily_summary: Dictionary = _performance_report.generate_report()
	assert_almost_eq(
		float(daily_summary.get("gross_revenue", 0.0)),
		SALE_PRICE,
		FLOAT_EPSILON,
		"Daily summary gross_revenue should equal the completed sale"
	)
	assert_almost_eq(
		float(daily_summary.get("total_expenses", 0.0)),
		expected_expenses,
		FLOAT_EPSILON,
		"Daily summary total_expenses should include rent paid"
	)
	assert_almost_eq(
		float(daily_summary.get("net_profit", 0.0)),
		expected_profit,
		FLOAT_EPSILON,
		"Daily summary net_profit should equal gross_revenue - total_expenses"
	)


func _stock_real_item() -> ItemInstance:
	var starter_items: Array[ItemInstance] = _data_loader.create_starting_inventory(
		String(STORE_ID)
	)
	assert_false(
		starter_items.is_empty(),
		"retro_games should have starter inventory available"
	)
	var item: ItemInstance = starter_items[0]
	item.player_set_price = SALE_PRICE
	var registered: bool = _inventory.register_item(item)
	assert_true(registered, "The stocked starter item should register successfully")
	assert_eq(
		_inventory.get_stock(STORE_ID).size(),
		1,
		"InventorySystem stock should show the added item"
	)
	return item


func _force_complete_checkout() -> void:
	_checkout._checkout_timer.stop()
	_checkout._on_checkout_timer_timeout()


func advance_to_day_end() -> void:
	_time_system.game_time_minutes = 1259.0
	_time_system.current_hour = 20
	_time_system.current_phase = TimeSystem.DayPhase.EVENING
	_time_system._last_emitted_hour = 20
	_time_system._process(2.0)


func _on_lease_completed(
	store_id: StringName, success: bool, message: String
) -> void:
	_lease_results.append({
		"store_id": store_id,
		"success": success,
		"message": message,
	})


func _on_store_entered(store_id: StringName) -> void:
	_store_entered_ids.append(store_id)


func _on_item_sold(
	item_id: String, price: float, category: String
) -> void:
	_sold_items.append({
		"item_id": item_id,
		"price": price,
		"category": category,
	})


func _on_day_ended(day: int) -> void:
	_day_end_payloads.append({
		"day": day,
		"summary": EventBus.get_day_end_summary(),
	})


func _on_performance_report_ready(report: PerformanceReport) -> void:
	_reports.append(report)
