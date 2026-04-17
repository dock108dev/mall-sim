## Tests atomic cart submission behavior in OrderSystem.
extends GutTest

var _order_system: OrderSystem
var _inventory_system: InventorySystem
var _reputation_system: ReputationSystem
var _progression_system: ProgressionSystem
var _economy_system: EconomySystem
var _order_placed_count: int = 0
var _order_failed_reason: String = ""
var _saved_data_loader: DataLoader
var _saved_store_id: StringName = &""


func before_each() -> void:
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()
	_saved_data_loader = GameManager.data_loader
	_saved_store_id = GameManager.current_store_id
	GameManager.data_loader = DataLoaderSingleton
	GameManager.current_store_id = &""
	_order_placed_count = 0
	_order_failed_reason = ""

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


func after_each() -> void:
	if EventBus.order_placed.is_connected(_on_order_placed):
		EventBus.order_placed.disconnect(_on_order_placed)
	if EventBus.order_failed.is_connected(_on_order_failed):
		EventBus.order_failed.disconnect(_on_order_failed)
	GameManager.data_loader = _saved_data_loader
	GameManager.current_store_id = _saved_store_id


func test_submit_order_creates_pending_entries_for_each_cart_line() -> void:
	var store_id: StringName = _find_store_with_basic_items(2)
	if store_id.is_empty():
		pending("Need a store with two basic-tier supplier items")
		return
	var items: Array[ItemDefinition] = _get_basic_tier_items(store_id)
	var cart_items: Array[Dictionary] = [
		{"item_id": items[0].id, "quantity": 1},
		{"item_id": items[1].id, "quantity": 2},
	]
	var expected_total: float = (
		_order_system.get_order_cost(items[0], OrderSystem.SupplierTier.BASIC)
		+ _order_system.get_order_cost(
			items[1], OrderSystem.SupplierTier.BASIC
		) * 2.0
	)
	var success: bool = _order_system.submit_order(
		store_id, OrderSystem.SupplierTier.BASIC, cart_items
	)
	assert_true(success, "Cart submission should succeed for valid basic-tier items")
	assert_eq(
		_order_system.get_pending_orders_for_store(store_id).size(), 2,
		"Each cart line should become a pending order entry"
	)
	assert_eq(
		_order_placed_count, 2,
		"submit_order should emit order_placed once per cart line"
	)
	assert_almost_eq(
		_order_system.get_daily_spending(OrderSystem.SupplierTier.BASIC),
		expected_total,
		0.01,
		"Daily spending should accumulate the entire cart total"
	)


func test_submit_order_is_atomic_when_daily_limit_is_exceeded() -> void:
	var store_id: StringName = _find_store_with_basic_items(2)
	if store_id.is_empty():
		pending("Need a store with two basic-tier supplier items")
		return
	var items: Array[ItemDefinition] = _get_basic_tier_items(store_id)
	var first_cost: float = _order_system.get_order_cost(
		items[0], OrderSystem.SupplierTier.BASIC
	)
	var second_cost: float = _order_system.get_order_cost(
		items[1], OrderSystem.SupplierTier.BASIC
	)
	var daily_limit: float = _order_system.get_daily_limit(
		OrderSystem.SupplierTier.BASIC
	)
	var first_quantity: int = maxi(1, floori(daily_limit / first_cost) - 1)
	var remaining_budget: float = daily_limit - (first_cost * first_quantity)
	var second_quantity: int = maxi(
		1, floori(remaining_budget / second_cost) + 1
	)
	var cart_items: Array[Dictionary] = [
		{"item_id": items[0].id, "quantity": first_quantity},
		{"item_id": items[1].id, "quantity": second_quantity},
	]
	var success: bool = _order_system.submit_order(
		store_id, OrderSystem.SupplierTier.BASIC, cart_items
	)
	assert_false(
		success,
		"submit_order should reject carts that exceed the supplier daily limit"
	)
	assert_eq(
		_order_system.get_pending_orders_for_store(store_id).size(), 0,
		"Rejected cart submissions must not create partial pending orders"
	)
	assert_eq(
		_order_placed_count, 0,
		"Rejected cart submissions must not emit order_placed"
	)
	assert_eq(
		_order_failed_reason,
		"Daily order limit ($%.0f) exceeded" % daily_limit,
		"Rejected cart should surface the daily limit failure reason"
	)


func _on_order_placed(
	_store_id: StringName,
	_item_id: StringName,
	_quantity: int,
	_delivery_day: int,
) -> void:
	_order_placed_count += 1


func _on_order_failed(reason: String) -> void:
	_order_failed_reason = reason


func _find_store_with_basic_items(minimum_items: int) -> StringName:
	for store_def: StoreDefinition in GameManager.data_loader.get_all_stores():
		var store_id: StringName = StringName(store_def.id)
		if _get_basic_tier_items(store_id).size() >= minimum_items:
			return store_id
	return &""


func _get_basic_tier_items(store_id: StringName) -> Array[ItemDefinition]:
	var items: Array[ItemDefinition] = []
	var store_items: Array[ItemDefinition] = GameManager.data_loader.get_items_by_store(
		String(store_id)
	)
	for item_def: ItemDefinition in store_items:
		if _order_system.is_item_in_tier_catalog(
			item_def, OrderSystem.SupplierTier.BASIC
		):
			items.append(item_def)
	return items
