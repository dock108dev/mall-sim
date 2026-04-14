## Unit tests for StockerBehavior auto-restock timer logic.
extends GutTest


var _staff: StaffSystem
var _inventory: InventorySystem
var _economy: EconomySystem
var _reputation: ReputationSystem
var _data_loader: DataLoader
var _stocker_behavior: StockerBehavior


func before_each() -> void:
	ContentRegistry.clear_for_testing()
	ContentRegistry.register_entry(
		{"id": "test_store", "name": "Test Store", "store_type": "test_store"},
		"store"
	)

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(5000.0)

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)
	_reputation.initialize_store("test_store")
	_reputation.add_reputation("test_store", 50.0)

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_register_test_data()

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)

	_staff = StaffSystem.new()
	add_child_autofree(_staff)
	_staff.initialize(
		_economy, _reputation, _inventory, _data_loader
	)

	_stocker_behavior = _staff._stocker_behavior

	GameManager.current_store_id = &"test_store"


func after_each() -> void:
	GameManager.current_store_id = &""
	ContentRegistry.clear_for_testing()
	DataLoaderSingleton.load_all_content()


func test_timer_starts_on_stocker_hire() -> void:
	_staff.hire_staff("test_stocker", "test_store")
	assert_true(
		_stocker_behavior._timers.has("test_store"),
		"Timer should exist after hiring a stocker"
	)
	assert_true(
		_stocker_behavior._active_stockers.has("test_store"),
		"Active stocker should be tracked"
	)


func test_no_timer_for_non_stocker() -> void:
	_staff.hire_staff("test_cashier", "test_store")
	assert_false(
		_stocker_behavior._timers.has("test_store"),
		"Timer should not exist for non-stocker staff"
	)


func test_timer_stops_on_stocker_fire() -> void:
	var hired: Dictionary = _staff.hire_staff(
		"test_stocker", "test_store"
	)
	var instance_id: String = hired["instance_id"]
	assert_true(
		_stocker_behavior._timers.has("test_store"),
		"Timer should exist after hire"
	)
	_staff.fire_staff(instance_id, "test_store")
	assert_false(
		_stocker_behavior._timers.has("test_store"),
		"Timer should be removed after firing stocker"
	)
	assert_false(
		_stocker_behavior._active_stockers.has("test_store"),
		"Active stocker tracking should be cleared"
	)


func test_interval_uses_skill_base_divided_by_performance() -> void:
	_staff.hire_staff("test_stocker", "test_store")
	var timer: Timer = _stocker_behavior._timers.get(
		"test_store"
	) as Timer
	assert_not_null(timer, "Timer should exist")
	var def: StaffDefinition = _data_loader.get_staff_definition(
		"test_stocker"
	)
	var expected: float = 60.0 / def.performance_multiplier()
	assert_almost_eq(
		timer.wait_time, expected, 0.01,
		"Timer interval should be base/performance_multiplier"
	)


func test_skill_1_base_interval() -> void:
	_staff.hire_staff("test_stocker_s1", "test_store")
	var timer: Timer = _stocker_behavior._timers.get(
		"test_store"
	) as Timer
	assert_not_null(timer, "Timer should exist for skill-1 stocker")
	var def: StaffDefinition = _data_loader.get_staff_definition(
		"test_stocker_s1"
	)
	var expected: float = 90.0 / def.performance_multiplier()
	assert_almost_eq(
		timer.wait_time, expected, 0.01,
		"Skill 1 should use 90s base interval"
	)


func test_skill_3_base_interval() -> void:
	_staff.hire_staff("test_stocker_s3", "test_store")
	var timer: Timer = _stocker_behavior._timers.get(
		"test_store"
	) as Timer
	assert_not_null(timer, "Timer should exist for skill-3 stocker")
	var def: StaffDefinition = _data_loader.get_staff_definition(
		"test_stocker_s3"
	)
	var expected: float = 45.0 / def.performance_multiplier()
	assert_almost_eq(
		timer.wait_time, expected, 0.01,
		"Skill 3 should use 45s base interval"
	)


func test_restock_moves_one_backroom_item_to_shelf() -> void:
	watch_signals(EventBus)
	_staff.hire_staff("test_stocker", "test_store")
	_add_backroom_item("test_store", "test_item")
	var backroom_before: int = (
		_inventory.get_backroom_items_for_store("test_store").size()
	)
	assert_eq(backroom_before, 1, "Should have 1 backroom item")
	_stocker_behavior._restock_one_item(
		"test_store",
		_stocker_behavior._active_stockers["test_store"]
			.get("instance_id", "")
	)
	var backroom_after: int = (
		_inventory.get_backroom_items_for_store("test_store").size()
	)
	var shelf_after: int = (
		_inventory.get_shelf_items_for_store("test_store").size()
	)
	assert_eq(
		backroom_after, 0,
		"Backroom should have 0 items after restock"
	)
	assert_eq(
		shelf_after, 1,
		"Shelf should have 1 item after restock"
	)
	assert_signal_emitted(
		EventBus, "staff_restocked_shelf",
		"staff_restocked_shelf should emit on restock"
	)


func test_restock_emits_correct_signal_params() -> void:
	watch_signals(EventBus)
	var hired: Dictionary = _staff.hire_staff(
		"test_stocker", "test_store"
	)
	_add_backroom_item("test_store", "test_item")
	_stocker_behavior._restock_one_item(
		"test_store", hired["instance_id"]
	)
	var params: Array = get_signal_parameters(
		EventBus, "staff_restocked_shelf"
	)
	assert_eq(
		params[0], hired["instance_id"],
		"Signal staff_id should match stocker instance_id"
	)
	assert_eq(
		params[1], "test_item",
		"Signal item_id should match restocked item definition id"
	)


func test_no_restock_when_backroom_empty() -> void:
	watch_signals(EventBus)
	_staff.hire_staff("test_stocker", "test_store")
	_stocker_behavior._restock_one_item(
		"test_store",
		_stocker_behavior._active_stockers["test_store"]
			.get("instance_id", "")
	)
	assert_signal_not_emitted(
		EventBus, "staff_restocked_shelf",
		"No restock signal when backroom is empty"
	)


func test_no_restock_when_shelf_at_capacity() -> void:
	watch_signals(EventBus)
	_staff.hire_staff("test_stocker", "test_store")
	var store_def: StoreDefinition = _data_loader.get_store(
		"test_store"
	)
	for i: int in range(store_def.shelf_capacity):
		_add_shelf_item("test_store", "test_item", "slot_%d" % i)
	_add_backroom_item("test_store", "test_item")
	_stocker_behavior._restock_one_item(
		"test_store",
		_stocker_behavior._active_stockers["test_store"]
			.get("instance_id", "")
	)
	assert_signal_not_emitted(
		EventBus, "staff_restocked_shelf",
		"No restock signal when shelf is full"
	)


func test_restock_only_one_item_per_fire() -> void:
	watch_signals(EventBus)
	_staff.hire_staff("test_stocker", "test_store")
	_add_backroom_item("test_store", "test_item")
	_add_backroom_item("test_store", "test_item")
	_stocker_behavior._restock_one_item(
		"test_store",
		_stocker_behavior._active_stockers["test_store"]
			.get("instance_id", "")
	)
	var backroom_after: int = (
		_inventory.get_backroom_items_for_store("test_store").size()
	)
	assert_eq(
		backroom_after, 1,
		"Only one item should be restocked per timer fire"
	)


func test_refresh_after_load_rebuilds_timers() -> void:
	_staff.hire_staff("test_stocker", "test_store")
	assert_true(
		_stocker_behavior._timers.has("test_store"),
		"Timer should exist before save"
	)
	var save_data: Dictionary = _staff.get_save_data()
	var fresh_staff: StaffSystem = StaffSystem.new()
	add_child_autofree(fresh_staff)
	fresh_staff.initialize(
		_economy, _reputation, _inventory, _data_loader
	)
	fresh_staff.load_save_data(save_data)
	var fresh_behavior: StockerBehavior = fresh_staff._stocker_behavior
	assert_true(
		fresh_behavior._timers.has("test_store"),
		"Timer should be rebuilt after load"
	)
	assert_true(
		fresh_behavior._active_stockers.has("test_store"),
		"Active stocker should be tracked after load"
	)


func _register_test_data() -> void:
	var cashier := StaffDefinition.new()
	cashier.staff_id = "test_cashier"
	cashier.display_name = "Test Cashier"
	cashier.role = StaffDefinition.StaffRole.CASHIER
	cashier.skill_level = 1
	cashier.daily_wage = 30.0
	_data_loader._staff_definitions["test_cashier"] = cashier

	var stocker := StaffDefinition.new()
	stocker.staff_id = "test_stocker"
	stocker.display_name = "Test Stocker"
	stocker.role = StaffDefinition.StaffRole.STOCKER
	stocker.skill_level = 2
	stocker.daily_wage = 60.0
	_data_loader._staff_definitions["test_stocker"] = stocker

	var stocker_s1 := StaffDefinition.new()
	stocker_s1.staff_id = "test_stocker_s1"
	stocker_s1.display_name = "Test Stocker S1"
	stocker_s1.role = StaffDefinition.StaffRole.STOCKER
	stocker_s1.skill_level = 1
	stocker_s1.daily_wage = 30.0
	_data_loader._staff_definitions["test_stocker_s1"] = stocker_s1

	var stocker_s3 := StaffDefinition.new()
	stocker_s3.staff_id = "test_stocker_s3"
	stocker_s3.display_name = "Test Stocker S3"
	stocker_s3.role = StaffDefinition.StaffRole.STOCKER
	stocker_s3.skill_level = 3
	stocker_s3.daily_wage = 110.0
	_data_loader._staff_definitions["test_stocker_s3"] = stocker_s3

	var store := StoreDefinition.new()
	store.id = "test_store"
	store.store_name = "Test Store"
	store.store_type = "test_store"
	store.shelf_capacity = 10
	store.backroom_capacity = 20
	_data_loader._stores["test_store"] = store

	var item := ItemDefinition.new()
	item.id = "test_item"
	item.item_name = "Test Item"
	item.store_type = "test_store"
	item.base_price = 10.0
	_data_loader._items["test_item"] = item


func _add_backroom_item(
	store_id: String, definition_id: String
) -> ItemInstance:
	var def: ItemDefinition = _data_loader.get_item(definition_id)
	var item: ItemInstance = ItemInstance.create(
		def, "good", 0, def.base_price
	)
	item.current_location = "backroom"
	_inventory.add_item(StringName(store_id), item)
	return item


func _add_shelf_item(
	store_id: String, definition_id: String, slot_id: String
) -> ItemInstance:
	var def: ItemDefinition = _data_loader.get_item(definition_id)
	var item: ItemInstance = ItemInstance.create(
		def, "good", 0, def.base_price
	)
	item.current_location = "shelf:%s" % slot_id
	_inventory.add_item(StringName(store_id), item)
	return item
