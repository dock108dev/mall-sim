## GUT integration test: OrderSystem full lifecycle — submit → timer → restock → toast.
extends GutTest


const STORE_ID: StringName = &"retro_games"
const STARTING_CASH: float = 2000.0
const ORDER_QTY: int = 3
const BASIC_TIER: OrderSystem.SupplierTier = OrderSystem.SupplierTier.BASIC
## BASIC tier delivers in 1 day per TIER_CONFIG.
const BASIC_DELIVERY_DAYS: int = 1

var _order_system: OrderSystem
var _inventory_system: InventorySystem
var _economy_system: EconomySystem
var _time_system: TimeSystem

var _saved_data_loader: DataLoader
var _data_loader: DataLoader

var _delivered_store_id: StringName = &""
var _delivered_items: Array = []
var _toast_message: String = ""
var _toast_category: StringName = &""
var _order_failed_reason: String = ""
var _order_delivered_count: int = 0


func before_each() -> void:
	_delivered_store_id = &""
	_delivered_items = []
	_toast_message = ""
	_toast_category = &""
	_order_failed_reason = ""
	_order_delivered_count = 0

	ContentRegistry.clear_for_testing()
	_saved_data_loader = GameManager.data_loader
	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_data_loader.load_all_content()
	GameManager.data_loader = _data_loader

	_inventory_system = InventorySystem.new()
	_inventory_system.name = "InventorySystem"
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(_data_loader)

	_economy_system = EconomySystem.new()
	_economy_system.name = "EconomySystem"
	add_child_autofree(_economy_system)
	_economy_system.initialize(STARTING_CASH)

	_time_system = TimeSystem.new()
	_time_system.name = "TimeSystem"
	add_child_autofree(_time_system)
	_time_system.initialize()
	_time_system.current_day = GameManager.current_day

	_order_system = OrderSystem.new()
	_order_system.name = "OrderSystem"
	add_child_autofree(_order_system)
	_order_system.initialize(_inventory_system, null, null)

	EventBus.order_delivered.connect(_on_order_delivered)
	EventBus.toast_requested.connect(_on_toast_requested)
	EventBus.order_failed.connect(_on_order_failed)


func after_each() -> void:
	if EventBus.order_delivered.is_connected(_on_order_delivered):
		EventBus.order_delivered.disconnect(_on_order_delivered)
	if EventBus.toast_requested.is_connected(_on_toast_requested):
		EventBus.toast_requested.disconnect(_on_toast_requested)
	if EventBus.order_failed.is_connected(_on_order_failed):
		EventBus.order_failed.disconnect(_on_order_failed)
	GameManager.data_loader = _saved_data_loader
	ContentRegistry.clear_for_testing()
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()


func _on_order_delivered(store_id: StringName, items: Array) -> void:
	_order_delivered_count += 1
	_delivered_store_id = store_id
	_delivered_items = items.duplicate()


func _on_toast_requested(
	message: String, category: StringName, _duration: float
) -> void:
	_toast_message = message
	_toast_category = category


func _on_order_failed(reason: String) -> void:
	_order_failed_reason = reason


## Returns the first common/uncommon ItemDefinition for the retro_games store.
func _get_basic_item() -> ItemDefinition:
	if not GameManager.data_loader:
		return null
	var items: Array[ItemDefinition] = (
		GameManager.data_loader.get_items_by_store("retro_games")
	)
	for item: ItemDefinition in items:
		if item.rarity in ["common", "uncommon"]:
			return item
	return null


## Counts items in inventory whose definition matches def_id for the given store.
func _count_stock_by_def(store_id: StringName, def_id: StringName) -> int:
	var all_stock: Array[ItemInstance] = _inventory_system.get_stock(store_id)
	var count: int = 0
	for item: ItemInstance in all_stock:
		if item.definition and item.definition.id == String(def_id):
			count += 1
	return count


# ── Happy path: submit → delivery timer → restock ────────────────────────────


func test_lifecycle_stock_increases_by_order_quantity() -> void:
	var item: ItemDefinition = _get_basic_item()
	if not item:
		pending("DataLoader or basic-tier retro_games items not available")
		return
	var stock_before: int = _count_stock_by_def(STORE_ID, StringName(item.id))
	_order_system.place_order(STORE_ID, BASIC_TIER, StringName(item.id), ORDER_QTY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	var stock_after: int = _count_stock_by_def(STORE_ID, StringName(item.id))
	assert_eq(
		stock_after - stock_before,
		ORDER_QTY,
		"InventorySystem stock increased by exactly the ordered quantity"
	)


# ── Happy path: order_delivered signal metadata ───────────────────────────────


func test_lifecycle_order_delivered_emitted_once() -> void:
	var item: ItemDefinition = _get_basic_item()
	if not item:
		pending("DataLoader or basic-tier retro_games items not available")
		return
	_order_system.place_order(STORE_ID, BASIC_TIER, StringName(item.id), ORDER_QTY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	assert_eq(
		_order_delivered_count, 1,
		"order_delivered emitted exactly once for a single order"
	)


func test_lifecycle_order_delivered_store_id_matches() -> void:
	var item: ItemDefinition = _get_basic_item()
	if not item:
		pending("DataLoader or basic-tier retro_games items not available")
		return
	_order_system.place_order(STORE_ID, BASIC_TIER, StringName(item.id), ORDER_QTY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	assert_eq(
		_delivered_store_id, STORE_ID,
		"order_delivered store_id matches the store that placed the order"
	)


func test_lifecycle_order_delivered_quantity_matches() -> void:
	var item: ItemDefinition = _get_basic_item()
	if not item:
		pending("DataLoader or basic-tier retro_games items not available")
		return
	_order_system.place_order(STORE_ID, BASIC_TIER, StringName(item.id), ORDER_QTY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	assert_eq(
		_delivered_items.size(),
		ORDER_QTY,
		"order_delivered items array length matches ordered quantity"
	)


func test_lifecycle_delivered_items_match_ordered_definition() -> void:
	var item: ItemDefinition = _get_basic_item()
	if not item:
		pending("DataLoader or basic-tier retro_games items not available")
		return
	_order_system.place_order(STORE_ID, BASIC_TIER, StringName(item.id), ORDER_QTY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	var matched: Array = [0]
	for inst_id: Variant in _delivered_items:
		var inst: ItemInstance = _inventory_system.get_item(str(inst_id))
		if inst and inst.definition and inst.definition.id == item.id:
			matched[0] += 1
	assert_eq(
		matched[0],
		ORDER_QTY,
		"All items in order_delivered resolve to the ordered item definition"
	)


# ── Happy path: toast_requested after delivery ────────────────────────────────


func test_lifecycle_toast_requested_emitted_after_delivery() -> void:
	var item: ItemDefinition = _get_basic_item()
	if not item:
		pending("DataLoader or basic-tier retro_games items not available")
		return
	_order_system.place_order(STORE_ID, BASIC_TIER, StringName(item.id), ORDER_QTY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	assert_false(
		_toast_message.is_empty(),
		"toast_requested emitted with non-empty message after delivery"
	)


func test_lifecycle_toast_category_is_system() -> void:
	var item: ItemDefinition = _get_basic_item()
	if not item:
		pending("DataLoader or basic-tier retro_games items not available")
		return
	_order_system.place_order(STORE_ID, BASIC_TIER, StringName(item.id), ORDER_QTY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	assert_eq(
		_toast_category,
		&"system",
		"toast_requested uses category 'system' for order deliveries"
	)


# ── Rejection: insufficient funds ────────────────────────────────────────────


func test_rejection_insufficient_funds_returns_false() -> void:
	var item: ItemDefinition = _get_basic_item()
	if not item:
		pending("DataLoader or basic-tier retro_games items not available")
		return
	_economy_system.load_save_data({"current_cash": 0.0})
	var result: bool = _order_system.place_order(
		STORE_ID, BASIC_TIER, StringName(item.id), 1
	)
	assert_false(result, "place_order returns false when player cash is insufficient")


func test_rejection_insufficient_funds_emits_order_failed() -> void:
	var item: ItemDefinition = _get_basic_item()
	if not item:
		pending("DataLoader or basic-tier retro_games items not available")
		return
	_economy_system.load_save_data({"current_cash": 0.0})
	_order_system.place_order(STORE_ID, BASIC_TIER, StringName(item.id), 1)
	assert_eq(
		_order_failed_reason,
		"Insufficient funds",
		"order_failed emitted with 'Insufficient funds' message"
	)


func test_rejection_insufficient_funds_no_pending_order() -> void:
	var item: ItemDefinition = _get_basic_item()
	if not item:
		pending("DataLoader or basic-tier retro_games items not available")
		return
	_economy_system.load_save_data({"current_cash": 0.0})
	_order_system.place_order(STORE_ID, BASIC_TIER, StringName(item.id), 1)
	assert_eq(
		_order_system.get_pending_order_count(),
		0,
		"No pending order created when funds are insufficient"
	)


func test_rejection_insufficient_funds_order_delivered_never_emitted() -> void:
	var item: ItemDefinition = _get_basic_item()
	if not item:
		pending("DataLoader or basic-tier retro_games items not available")
		return
	_economy_system.load_save_data({"current_cash": 0.0})
	_order_system.place_order(STORE_ID, BASIC_TIER, StringName(item.id), 1)
	for _i: int in range(BASIC_DELIVERY_DAYS + 2):
		_time_system.advance_to_next_day()
	assert_eq(
		_order_delivered_count,
		0,
		"order_delivered never emitted when order was rejected for insufficient funds"
	)


func test_rejection_insufficient_funds_balance_unchanged() -> void:
	var item: ItemDefinition = _get_basic_item()
	if not item:
		pending("DataLoader or basic-tier retro_games items not available")
		return
	_economy_system.load_save_data({"current_cash": 0.0})
	var cash_before: float = _economy_system.get_cash()
	_order_system.place_order(STORE_ID, BASIC_TIER, StringName(item.id), 1)
	assert_eq(
		_economy_system.get_cash(),
		cash_before,
		"EconomySystem balance unchanged after rejected order"
	)


# ── Duplicate order guard ─────────────────────────────────────────────────────


func test_duplicate_order_second_call_returns_false() -> void:
	var item: ItemDefinition = _get_basic_item()
	if not item:
		pending("DataLoader or basic-tier retro_games items not available")
		return
	var first: bool = _order_system.place_order(
		STORE_ID, BASIC_TIER, StringName(item.id), 2
	)
	var second: bool = _order_system.place_order(
		STORE_ID, BASIC_TIER, StringName(item.id), 2
	)
	assert_true(first, "First order for the item should succeed")
	assert_false(second, "Second order for the same pending item should be rejected")


func test_duplicate_order_does_not_create_second_entry() -> void:
	var item: ItemDefinition = _get_basic_item()
	if not item:
		pending("DataLoader or basic-tier retro_games items not available")
		return
	_order_system.place_order(STORE_ID, BASIC_TIER, StringName(item.id), 2)
	_order_system.place_order(STORE_ID, BASIC_TIER, StringName(item.id), 2)
	assert_eq(
		_order_system.get_pending_order_count(),
		1,
		"Duplicate order attempt does not create a second pending entry"
	)


func test_duplicate_order_emits_order_failed() -> void:
	var item: ItemDefinition = _get_basic_item()
	if not item:
		pending("DataLoader or basic-tier retro_games items not available")
		return
	_order_system.place_order(STORE_ID, BASIC_TIER, StringName(item.id), 2)
	_order_system.place_order(STORE_ID, BASIC_TIER, StringName(item.id), 2)
	assert_false(
		_order_failed_reason.is_empty(),
		"order_failed emitted when a duplicate order is attempted"
	)


func test_duplicate_guard_does_not_block_different_items() -> void:
	var items: Array[ItemDefinition] = []
	if not GameManager.data_loader:
		pending("DataLoader not available")
		return
	for item: ItemDefinition in GameManager.data_loader.get_items_by_store("retro_games"):
		if item.rarity in ["common", "uncommon"]:
			items.append(item)
		if items.size() >= 2:
			break
	if items.size() < 2:
		pending("Need at least 2 distinct basic-tier retro_games items")
		return
	var first: bool = _order_system.place_order(
		STORE_ID, BASIC_TIER, StringName(items[0].id), 1
	)
	var second: bool = _order_system.place_order(
		STORE_ID, BASIC_TIER, StringName(items[1].id), 1
	)
	assert_true(first, "First order for item A should succeed")
	assert_true(second, "Order for a different item B should also succeed")
	assert_eq(
		_order_system.get_pending_order_count(),
		2,
		"Two orders for different items both accepted"
	)
