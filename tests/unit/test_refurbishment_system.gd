## Unit tests for RefurbishmentSystem queueing, costs, upgrades, signals, and save data.
extends GutTest


class _EconomySpy extends EconomySystem:
	var deducted_amounts: Array[float] = []
	var deducted_reasons: Array[String] = []

	func deduct_cash(amount: float, reason: String) -> bool:
		deducted_amounts.append(amount)
		deducted_reasons.append(reason)
		return super.deduct_cash(amount, reason)


var _refurb: RefurbishmentSystem
var _inventory: InventorySystem
var _economy: _EconomySpy


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_economy = _EconomySpy.new()
	add_child_autofree(_economy)
	_economy.initialize(1000.0)

	_refurb = RefurbishmentSystem.new()
	add_child_autofree(_refurb)
	_refurb.initialize(_inventory, _economy)


func after_each() -> void:
	if _refurb and EventBus.day_started.is_connected(_refurb._on_day_started):
		EventBus.day_started.disconnect(_refurb._on_day_started)


func _make_definition(base_price: float = 20.0) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = "test_retro_item"
	def.item_name = "Test Retro Item"
	def.store_type = "retro_games"
	def.base_price = base_price
	return def


func _make_item(condition: String, base_price: float = 20.0) -> ItemInstance:
	var item := ItemInstance.create_from_definition(
		_make_definition(base_price), condition
	)
	item.current_location = "backroom"
	_inventory._items[String(item.instance_id)] = item
	_inventory._item_store_ids[item.instance_id] = "retro_games"
	return item


func test_enqueue_item_adds_to_queue() -> void:
	var item: ItemInstance = _make_item("poor")

	var result: bool = _refurb.start_refurbishment(String(item.instance_id))

	assert_true(result, "Eligible item should enqueue successfully")
	assert_eq(_refurb.get_active_count(), 1, "Queue should contain one item")
	var queue: Array[Dictionary] = _refurb.get_queue()
	assert_eq(
		queue[0].get("instance_id", ""),
		String(item.instance_id),
		"Queued entry should store the item instance id"
	)


func test_process_refurbishment_upgrades_condition() -> void:
	var item: ItemInstance = _make_item("fair", 10.0)
	item.tested = true
	item.test_result = "tested_not_working"
	_refurb.start_refurbishment(String(item.instance_id))

	EventBus.day_started.emit(1)

	assert_eq(item.condition, "good", "Fair condition should advance to good")
	assert_eq(_refurb.get_active_count(), 0, "Completed item should leave queue")


func test_refurbishment_deducts_cost() -> void:
	var item: ItemInstance = _make_item("poor")
	var expected_cost: float = _refurb.get_parts_cost(item)

	var result: bool = _refurb.start_refurbishment(String(item.instance_id))

	assert_true(result, "Refurbishment should start with sufficient cash")
	assert_eq(
		_economy.deducted_amounts.size(),
		1,
		"Refurbishment should request one cash deduction"
	)
	assert_almost_eq(
		_economy.deducted_amounts[0],
		expected_cost,
		0.01,
		"Deduction amount should match configured parts cost"
	)


func test_already_mint_item_rejected() -> void:
	var item: ItemInstance = _make_item("mint")

	var result: bool = _refurb.start_refurbishment(String(item.instance_id))

	assert_false(result, "Mint items should be rejected")
	assert_eq(_refurb.get_active_count(), 0, "Rejected item should not enqueue")
	assert_eq(
		_economy.deducted_amounts.size(),
		0,
		"Rejected item should not deduct refurbishment cost"
	)


func test_refurbishment_completed_signal() -> void:
	var item: ItemInstance = _make_item("poor")
	var completed_ids: Array[String] = []
	var completed_conditions: Array[String] = []
	var capture: Callable = func(
		instance_id: String, success: bool, new_condition: String
	) -> void:
		if success:
			completed_ids.append(instance_id)
			completed_conditions.append(new_condition)
	EventBus.refurbishment_completed.connect(capture)

	_refurb.start_refurbishment(String(item.instance_id))
	EventBus.day_started.emit(1)

	EventBus.refurbishment_completed.disconnect(capture)
	assert_eq(completed_ids.size(), 1, "Completion signal should fire once")
	assert_eq(
		completed_ids[0],
		String(item.instance_id),
		"Completion signal should carry the instance id"
	)
	assert_eq(
		completed_conditions[0],
		"fair",
		"Completion signal should carry the upgraded condition"
	)


func test_save_load_preserves_queue() -> void:
	var item_a: ItemInstance = _make_item("poor")
	var item_b: ItemInstance = _make_item("poor")
	_refurb.start_refurbishment(String(item_a.instance_id))
	_refurb.start_refurbishment(String(item_b.instance_id))
	var original_queue: Array[Dictionary] = _refurb.get_queue()

	var fresh_refurb := RefurbishmentSystem.new()
	add_child_autofree(fresh_refurb)
	fresh_refurb.load_save_data(_refurb.get_save_data())

	var loaded_queue: Array[Dictionary] = fresh_refurb.get_queue()
	assert_eq(loaded_queue.size(), 2, "Loaded queue should contain both items")
	assert_eq(
		loaded_queue[0],
		original_queue[0],
		"First queue entry should round-trip intact"
	)
	assert_eq(
		loaded_queue[1],
		original_queue[1],
		"Second queue entry should round-trip intact"
	)
