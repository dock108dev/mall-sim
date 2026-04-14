## Tests customer_purchased signal wiring into InventorySystem stock deduction.
extends GutTest


var _data_loader: DataLoader
var _inventory_system: InventorySystem
var _stock_changed_events: Array[Dictionary] = []
var _out_of_stock_events: Array[Dictionary] = []


func before_each() -> void:
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()
	_inventory_system = InventorySystem.new()
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(_data_loader)
	_stock_changed_events = []
	_out_of_stock_events = []
	EventBus.stock_changed.connect(_on_stock_changed)
	EventBus.out_of_stock.connect(_on_out_of_stock)


func after_each() -> void:
	if EventBus.stock_changed.is_connected(_on_stock_changed):
		EventBus.stock_changed.disconnect(_on_stock_changed)
	if EventBus.out_of_stock.is_connected(_on_out_of_stock):
		EventBus.out_of_stock.disconnect(_on_out_of_stock)


func _on_stock_changed(
	store_id: StringName, item_id: StringName, new_quantity: int
) -> void:
	_stock_changed_events.append({
		"store_id": store_id,
		"item_id": item_id,
		"new_quantity": new_quantity,
	})


func _on_out_of_stock(
	store_id: StringName, item_id: StringName
) -> void:
	_out_of_stock_events.append({
		"store_id": store_id,
		"item_id": item_id,
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


func test_stock_decreases_on_customer_purchased() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	var item_a: ItemInstance = _make_item(def)
	var item_b: ItemInstance = _make_item(def)
	_inventory_system.add_item(store_id, item_a)
	_inventory_system.add_item(store_id, item_b)
	var stock_before: Array[ItemInstance] = _inventory_system.get_stock(
		store_id
	)
	assert_eq(stock_before.size(), 2, "Should start with 2 items")
	EventBus.customer_purchased.emit(
		store_id, StringName(item_a.instance_id), 10.0, &"cust_1"
	)
	var stock_after: Array[ItemInstance] = _inventory_system.get_stock(
		store_id
	)
	assert_eq(
		stock_after.size(), 1,
		"Stock should decrease by 1 after customer_purchased"
	)
	assert_eq(
		_stock_changed_events.size(), 1,
		"stock_changed should fire once"
	)
	assert_eq(
		_stock_changed_events[0]["new_quantity"], 1,
		"Remaining quantity should be 1"
	)


func test_out_of_stock_fires_at_zero() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	var item: ItemInstance = _make_item(def)
	_inventory_system.add_item(store_id, item)
	EventBus.customer_purchased.emit(
		store_id, StringName(item.instance_id), 5.0, &"cust_2"
	)
	assert_eq(
		_out_of_stock_events.size(), 1,
		"out_of_stock should fire when quantity reaches 0"
	)
	assert_eq(
		_out_of_stock_events[0]["store_id"], store_id,
		"out_of_stock store_id should match"
	)


func test_out_of_stock_does_not_fire_at_one() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	var item_a: ItemInstance = _make_item(def)
	var item_b: ItemInstance = _make_item(def)
	_inventory_system.add_item(store_id, item_a)
	_inventory_system.add_item(store_id, item_b)
	EventBus.customer_purchased.emit(
		store_id, StringName(item_a.instance_id), 5.0, &"cust_3"
	)
	assert_eq(
		_out_of_stock_events.size(), 0,
		"out_of_stock should NOT fire when quantity is still 1"
	)
	assert_eq(
		_stock_changed_events[0]["new_quantity"], 1,
		"Remaining quantity should be 1"
	)


func test_handler_silent_on_missing_item() -> void:
	var store_id: StringName = &"sports_memorabilia"
	EventBus.customer_purchased.emit(
		store_id, &"nonexistent_item", 10.0, &"cust_4"
	)
	assert_eq(
		_stock_changed_events.size(), 0,
		"No stock_changed when item not in inventory"
	)
	assert_eq(
		_out_of_stock_events.size(), 0,
		"No out_of_stock when item not in inventory"
	)
