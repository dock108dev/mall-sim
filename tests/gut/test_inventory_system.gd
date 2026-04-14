## Tests InventorySystem add/remove, shelf assignment, restock queue,
## and serialize/deserialize round-trip.
extends GutTest


var _data_loader: DataLoader
var _inventory_system: InventorySystem
var _updated_store_ids: Array[StringName] = []


func before_each() -> void:
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()
	_inventory_system = InventorySystem.new()
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(_data_loader)
	_updated_store_ids = []
	EventBus.inventory_updated.connect(_on_inventory_updated)


func after_each() -> void:
	if EventBus.inventory_updated.is_connected(_on_inventory_updated):
		EventBus.inventory_updated.disconnect(_on_inventory_updated)


func _on_inventory_updated(store_id: StringName) -> void:
	_updated_store_ids.append(store_id)


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


func test_add_item_stores_and_emits() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var item: ItemInstance = _make_item(def)
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	_inventory_system.add_item(store_id, item)
	var fetched: ItemInstance = _inventory_system.get_item(
		item.instance_id
	)
	assert_not_null(fetched, "Item should be in inventory after add")
	assert_true(
		_updated_store_ids.has(store_id),
		"inventory_updated should fire with store_id"
	)


func test_remove_item_returns_false_if_missing() -> void:
	var result: bool = _inventory_system.remove_item("nonexistent_id")
	assert_false(result, "remove_item should return false for missing")


func test_remove_item_returns_true_and_emits() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var item: ItemInstance = _make_item(def)
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	_inventory_system.add_item(store_id, item)
	_updated_store_ids.clear()
	var result: bool = _inventory_system.remove_item(item.instance_id)
	assert_true(result, "remove_item should return true for existing")
	assert_null(
		_inventory_system.get_item(item.instance_id),
		"Item should be gone after removal"
	)
	assert_true(
		_updated_store_ids.has(store_id),
		"inventory_updated should fire on removal"
	)


func test_get_stock_returns_store_items() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	var item_a: ItemInstance = _make_item(def)
	var item_b: ItemInstance = _make_item(def)
	_inventory_system.add_item(store_id, item_a)
	_inventory_system.add_item(store_id, item_b)
	var stock: Array[ItemInstance] = _inventory_system.get_stock(store_id)
	assert_eq(stock.size(), 2, "get_stock should return 2 items")


func test_get_stock_empty_for_unknown_store() -> void:
	var stock: Array[ItemInstance] = _inventory_system.get_stock(
		&"nonexistent_store"
	)
	assert_eq(stock.size(), 0, "get_stock should be empty for bad id")


func test_assign_to_shelf_links_item() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	var item: ItemInstance = _make_item(def)
	_inventory_system.add_item(store_id, item)
	var ok: bool = _inventory_system.assign_to_shelf(
		store_id, StringName(item.instance_id), &"slot_01"
	)
	assert_true(ok, "assign_to_shelf should succeed")
	var shelf_item: ItemInstance = _inventory_system.get_shelf_item(
		store_id, &"slot_01"
	)
	assert_not_null(shelf_item, "Shelf slot should have item")
	assert_eq(
		shelf_item.instance_id, item.instance_id,
		"Shelf item should match assigned item"
	)
	assert_eq(
		item.current_location, "shelf:slot_01",
		"Item location should update to shelf"
	)


func test_assign_to_shelf_fails_for_missing_item() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	var ok: bool = _inventory_system.assign_to_shelf(
		store_id, &"ghost_item", &"slot_01"
	)
	assert_false(ok, "assign_to_shelf should fail for missing item")


func test_process_restock_queue_adds_items() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	_inventory_system.queue_restock(store_id, StringName(def.id), 3)
	_inventory_system.process_restock_queue()
	var stock: Array[ItemInstance] = _inventory_system.get_stock(store_id)
	assert_eq(
		stock.size(), 3,
		"Restock should add 3 items in one process call"
	)


func test_process_restock_queue_one_entry_per_call() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	_inventory_system.queue_restock(store_id, StringName(def.id), 1)
	_inventory_system.queue_restock(store_id, StringName(def.id), 2)
	_inventory_system.process_restock_queue()
	var stock: Array[ItemInstance] = _inventory_system.get_stock(store_id)
	assert_eq(
		stock.size(), 1,
		"First process call should handle first entry only"
	)
	_inventory_system.process_restock_queue()
	stock = _inventory_system.get_stock(store_id)
	assert_eq(
		stock.size(), 3,
		"Second process call should handle second entry"
	)


func test_serialize_deserialize_round_trip() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	var item: ItemInstance = _make_item(def)
	_inventory_system.add_item(store_id, item)
	_inventory_system.assign_to_shelf(
		store_id, StringName(item.instance_id), &"slot_02"
	)
	_inventory_system.queue_restock(store_id, StringName(def.id), 2)
	var saved: Dictionary = _inventory_system.serialize()
	var new_system: InventorySystem = InventorySystem.new()
	add_child_autofree(new_system)
	new_system.initialize(_data_loader)
	new_system.deserialize(saved)
	var loaded_item: ItemInstance = new_system.get_item(item.instance_id)
	assert_not_null(loaded_item, "Item should survive round-trip")
	assert_eq(
		loaded_item.current_location, "shelf:slot_02",
		"Location should match after reload"
	)
	var shelf_item: ItemInstance = new_system.get_shelf_item(
		store_id, &"slot_02"
	)
	assert_not_null(
		shelf_item,
		"Shelf assignment should survive round-trip"
	)
	assert_eq(
		shelf_item.instance_id, item.instance_id,
		"Shelf assignment should point to correct item"
	)


func test_remove_item_clears_shelf_assignment() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	var item: ItemInstance = _make_item(def)
	_inventory_system.add_item(store_id, item)
	_inventory_system.assign_to_shelf(
		store_id, StringName(item.instance_id), &"slot_03"
	)
	_inventory_system.remove_item(item.instance_id)
	var shelf_item: ItemInstance = _inventory_system.get_shelf_item(
		store_id, &"slot_03"
	)
	assert_null(
		shelf_item,
		"Shelf slot should be empty after item removal"
	)
