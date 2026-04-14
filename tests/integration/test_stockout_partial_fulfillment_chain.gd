## Integration test: Hard mode stockout chain — DifficultySystemSingleton.get_modifier →
## OrderSystem partial delivery → InventorySystem stock → order_stockout signal.
extends GutTest


const STORE_ID: StringName = &"retro_games"
const ITEM_ID: StringName = &"retro_plumber_world_ss_loose"
const STARTING_CASH: float = 2000.0
const ORDER_QUANTITY: int = 10
const BASIC_TIER: OrderSystem.SupplierTier = OrderSystem.SupplierTier.BASIC
const BASIC_DELIVERY_DAYS: int = 1

var _order_system: OrderSystem
var _inventory_system: InventorySystem
var _economy_system: EconomySystem
var _time_system: TimeSystem

var _saved_store_id: StringName
var _saved_data_loader: DataLoader
var _saved_tier: StringName

var _stockout_item_ids: Array[StringName] = []
var _stockout_requested: Array[int] = []
var _stockout_fulfilled: Array[int] = []
var _delivered_signals: Array[Dictionary] = []
var _refund_amounts: Array[float] = []


func before_each() -> void:
	_saved_store_id = GameManager.current_store_id
	_saved_data_loader = GameManager.data_loader
	_saved_tier = DifficultySystemSingleton.get_current_tier_id()

	_stockout_item_ids = []
	_stockout_requested = []
	_stockout_fulfilled = []
	_delivered_signals = []
	_refund_amounts = []

	var data_loader: DataLoader = DataLoader.new()
	add_child_autofree(data_loader)
	data_loader.load_all_content()
	GameManager.data_loader = data_loader
	GameManager.current_store_id = STORE_ID

	_inventory_system = InventorySystem.new()
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(data_loader)

	_economy_system = EconomySystem.new()
	add_child_autofree(_economy_system)
	_economy_system.initialize(STARTING_CASH)

	_time_system = TimeSystem.new()
	add_child_autofree(_time_system)
	_time_system.initialize()
	_time_system.current_day = GameManager.current_day

	_order_system = OrderSystem.new()
	add_child_autofree(_order_system)
	_order_system.initialize(_inventory_system, null, null)

	EventBus.order_stockout.connect(_on_order_stockout)
	EventBus.order_delivered.connect(_on_order_delivered)
	EventBus.order_refund_issued.connect(_on_order_refund_issued)


func after_each() -> void:
	if EventBus.order_stockout.is_connected(_on_order_stockout):
		EventBus.order_stockout.disconnect(_on_order_stockout)
	if EventBus.order_delivered.is_connected(_on_order_delivered):
		EventBus.order_delivered.disconnect(_on_order_delivered)
	if EventBus.order_refund_issued.is_connected(_on_order_refund_issued):
		EventBus.order_refund_issued.disconnect(_on_order_refund_issued)

	DifficultySystemSingleton.set_tier(_saved_tier)
	GameManager.current_store_id = _saved_store_id
	GameManager.data_loader = _saved_data_loader


func _on_order_stockout(
	item_id: StringName, requested: int, fulfilled: int
) -> void:
	_stockout_item_ids.append(item_id)
	_stockout_requested.append(requested)
	_stockout_fulfilled.append(fulfilled)


func _on_order_delivered(store_id: StringName, items: Array) -> void:
	_delivered_signals.append({"store_id": store_id, "items": items.duplicate()})


func _on_order_refund_issued(amount: float, _reason: String) -> void:
	_refund_amounts.append(amount)


func _count_stock_by_def(store_id: StringName, def_id: StringName) -> int:
	var all_stock: Array[ItemInstance] = _inventory_system.get_stock(store_id)
	var count: int = 0
	for item: ItemInstance in all_stock:
		if item.definition and item.definition.id == String(def_id):
			count += 1
	return count


func _place_order_and_force_stockout() -> void:
	_order_system._force_stockout_for_test = true
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	_order_system._force_stockout_for_test = false


# ── Scenario A: Hard mode stockout chain ──────────────────────────────────────


func test_hard_mode_stockout_probability_is_positive() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	var prob: float = DifficultySystemSingleton.get_modifier(&"supplier_stockout_probability")
	assert_gt(
		prob, 0.0,
		"Hard difficulty must have a stockout probability greater than 0.0"
	)


func test_hard_mode_stockout_signal_fires() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	_place_order_and_force_stockout()
	assert_eq(
		_stockout_item_ids.size(), 1,
		"order_stockout should fire exactly once on a forced stockout"
	)


func test_hard_mode_stockout_signal_carries_correct_item_id() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	_place_order_and_force_stockout()
	if _stockout_item_ids.is_empty():
		pending("Stockout signal not emitted — stockout may not have fired")
		return
	assert_eq(
		_stockout_item_ids[0], ITEM_ID,
		"order_stockout item_id should match the ordered item"
	)


func test_hard_mode_stockout_requested_equals_ordered_quantity() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	_place_order_and_force_stockout()
	if _stockout_requested.is_empty():
		pending("Stockout signal not emitted")
		return
	assert_eq(
		_stockout_requested[0], ORDER_QUANTITY,
		"order_stockout requested quantity must equal the original order quantity"
	)


func test_hard_mode_stockout_fulfilled_less_than_requested() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	_place_order_and_force_stockout()
	if _stockout_fulfilled.is_empty():
		pending("Stockout signal not emitted")
		return
	assert_lt(
		_stockout_fulfilled[0], _stockout_requested[0],
		"Fulfilled quantity must be less than requested on a stockout"
	)


func test_hard_mode_stockout_fulfilled_within_40_to_75_percent() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	_place_order_and_force_stockout()
	if _stockout_fulfilled.is_empty():
		pending("Stockout signal not emitted")
		return
	var fulfilled: int = _stockout_fulfilled[0]
	var min_fill: int = ceili(ORDER_QUANTITY * 0.40)
	var max_fill: int = ceili(ORDER_QUANTITY * 0.75)
	assert_gte(
		fulfilled, min_fill,
		"Fulfilled must be >= ceil(40%% of ordered quantity)"
	)
	assert_lte(
		fulfilled, max_fill,
		"Fulfilled must be <= ceil(75%% of ordered quantity)"
	)


func test_hard_mode_order_delivered_fires_after_stockout() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	_place_order_and_force_stockout()
	assert_eq(
		_delivered_signals.size(), 1,
		"order_delivered must still fire when a partial stockout occurs"
	)


func test_hard_mode_delivery_items_count_matches_fulfilled_quantity() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	_place_order_and_force_stockout()
	if _stockout_fulfilled.is_empty() or _delivered_signals.is_empty():
		pending("Stockout or delivery signal not emitted")
		return
	var delivered_count: int = (_delivered_signals[0]["items"] as Array).size()
	assert_eq(
		delivered_count, _stockout_fulfilled[0],
		"Items delivered must equal the fulfilled quantity from order_stockout"
	)


func test_hard_mode_inventory_stock_matches_fulfilled_quantity() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	_place_order_and_force_stockout()
	if _stockout_fulfilled.is_empty():
		pending("Stockout signal not emitted")
		return
	var stock_count: int = _count_stock_by_def(STORE_ID, ITEM_ID)
	assert_eq(
		stock_count, _stockout_fulfilled[0],
		"InventorySystem stock count must match the partial fulfillment quantity"
	)


func test_hard_mode_inventory_stock_less_than_ordered() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	_place_order_and_force_stockout()
	var stock_count: int = _count_stock_by_def(STORE_ID, ITEM_ID)
	assert_lt(
		stock_count, ORDER_QUANTITY,
		"Inventory stock after a stockout must be less than the originally ordered quantity"
	)


func test_hard_mode_refund_issued_for_undelivered_units() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	_place_order_and_force_stockout()
	assert_eq(
		_refund_amounts.size(), 1,
		"order_refund_issued must fire once for the undelivered units"
	)
	assert_gt(
		_refund_amounts[0], 0.0,
		"Refund amount must be positive"
	)


func test_hard_mode_pending_orders_cleared_after_stockout_delivery() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	_place_order_and_force_stockout()
	assert_eq(
		_order_system.get_pending_order_count(), 0,
		"Pending order queue must be empty after partial delivery"
	)


# ── Scenario B: Normal mode — full fulfillment, no stockout ───────────────────


func test_normal_mode_stockout_probability_is_low() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	var prob: float = DifficultySystemSingleton.get_modifier(&"supplier_stockout_probability")
	assert_almost_eq(
		prob, 0.05, 0.0001,
		"Normal difficulty stockout probability should be 0.05"
	)


func test_normal_mode_zero_stockout_flag_produces_full_delivery() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	# _force_stockout_for_test is false — delivery is full
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	assert_eq(
		_stockout_item_ids.size(), 0,
		"No order_stockout signal on normal delivery (no force flag)"
	)


func test_normal_mode_full_delivery_stock_matches_order() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	assert_eq(
		_count_stock_by_def(STORE_ID, ITEM_ID), ORDER_QUANTITY,
		"Full delivery must add exactly the ordered quantity to inventory"
	)


func test_normal_mode_no_refund_on_full_delivery() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	assert_eq(
		_refund_amounts.size(), 0,
		"No refund should be issued on a full delivery"
	)


func test_normal_mode_order_delivered_carries_full_item_count() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	assert_eq(
		_delivered_signals.size(), 1,
		"order_delivered fires once on normal full delivery"
	)
	var delivered_count: int = (_delivered_signals[0]["items"] as Array).size()
	assert_eq(
		delivered_count, ORDER_QUANTITY,
		"order_delivered items count equals the full ordered quantity on normal mode"
	)
