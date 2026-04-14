## Integration test: order_delivered → InventorySystem restocked → toast_requested emitted.
extends GutTest

## Common-rarity retro games item compatible with BASIC supplier tier.
const STORE_ID: StringName = &"retro_games"
const ITEM_ID: StringName = &"retro_plumber_world_ss_loose"
## Common-rarity sports item used for multi-store delivery scenario.
const STORE_ID_B: StringName = &"sports"
const ITEM_ID_B: StringName = &"sports_duvall_hr_common"
const STARTING_CASH: float = 2000.0
const ORDER_QUANTITY: int = 5
const BASIC_TIER: OrderSystem.SupplierTier = OrderSystem.SupplierTier.BASIC
## BASIC tier delivers in 1 day per TIER_CONFIG.
const BASIC_DELIVERY_DAYS: int = 1

var _order_system: OrderSystem
var _inventory_system: InventorySystem
var _economy_system: EconomySystem
var _time_system: TimeSystem
var _data_loader: DataLoader

var _saved_store_id: StringName
var _saved_data_loader: DataLoader

var _toast_signals: Array[Dictionary] = []
var _delivered_signals: Array[Dictionary] = []


func before_each() -> void:
	_saved_store_id = GameManager.current_store_id
	_saved_data_loader = GameManager.data_loader
	_toast_signals = []
	_delivered_signals = []

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
	_time_system.current_day = GameManager.current_day

	_order_system = OrderSystem.new()
	add_child_autofree(_order_system)
	_order_system.initialize(_inventory_system, null, null)

	EventBus.order_delivered.connect(_on_order_delivered)
	EventBus.toast_requested.connect(_on_toast_requested)


func after_each() -> void:
	if EventBus.order_delivered.is_connected(_on_order_delivered):
		EventBus.order_delivered.disconnect(_on_order_delivered)
	if EventBus.toast_requested.is_connected(_on_toast_requested):
		EventBus.toast_requested.disconnect(_on_toast_requested)
	GameManager.current_store_id = _saved_store_id
	GameManager.data_loader = _saved_data_loader


func _on_order_delivered(store_id: StringName, items: Array) -> void:
	_delivered_signals.append({"store_id": store_id, "items": items.duplicate()})


func _on_toast_requested(message: String, category: StringName, duration: float) -> void:
	_toast_signals.append({"message": message, "category": category, "duration": duration})


## Returns the number of items in inventory matching a specific definition ID for a store.
func _count_stock_by_def(store_id: StringName, def_id: StringName) -> int:
	var all_stock: Array[ItemInstance] = _inventory_system.get_stock(store_id)
	var count: int = 0
	for item: ItemInstance in all_stock:
		if item.definition and item.definition.id == String(def_id):
			count += 1
	return count


# ── Scenario A: Delivery completes restock ────────────────────────────────────


func test_scenario_a_stock_empty_before_delivery_day() -> void:
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)
	assert_eq(
		_count_stock_by_def(STORE_ID, ITEM_ID), 0,
		"No stock present while order is still in transit"
	)


func test_scenario_a_delivery_restocks_inventory() -> void:
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	assert_eq(
		_count_stock_by_def(STORE_ID, ITEM_ID), ORDER_QUANTITY,
		"InventorySystem stock matches ordered quantity after delivery day"
	)


# ── Scenario B: Delivery triggers toast ──────────────────────────────────────


func test_scenario_b_delivery_triggers_toast_exactly_once() -> void:
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	assert_eq(
		_toast_signals.size(), 1,
		"toast_requested emitted exactly once after a single delivery"
	)


func test_scenario_b_toast_category_is_system() -> void:
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	assert_true(
		_toast_signals.size() > 0,
		"At least one toast was emitted"
	)
	assert_eq(
		_toast_signals[0]["category"], &"system",
		"Toast category is 'system'"
	)


# ── Scenario C: Toast message contains item count ─────────────────────────────


func test_scenario_c_toast_message_contains_item_count() -> void:
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, ORDER_QUANTITY)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	assert_true(
		_toast_signals.size() > 0,
		"At least one toast was emitted"
	)
	var message: String = _toast_signals[0]["message"]
	assert_true(
		message.contains(str(ORDER_QUANTITY)),
		"Toast message contains the item count (%d); actual: '%s'" % [ORDER_QUANTITY, message]
	)


# ── Scenario D: Empty delivery does not crash ─────────────────────────────────
## OrderSystem._on_order_delivered short-circuits on an empty items array and
## emits no toast. Triggering order_delivered manually with [] verifies this.


func test_scenario_d_empty_delivery_emits_no_toast() -> void:
	EventBus.order_delivered.emit(STORE_ID, [])
	assert_eq(
		_toast_signals.size(), 0,
		"Empty delivery emits no toast (OrderSystem._on_order_delivered short-circuits)"
	)


func test_scenario_d_empty_delivery_does_not_crash() -> void:
	EventBus.order_delivered.emit(STORE_ID, [])
	assert_true(true, "Empty delivery reached end of test without crashing")


# ── Scenario E: Multiple orders generate separate toasts ──────────────────────


func test_scenario_e_two_deliveries_emit_two_toasts() -> void:
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, 3)
	_order_system.place_order(STORE_ID_B, BASIC_TIER, ITEM_ID_B, 2)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	assert_eq(
		_toast_signals.size(), 2,
		"Two deliveries each emit their own toast_requested"
	)


func test_scenario_e_two_deliveries_restock_both_stores() -> void:
	_order_system.place_order(STORE_ID, BASIC_TIER, ITEM_ID, 3)
	_order_system.place_order(STORE_ID_B, BASIC_TIER, ITEM_ID_B, 2)
	for _i: int in range(BASIC_DELIVERY_DAYS):
		_time_system.advance_to_next_day()
	assert_eq(
		_count_stock_by_def(STORE_ID, ITEM_ID), 3,
		"First store restocked with correct quantity"
	)
	assert_eq(
		_count_stock_by_def(STORE_ID_B, ITEM_ID_B), 2,
		"Second store restocked with correct quantity"
	)
