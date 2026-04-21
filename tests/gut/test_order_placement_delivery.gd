## Tests for OrderSystem order placement, delivery timer, and fulfillment.
extends GutTest


var _order_system: OrderSystem
var _inventory_system: InventorySystem
var _reputation_system: ReputationSystem
var _progression_system: ProgressionSystem
var _economy_system: EconomySystem
var _order_placed_count: int = 0
var _order_failed_reason: String = ""
var _delivered_stores: Array[StringName] = []
var _delivered_items: Array = []
var _last_placed_store_id: StringName = &""
var _last_placed_item_id: StringName = &""
var _last_placed_quantity: int = 0
var _last_placed_delivery_day: int = 0


func before_each() -> void:
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()
	GameManager.data_loader = DataLoaderSingleton
	_order_placed_count = 0
	_order_failed_reason = ""
	_delivered_stores = []
	_delivered_items = []
	_last_placed_store_id = &""
	_last_placed_item_id = &""
	_last_placed_quantity = 0
	_last_placed_delivery_day = 0

	_economy_system = EconomySystem.new()
	_economy_system.name = "EconomySystem"
	add_child_autofree(_economy_system)
	_economy_system.initialize()

	_inventory_system = InventorySystem.new()
	_inventory_system.name = "InventorySystem"
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(GameManager.data_loader)

	_reputation_system = ReputationSystem.new()
	_reputation_system.name = "ReputationSystem"
	add_child_autofree(_reputation_system)

	_progression_system = ProgressionSystem.new()
	_progression_system.name = "ProgressionSystem"
	add_child_autofree(_progression_system)
	_progression_system.initialize(_economy_system, _reputation_system)

	_order_system = OrderSystem.new()
	_order_system.name = "OrderSystem"
	add_child_autofree(_order_system)
	_order_system.initialize(
		_inventory_system, _reputation_system, _progression_system
	)

	EventBus.order_placed.connect(_on_order_placed)
	EventBus.order_failed.connect(_on_order_failed)
	EventBus.order_delivered.connect(_on_order_delivered)


func after_each() -> void:
	if EventBus.order_placed.is_connected(_on_order_placed):
		EventBus.order_placed.disconnect(_on_order_placed)
	if EventBus.order_failed.is_connected(_on_order_failed):
		EventBus.order_failed.disconnect(_on_order_failed)
	if EventBus.order_delivered.is_connected(_on_order_delivered):
		EventBus.order_delivered.disconnect(_on_order_delivered)

func _on_order_placed(
	store_id: StringName,
	item_id: StringName,
	quantity: int,
	delivery_day: int,
) -> void:
	_order_placed_count += 1
	_last_placed_store_id = store_id
	_last_placed_item_id = item_id
	_last_placed_quantity = quantity
	_last_placed_delivery_day = delivery_day


func _on_order_failed(reason: String) -> void:
	_order_failed_reason = reason


func _on_order_delivered(
	store_id: StringName, items: Array
) -> void:
	_delivered_stores.append(store_id)
	_delivered_items.append_array(items)


func _get_basic_tier_item() -> ItemDefinition:
	return _get_basic_item_for_store("retro_games")


func _get_basic_item_for_store(store_id: String) -> ItemDefinition:
	if not GameManager.data_loader:
		return null
	var items: Array[ItemDefinition] = (
		GameManager.data_loader.get_items_by_store(store_id)
	)
	for item: ItemDefinition in items:
		if item.rarity in ["common", "uncommon"]:
			return item
	return null


func _get_second_basic_item_for_store(store_id: String) -> ItemDefinition:
	if not GameManager.data_loader:
		return null
	var items: Array[ItemDefinition] = (
		GameManager.data_loader.get_items_by_store(store_id)
	)
	var matched: int = 0
	for item: ItemDefinition in items:
		if item.rarity not in ["common", "uncommon"]:
			continue
		if matched == 1:
			return item
		matched += 1
	return null


func _load_pending_order(
	item: ItemDefinition,
	delivery_day: int,
	store_id: StringName = &"retro_games",
	quantity: int = 1,
) -> void:
	_order_system.load_save_data({
		"pending_orders": [
			{
				"store_id": String(store_id),
				"supplier_tier": OrderSystem.SupplierTier.BASIC,
				"item_id": item.id,
				"quantity": quantity,
				"unit_cost": 5.0,
				"delivery_day": delivery_day,
			},
		],
	})


# --- Successful order placement ---


func test_place_order_creates_pending_order() -> void:
	var item: ItemDefinition = _get_basic_tier_item()
	if not item:
		pending("DataLoader or basic-tier items not available")
		return
	var result: bool = _order_system.place_order(
		&"retro_games",
		OrderSystem.SupplierTier.BASIC,
		StringName(item.id),
		2,
	)
	assert_true(result, "place_order should succeed")
	assert_eq(
		_order_system.get_pending_order_count(), 1,
		"Should have 1 pending order"
	)


func test_place_order_pending_entry_has_correct_fields() -> void:
	var item: ItemDefinition = _get_basic_tier_item()
	if not item:
		pending("DataLoader or basic-tier items not available")
		return
	_order_system.place_order(
		&"retro_games",
		OrderSystem.SupplierTier.BASIC,
		StringName(item.id),
		3,
	)
	var orders: Array[Dictionary] = _order_system.get_pending_orders()
	assert_eq(orders.size(), 1, "Should have 1 pending order")
	var order: Dictionary = orders[0]
	assert_eq(
		order["store_id"], "retro_games",
		"store_id should match"
	)
	assert_eq(
		order["item_id"], item.id,
		"item_id should match"
	)
	assert_eq(
		int(order["quantity"]), 3,
		"quantity should match"
	)
	assert_eq(
		int(order["supplier_tier"]),
		OrderSystem.SupplierTier.BASIC,
		"supplier_tier should match"
	)
	var expected_day: int = (
		GameManager.current_day
		+ OrderSystem.TIER_CONFIG[OrderSystem.SupplierTier.BASIC][
			"delivery_days"
		]
	)
	assert_eq(
		int(order["delivery_day"]), expected_day,
		"delivery_day should be current_day + delivery_days"
	)
	assert_gt(
		float(order["unit_cost"]), 0.0,
		"unit_cost should be positive"
	)


func test_place_order_emits_order_placed_signal() -> void:
	var item: ItemDefinition = _get_basic_tier_item()
	if not item:
		pending("DataLoader or basic-tier items not available")
		return
	_order_system.place_order(
		&"retro_games",
		OrderSystem.SupplierTier.BASIC,
		StringName(item.id),
		2,
	)
	assert_eq(
		_order_placed_count, 1,
		"order_placed should have been emitted once"
	)
	assert_eq(
		_last_placed_store_id, &"retro_games",
		"order_placed store_id should match"
	)
	assert_eq(
		_last_placed_item_id, StringName(item.id),
		"order_placed item_id should match"
	)
	assert_eq(
		_last_placed_quantity, 2,
		"order_placed quantity should match"
	)


func test_place_order_insufficient_funds_no_pending_order() -> void:
	var item: ItemDefinition = _get_basic_tier_item()
	if not item:
		pending("DataLoader or basic-tier items not available")
		return
	_economy_system.load_save_data({"current_cash": 0.0})
	_order_system.place_order(
		&"retro_games",
		OrderSystem.SupplierTier.BASIC,
		StringName(item.id),
		1,
	)
	assert_eq(
		_order_system.get_pending_order_count(), 0,
		"No pending order should be created on insufficient funds"
	)
	assert_eq(
		_order_failed_reason, "Insufficient funds",
		"Should emit order_failed with insufficient funds"
	)


# --- Delivery on day_started ---


func test_day_started_delivers_due_orders() -> void:
	var item: ItemDefinition = _get_basic_tier_item()
	if not item:
		pending("DataLoader or basic-tier items not available")
		return
	_load_pending_order(item, 3, &"retro_games", 2)
	assert_eq(
		_order_system.get_pending_order_count(), 1,
		"Should start with 1 pending order"
	)
	EventBus.day_started.emit(3)
	assert_eq(
		_order_system.get_pending_order_count(), 0,
		"Pending order should be removed after delivery"
	)


func test_day_started_emits_order_delivered() -> void:
	var item: ItemDefinition = _get_basic_tier_item()
	if not item:
		pending("DataLoader or basic-tier items not available")
		return
	_load_pending_order(item, 5)
	EventBus.day_started.emit(5)
	assert_eq(
		_delivered_stores.size(), 1,
		"order_delivered should be emitted once"
	)
	assert_eq(
		_delivered_stores[0], &"retro_games",
		"Delivered store_id should match"
	)


func test_day_started_does_not_deliver_future_orders() -> void:
	var item: ItemDefinition = _get_basic_tier_item()
	if not item:
		pending("DataLoader or basic-tier items not available")
		return
	_load_pending_order(item, 10)
	EventBus.day_started.emit(8)
	assert_eq(
		_order_system.get_pending_order_count(), 1,
		"Future order should remain pending"
	)
	assert_eq(
		_delivered_stores.size(), 0,
		"No delivery signal for future orders"
	)


func test_fulfilled_order_removed_from_pending() -> void:
	var item_a: ItemDefinition = _get_basic_tier_item()
	var item_b: ItemDefinition = _get_second_basic_item_for_store("retro_games")
	if not item_a or not item_b:
		pending("Need basic-tier items available")
		return
	_order_system.load_save_data({
		"pending_orders": [
			{
				"store_id": "retro_games",
				"supplier_tier": 0,
				"item_id": item_a.id,
				"quantity": 1,
				"unit_cost": 5.0,
				"delivery_day": 4,
			},
			{
				"store_id": "retro_games",
				"supplier_tier": 0,
				"item_id": item_b.id,
				"quantity": 1,
				"unit_cost": 5.0,
				"delivery_day": 6,
			},
		],
	})
	EventBus.day_started.emit(4)
	assert_eq(
		_order_system.get_pending_order_count(), 1,
		"Only the non-due order should remain"
	)
	var remaining: Array[Dictionary] = (
		_order_system.get_pending_orders()
	)
	assert_eq(
		remaining[0]["item_id"], item_b.id,
		"Remaining order should be the future one"
	)


func test_overdue_orders_also_delivered() -> void:
	var item: ItemDefinition = _get_basic_tier_item()
	if not item:
		pending("DataLoader or basic-tier items not available")
		return
	_load_pending_order(item, 2)
	EventBus.day_started.emit(5)
	assert_eq(
		_order_system.get_pending_order_count(), 0,
		"Overdue order should be delivered"
	)
	assert_eq(
		_delivered_stores.size(), 1,
		"order_delivered should fire for overdue order"
	)


# --- Multiple concurrent orders ---


func test_multiple_orders_track_independently() -> void:
	var retro_item: ItemDefinition = _get_basic_tier_item()
	var pocket_item: ItemDefinition = _get_basic_item_for_store("pocket_creatures")
	var rental_item: ItemDefinition = _get_basic_item_for_store("video_rental")
	if not retro_item or not pocket_item or not rental_item:
		pending("Need basic-tier items for retro, pocket_creatures, and video_rental")
		return
	_order_system.load_save_data({
		"pending_orders": [
			{
				"store_id": "retro_games",
				"supplier_tier": 0,
				"item_id": retro_item.id,
				"quantity": 1,
				"unit_cost": 5.0,
				"delivery_day": 3,
			},
			{
				"store_id": "pocket_creatures",
				"supplier_tier": 0,
				"item_id": pocket_item.id,
				"quantity": 2,
				"unit_cost": 10.0,
				"delivery_day": 5,
			},
			{
				"store_id": "video_rental",
				"supplier_tier": 0,
				"item_id": rental_item.id,
				"quantity": 3,
				"unit_cost": 8.0,
				"delivery_day": 7,
			},
		],
	})
	assert_eq(
		_order_system.get_pending_order_count(), 3,
		"Should start with 3 pending orders"
	)
	EventBus.day_started.emit(3)
	assert_eq(
		_order_system.get_pending_order_count(), 2,
		"Day 3: 1 delivered, 2 remaining"
	)
	assert_eq(
		_delivered_stores.size(), 1,
		"Day 3: 1 delivery signal"
	)
	assert_eq(
		_delivered_stores[0], &"retro_games",
		"Day 3: retro_games order delivered"
	)
	_delivered_stores.clear()
	_delivered_items.clear()
	EventBus.day_started.emit(5)
	assert_eq(
		_order_system.get_pending_order_count(), 1,
		"Day 5: 1 more delivered, 1 remaining"
	)
	assert_eq(
		_delivered_stores[0], &"pocket_creatures",
		"Day 5: pocket_creatures order delivered"
	)
	_delivered_stores.clear()
	_delivered_items.clear()
	EventBus.day_started.emit(7)
	assert_eq(
		_order_system.get_pending_order_count(), 0,
		"Day 7: all orders delivered"
	)
	assert_eq(
		_delivered_stores[0], &"rentals",
		"Day 7: video_rental order delivered (canonicalized to rentals)"
	)


func test_day_started_resets_daily_spending() -> void:
	var item: ItemDefinition = _get_basic_tier_item()
	if not item:
		pending("DataLoader or basic-tier items not available")
		return
	_order_system.place_order(
		&"retro_games",
		OrderSystem.SupplierTier.BASIC,
		StringName(item.id),
		1,
	)
	assert_gt(
		_order_system.get_daily_spending(
			OrderSystem.SupplierTier.BASIC
		),
		0.0,
		"Spending should be positive after placing an order"
	)
	EventBus.day_started.emit(GameManager.current_day + 10)
	assert_eq(
		_order_system.get_daily_spending(
			OrderSystem.SupplierTier.BASIC
		),
		0.0,
		"Daily spending should reset on day_started"
	)
