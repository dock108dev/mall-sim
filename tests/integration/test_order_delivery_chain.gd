## Integration test: OrderSystem delivery chain — order placed → days advance →
## order_delivered fired → InventorySystem stock updated.
extends GutTest

## Common-rarity item from retro_games (base_price 25.0, rarity "common").
const STORE_ID: StringName = &"retro_games"
const ITEM_ID: StringName = &"retro_plumber_world_ss_loose"
const STARTING_CASH: float = 1000.0
const ORDER_QUANTITY: int = 3
const BASIC_TIER: OrderSystem.SupplierTier = OrderSystem.SupplierTier.BASIC
## BASIC tier delivers in 1 day per TIER_CONFIG.
const BASIC_DELIVERY_DAYS: int = 1
## BASIC tier daily limit per TIER_CONFIG.
const BASIC_DAILY_LIMIT: float = 500.0

var _order_system: OrderSystem
var _inventory_system: InventorySystem
var _economy_system: EconomySystem
var _time_system: TimeSystem
var _data_loader: DataLoader

var _saved_store_id: StringName
var _saved_data_loader: DataLoader

var _delivered_signals: Array[Dictionary] = []
var _failed_reasons: Array[String] = []


func before_each() -> void:
	_saved_store_id = GameManager.current_store_id
	_saved_data_loader = GameManager.data_loader
	_delivered_signals = []
	_failed_reasons = []

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_data_loader.load_all_content()

	GameManager.data_loader = _data_loader
	GameManager.current_store_id = STORE_ID

	_inventory_system = InventorySystem.new()
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(_data_loader)

	_economy_system = EconomySystem.new()
	add_child_autofree(_economy_system)
	_economy_system.initialize(STARTING_CASH)

	_time_system = TimeSystem.new()
	add_child_autofree(_time_system)
	_time_system.initialize()
	## Sync to GameManager so delivery_day arithmetic is consistent regardless
	## of how many day advances previous tests may have triggered.
	_time_system.current_day = GameManager.current_day

	_order_system = OrderSystem.new()
	add_child_autofree(_order_system)
	_order_system.initialize(_inventory_system, null, null)

	EventBus.order_delivered.connect(_on_order_delivered)
	EventBus.order_failed.connect(_on_order_failed)


func after_each() -> void:
	if EventBus.order_delivered.is_connected(_on_order_delivered):
		EventBus.order_delivered.disconnect(_on_order_delivered)
	if EventBus.order_failed.is_connected(_on_order_failed):
		EventBus.order_failed.disconnect(_on_order_failed)
	GameManager.current_store_id = _saved_store_id
	GameManager.data_loader = _saved_data_loader


func _on_order_delivered(store_id: StringName, items: Array) -> void:
	_delivered_signals.append({"store_id": store_id, "items": items.duplicate()})


func _on_order_failed(reason: String) -> void:
	_failed_reasons.append(reason)


## Returns the number of items in inventory matching a specific definition ID.
func _count_stock_by_def(store_id: StringName, def_id: StringName) -> int:
	var all_stock: Array[ItemInstance] = _inventory_system.get_stock(store_id)
	var count: Array = [0]
	for item: ItemInstance in all_stock:
		if item.definition and item.definition.id == String(def_id):
			count[0] += 1
	return count


## Returns the expected total order cost from TIER_CONFIG and item base price.
func _expected_total_cost(quantity: int) -> float:
	var item_def: ItemDefinition = _data_loader.get_item(String(ITEM_ID))
	if not item_def:
		return 0.0
	return _order_system.get_order_cost(item_def, BASIC_TIER) * quantity


# ── Scenario A: Standard delivery chain ───────────────────────────────────────


func test_scenario_a_place_order_returns_true() -> void:
	var success: bool = _order_system.place_order(
		STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY
	)
	assert_true(success, "place_order returns true with sufficient cash")


func test_scenario_a_cash_deducted_on_placement() -> void:
	var baseline: float = _economy_system.get_cash()
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)
	var expected: float = _expected_total_cost(ORDER_QUANTITY)
	assert_almost_eq(
		_economy_system.get_cash(),
		baseline - expected,
		0.01,
		"EconomySystem cash reduced by order cost immediately on placement"
	)


func test_scenario_a_stock_empty_before_day_advances() -> void:
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)
	assert_eq(
		_count_stock_by_def(STORE_ID, ITEM_ID), 0,
		"No stock present while order is still in transit"
	)


func test_scenario_a_order_delivered_fires_after_delivery_days() -> void:
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	assert_eq(
		_delivered_signals.size(), 1,
		"order_delivered fires exactly once after delivery days elapse"
	)
	assert_eq(
		_delivered_signals[0]["store_id"], STORE_ID,
		"order_delivered carries the correct store_id"
	)
	assert_eq(
		(_delivered_signals[0]["items"] as Array).size(), ORDER_QUANTITY,
		"order_delivered carries the correct number of item instance IDs"
	)


func test_scenario_a_inventory_stock_matches_quantity_after_delivery() -> void:
	assert_eq(_count_stock_by_def(STORE_ID, ITEM_ID), 0, "Stock starts at zero")

	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()

	assert_eq(
		_count_stock_by_def(STORE_ID, ITEM_ID), ORDER_QUANTITY,
		"InventorySystem stock matches the ordered quantity after delivery"
	)


func test_scenario_a_pending_orders_cleared_after_delivery() -> void:
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)
	assert_eq(
		_order_system.get_pending_order_count(), 1,
		"One pending order registered before delivery"
	)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	assert_eq(
		_order_system.get_pending_order_count(), 0,
		"No pending orders remain after delivery days elapse"
	)


# ── Scenario B: Insufficient funds guard ──────────────────────────────────────


func test_scenario_b_order_rejected_with_zero_cash() -> void:
	var cash: float = _economy_system.get_cash()
	_economy_system.deduct_cash(cash, "test: drain all cash")

	var success: bool = _order_system.place_order(
		STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY
	)
	assert_false(success, "place_order returns false with zero cash")


func test_scenario_b_order_failed_signal_emitted() -> void:
	var cash: float = _economy_system.get_cash()
	_economy_system.deduct_cash(cash, "test: drain all cash")
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)

	assert_eq(
		_failed_reasons.size(), 1,
		"order_failed signal emitted once on rejection"
	)


func test_scenario_b_no_pending_order_created_on_rejection() -> void:
	var cash: float = _economy_system.get_cash()
	_economy_system.deduct_cash(cash, "test: drain all cash")
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)

	assert_eq(
		_order_system.get_pending_order_count(), 0,
		"No delivery timer created when order is rejected for insufficient funds"
	)


func test_scenario_b_inventory_unchanged_after_failed_order() -> void:
	var cash: float = _economy_system.get_cash()
	_economy_system.deduct_cash(cash, "test: drain all cash")
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)

	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()

	assert_eq(
		_count_stock_by_def(STORE_ID, ITEM_ID), 0,
		"Inventory remains empty after a rejected order and day advance"
	)


# ── Scenario C: Daily spending limit guard ────────────────────────────────────
## The BASIC tier enforces a $500 daily cap per TIER_CONFIG.
## A second in-flight order for the same item is rejected when the combined
## cost exceeds that cap — this is OrderSystem's per-day order limit.


func test_scenario_c_first_large_order_succeeds_within_daily_limit() -> void:
	## 15 × 31.25 = 468.75 which is within the $500 BASIC daily limit.
	var success: bool = _order_system.place_order(
		STORE_ID, BASIC_TIER, ITEM_ID, 15
	)
	assert_true(success, "First order succeeds when total is within the daily limit")


func test_scenario_c_second_order_rejected_when_daily_limit_exceeded() -> void:
	## First: 15 × 31.25 = 468.75; second: 468.75 more → 937.5 > 500 → rejected.
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, 15)
	_failed_reasons.clear()

	var success: bool = _order_system.place_order(
		STORE_ID, BASIC_TIER, ITEM_ID, 15
	)
	assert_false(
		success,
		"Second in-flight order rejected when combined cost exceeds daily limit"
	)
	assert_eq(
		_failed_reasons.size(), 1,
		"order_failed emitted for the rejected duplicate order"
	)


func test_scenario_c_only_first_order_in_pending_queue() -> void:
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, 15)
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, 15)

	assert_eq(
		_order_system.get_pending_order_count(), 1,
		"Only the first order is queued; second rejected order has no delivery timer"
	)


func test_scenario_c_daily_limit_resets_on_next_day() -> void:
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, 15)
	## Advance one day — delivers the first order and resets daily spending.
	_time_system.advance_to_next_day()
	_delivered_signals.clear()
	_failed_reasons.clear()

	## After the reset a fresh 15-item order should be accepted again.
	var success: bool = _order_system.place_order(
		STORE_ID, BASIC_TIER, ITEM_ID, 15
	)
	assert_true(
		success,
		"Daily spending limit resets at day start, allowing another large order"
	)
