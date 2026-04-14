## Integration test: InventorySystem low-stock threshold → restock_requested →
## OrderSystem creates a pending order (ISSUE-413).
extends GutTest


var _inventory_system: InventorySystem
var _order_system: OrderSystem
var _reputation_system: ReputationSystem
var _progression_system: ProgressionSystem
var _economy_system: EconomySystem
var _restock_signals: Array[Dictionary] = []


func before_each() -> void:
	_restock_signals = []

	_economy_system = EconomySystem.new()
	_economy_system.name = "EconomySystem"
	add_child(_economy_system)
	_economy_system.initialize()

	_inventory_system = InventorySystem.new()
	_inventory_system.name = "InventorySystem"
	add_child(_inventory_system)
	_inventory_system.initialize(GameManager.data_loader)

	_reputation_system = ReputationSystem.new()
	_reputation_system.name = "ReputationSystem"
	add_child(_reputation_system)

	_progression_system = ProgressionSystem.new()
	_progression_system.name = "ProgressionSystem"
	add_child(_progression_system)
	_progression_system.initialize(_economy_system, _reputation_system)

	_order_system = OrderSystem.new()
	_order_system.name = "OrderSystem"
	add_child(_order_system)
	_order_system.initialize(
		_inventory_system, _reputation_system, _progression_system
	)

	EventBus.restock_requested.connect(_on_restock_requested)


func after_each() -> void:
	if EventBus.restock_requested.is_connected(_on_restock_requested):
		EventBus.restock_requested.disconnect(_on_restock_requested)
	_order_system.queue_free()
	_progression_system.queue_free()
	_reputation_system.queue_free()
	_inventory_system.queue_free()
	_economy_system.queue_free()


func _on_restock_requested(
	store_id: StringName, item_id: StringName, quantity: int
) -> void:
	_restock_signals.append({
		"store_id": store_id,
		"item_id": item_id,
		"quantity": quantity,
	})


func _get_first_def() -> ItemDefinition:
	if not GameManager.data_loader:
		return null
	var items: Array[ItemDefinition] = GameManager.data_loader.get_all_items()
	if items.is_empty():
		return null
	return items[0]


func _populate_stock(
	store_id: StringName, def: ItemDefinition, count: int
) -> Array[ItemInstance]:
	var items: Array[ItemInstance] = []
	for i: int in range(count):
		var item: ItemInstance = ItemInstance.create(
			def, "good", 0, def.base_price
		)
		item.current_location = "backroom"
		_inventory_system.add_item(store_id, item)
		items.append(item)
	return items


# --- restock_requested signal emission ---


func test_restock_triggered_when_stock_falls_below_min() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pending("DataLoader not available — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	_inventory_system.set_reorder_config(store_id, StringName(def.id), 5, 10)
	var items: Array[ItemInstance] = _populate_stock(store_id, def, 6)
	_restock_signals.clear()
	# Remove 2 items: stock 6 → 4, which is strictly below reorder_min = 5.
	_inventory_system.remove_item(items[0].instance_id)
	_inventory_system.remove_item(items[1].instance_id)
	assert_eq(
		_restock_signals.size(), 1,
		"restock_requested should fire exactly once when stock crosses below threshold"
	)
	assert_eq(
		_restock_signals[0]["store_id"], store_id,
		"restock_requested store_id should match the configured store"
	)
	assert_eq(
		_restock_signals[0]["item_id"], StringName(def.id),
		"restock_requested item_id should match the definition id"
	)
	assert_eq(
		_restock_signals[0]["quantity"], 10,
		"restock_requested quantity should match the configured reorder_quantity"
	)


func test_restock_not_triggered_at_exact_threshold() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pending("DataLoader not available — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	_inventory_system.set_reorder_config(store_id, StringName(def.id), 5, 10)
	var items: Array[ItemInstance] = _populate_stock(store_id, def, 6)
	_restock_signals.clear()
	# Remove 1: stock drops from 6 to 5, exactly equal to reorder_min — must NOT fire.
	_inventory_system.remove_item(items[0].instance_id)
	assert_eq(
		_restock_signals.size(), 0,
		"restock_requested must NOT fire when stock is exactly at reorder_min"
	)


func test_restock_idempotency_prevents_duplicate_signals() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pending("DataLoader not available — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	_inventory_system.set_reorder_config(store_id, StringName(def.id), 5, 10)
	var items: Array[ItemInstance] = _populate_stock(store_id, def, 8)
	_restock_signals.clear()
	# Remove items one by one; only the first removal that crosses below threshold fires.
	_inventory_system.remove_item(items[0].instance_id)
	_inventory_system.remove_item(items[1].instance_id)
	_inventory_system.remove_item(items[2].instance_id)
	_inventory_system.remove_item(items[3].instance_id)
	assert_eq(
		_restock_signals.size(), 1,
		"Idempotency guard must prevent duplicate restock_requested emissions"
	)


func test_restock_guard_resets_after_replenishment() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pending("DataLoader not available — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	_inventory_system.set_reorder_config(store_id, StringName(def.id), 5, 10)
	var items: Array[ItemInstance] = _populate_stock(store_id, def, 6)
	_restock_signals.clear()
	_inventory_system.remove_item(items[0].instance_id)
	_inventory_system.remove_item(items[1].instance_id)
	assert_eq(_restock_signals.size(), 1, "First threshold crossing should fire")
	# Replenish above threshold — adds 3 items, total becomes 7.
	_populate_stock(store_id, def, 3)
	_restock_signals.clear()
	# Remove 3 items again to cross below threshold a second time.
	var current_stock: Array[ItemInstance] = _inventory_system.get_stock(store_id)
	_inventory_system.remove_item(current_stock[0].instance_id)
	_inventory_system.remove_item(current_stock[1].instance_id)
	_inventory_system.remove_item(current_stock[2].instance_id)
	assert_eq(
		_restock_signals.size(), 1,
		"restock_requested should fire again after stock was replenished above threshold"
	)


# --- OrderSystem response ---


func test_order_system_creates_pending_order_on_restock() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pending("DataLoader not available — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	_inventory_system.set_reorder_config(store_id, StringName(def.id), 5, 10)
	var items: Array[ItemInstance] = _populate_stock(store_id, def, 6)
	# Trigger restock_requested by crossing below threshold.
	_inventory_system.remove_item(items[0].instance_id)
	_inventory_system.remove_item(items[1].instance_id)
	var pending_orders: Array[Dictionary] = (
		_order_system.get_pending_orders_for_store(store_id)
	)
	assert_eq(
		pending_orders.size(), 1,
		"OrderSystem should have exactly one pending order after restock_requested"
	)


func test_pending_order_has_correct_item_id() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pending("DataLoader not available — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	_inventory_system.set_reorder_config(store_id, StringName(def.id), 5, 10)
	var items: Array[ItemInstance] = _populate_stock(store_id, def, 6)
	_inventory_system.remove_item(items[0].instance_id)
	_inventory_system.remove_item(items[1].instance_id)
	var pending_orders: Array[Dictionary] = (
		_order_system.get_pending_orders_for_store(store_id)
	)
	assert_eq(pending_orders.size(), 1, "Should have one pending order")
	assert_eq(
		pending_orders[0].get("item_id", ""), String(def.id),
		"Pending order item_id should match the definition id"
	)


func test_pending_order_quantity_matches_reorder_config() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pending("DataLoader not available — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	_inventory_system.set_reorder_config(store_id, StringName(def.id), 3, 8)
	var items: Array[ItemInstance] = _populate_stock(store_id, def, 4)
	# Remove 2 items: stock 4 → 2, below reorder_min = 3.
	_inventory_system.remove_item(items[0].instance_id)
	_inventory_system.remove_item(items[1].instance_id)
	var pending_orders: Array[Dictionary] = (
		_order_system.get_pending_orders_for_store(store_id)
	)
	assert_eq(pending_orders.size(), 1, "Should have one pending order")
	assert_eq(
		pending_orders[0].get("quantity", 0), 8,
		"Pending order quantity should match the configured reorder_quantity"
	)


func test_get_pending_orders_for_store_filters_correctly() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pending("DataLoader not available — skip")
		return
	var store_id: StringName = ContentRegistry.resolve(def.store_type)
	_inventory_system.set_reorder_config(store_id, StringName(def.id), 5, 10)
	var items: Array[ItemInstance] = _populate_stock(store_id, def, 6)
	_inventory_system.remove_item(items[0].instance_id)
	_inventory_system.remove_item(items[1].instance_id)
	var all_orders: Array[Dictionary] = _order_system.get_pending_orders()
	var store_orders: Array[Dictionary] = (
		_order_system.get_pending_orders_for_store(store_id)
	)
	var other_store_orders: Array[Dictionary] = (
		_order_system.get_pending_orders_for_store(&"nonexistent_store")
	)
	assert_eq(
		all_orders.size(), store_orders.size(),
		"All pending orders should belong to the test store"
	)
	assert_eq(
		other_store_orders.size(), 0,
		"get_pending_orders_for_store should return empty for unknown store"
	)
