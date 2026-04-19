## Tests ElectronicsStoreController demo unit designation and browse influence.
extends GutTest


var _controller: ElectronicsStoreController
var _inventory: InventorySystem


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_controller = ElectronicsStoreController.new()
	add_child_autofree(_controller)
	_controller.set_inventory_system(_inventory)


func _make_item(
	category: String,
	condition: String = "good",
	can_be_demo: bool = true
) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "test_%s" % category
	def.item_name = "Test %s" % category
	def.category = category
	def.store_type = "electronics"
	def.base_price = 50.0
	def.can_be_demo_unit = can_be_demo
	var item: ItemInstance = ItemInstance.create_from_definition(
		def, condition
	)
	_inventory.register_item(item)
	return item


func test_has_demo_slots_available_initially() -> void:
	assert_true(
		_controller.has_demo_slots_available(),
		"Should have demo slots available initially"
	)


func test_get_active_demo_count_starts_at_zero() -> void:
	assert_eq(
		_controller.get_active_demo_count(), 0,
		"Active demo count should start at 0"
	)


func test_can_demo_item_rejects_poor_condition() -> void:
	var item: ItemInstance = _make_item("portable_audio", "poor")
	assert_false(
		_controller.can_demo_item(item),
		"Should reject poor condition items for demo"
	)


func test_can_demo_item_rejects_already_demo() -> void:
	var item: ItemInstance = _make_item("portable_audio")
	item.is_demo = true
	assert_false(
		_controller.can_demo_item(item),
		"Should reject items already set as demo"
	)


func test_can_demo_item_rejects_wrong_store_type() -> void:
	var def := ItemDefinition.new()
	def.id = "retro_item"
	def.category = "cartridges"
	def.store_type = "retro_games"
	def.base_price = 10.0
	var item: ItemInstance = ItemInstance.create_from_definition(def)
	_inventory.register_item(item)
	assert_false(
		_controller.can_demo_item(item),
		"Should reject items from other store types"
	)


func test_has_active_demo_for_category_false_when_empty() -> void:
	assert_false(
		_controller.has_active_demo_for_category("portable_audio"),
		"Should return false when no demo items exist"
	)


func test_is_demo_unit_returns_false_for_non_demo() -> void:
	assert_false(
		_controller.is_demo_unit("nonexistent"),
		"Should return false for non-demo items"
	)


func test_get_demo_item_ids_returns_empty_initially() -> void:
	var ids: Array[String] = _controller.get_demo_item_ids()
	assert_eq(
		ids.size(), 0,
		"Should return empty array initially"
	)


func test_get_demo_interest_bonus_returns_default() -> void:
	var bonus: float = _controller.get_demo_interest_bonus()
	assert_eq(
		bonus, 0.20,
		"Should return default demo interest bonus"
	)


func test_get_max_demo_units_returns_default() -> void:
	var max_units: int = _controller.get_max_demo_units()
	assert_eq(
		max_units, 2,
		"Should return default max demo units"
	)


func test_save_load_demo_item_ids() -> void:
	_controller._demo_item_ids = ["item_a", "item_b"]
	var data: Dictionary = _controller.get_save_data()
	assert_true(
		data.has("demo_item_ids"),
		"Save data should include demo_item_ids"
	)
	_controller._demo_item_ids.clear()
	_controller.load_save_data(data)
	assert_eq(
		_controller._demo_item_ids.size(), 2,
		"Should restore 2 demo item ids after load"
	)
	assert_true(
		_controller.is_demo_unit("item_a"),
		"item_a should be restored as demo unit"
	)
	assert_true(
		_controller.is_demo_unit("item_b"),
		"item_b should be restored as demo unit"
	)


func test_save_load_empty_state() -> void:
	var data: Dictionary = _controller.get_save_data()
	_controller.load_save_data(data)
	assert_eq(
		_controller._demo_item_ids.size(), 0,
		"Should handle empty demo_item_ids on load"
	)


func test_remove_demo_item_clears_demo_state() -> void:
	var item: ItemInstance = _make_item("portable_audio")
	item.is_demo = true
	item.demo_placed_day = 1
	_controller._demo_item_ids.append(item.instance_id)
	var result: bool = _controller.remove_demo_item(item.instance_id)
	assert_true(result, "remove_demo_item should succeed")
	assert_false(
		item.is_demo,
		"Item should no longer be marked as demo"
	)
	assert_eq(
		item.demo_placed_day, 0,
		"demo_placed_day should be reset"
	)
	assert_eq(
		item.current_location, "backroom",
		"Item should be moved to backroom"
	)


func test_remove_demo_emits_signal() -> void:
	var item: ItemInstance = _make_item("portable_audio")
	item.is_demo = true
	_controller._demo_item_ids.append(item.instance_id)
	var removed_ids: Array[String] = []
	var capture: Callable = func(
		item_id: String, _days: int
	) -> void:
		removed_ids.append(item_id)
	EventBus.demo_item_removed.connect(capture)
	_controller.remove_demo_item(item.instance_id)
	EventBus.demo_item_removed.disconnect(capture)
	assert_eq(
		removed_ids.size(), 1,
		"demo_item_removed should be emitted"
	)


func test_remove_demo_nonexistent_returns_false() -> void:
	assert_false(
		_controller.remove_demo_item("nonexistent"),
		"Should return false for non-demo item"
	)


func test_can_demo_item_rejects_non_demoable_content() -> void:
	var item: ItemInstance = _make_item("portable_audio", "good", false)
	assert_false(
		_controller.can_demo_item(item),
		"Should reject items with can_be_demo_unit = false"
	)


func test_try_demo_interaction_returns_false_for_non_demo() -> void:
	assert_false(
		_controller.try_demo_interaction("nonexistent"),
		"Should return false when item is not a demo unit"
	)


func test_try_demo_interaction_emits_signal() -> void:
	var triggered_ids: Array[String] = []
	var capture: Callable = func(item_id: String) -> void:
		triggered_ids.append(item_id)
	EventBus.demo_interaction_triggered.connect(capture)
	_controller._demo_item_ids.append("demo_item_1")
	var result: bool = _controller.try_demo_interaction("demo_item_1")
	EventBus.demo_interaction_triggered.disconnect(capture)
	assert_true(result, "try_demo_interaction should return true for demo unit")
	assert_eq(
		triggered_ids.size(), 1,
		"demo_interaction_triggered should be emitted once"
	)
	assert_eq(
		triggered_ids[0], "demo_item_1",
		"Signal should carry the correct item_id"
	)
