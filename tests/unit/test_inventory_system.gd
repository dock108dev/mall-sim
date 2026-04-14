## Unit tests for InventorySystem — stock deduction, restock threshold,
## overfill guard, and signal contracts.
extends GutTest


var _data_loader: DataLoader
var _inventory: InventorySystem
var _stock_changed_events: Array[Dictionary] = []
var _restock_requested_events: Array[Dictionary] = []


func before_each() -> void:
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)
	_stock_changed_events = []
	_restock_requested_events = []
	EventBus.stock_changed.connect(_on_stock_changed)
	EventBus.restock_requested.connect(_on_restock_requested)


func after_each() -> void:
	if EventBus.stock_changed.is_connected(_on_stock_changed):
		EventBus.stock_changed.disconnect(_on_stock_changed)
	if EventBus.restock_requested.is_connected(_on_restock_requested):
		EventBus.restock_requested.disconnect(_on_restock_requested)


func _on_stock_changed(
	store_id: StringName, item_id: StringName, new_quantity: int
) -> void:
	_stock_changed_events.append({
		"store_id": store_id,
		"item_id": item_id,
		"new_quantity": new_quantity,
	})


func _on_restock_requested(
	store_id: StringName, item_id: StringName, quantity: int
) -> void:
	_restock_requested_events.append({
		"store_id": store_id,
		"item_id": item_id,
		"quantity": quantity,
	})


func _get_first_def() -> ItemDefinition:
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	if items.is_empty():
		return null
	return items[0]


func _make_item(def: ItemDefinition) -> ItemInstance:
	var item: ItemInstance = ItemInstance.create(
		def, "good", 0, def.base_price
	)
	item.current_location = "backroom"
	return item


func _add_items_for_def(
	store_id: StringName, def: ItemDefinition, count: int
) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for i: int in range(count):
		var item: ItemInstance = _make_item(def)
		_inventory.add_item(store_id, item)
		result.append(item)
	return result


# --- Stock deduction ---

func test_deduct_stock_removes_item() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	var item: ItemInstance = _make_item(def)
	_inventory.add_item(store_id, item)
	assert_eq(_inventory.get_item_count(), 1, "Should have 1 item before deduct")
	var ok: bool = _inventory.deduct_stock(store_id, item.instance_id)
	assert_true(ok, "deduct_stock should return true for existing item")
	assert_eq(_inventory.get_item_count(), 0, "Item count should be 0 after deduction")
	assert_null(
		_inventory.get_item(item.instance_id),
		"Item should not be retrievable after deduction"
	)


func test_deduct_nonexistent_returns_false() -> void:
	assert_false(
		_inventory.deduct_stock(&"sports", "nonexistent_instance_id"),
		"deduct_stock should return false for a missing item"
	)
	assert_eq(
		_inventory.get_item_count(), 0,
		"Item count must not change when deducting a nonexistent item"
	)


func test_deduct_does_not_go_negative() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	var item: ItemInstance = _make_item(def)
	_inventory.add_item(store_id, item)
	_inventory.deduct_stock(store_id, item.instance_id)
	_inventory.deduct_stock(store_id, item.instance_id)
	assert_true(
		_inventory.get_item_count() >= 0,
		"Item count must never go negative"
	)


func test_stock_changed_emits_with_correct_values_on_purchase() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	var item_a: ItemInstance = _make_item(def)
	var item_b: ItemInstance = _make_item(def)
	_inventory.add_item(store_id, item_a)
	_inventory.add_item(store_id, item_b)
	EventBus.customer_purchased.emit(
		store_id, StringName(item_a.instance_id), 10.0, &"cust_1"
	)
	assert_eq(
		_stock_changed_events.size(), 1,
		"stock_changed should fire once after purchase"
	)
	assert_eq(
		_stock_changed_events[0]["store_id"], store_id,
		"stock_changed store_id should match"
	)
	assert_eq(
		_stock_changed_events[0]["new_quantity"], 1,
		"stock_changed new_quantity should be 1 after one item sold"
	)


# --- Restock threshold ---

func test_restock_requested_fires_when_stock_falls_below_threshold() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	var def_id: StringName = StringName(def.id)
	_inventory.set_reorder_config(store_id, def_id, 2, 5)
	var items: Array[ItemInstance] = _add_items_for_def(store_id, def, 3)
	_restock_requested_events.clear()
	_inventory.remove_item(items[0].instance_id)
	_inventory.remove_item(items[1].instance_id)
	assert_eq(
		_restock_requested_events.size(), 1,
		"restock_requested should fire when stock falls below reorder_min"
	)
	assert_eq(
		_restock_requested_events[0]["store_id"], store_id,
		"restock_requested store_id should match"
	)
	assert_eq(
		_restock_requested_events[0]["item_id"], def_id,
		"restock_requested item_id should match definition id"
	)


func test_restock_not_fired_when_stock_stays_at_or_above_threshold() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	var def_id: StringName = StringName(def.id)
	_inventory.set_reorder_config(store_id, def_id, 2, 5)
	var items: Array[ItemInstance] = _add_items_for_def(store_id, def, 4)
	_restock_requested_events.clear()
	_inventory.remove_item(items[0].instance_id)
	assert_eq(
		_restock_requested_events.size(), 0,
		"restock_requested must NOT fire when stock is still at or above reorder_min"
	)


func test_restock_not_re_emitted_while_pending() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	var def_id: StringName = StringName(def.id)
	_inventory.set_reorder_config(store_id, def_id, 3, 5)
	var items: Array[ItemInstance] = _add_items_for_def(store_id, def, 4)
	_restock_requested_events.clear()
	_inventory.remove_item(items[0].instance_id)
	_inventory.remove_item(items[1].instance_id)
	var count_after_first_trigger: int = _restock_requested_events.size()
	_inventory.remove_item(items[2].instance_id)
	assert_eq(
		_restock_requested_events.size(), count_after_first_trigger,
		"restock_requested should not fire again while restock is already pending"
	)


# --- Overfill guard ---

func test_register_item_returns_false_when_backroom_full() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	var entry: Dictionary = ContentRegistry.get_entry(store_id)
	var capacity: int = int(entry.get("backroom_capacity", 0))
	if capacity <= 0:
		pass_test("Store has no capacity limit — skip overfill test")
		return
	for i: int in range(capacity):
		var fake := ItemInstance.new()
		fake.definition = def
		fake.instance_id = "overfill_test_%d" % i
		fake.current_location = "backroom"
		_inventory._items[fake.instance_id] = fake
	var overflow_item: ItemInstance = _make_item(def)
	var result: bool = _inventory.register_item(overflow_item)
	assert_false(result, "register_item must return false when backroom is at capacity")
	assert_eq(
		_inventory.get_item_count(), capacity,
		"Item count must clamp to max_capacity after a rejected overfill"
	)


func test_create_item_returns_null_when_backroom_full() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	var entry: Dictionary = ContentRegistry.get_entry(store_id)
	var capacity: int = int(entry.get("backroom_capacity", 0))
	if capacity <= 0:
		pass_test("Store has no capacity limit — skip overfill test")
		return
	for i: int in range(capacity):
		var fake := ItemInstance.new()
		fake.definition = def
		fake.instance_id = "fill_test_%d" % i
		fake.current_location = "backroom"
		_inventory._items[fake.instance_id] = fake
	var result: ItemInstance = _inventory.create_item(
		def.id, "good", def.base_price
	)
	assert_null(result, "create_item should return null when backroom is full")
	assert_eq(
		_inventory.get_item_count(), capacity,
		"Item count must not exceed max_capacity after overfill attempt"
	)


# --- Query contract ---

func test_get_stock_returns_empty_array_for_unknown_store() -> void:
	var stock: Array[ItemInstance] = _inventory.get_stock(&"nonexistent_store_id")
	assert_not_null(stock, "get_stock must never return null")
	assert_eq(
		stock.size(), 0,
		"get_stock should return an empty array for an unknown store, not an error"
	)


func test_get_stock_count_matches_items_added() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	_add_items_for_def(store_id, def, 3)
	var stock: Array[ItemInstance] = _inventory.get_stock(store_id)
	assert_eq(
		stock.size(), 3,
		"get_stock count should equal the number of items added"
	)
