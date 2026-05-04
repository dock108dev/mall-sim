## Integration test: full day cycle across time, spawning, queueing, checkout,
## economy day-end summary, and inventory depletion.
extends GutTest

const TEST_SIGNAL_UTILS: GDScript = preload("res://game/tests/signal_utils.gd")

const STORE_ID: String = "test_day_cycle_store"
const STARTING_CASH: float = 1000.0
const TEST_PRICE: float = 42.0
const REGISTER_POS: Vector3 = Vector3.ZERO
const QUEUE_ENTRY_POS: Vector3 = Vector3(0.0, 0.0, 3.0)

var _data_loader: DataLoader
var _time: TimeSystem
var _economy: EconomySystem
var _inventory: InventorySystem
var _reputation: ReputationSystem
var _customer_system: CustomerSystem
var _spawner: MallCustomerSpawner
var _queue: QueueSystem
var _checkout: PlayerCheckout

var _stocked_item: ItemInstance
var _spawned_customer: Customer
var _day_end_payloads: Array[Dictionary] = []
var _entered_customers: Array[Dictionary] = []

var _saved_store_id: StringName = &""
var _saved_owned_stores: Array[StringName] = []
var _saved_data_loader: DataLoader = null
var _saved_day: int = 1


func before_each() -> void:
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_data_loader = GameManager.data_loader
	_saved_day = GameManager.current_day

	EventBus.clear_day_end_summary()
	_day_end_payloads.clear()
	_entered_customers.clear()
	_spawned_customer = null

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_register_test_store()
	_register_test_customer_profile()

	GameManager.current_store_id = StringName(STORE_ID)
	GameManager.owned_stores = [StringName(STORE_ID)]
	GameManager.current_day = 1

	_time = TimeSystem.new()
	add_child_autofree(_time)
	_time.initialize()

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)
	_time.set_day_end_summary_provider(
		Callable(_economy, "get_day_end_summary")
	)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)
	_economy.set_inventory_system(_inventory)

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)
	_reputation.initialize_store(STORE_ID)

	_customer_system = CustomerSystem.new()
	add_child_autofree(_customer_system)
	_customer_system.initialize(null, _inventory, _reputation)
	_customer_system.set_store_id(STORE_ID)
	_prime_customer_pool()
	# prevent Day-1 auto-spawn from polluting active count
	_customer_system._day1_first_customer_spawned = true

	_spawner = MallCustomerSpawner.new()
	add_child_autofree(_spawner)
	_spawner.initialize(_customer_system, _reputation)

	_queue = QueueSystem.new()
	add_child_autofree(_queue)
	_queue.initialize()
	_queue.setup_queue_positions(REGISTER_POS, QUEUE_ENTRY_POS)

	_checkout = PlayerCheckout.new()
	add_child_autofree(_checkout)
	_checkout.initialize(
		_economy, _inventory, _customer_system, _reputation
	)
	_checkout.setup_queue_positions(REGISTER_POS, QUEUE_ENTRY_POS)
	if EventBus.checkout_queue_ready.is_connected(_checkout._on_checkout_queue_ready):
		EventBus.checkout_queue_ready.disconnect(_checkout._on_checkout_queue_ready)

	_stock_known_item()

	EventBus.customer_entered.connect(_on_customer_entered)
	EventBus.day_ended.connect(_on_day_ended)


func after_each() -> void:
	TEST_SIGNAL_UTILS.safe_disconnect(EventBus.customer_entered, _on_customer_entered)
	TEST_SIGNAL_UTILS.safe_disconnect(EventBus.day_ended, _on_day_ended)
	EventBus.clear_day_end_summary()
	_unregister_test_store()
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores
	GameManager.data_loader = _saved_data_loader
	GameManager.current_day = _saved_day


func test_full_day_cycle_tracks_spawn_sale_summary_and_inventory() -> void:
	var stock_before_sale: int = _inventory.get_stock(StringName(STORE_ID)).size()

	advance_time_to_phase(TimeSystem.DayPhase.MORNING_RAMP)
	_force_spawn_customer()

	assert_not_null(
		_spawned_customer,
		"CustomerSystem should spawn a customer during open hours"
	)
	assert_eq(
		_customer_system.get_active_customer_count(),
		1,
		"CustomerSystem should track the spawned customer as active"
	)
	assert_eq(
		_entered_customers.size(),
		1,
		"customer_entered should fire once for the spawned customer"
	)

	_spawned_customer._desired_item = _stocked_item
	_spawned_customer.current_state = Customer.State.PURCHASING

	var queued: bool = _queue.enqueue_customer(_spawned_customer)
	assert_true(queued, "Customer should enter the checkout queue")
	assert_eq(_queue.get_queue_size(), 1, "Queue size should be 1 before checkout")

	_checkout.initiate_sale(_spawned_customer, _stocked_item, TEST_PRICE)
	_force_complete_checkout()

	assert_eq(
		_inventory.get_stock(StringName(STORE_ID)).size(),
		stock_before_sale - 1,
		"Inventory stock should decrement by 1 after the sale"
	)
	assert_null(
		_inventory.get_item(String(_stocked_item.instance_id)),
		"Sold item should no longer be present in inventory"
	)
	assert_almost_eq(
		_economy.get_store_daily_revenue(STORE_ID),
		TEST_PRICE,
		0.01,
		"Store daily revenue should equal the completed sale price"
	)

	advance_to_day_end()

	assert_eq(_day_end_payloads.size(), 1, "day_ended should fire exactly once")
	assert_eq(_day_end_payloads[0]["day"], 1, "day_ended should report day 1")

	var summary: Dictionary = _day_end_payloads[0]["summary"] as Dictionary
	var transactions: Array = summary.get("transactions", []) as Array
	assert_false(summary.is_empty(), "day_ended should publish a non-empty summary")
	assert_eq(int(summary.get("items_sold", 0)), 1, "Summary should report one sold item")
	assert_eq(
		int(summary.get("transaction_count", 0)),
		1,
		"Summary should report one completed transaction"
	)
	assert_eq(transactions.size(), 1, "Summary should include the completed transaction")
	assert_almost_eq(
		float(summary.get("total_revenue", 0.0)),
		TEST_PRICE,
		0.01,
		"Summary revenue should equal the completed sale price"
	)
	assert_almost_eq(
		_economy.get_store_daily_revenue(STORE_ID),
		TEST_PRICE,
		0.01,
		"Revenue should remain available for day-end assertions"
	)


func _stock_known_item() -> void:
	var definition: ItemDefinition = ItemDefinition.new()
	definition.id = "test_day_cycle_item"
	definition.item_name = "Day Cycle Test Item"
	definition.category = &"games"
	definition.base_price = TEST_PRICE
	definition.rarity = "common"
	definition.store_type = StringName(STORE_ID)

	_stocked_item = ItemInstance.create(definition, "good", 1, definition.base_price)
	_stocked_item.player_set_price = TEST_PRICE
	_inventory.add_item(StringName(STORE_ID), _stocked_item)
	var assigned: bool = _inventory.assign_to_shelf(
		StringName(STORE_ID),
		_stocked_item.instance_id,
		&"slot_day_cycle"
	)
	assert_true(assigned, "Known item should be assignable to a shelf slot")


func advance_time_to_phase(target_phase: TimeSystem.DayPhase) -> void:
	var safety_steps: int = 0
	while _time.current_phase != target_phase:
		_time._process(60.0)
		safety_steps += 1
		if safety_steps > 32 or not _day_end_payloads.is_empty():
			break


func advance_to_day_end() -> void:
	_time.game_time_minutes = 1259.0
	_time.current_hour = 20
	_time.current_phase = TimeSystem.DayPhase.EVENING
	_time._last_emitted_hour = 20
	_time._process(2.0)


func _force_spawn_customer() -> void:
	var interval: float = _spawner._get_spawn_interval()
	_spawner._process(interval)
	var active_customers: Array[Customer] = _customer_system.get_active_customers()
	if not active_customers.is_empty():
		_spawned_customer = active_customers[0]


func _force_complete_checkout() -> void:
	_checkout._checkout_timer.stop()
	_checkout._on_checkout_timer_timeout()


func _on_customer_entered(customer_data: Dictionary) -> void:
	_entered_customers.append(customer_data)


func _on_day_ended(day: int) -> void:
	_day_end_payloads.append({
		"day": day,
		"summary": EventBus.get_day_end_summary(),
	})


func _register_test_store() -> void:
	var store_def: StoreDefinition = StoreDefinition.new()
	store_def.id = STORE_ID
	store_def.store_name = "Day Cycle Test Store"
	store_def.display_name = "Day Cycle Test Store"
	store_def.store_type = StringName(STORE_ID)
	store_def.size_category = "small"
	store_def.daily_rent = 1.0
	store_def.base_foot_traffic = 1.0
	store_def.allowed_categories = PackedStringArray(["games"])
	_data_loader._stores[STORE_ID] = store_def
	ContentRegistry.register(StringName(STORE_ID), store_def, "store")
	ContentRegistry.register_entry(
		{
			"id": STORE_ID,
			"name": "Day Cycle Test Store",
			"scene_path": "",
			"backroom_capacity": 8,
			"base_foot_traffic": 1.0,
		},
		"store"
	)
	GameManager.data_loader = _data_loader


func _register_test_customer_profile() -> void:
	var profile: CustomerTypeDefinition = CustomerTypeDefinition.new()
	profile.id = "day_cycle_profile"
	profile.customer_name = "Day Cycle Buyer"
	profile.store_types = PackedStringArray([STORE_ID])
	profile.budget_range = [TEST_PRICE, TEST_PRICE * 3.0]
	profile.patience = 1.0
	profile.price_sensitivity = 0.1
	profile.condition_preference = "good"
	profile.browse_time_range = [5.0, 5.0]
	profile.purchase_probability_base = 1.0
	profile.impulse_buy_chance = 0.0
	_data_loader._customers[profile.id] = profile

	var vip_profile: CustomerTypeDefinition = CustomerTypeDefinition.new()
	vip_profile.id = "vip_customer"
	vip_profile.customer_name = "VIP Customer"
	vip_profile.store_types = PackedStringArray([STORE_ID])
	vip_profile.budget_range = [TEST_PRICE, TEST_PRICE * 4.0]
	vip_profile.patience = 1.0
	vip_profile.price_sensitivity = 0.1
	vip_profile.condition_preference = "good"
	vip_profile.browse_time_range = [5.0, 5.0]
	vip_profile.purchase_probability_base = 1.0
	vip_profile.impulse_buy_chance = 0.0
	_data_loader._customers[vip_profile.id] = vip_profile


func _prime_customer_pool() -> void:
	var pooled_customer: Customer = (
		_customer_system._customer_scene.instantiate() as Customer
	)
	_customer_system.add_child(pooled_customer)
	pooled_customer.visible = false
	pooled_customer.set_process(false)
	pooled_customer.set_physics_process(false)
	_customer_system._customer_pool.append(pooled_customer)


func _unregister_test_store() -> void:
	if not ContentRegistry.exists(STORE_ID):
		return
	var key: StringName = StringName(STORE_ID)
	ContentRegistry._entries.erase(key)
	ContentRegistry._types.erase(key)
	ContentRegistry._display_names.erase(key)
	ContentRegistry._scene_map.erase(key)
	ContentRegistry._resources.erase(key)
	for alias_key: StringName in ContentRegistry._aliases.keys():
		if ContentRegistry._aliases[alias_key] == key:
			ContentRegistry._aliases.erase(alias_key)
