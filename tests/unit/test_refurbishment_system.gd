## Unit tests for RefurbishmentSystem queue, cost, condition, and signals.
extends GutTest


var _refurb: RefurbishmentSystem
var _inventory: InventorySystem
var _economy: EconomySystem


func _make_definition(
	base_price: float, store_type: String = "retro_games"
) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = "test_retro_item"
	def.item_name = "Test Retro Item"
	def.store_type = store_type
	def.base_price = base_price
	return def


func _make_item(
	def: ItemDefinition,
	cond: String = "poor",
	location: String = "backroom"
) -> ItemInstance:
	var item: ItemInstance = ItemInstance.create_from_definition(def, cond)
	item.current_location = location
	return item


func _register_item(item: ItemInstance) -> void:
	_inventory._items[item.instance_id] = item


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(1000.0)
	_refurb = RefurbishmentSystem.new()
	add_child_autofree(_refurb)
	_refurb.initialize(_inventory, _economy)


func after_each() -> void:
	if EventBus.day_started.is_connected(_refurb._on_day_started):
		EventBus.day_started.disconnect(_refurb._on_day_started)


func test_enqueue_item_adds_to_queue() -> void:
	var def: ItemDefinition = _make_definition(20.0)
	var item: ItemInstance = _make_item(def, "poor")
	_register_item(item)

	var result: bool = _refurb.start_refurbishment(item.instance_id)

	assert_true(result, "start_refurbishment should return true")
	assert_eq(
		_refurb.get_active_count(), 1,
		"Queue should contain 1 item after enqueue"
	)
	var queue: Array[Dictionary] = _refurb.get_queue()
	assert_eq(
		queue[0]["instance_id"], item.instance_id,
		"Queued entry should reference the correct instance_id"
	)


func test_process_refurbishment_upgrades_condition() -> void:
	var def: ItemDefinition = _make_definition(10.0)
	var item: ItemInstance = _make_item(def, "fair")
	item.tested = true
	item.test_result = "tested_not_working"
	_register_item(item)

	_refurb.start_refurbishment(item.instance_id)
	assert_eq(
		_refurb.get_active_count(), 1,
		"Item should be in queue before processing"
	)

	EventBus.day_started.emit(1)

	assert_eq(
		item.condition, "good",
		"Condition should advance from 'fair' to 'good'"
	)
	assert_eq(
		_refurb.get_active_count(), 0,
		"Queue should be empty after processing completes"
	)


func test_refurbishment_deducts_cost() -> void:
	var def: ItemDefinition = _make_definition(10.0)
	var item: ItemInstance = _make_item(def, "poor")
	_register_item(item)

	var cash_before: float = _economy.get_cash()
	var expected_cost: float = _refurb.get_parts_cost(item)

	_refurb.start_refurbishment(item.instance_id)

	assert_almost_eq(
		_economy.get_cash(),
		cash_before - expected_cost,
		0.01,
		"Cash should decrease by parts cost"
	)


func test_already_mint_item_rejected() -> void:
	var def: ItemDefinition = _make_definition(20.0)
	var item: ItemInstance = _make_item(def, "mint")
	_register_item(item)

	var result: bool = _refurb.start_refurbishment(item.instance_id)

	assert_false(
		result,
		"start_refurbishment should return false for mint item"
	)
	assert_eq(
		_refurb.get_active_count(), 0,
		"Queue should remain empty after rejecting mint item"
	)


func test_refurbishment_completed_signal() -> void:
	var def: ItemDefinition = _make_definition(10.0)
	var item: ItemInstance = _make_item(def, "poor")
	_register_item(item)

	_refurb.start_refurbishment(item.instance_id)

	var completed_ids: Array[String] = []
	var completed_conditions: Array[String] = []
	var capture: Callable = func(
		id: String, _success: bool, new_cond: String
	) -> void:
		completed_ids.append(id)
		completed_conditions.append(new_cond)
	EventBus.refurbishment_completed.connect(capture)

	EventBus.day_started.emit(1)

	EventBus.refurbishment_completed.disconnect(capture)

	assert_eq(
		completed_ids.size(), 1,
		"refurbishment_completed should fire once"
	)
	assert_eq(
		completed_ids[0], item.instance_id,
		"Signal should carry the correct instance_id"
	)
	assert_eq(
		completed_conditions[0], "fair",
		"Signal should carry the upgraded condition 'fair'"
	)


func test_refurb_sets_item_unavailable() -> void:
	var def: ItemDefinition = _make_definition(20.0)
	var item: ItemInstance = _make_item(def, "poor")
	_register_item(item)

	_refurb.start_refurbishment(item.instance_id)

	assert_eq(
		item.current_location, "refurbishing",
		"Item location should be 'refurbishing' (refurb_in_progress) after initiation"
	)
	var in_backroom: Array = [false]
	for bi: ItemInstance in _inventory.get_backroom_items():
		if bi.instance_id == item.instance_id:
			in_backroom[0] = true
			break
	assert_false(in_backroom[0], "Item should not appear in backroom after refurb initiated")
	var on_shelf: Array = [false]
	for si: ItemInstance in _inventory.get_shelf_items():
		if si.instance_id == item.instance_id:
			on_shelf[0] = true
			break
	assert_false(on_shelf[0], "Item should not appear on shelves after refurb initiated")


func test_refurb_queue_capacity_enforced() -> void:
	var def: ItemDefinition = _make_definition(10.0)
	for _i: int in range(_refurb._active_max_queue_size):
		var item: ItemInstance = _make_item(def, "poor")
		_register_item(item)
		_refurb.start_refurbishment(item.instance_id)
	assert_eq(
		_refurb.get_active_count(), _refurb._active_max_queue_size,
		"Queue should be at max capacity"
	)

	var overflow: ItemInstance = _make_item(def, "poor")
	_register_item(overflow)
	var result: bool = _refurb.start_refurbishment(overflow.instance_id)

	assert_false(result, "start_refurbishment should return false when queue is full")
	assert_eq(
		_refurb.get_active_count(), _refurb._active_max_queue_size,
		"Queue size should remain unchanged after rejected enqueue"
	)


func test_refurb_completes_on_correct_day() -> void:
	# base_price >= DURATION_PRICE_THRESHOLD forces get_duration() to return MAX_DURATION (2)
	var def: ItemDefinition = _make_definition(40.0)
	var item: ItemInstance = _make_item(def, "fair")
	item.tested = true
	item.test_result = "tested_not_working"
	_register_item(item)

	var duration: int = _refurb.get_duration(item)
	_refurb.start_refurbishment(item.instance_id)

	for d: int in range(duration - 1):
		EventBus.day_started.emit(d + 2)
		assert_eq(
			_refurb.get_active_count(), 1,
			"Item should still be in queue on intermediate day %d" % (d + 2)
		)

	EventBus.day_started.emit(duration + 1)
	assert_eq(
		_refurb.get_active_count(), 0,
		"Item should exit queue exactly after refurb_duration_days"
	)
	assert_eq(item.condition, "good", "Condition should advance from 'fair' to 'good'")


func test_refurb_triggers_market_value_recalculation() -> void:
	var market: MarketValueSystem = MarketValueSystem.new()
	add_child_autofree(market)

	var def: ItemDefinition = _make_definition(20.0)
	var item: ItemInstance = _make_item(def, "poor")
	_register_item(item)

	var value_before: float = market.calculate_item_value(item)
	_refurb.start_refurbishment(item.instance_id)
	EventBus.day_started.emit(1)
	var value_after: float = market.calculate_item_value(item)

	assert_true(
		value_after > value_before,
		"Market value should increase after condition improves through refurbishment"
	)


func test_refurb_state_persists_in_save() -> void:
	# base_price >= DURATION_PRICE_THRESHOLD ensures days_remaining starts at 2
	var def: ItemDefinition = _make_definition(40.0)
	var item: ItemInstance = _make_item(def, "fair")
	item.tested = true
	item.test_result = "tested_not_working"
	_register_item(item)

	_refurb.start_refurbishment(item.instance_id)
	var days_at_start: int = _refurb.get_queue()[0]["days_remaining"]

	var save_data: Dictionary = _refurb.get_save_data()
	var fresh_refurb: RefurbishmentSystem = RefurbishmentSystem.new()
	add_child_autofree(fresh_refurb)
	fresh_refurb.load_save_data(save_data)

	assert_eq(
		fresh_refurb.get_active_count(), 1,
		"Loaded system should have 1 item in refurb queue"
	)
	var loaded_queue: Array[Dictionary] = fresh_refurb.get_queue()
	assert_eq(
		loaded_queue[0]["instance_id"], item.instance_id,
		"Loaded entry should reference the correct instance_id"
	)
	assert_eq(
		loaded_queue[0]["days_remaining"], days_at_start,
		"days_remaining should be preserved across save/load (refurb_in_progress state)"
	)
	assert_true(
		loaded_queue[0]["days_remaining"] > 0,
		"days_remaining > 0 confirms item is still in refurb_in_progress after load"
	)


func test_save_load_preserves_queue() -> void:
	var def: ItemDefinition = _make_definition(20.0)
	var item_a: ItemInstance = _make_item(def, "poor")
	var item_b: ItemInstance = _make_item(def, "poor")
	_register_item(item_a)
	_register_item(item_b)

	_refurb.start_refurbishment(item_a.instance_id)
	_refurb.start_refurbishment(item_b.instance_id)
	assert_eq(
		_refurb.get_active_count(), 2,
		"Queue should have 2 items before save"
	)

	var save_data: Dictionary = _refurb.get_save_data()

	var fresh_refurb: RefurbishmentSystem = RefurbishmentSystem.new()
	add_child_autofree(fresh_refurb)
	fresh_refurb.load_save_data(save_data)

	assert_eq(
		fresh_refurb.get_active_count(), 2,
		"Queue should have 2 items after load"
	)
	var original_queue: Array[Dictionary] = _refurb.get_queue()
	var loaded_queue: Array[Dictionary] = fresh_refurb.get_queue()
	assert_eq(
		loaded_queue[0]["instance_id"],
		original_queue[0]["instance_id"],
		"First queue entry instance_id should match after round-trip"
	)
	assert_eq(
		loaded_queue[1]["instance_id"],
		original_queue[1]["instance_id"],
		"Second queue entry instance_id should match after round-trip"
	)
	assert_eq(
		loaded_queue[0]["days_remaining"],
		original_queue[0]["days_remaining"],
		"First entry days_remaining should match after round-trip"
	)
