## Tests demo-unit value depreciation, retirement, and day-summary
## contribution tracking (ISSUE-017).
extends GutTest


var _controller: ElectronicsStoreController
var _inventory: InventorySystem


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_controller = ElectronicsStoreController.new()
	add_child_autofree(_controller)
	_controller.set_inventory_system(_inventory)


func _make_item(category: String = "portable_audio") -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "demo_test_%s" % category
	def.item_name = "Demo Test %s" % category
	def.category = category
	def.store_type = "electronics"
	def.base_price = 100.0
	def.can_be_demo_unit = true
	var item: ItemInstance = ItemInstance.create_from_definition(
		def, "good"
	)
	_inventory.register_item(item)
	return item


func _designate_demo(item: ItemInstance, placed_day: int = 1) -> void:
	item.is_demo = true
	item.demo_placed_day = placed_day
	item.demo_depreciation_factor = 1.0
	_controller._demo_item_ids.append(item.instance_id)


func test_depreciation_factor_decreases_each_day() -> void:
	var item: ItemInstance = _make_item()
	_designate_demo(item, 1)
	_controller._current_day = 3
	_controller._process_demo_degradation()
	var expected: float = 1.0 - ElectronicsStoreController.DEMO_DAILY_DEPRECIATION * 2.0
	assert_almost_eq(
		item.demo_depreciation_factor, expected, 0.0001,
		"Depreciation factor should reflect 2 days on demo"
	)


func test_depreciation_factor_floors() -> void:
	var item: ItemInstance = _make_item()
	_designate_demo(item, 1)
	_controller._current_day = 1000
	_controller._process_demo_degradation()
	assert_eq(
		item.demo_depreciation_factor,
		ElectronicsStoreController.DEMO_DEPRECIATION_FLOOR,
		"Factor should not drop below the configured floor"
	)


func test_get_demo_remaining_value_reflects_depreciation() -> void:
	var item: ItemInstance = _make_item()
	_designate_demo(item, 1)
	_controller._current_day = 5
	_controller._process_demo_degradation()
	var base_value: float = item.get_current_value()
	var expected_factor: float = 1.0 - ElectronicsStoreController.DEMO_DAILY_DEPRECIATION * 4.0
	var remaining: float = _controller.get_demo_remaining_value(item.instance_id)
	assert_almost_eq(
		remaining, base_value * expected_factor, 0.01,
		"Remaining value should equal base_value * factor"
	)


func test_retire_demo_sets_player_price_to_depreciated_value() -> void:
	var item: ItemInstance = _make_item()
	_designate_demo(item, 1)
	_controller._current_day = 5
	_controller._process_demo_degradation()
	var expected: float = _controller.get_demo_remaining_value(item.instance_id)
	_controller.remove_demo_item(item.instance_id)
	assert_almost_eq(
		item.player_price, expected, 0.01,
		"Retired demo unit player_price should equal depreciated value"
	)


func test_retire_emits_demo_item_retired_signal() -> void:
	var item: ItemInstance = _make_item()
	_designate_demo(item, 1)
	_controller._current_day = 3
	_controller._process_demo_degradation()
	var captured: Array = []
	var capture: Callable = func(item_id: String, value: float) -> void:
		captured.append({"id": item_id, "value": value})
	EventBus.demo_item_retired.connect(capture)
	_controller.remove_demo_item(item.instance_id)
	EventBus.demo_item_retired.disconnect(capture)
	assert_eq(captured.size(), 1, "demo_item_retired should emit once")
	assert_eq(
		String(captured[0]["id"]), String(item.instance_id),
		"Signal should carry the retired item id"
	)


func test_daily_contribution_accumulates_on_same_category_sale() -> void:
	var item: ItemInstance = _make_item("portable_audio")
	_designate_demo(item, 1)
	_controller._current_day = 1
	var price: float = 120.0
	EventBus.item_sold.emit("some_other_item", price, "portable_audio")
	var bonus: float = _controller.get_demo_interest_bonus()
	var expected: float = price * bonus / (1.0 + bonus)
	assert_almost_eq(
		_controller.get_daily_demo_contribution(), expected, 0.01,
		"Contribution should be proportional to the demo buff"
	)


func test_daily_contribution_ignores_other_category_sale() -> void:
	var item: ItemInstance = _make_item("portable_audio")
	_designate_demo(item, 1)
	EventBus.item_sold.emit("other", 120.0, "audio")
	assert_eq(
		_controller.get_daily_demo_contribution(), 0.0,
		"Sales in a different category should not contribute"
	)


func test_daily_contribution_resets_on_day_started() -> void:
	var item: ItemInstance = _make_item("portable_audio")
	_designate_demo(item, 1)
	EventBus.item_sold.emit("other", 120.0, "portable_audio")
	assert_gt(
		_controller.get_daily_demo_contribution(), 0.0,
		"Contribution should be non-zero before day rollover"
	)
	_controller._on_day_started(2)
	assert_eq(
		_controller.get_daily_demo_contribution(), 0.0,
		"Contribution should reset at day start"
	)


func test_designate_initializes_depreciation_factor() -> void:
	var item: ItemInstance = _make_item()
	item.demo_depreciation_factor = 0.3
	_controller._current_day = 1
	_controller._demo_station_slots = [_fake_slot("slot_a")]
	var ok: bool = _controller.place_demo_item(item.instance_id)
	assert_true(ok, "place_demo_item should succeed")
	assert_eq(
		item.demo_depreciation_factor, 1.0,
		"Factor should reset to 1.0 on fresh designation"
	)


func _fake_slot(slot_id: String) -> Node:
	var n := Node.new()
	n.set("slot_id", slot_id)
	add_child_autofree(n)
	return n
