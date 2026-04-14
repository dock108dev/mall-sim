## Integration test: bulk order event fires → inventory deducted →
## EconomySystem credits revenue at premium price.
extends GutTest


var _random_event_system: RandomEventSystem
var _inventory_system: InventorySystem
var _economy_system: EconomySystem
var _reputation_system: ReputationSystem
var _saved_store_id: StringName

var _transactions: Array[Dictionary] = []
var _bulk_orders: Array[Dictionary] = []

const STORE_ID: StringName = &"retro_games"
const STARTING_CASH: float = 1000.0


func _make_item_def(
	id: String = "test_bulk_item",
	base_price: float = 10.0
) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.item_name = "Test Bulk Item"
	def.category = "cartridges"
	def.store_type = "retro_games"
	def.base_price = base_price
	def.rarity = "common"
	def.condition_range = PackedStringArray(["good"])
	return def


func _make_shelf_item(
	item_def: ItemDefinition = null
) -> ItemInstance:
	if not item_def:
		item_def = _make_item_def()
	var inst := ItemInstance.create(
		item_def, "good", 0, item_def.base_price
	)
	inst.current_location = "shelf:0"
	return inst


func _put_item_on_shelf(item: ItemInstance) -> void:
	_inventory_system._items[item.instance_id] = item
	_inventory_system._shelf_cache_dirty = true


func _make_bulk_order_def(
	overrides: Dictionary = {}
) -> RandomEventDefinition:
	var d := RandomEventDefinition.new()
	d.id = overrides.get("id", "corporate_bulk_buy")
	d.name = overrides.get("name", "Corporate Bulk Buy")
	d.description = overrides.get("description", "Bulk order test")
	d.effect_type = "bulk_order"
	d.duration_days = overrides.get("duration_days", 1)
	d.severity = overrides.get("severity", "high")
	d.cooldown_days = overrides.get("cooldown_days", 0)
	d.probability_weight = overrides.get("probability_weight", 100.0)
	d.notification_text = overrides.get(
		"notification_text",
		"Corporate Bulk Buy! A corporate buyer placed a large order"
		+ " worth $%.0f!"
	)
	d.resolution_text = ""
	d.toast_message = overrides.get(
		"toast_message", "A corporate buyer just placed a massive"
		+ " bulk order!"
	)
	d.time_window_start = -1
	d.time_window_end = -1
	d.bulk_order_quantity = overrides.get("bulk_order_quantity", 3)
	d.bulk_order_price_multiplier = overrides.get(
		"bulk_order_price_multiplier", 1.2
	)
	return d


func _get_bulk_def_from_json() -> RandomEventDefinition:
	var data_loader := DataLoader.new()
	data_loader.load_all_content()
	var all_events: Array[RandomEventDefinition] = (
		data_loader.get_all_random_events()
	)
	for ev: RandomEventDefinition in all_events:
		if ev.effect_type == "bulk_order":
			return ev
	return null


func before_each() -> void:
	_saved_store_id = GameManager.current_store_id
	GameManager.current_store_id = STORE_ID

	var data_loader := DataLoader.new()
	data_loader.load_all_content()

	_inventory_system = InventorySystem.new()
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(data_loader)

	_economy_system = EconomySystem.new()
	add_child_autofree(_economy_system)
	_economy_system.initialize(STARTING_CASH)

	_reputation_system = ReputationSystem.new()
	add_child_autofree(_reputation_system)
	_reputation_system.initialize_store("retro_games")

	_random_event_system = RandomEventSystem.new()
	add_child_autofree(_random_event_system)
	_random_event_system._effects = RandomEventEffects.new()
	_random_event_system._effects.initialize(
		_inventory_system, _reputation_system, _economy_system
	)

	_transactions = []
	_bulk_orders = []
	EventBus.transaction_completed.connect(
		_on_transaction_completed
	)
	EventBus.bulk_order_started.connect(_on_bulk_order_started)


func after_each() -> void:
	GameManager.current_store_id = _saved_store_id
	if EventBus.transaction_completed.is_connected(
		_on_transaction_completed
	):
		EventBus.transaction_completed.disconnect(
			_on_transaction_completed
		)
	if EventBus.bulk_order_started.is_connected(
		_on_bulk_order_started
	):
		EventBus.bulk_order_started.disconnect(
			_on_bulk_order_started
		)


func _on_transaction_completed(
	amount: float, success: bool, message: String
) -> void:
	_transactions.append({
		"amount": amount, "success": success, "message": message,
	})


func _on_bulk_order_started(
	item_id: StringName, quantity: int, unit_price: float
) -> void:
	_bulk_orders.append({
		"item_id": item_id,
		"quantity": quantity,
		"unit_price": unit_price,
	})


# --- Scenario: bulk order fires and completes with sufficient stock ---


func test_bulk_order_deducts_correct_quantity_from_inventory() -> void:
	var item_def := _make_item_def("test_item_id", 10.0)
	for i: int in range(5):
		_put_item_on_shelf(_make_shelf_item(item_def))
	assert_eq(
		_inventory_system.get_shelf_items().size(), 5,
		"Setup: 5 items on shelf"
	)

	var def := _make_bulk_order_def()
	_random_event_system._activate_event(def, 1)

	assert_eq(
		_inventory_system.get_shelf_items().size(), 2,
		"Bulk order of 3 leaves 2 items on shelf"
	)


func test_bulk_order_emits_bulk_order_started_signal() -> void:
	var item_def := _make_item_def("test_item_id", 10.0)
	for i: int in range(5):
		_put_item_on_shelf(_make_shelf_item(item_def))

	var def := _make_bulk_order_def()
	_random_event_system._activate_event(def, 1)

	assert_eq(
		_bulk_orders.size(), 1,
		"bulk_order_started fires once"
	)
	assert_eq(
		_bulk_orders[0]["item_id"], &"test_item_id",
		"bulk_order_started carries correct item_id"
	)
	assert_eq(
		_bulk_orders[0]["quantity"], 3,
		"bulk_order_started carries quantity=3"
	)
	var expected_unit: float = snappedf(10.0 * 1.2, 0.01)
	assert_almost_eq(
		float(_bulk_orders[0]["unit_price"]),
		expected_unit,
		0.01,
		"bulk_order_started unit_price = base * 1.2"
	)


func test_bulk_order_credits_correct_revenue() -> void:
	var item_def := _make_item_def("test_item_id", 10.0)
	for i: int in range(5):
		_put_item_on_shelf(_make_shelf_item(item_def))
	var baseline: float = _economy_system.get_cash()

	var def := _make_bulk_order_def()
	_random_event_system._activate_event(def, 1)

	var unit_price: float = snappedf(10.0 * 1.2, 0.01)
	var expected_total: float = unit_price * 3.0
	assert_almost_eq(
		_economy_system.get_cash(),
		baseline + expected_total,
		0.01,
		"Player cash increased by quantity * unit_price"
	)


func test_bulk_order_emits_random_event_triggered() -> void:
	var item_def := _make_item_def("test_item_id", 10.0)
	for i: int in range(5):
		_put_item_on_shelf(_make_shelf_item(item_def))
	watch_signals(EventBus)

	var def := _make_bulk_order_def()
	_random_event_system._activate_event(def, 1)

	assert_signal_emitted(EventBus, "random_event_started")
	assert_signal_emitted(EventBus, "random_event_triggered")

	var params: Array = get_signal_parameters(
		EventBus, "random_event_triggered"
	)
	assert_eq(
		params[0], StringName("corporate_bulk_buy"),
		"Triggered event_id matches"
	)
	var effect: Dictionary = params[2]
	assert_eq(
		effect["type"], "bulk_order",
		"Effect type is bulk_order"
	)
	assert_true(
		effect.has("cash_amount"),
		"Effect contains cash_amount"
	)


func test_bulk_order_is_instant_event() -> void:
	var item_def := _make_item_def("test_item_id", 10.0)
	for i: int in range(5):
		_put_item_on_shelf(_make_shelf_item(item_def))
	watch_signals(EventBus)

	var def := _make_bulk_order_def()
	_random_event_system._activate_event(def, 1)

	assert_false(
		_random_event_system.has_active_event(),
		"Bulk order is instant — no lingering active event"
	)
	assert_signal_emitted(EventBus, "random_event_ended")


func test_bulk_order_uses_json_quantity_and_multiplier() -> void:
	var json_def := _get_bulk_def_from_json()
	if not json_def:
		pending("No bulk_order event found in random_events.json")
		return
	assert_eq(
		json_def.bulk_order_quantity, 3,
		"JSON quantity matches expected value"
	)
	assert_almost_eq(
		json_def.bulk_order_price_multiplier, 1.2, 0.001,
		"JSON price multiplier matches expected value"
	)


# --- Scenario: insufficient stock partially fulfills bulk order ---


func test_insufficient_stock_partial_fulfillment() -> void:
	var item_def := _make_item_def("scarce_item", 10.0)
	_put_item_on_shelf(_make_shelf_item(item_def))
	assert_eq(
		_inventory_system.get_shelf_items().size(), 1,
		"Setup: only 1 item on shelf"
	)
	var baseline: float = _economy_system.get_cash()

	var def := _make_bulk_order_def()
	_random_event_system._activate_event(def, 1)

	assert_eq(
		_inventory_system.get_shelf_items().size(), 0,
		"All available stock consumed"
	)
	var unit_price: float = snappedf(10.0 * 1.2, 0.01)
	assert_almost_eq(
		_economy_system.get_cash(),
		baseline + unit_price,
		0.01,
		"Revenue reflects 1 unit fulfilled, not 3 requested"
	)


func test_insufficient_stock_bulk_order_started_reflects_fulfilled() -> void:
	var item_def := _make_item_def("scarce_item", 10.0)
	_put_item_on_shelf(_make_shelf_item(item_def))

	var def := _make_bulk_order_def()
	_random_event_system._activate_event(def, 1)

	assert_eq(
		_bulk_orders.size(), 1,
		"bulk_order_started fires even for partial fulfillment"
	)
	assert_eq(
		_bulk_orders[0]["quantity"], 1,
		"Reported quantity matches fulfilled amount, not requested"
	)


func test_empty_shelf_bulk_order_no_revenue() -> void:
	var baseline: float = _economy_system.get_cash()

	var def := _make_bulk_order_def()
	_random_event_system._activate_event(def, 1)

	assert_eq(
		_economy_system.get_cash(), baseline,
		"No revenue when shelf is empty"
	)
	assert_eq(
		_bulk_orders.size(), 0,
		"No bulk_order_started signal when nothing to sell"
	)


func test_empty_shelf_no_push_error() -> void:
	watch_signals(EventBus)

	var def := _make_bulk_order_def()
	_random_event_system._activate_event(def, 1)

	assert_signal_emitted(
		EventBus, "random_event_started",
		"Event still starts even with empty shelf"
	)
	assert_false(
		_random_event_system.has_active_event(),
		"Instant event clears active state"
	)
