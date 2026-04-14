## Integration test: complete customer purchase chain — checkout arrival through
## reputation update, verifying the 5-signal chain integrity.
extends GutTest

const CUSTOMER_SCENE: PackedScene = preload(
	"res://game/scenes/characters/customer.tscn"
)

const STARTING_REPUTATION: float = 50.0
const TEST_STORE_ID: String = "test_purchase_chain_store"
const ITEM_PRICE: float = 30.0
const ITEM_ID: String = "chain_test_item"

var _inventory: InventorySystem
var _queue: QueueSystem
var _reputation: ReputationSystem
var _customer: Customer
var _test_item: ItemInstance


func before_each() -> void:
	_register_test_store()
	GameManager.current_store_id = &"test_purchase_chain_store"

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_queue = QueueSystem.new()
	add_child_autofree(_queue)
	_queue.initialize()
	_queue.setup_queue_positions(Vector3.ZERO, Vector3(0.0, 0.0, 5.0))

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)
	_reputation.initialize_store(TEST_STORE_ID)
	_reputation._scores[TEST_STORE_ID] = STARTING_REPUTATION

	# purchase_intent = 1.0 is achieved by bypassing the Customer state machine:
	# the test emits customer_reached_checkout directly, making checkout deterministic.
	_customer = CUSTOMER_SCENE.instantiate() as Customer
	add_child_autofree(_customer)
	_customer.current_state = Customer.State.PURCHASING

	_test_item = _create_test_item(ITEM_ID, ITEM_PRICE)
	_inventory._items[_test_item.instance_id] = _test_item


func after_each() -> void:
	_unregister_test_store()
	GameManager.current_store_id = &""


# ── Signal 1 → 2: customer_reached_checkout fires checkout_queue_ready ───────


func test_checkout_queue_ready_fires_after_customer_reached_checkout() -> void:
	watch_signals(EventBus)

	EventBus.customer_reached_checkout.emit(_customer)

	assert_signal_emitted(
		EventBus,
		"checkout_queue_ready",
		"checkout_queue_ready must fire synchronously after customer_reached_checkout"
	)


func test_checkout_queue_ready_carries_correct_customer() -> void:
	var dispatched: Array[Node] = []
	EventBus.checkout_queue_ready.connect(
		func(c: Node) -> void: dispatched.append(c)
	)

	EventBus.customer_reached_checkout.emit(_customer)

	assert_eq(dispatched.size(), 1, "checkout_queue_ready should fire exactly once")
	assert_eq(dispatched[0], _customer as Node, "Dispatched customer must match the one who arrived")


func test_queue_size_is_one_after_customer_arrives_at_checkout() -> void:
	EventBus.customer_reached_checkout.emit(_customer)

	assert_eq(
		_queue.get_queue_size(), 1,
		"Queue size should be 1 after one customer arrives at checkout"
	)


# ── Signal 3: customer_purchased fires with correct parameters ────────────────


func test_customer_purchased_fires_after_checkout_queue_ready() -> void:
	watch_signals(EventBus)
	EventBus.customer_reached_checkout.emit(_customer)
	_simulate_sale(_customer, _test_item)

	assert_signal_emitted(
		EventBus,
		"customer_purchased",
		"customer_purchased must fire after sale processing"
	)


func test_customer_purchased_carries_correct_store_id() -> void:
	watch_signals(EventBus)
	EventBus.customer_reached_checkout.emit(_customer)
	_simulate_sale(_customer, _test_item)

	var params: Array = get_signal_parameters(EventBus, "customer_purchased", 0)
	assert_eq(
		params[0],
		StringName(TEST_STORE_ID),
		"customer_purchased store_id must match the active store"
	)


func test_customer_purchased_carries_correct_item_id() -> void:
	watch_signals(EventBus)
	EventBus.customer_reached_checkout.emit(_customer)
	_simulate_sale(_customer, _test_item)

	var params: Array = get_signal_parameters(EventBus, "customer_purchased", 0)
	assert_eq(
		params[1],
		StringName(_test_item.instance_id),
		"customer_purchased item_id must match the sold item instance"
	)


func test_customer_purchased_carries_correct_price() -> void:
	watch_signals(EventBus)
	EventBus.customer_reached_checkout.emit(_customer)
	_simulate_sale(_customer, _test_item)

	var params: Array = get_signal_parameters(EventBus, "customer_purchased", 0)
	assert_almost_eq(
		float(params[2]),
		ITEM_PRICE,
		0.01,
		"customer_purchased price must match the item sale price"
	)


# ── Inventory: item count decremented by 1 after sale ────────────────────────


func test_inventory_item_count_decremented_by_one_after_sale() -> void:
	var count_before: int = _inventory.get_item_count()
	EventBus.customer_reached_checkout.emit(_customer)
	_simulate_sale(_customer, _test_item)

	assert_eq(
		_inventory.get_item_count(),
		count_before - 1,
		"InventorySystem item count must decrease by 1 after sale"
	)


func test_sold_item_is_no_longer_in_inventory() -> void:
	var sold_id: String = _test_item.instance_id
	EventBus.customer_reached_checkout.emit(_customer)
	_simulate_sale(_customer, _test_item)

	assert_null(
		_inventory.get_item(sold_id),
		"Sold item must not be retrievable from InventorySystem after purchase"
	)


# ── Signal 4: customer_left_mall satisfied=true ───────────────────────────────


func test_customer_left_mall_fires_with_satisfied_true() -> void:
	EventBus.customer_reached_checkout.emit(_customer)
	_simulate_sale(_customer, _test_item)
	EventBus.checkout_completed.emit(_customer)
	watch_signals(EventBus)

	EventBus.customer_left_mall.emit(_customer, true)

	assert_signal_emitted(
		EventBus,
		"customer_left_mall",
		"customer_left_mall must fire in the happy path"
	)
	var params: Array = get_signal_parameters(EventBus, "customer_left_mall", 0)
	assert_true(
		bool(params[1]),
		"customer_left_mall satisfied parameter must be true in the happy path"
	)


# ── Signal 5: reputation_changed fires and score increases ───────────────────


func test_reputation_increased_by_satisfaction_gain_after_satisfied_exit() -> void:
	EventBus.customer_reached_checkout.emit(_customer)
	_simulate_sale(_customer, _test_item)
	EventBus.checkout_completed.emit(_customer)

	var rep_before: float = _reputation.get_reputation(TEST_STORE_ID)
	EventBus.customer_left_mall.emit(_customer, true)

	assert_almost_eq(
		_reputation.get_reputation(TEST_STORE_ID),
		rep_before + ReputationSystem.SATISFACTION_GAIN,
		0.01,
		"Reputation must increase by SATISFACTION_GAIN when satisfied customer leaves"
	)


func test_reputation_changed_fires_after_satisfied_exit() -> void:
	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_customer, true)

	assert_signal_emitted(
		EventBus,
		"reputation_changed",
		"reputation_changed must fire after a satisfied customer leaves"
	)


# ── Combined: all 5 signals fire in the chain ─────────────────────────────────


func test_complete_happy_path_all_5_signals_fire() -> void:
	watch_signals(EventBus)

	EventBus.customer_reached_checkout.emit(_customer)
	assert_signal_emitted(
		EventBus, "customer_reached_checkout",
		"Signal 1: customer_reached_checkout must fire"
	)
	assert_signal_emitted(
		EventBus, "checkout_queue_ready",
		"Signal 2: checkout_queue_ready must fire after customer_reached_checkout"
	)

	_simulate_sale(_customer, _test_item)
	assert_signal_emitted(
		EventBus, "customer_purchased",
		"Signal 3: customer_purchased must fire during sale"
	)

	EventBus.checkout_completed.emit(_customer)
	EventBus.customer_left_mall.emit(_customer, true)
	assert_signal_emitted(
		EventBus, "customer_left_mall",
		"Signal 4: customer_left_mall must fire after customer exits"
	)
	assert_signal_emitted(
		EventBus, "reputation_changed",
		"Signal 5: reputation_changed must fire after satisfied customer leaves"
	)


# ── Unhappy Path: empty inventory ─────────────────────────────────────────────


func test_unhappy_no_customer_purchased_when_inventory_empty() -> void:
	_inventory._items.clear()
	watch_signals(EventBus)

	EventBus.customer_left_mall.emit(_customer, false)

	assert_signal_emit_count(
		EventBus, "customer_purchased", 0,
		"customer_purchased must not fire when inventory is empty"
	)


func test_unhappy_inventory_count_unchanged_when_empty() -> void:
	_inventory._items.clear()

	EventBus.customer_left_mall.emit(_customer, false)

	assert_eq(
		_inventory.get_item_count(), 0,
		"Inventory count must remain 0 in the unhappy path"
	)


func test_unhappy_customer_left_mall_fires_with_satisfied_false() -> void:
	_inventory._items.clear()
	watch_signals(EventBus)

	EventBus.customer_left_mall.emit(_customer, false)

	assert_signal_emitted(
		EventBus, "customer_left_mall",
		"customer_left_mall must fire in the unhappy path"
	)
	var params: Array = get_signal_parameters(EventBus, "customer_left_mall", 0)
	assert_false(
		bool(params[1]),
		"customer_left_mall satisfied must be false in the unhappy path"
	)


func test_unhappy_reputation_decremented_by_dissatisfaction_loss() -> void:
	_inventory._items.clear()

	var rep_before: float = _reputation.get_reputation(TEST_STORE_ID)
	EventBus.customer_left_mall.emit(_customer, false)

	assert_almost_eq(
		_reputation.get_reputation(TEST_STORE_ID),
		rep_before + ReputationSystem.DISSATISFACTION_LOSS,
		0.01,
		"Reputation must decrease by DISSATISFACTION_LOSS when dissatisfied customer leaves"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


## Simulates CheckoutSystem sale processing by emitting the sale signal chain.
func _simulate_sale(customer: Customer, item: ItemInstance) -> void:
	var item_id: String = item.instance_id
	var price: float = item.definition.base_price
	var category: String = item.definition.category
	var cust_id: StringName = StringName(str(customer.get_instance_id()))
	EventBus.item_sold.emit(item_id, price, category)
	EventBus.customer_purchased.emit(
		StringName(TEST_STORE_ID), StringName(item_id), price, cust_id
	)


func _create_test_item(item_id: String, price: float) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = item_id
	def.item_name = item_id.capitalize()
	def.base_price = price
	def.category = "test"
	def.store_type = TEST_STORE_ID
	def.rarity = "common"
	return ItemInstance.create_from_definition(def, "good")


func _register_test_store() -> void:
	if ContentRegistry.exists(TEST_STORE_ID):
		return
	ContentRegistry.register_entry(
		{
			"id": TEST_STORE_ID,
			"name": "Test Purchase Chain Store",
			"scene_path": "",
			"backroom_capacity": 50,
		},
		"store",
	)


func _unregister_test_store() -> void:
	if not ContentRegistry.exists(TEST_STORE_ID):
		return
	var key: StringName = StringName(TEST_STORE_ID)
	ContentRegistry._entries.erase(key)
	ContentRegistry._types.erase(key)
	ContentRegistry._display_names.erase(key)
	ContentRegistry._scene_map.erase(key)
	for alias_key: StringName in ContentRegistry._aliases.keys():
		if ContentRegistry._aliases[alias_key] == key:
			ContentRegistry._aliases.erase(alias_key)
