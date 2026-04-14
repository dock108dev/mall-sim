## Tests RefurbishmentSystem eligibility, queue processing, and save/load.
extends GutTest


var _refurb: RefurbishmentSystem
var _inventory: InventorySystem
var _economy: EconomySystem
var _completed_ids: Array[String] = []
var _completed_conditions: Array[String] = []


func before_each() -> void:
	_inventory = InventorySystem.new()
	_economy = EconomySystem.new()
	add_child_autofree(_inventory)
	add_child_autofree(_economy)
	_economy.initialize(1000.0)
	_refurb = RefurbishmentSystem.new()
	add_child_autofree(_refurb)
	_refurb.initialize(_inventory, _economy)
	_completed_ids.clear()
	_completed_conditions.clear()
	EventBus.refurbishment_completed.connect(_on_completed)


func after_each() -> void:
	if EventBus.refurbishment_completed.is_connected(_on_completed):
		EventBus.refurbishment_completed.disconnect(_on_completed)


func _on_completed(
	item_id: String, _success: bool, new_condition: String
) -> void:
	_completed_ids.append(item_id)
	_completed_conditions.append(new_condition)


func _make_item(
	cond: String = "poor",
	tested: bool = false,
	test_result: String = "",
) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "retro_test_item"
	def.item_name = "Test Cart"
	def.store_type = "retro_games"
	def.base_price = 20.0
	def.category = "cartridges"
	def.subcategory = "loose"
	var item := ItemInstance.create_from_definition(def, cond)
	item.tested = tested
	item.test_result = test_result
	item.current_location = "backroom"
	_inventory.add_item(&"retro_games", item)
	return item


func test_can_refurbish_poor_condition() -> void:
	var item: ItemInstance = _make_item("poor")
	assert_true(
		_refurb.can_refurbish(item),
		"Poor condition items should be eligible"
	)


func test_can_refurbish_tested_not_working() -> void:
	var item: ItemInstance = _make_item(
		"good", true, "tested_not_working"
	)
	assert_true(
		_refurb.can_refurbish(item),
		"Tested not-working items should be eligible"
	)


func test_cannot_refurbish_good_condition_untested() -> void:
	var item: ItemInstance = _make_item("good")
	assert_false(
		_refurb.can_refurbish(item),
		"Good condition untested items should not be eligible"
	)


func test_cannot_refurbish_tested_working() -> void:
	var item: ItemInstance = _make_item(
		"good", true, "tested_working"
	)
	assert_false(
		_refurb.can_refurbish(item),
		"Working items should not be eligible"
	)


func test_cannot_refurbish_mint_condition() -> void:
	var item: ItemInstance = _make_item("mint")
	assert_false(
		_refurb.can_refurbish(item),
		"Mint condition items have no next tier"
	)


func test_cannot_refurbish_shelf_items() -> void:
	var item: ItemInstance = _make_item("poor")
	item.current_location = "shelf:0"
	assert_false(
		_refurb.can_refurbish(item),
		"Items on shelves should not be eligible"
	)


func test_start_refurbishment_deducts_cash() -> void:
	var item: ItemInstance = _make_item("poor")
	var before: float = _economy.get_cash()
	var cost: float = _refurb.get_parts_cost(item)
	var result: bool = _refurb.start_refurbishment(item.instance_id)
	assert_true(result, "Should succeed with sufficient funds")
	assert_almost_eq(
		_economy.get_cash(), before - cost, 0.01,
		"Cash should decrease by parts cost"
	)


func test_start_refurbishment_moves_to_refurbishing() -> void:
	var item: ItemInstance = _make_item("poor")
	_refurb.start_refurbishment(item.instance_id)
	assert_eq(
		item.current_location,
		RefurbishmentSystem.REFURBISHING_LOCATION,
		"Item should be at refurbishing location"
	)


func test_start_refurbishment_fails_insufficient_funds() -> void:
	_economy.initialize(0.0)
	var item: ItemInstance = _make_item("poor")
	var result: bool = _refurb.start_refurbishment(item.instance_id)
	assert_false(result, "Should fail with no cash")
	assert_eq(
		item.current_location, "backroom",
		"Item should stay in backroom"
	)


func test_queue_max_concurrent() -> void:
	for i: int in range(RefurbishmentSystem.MAX_CONCURRENT):
		var item: ItemInstance = _make_item("poor")
		_refurb.start_refurbishment(item.instance_id)
	var extra: ItemInstance = _make_item("poor")
	assert_false(
		_refurb.can_refurbish(extra),
		"Should not accept items beyond MAX_CONCURRENT"
	)


func test_condition_advances_one_tier_poor_to_fair() -> void:
	var item: ItemInstance = _make_item("poor")
	_refurb.start_refurbishment(item.instance_id)
	var duration: int = _refurb.get_duration(item)
	for d: int in range(duration):
		EventBus.day_started.emit(d + 1)
	assert_eq(
		item.condition, "fair",
		"Poor should advance to fair"
	)
	assert_eq(
		item.current_location, "backroom",
		"Item should return to backroom"
	)


func test_condition_advances_tested_not_working_resets() -> void:
	var item: ItemInstance = _make_item(
		"good", true, "tested_not_working"
	)
	_refurb.start_refurbishment(item.instance_id)
	var duration: int = _refurb.get_duration(item)
	for d: int in range(duration):
		EventBus.day_started.emit(d + 1)
	assert_eq(
		item.condition, "near_mint",
		"Good should advance to near_mint"
	)
	assert_eq(
		item.test_result, "tested_working",
		"Test result should reset to working"
	)


func test_completion_emits_signal() -> void:
	var item: ItemInstance = _make_item("poor")
	_refurb.start_refurbishment(item.instance_id)
	var duration: int = _refurb.get_duration(item)
	for d: int in range(duration):
		EventBus.day_started.emit(d + 1)
	assert_eq(
		_completed_ids.size(), 1,
		"Should emit refurbishment_completed once"
	)
	assert_eq(_completed_conditions[0], "fair")


func test_save_load_round_trip() -> void:
	var item: ItemInstance = _make_item("poor")
	_refurb.start_refurbishment(item.instance_id)
	var save_data: Dictionary = _refurb.get_save_data()
	assert_true(
		save_data.has("queue"),
		"Save data should include queue"
	)
	var queue: Array = save_data["queue"]
	assert_eq(queue.size(), 1, "Queue should have one entry")
	var entry: Dictionary = queue[0]
	assert_true(entry.has("instance_id"))
	assert_true(entry.has("parts_cost"))
	assert_true(entry.has("days_remaining"))
	assert_true(entry.has("start_day"))
	var new_refurb := RefurbishmentSystem.new()
	add_child_autofree(new_refurb)
	new_refurb.initialize(_inventory, _economy)
	new_refurb.load_save_data(save_data)
	var loaded_queue: Array[Dictionary] = new_refurb.get_queue()
	assert_eq(
		loaded_queue.size(), 1,
		"Loaded queue should have one entry"
	)
	assert_eq(
		loaded_queue[0]["instance_id"], item.instance_id,
		"Loaded entry should match saved instance_id"
	)


func test_get_queue_returns_copies() -> void:
	var item: ItemInstance = _make_item("poor")
	_refurb.start_refurbishment(item.instance_id)
	var queue: Array[Dictionary] = _refurb.get_queue()
	queue[0]["days_remaining"] = 999
	var actual: Array[Dictionary] = _refurb.get_queue()
	assert_ne(
		actual[0]["days_remaining"], 999,
		"get_queue should return copies, not references"
	)
