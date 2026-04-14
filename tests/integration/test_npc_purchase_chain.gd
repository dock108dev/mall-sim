## Integration test: full NPC purchase chain — purchase decision through queue,
## checkout, revenue credit, inventory deduction, and reputation gain.
extends GutTest

const CUSTOMER_SCENE: PackedScene = preload(
	"res://game/scenes/characters/customer.tscn"
)

const TEST_STORE_ID: String = "test_npc_chain_store"
const ITEM_PRICE: float = 25.0
const ITEM_ID: String = "npc_chain_test_item"
const STARTING_CASH: float = 100.0
const STARTING_REPUTATION: float = 50.0

var _economy: EconomySystem
var _inventory: InventorySystem
var _queue: QueueSystem
var _reputation: ReputationSystem
var _customer: Customer
var _test_item: ItemInstance


func before_each() -> void:
	_register_test_store()
	GameManager.current_store_id = &"test_npc_chain_store"

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)

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

	_customer = CUSTOMER_SCENE.instantiate() as Customer
	add_child_autofree(_customer)
	_customer.current_state = Customer.State.PURCHASING

	_test_item = _create_test_item(ITEM_ID, ITEM_PRICE)
	_inventory._items[_test_item.instance_id] = _test_item


func after_each() -> void:
	_unregister_test_store()
	GameManager.current_store_id = &""


# ── Step 1-2: Purchase decision triggers queue enqueue ───────────────────────


func test_customer_reached_checkout_enqueues_customer() -> void:
	EventBus.customer_reached_checkout.emit(_customer)

	assert_eq(
		_queue.get_queue_size(), 1,
		"QueueSystem must have 1 customer after customer_reached_checkout"
	)


# ── Step 3: QueueSystem dispatches checkout_queue_ready ──────────────────────


func test_checkout_queue_ready_fires_on_enqueue() -> void:
	watch_signals(EventBus)

	EventBus.customer_reached_checkout.emit(_customer)

	assert_signal_emitted(
		EventBus,
		"checkout_queue_ready",
		"checkout_queue_ready must fire when customer is enqueued"
	)


func test_checkout_queue_ready_carries_correct_customer() -> void:
	var dispatched: Array[Node] = []
	EventBus.checkout_queue_ready.connect(
		func(c: Node) -> void: dispatched.append(c)
	)

	EventBus.customer_reached_checkout.emit(_customer)

	assert_eq(dispatched.size(), 1, "checkout_queue_ready should fire once")
	assert_eq(
		dispatched[0], _customer as Node,
		"Dispatched customer must match the enqueued customer"
	)


# ── Step 4-5: customer_purchased fires with correct parameters ──────────────


func test_customer_purchased_signal_fires() -> void:
	watch_signals(EventBus)

	_simulate_sale(_customer, _test_item)

	assert_signal_emitted(
		EventBus,
		"customer_purchased",
		"customer_purchased must fire after sale"
	)


func test_customer_purchased_has_correct_store_id() -> void:
	watch_signals(EventBus)
	_simulate_sale(_customer, _test_item)

	var params: Array = get_signal_parameters(EventBus, "customer_purchased", 0)
	assert_eq(
		params[0],
		StringName(TEST_STORE_ID),
		"customer_purchased store_id must match active store"
	)


func test_customer_purchased_has_correct_item_id() -> void:
	watch_signals(EventBus)
	_simulate_sale(_customer, _test_item)

	var params: Array = get_signal_parameters(EventBus, "customer_purchased", 0)
	assert_eq(
		params[1],
		StringName(_test_item.instance_id),
		"customer_purchased item_id must match the sold item"
	)


func test_customer_purchased_has_correct_price() -> void:
	watch_signals(EventBus)
	_simulate_sale(_customer, _test_item)

	var params: Array = get_signal_parameters(EventBus, "customer_purchased", 0)
	assert_almost_eq(
		float(params[2]),
		ITEM_PRICE,
		0.01,
		"customer_purchased price must match the item sale price"
	)


# ── Step 6: EconomySystem revenue increases by item price ────────────────────


func test_economy_revenue_increases_by_item_price() -> void:
	var cash_before: float = _economy.get_cash()
	_simulate_sale(_customer, _test_item)

	assert_almost_eq(
		_economy.get_cash(),
		cash_before + ITEM_PRICE,
		0.01,
		"EconomySystem cash must increase by the item price after sale"
	)


func test_transaction_completed_signal_fires() -> void:
	watch_signals(EventBus)
	_simulate_sale(_customer, _test_item)

	assert_signal_emitted(
		EventBus,
		"transaction_completed",
		"transaction_completed must fire when revenue is credited"
	)


# ── Step 7: InventorySystem stock decreases by 1 ────────────────────────────


func test_inventory_count_decreases_by_one() -> void:
	var count_before: int = _inventory.get_item_count()
	_simulate_sale(_customer, _test_item)

	assert_eq(
		_inventory.get_item_count(),
		count_before - 1,
		"Inventory count must decrease by 1 after sale"
	)


func test_sold_item_removed_from_inventory() -> void:
	var sold_id: String = _test_item.instance_id
	_simulate_sale(_customer, _test_item)

	assert_null(
		_inventory.get_item(sold_id),
		"Sold item must no longer exist in inventory"
	)


# ── Step 8: ReputationSystem score increases for satisfied customer ──────────


func test_reputation_increases_after_satisfied_customer_leaves() -> void:
	var rep_before: float = _reputation.get_reputation(TEST_STORE_ID)
	EventBus.customer_left_mall.emit(_customer, true)

	assert_almost_eq(
		_reputation.get_reputation(TEST_STORE_ID),
		rep_before + ReputationSystemSingleton.SATISFACTION_GAIN,
		0.01,
		"Reputation must increase by SATISFACTION_GAIN for satisfied customer"
	)


func test_reputation_changed_signal_fires_on_satisfied_exit() -> void:
	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_customer, true)

	assert_signal_emitted(
		EventBus,
		"reputation_changed",
		"reputation_changed must fire when satisfied customer leaves"
	)


# ── Full chain: all signals fire in sequence ─────────────────────────────────


func test_complete_chain_all_signals_fire() -> void:
	watch_signals(EventBus)

	EventBus.customer_reached_checkout.emit(_customer)
	assert_signal_emitted(
		EventBus, "customer_reached_checkout",
		"Signal 1: customer_reached_checkout must fire"
	)
	assert_signal_emitted(
		EventBus, "checkout_queue_ready",
		"Signal 2: checkout_queue_ready must fire after enqueue"
	)

	_simulate_sale(_customer, _test_item)
	assert_signal_emitted(
		EventBus, "customer_purchased",
		"Signal 3: customer_purchased must fire during sale"
	)
	assert_signal_emitted(
		EventBus, "transaction_completed",
		"Signal 4: transaction_completed must fire from economy credit"
	)

	EventBus.customer_left_mall.emit(_customer, true)
	assert_signal_emitted(
		EventBus, "customer_left_mall",
		"Signal 5: customer_left_mall must fire after customer exits"
	)
	assert_signal_emitted(
		EventBus, "reputation_changed",
		"Signal 6: reputation_changed must fire after satisfied exit"
	)


func test_complete_chain_economy_and_inventory_consistent() -> void:
	var cash_before: float = _economy.get_cash()
	var count_before: int = _inventory.get_item_count()
	var rep_before: float = _reputation.get_reputation(TEST_STORE_ID)

	EventBus.customer_reached_checkout.emit(_customer)
	_simulate_sale(_customer, _test_item)
	EventBus.customer_left_mall.emit(_customer, true)

	assert_almost_eq(
		_economy.get_cash(),
		cash_before + ITEM_PRICE,
		0.01,
		"Cash must increase by item price after full chain"
	)
	assert_eq(
		_inventory.get_item_count(),
		count_before - 1,
		"Inventory must decrease by 1 after full chain"
	)
	assert_true(
		_reputation.get_reputation(TEST_STORE_ID) > rep_before,
		"Reputation must increase after satisfied purchase chain"
	)


# ── Each signal fires exactly once ──────────────────────────────────────────


func test_customer_purchased_fires_exactly_once() -> void:
	watch_signals(EventBus)
	_simulate_sale(_customer, _test_item)

	assert_signal_emit_count(
		EventBus, "customer_purchased", 1,
		"customer_purchased must fire exactly once per sale"
	)


func test_checkout_queue_ready_fires_exactly_once() -> void:
	watch_signals(EventBus)
	EventBus.customer_reached_checkout.emit(_customer)

	assert_signal_emit_count(
		EventBus, "checkout_queue_ready", 1,
		"checkout_queue_ready must fire exactly once per enqueue"
	)


func test_reputation_changed_fires_exactly_once_on_exit() -> void:
	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_customer, true)

	assert_signal_emit_count(
		EventBus, "reputation_changed", 1,
		"reputation_changed must fire exactly once per customer exit"
	)


# ── Helpers ──────────────────────────────────────────────────────────────────


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
			"name": "Test NPC Chain Store",
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
