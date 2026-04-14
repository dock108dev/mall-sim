## Integration test: QueueSystem multi-customer FIFO checkout — 3 customers
## enqueue, served in order, queue drains completely.
extends GutTest

const CUSTOMER_SCENE: PackedScene = preload(
	"res://game/scenes/characters/customer.tscn"
)
const STARTING_CASH: float = 10000.0
const ITEM_PRICE_A: float = 25.0
const ITEM_PRICE_B: float = 50.0
const ITEM_PRICE_C: float = 75.0
const TEST_STORE_ID: String = "test_queue_store"

var _queue: QueueSystem
var _economy: EconomySystem
var _inventory: InventorySystem
var _customers: Array[Customer] = []
var _items: Array[ItemInstance] = []
var _dispatched: Array[Node] = []
var _item_sold_ids: Array[String] = []
var _transaction_count: int = 0
var _queue_advanced_count: int = 0


func before_each() -> void:
	_dispatched = []
	_item_sold_ids = []
	_transaction_count = 0
	_queue_advanced_count = 0
	_customers = []
	_items = []

	_register_test_store()
	GameManager.current_store_id = &"test_queue_store"

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_queue = QueueSystem.new()
	add_child_autofree(_queue)
	_queue.initialize()
	_queue.setup_queue_positions(Vector3.ZERO, Vector3(0, 0, 5))

	var prices: Array[float] = [
		ITEM_PRICE_A, ITEM_PRICE_B, ITEM_PRICE_C,
	]
	var suffixes: Array[String] = ["a", "b", "c"]
	for i: int in range(3):
		var cust: Customer = CUSTOMER_SCENE.instantiate() as Customer
		add_child_autofree(cust)
		var item: ItemInstance = _create_test_item(
			"item_%s" % suffixes[i], prices[i]
		)
		_inventory._items[item.instance_id] = item
		cust._desired_item = item
		_customers.append(cust)
		_items.append(item)

	EventBus.checkout_queue_ready.connect(_on_dispatched)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.transaction_completed.connect(_on_transaction)
	EventBus.queue_advanced.connect(_on_queue_advanced)


func after_each() -> void:
	_safe_disconnect(EventBus.checkout_queue_ready, _on_dispatched)
	_safe_disconnect(EventBus.item_sold, _on_item_sold)
	_safe_disconnect(
		EventBus.transaction_completed, _on_transaction
	)
	_safe_disconnect(
		EventBus.queue_advanced, _on_queue_advanced
	)
	_unregister_test_store()
	GameManager.current_store_id = &""


# ── FIFO ordering ────────────────────────────────────────────────────────────


func test_first_enqueued_customer_dispatched_immediately() -> void:
	_queue.enqueue_customer(_customers[0])

	assert_eq(
		_dispatched.size(), 1,
		"First customer should be dispatched on enqueue"
	)
	assert_eq(
		_dispatched[0], _customers[0] as Node,
		"Dispatched customer should be customer_1"
	)


func test_three_customers_dispatched_in_fifo_order() -> void:
	_enqueue_all()

	assert_eq(
		_dispatched[0], _customers[0] as Node,
		"First dispatch should be customer_1"
	)

	_complete_checkout(_customers[0], _items[0])
	assert_eq(
		_dispatched[1], _customers[1] as Node,
		"Second dispatch should be customer_2"
	)

	_complete_checkout(_customers[1], _items[1])
	assert_eq(
		_dispatched[2], _customers[2] as Node,
		"Third dispatch should be customer_3"
	)


func test_queue_size_after_each_enqueue() -> void:
	_queue.enqueue_customer(_customers[0])
	assert_eq(_queue.get_queue_size(), 1, "Size after first enqueue")

	_queue.enqueue_customer(_customers[1])
	assert_eq(_queue.get_queue_size(), 2, "Size after second enqueue")

	_queue.enqueue_customer(_customers[2])
	assert_eq(_queue.get_queue_size(), 3, "Size after third enqueue")


# ── item_sold signal ordering ────────────────────────────────────────────────


func test_item_sold_fires_per_customer_in_fifo_order() -> void:
	_enqueue_all()

	_complete_checkout(_customers[0], _items[0])
	_complete_checkout(_customers[1], _items[1])
	_complete_checkout(_customers[2], _items[2])

	assert_eq(
		_item_sold_ids.size(), 3,
		"item_sold should fire 3 times"
	)
	assert_eq(
		_item_sold_ids[0], _items[0].instance_id,
		"First item_sold should be customer_1's item"
	)
	assert_eq(
		_item_sold_ids[1], _items[1].instance_id,
		"Second item_sold should be customer_2's item"
	)
	assert_eq(
		_item_sold_ids[2], _items[2].instance_id,
		"Third item_sold should be customer_3's item"
	)


# ── queue_advanced signal ────────────────────────────────────────────────────


func test_queue_advanced_fires_after_each_checkout() -> void:
	_enqueue_all()

	_complete_checkout(_customers[0], _items[0])
	assert_eq(
		_queue_advanced_count, 1,
		"queue_advanced should fire once after first checkout"
	)

	_complete_checkout(_customers[1], _items[1])
	assert_eq(
		_queue_advanced_count, 2,
		"queue_advanced should fire twice after second checkout"
	)

	_complete_checkout(_customers[2], _items[2])
	assert_eq(
		_queue_advanced_count, 3,
		"queue_advanced should fire three times total"
	)


# ── Queue drains ─────────────────────────────────────────────────────────────


func test_queue_drains_to_zero_after_all_checkouts() -> void:
	_enqueue_all()
	assert_eq(_queue.get_queue_size(), 3, "Queue starts at 3")

	_complete_checkout(_customers[0], _items[0])
	assert_eq(_queue.get_queue_size(), 2, "Queue at 2 after first")

	_complete_checkout(_customers[1], _items[1])
	assert_eq(_queue.get_queue_size(), 1, "Queue at 1 after second")

	_complete_checkout(_customers[2], _items[2])
	assert_eq(
		_queue.get_queue_size(), 0,
		"Queue should be empty after all checkouts"
	)


# ── EconomySystem transactions ───────────────────────────────────────────────


func test_economy_receives_three_transaction_completed() -> void:
	_enqueue_all()

	_complete_checkout(_customers[0], _items[0])
	_complete_checkout(_customers[1], _items[1])
	_complete_checkout(_customers[2], _items[2])

	assert_eq(
		_transaction_count, 3,
		"EconomySystem should emit 3 transaction_completed signals"
	)


func test_economy_cash_increases_by_total_sale_amount() -> void:
	_enqueue_all()

	_complete_checkout(_customers[0], _items[0])
	_complete_checkout(_customers[1], _items[1])
	_complete_checkout(_customers[2], _items[2])

	var expected: float = (
		STARTING_CASH + ITEM_PRICE_A + ITEM_PRICE_B + ITEM_PRICE_C
	)
	assert_almost_eq(
		_economy.get_cash(), expected, 0.01,
		"Cash should increase by total of all sale prices"
	)


# ── Capacity enforcement ─────────────────────────────────────────────────────


func test_enqueue_beyond_max_capacity_rejected() -> void:
	_enqueue_all()
	var max_cap: int = RegisterQueue.MAX_QUEUE_SIZE
	assert_eq(
		_queue.get_queue_size(), max_cap,
		"Queue should be at max capacity"
	)

	var extra: Customer = CUSTOMER_SCENE.instantiate() as Customer
	add_child_autofree(extra)

	var accepted: bool = _queue.enqueue_customer(extra)
	assert_false(
		accepted,
		"Enqueue beyond max_capacity should be rejected"
	)
	assert_eq(
		_queue.get_queue_size(), max_cap,
		"Queue size should not exceed max_capacity"
	)


func test_max_capacity_sourced_from_config() -> void:
	assert_gt(
		RegisterQueue.MAX_QUEUE_SIZE, 0,
		"MAX_QUEUE_SIZE should be a positive value from config"
	)
	assert_eq(
		RegisterQueue.MAX_QUEUE_SIZE, 3,
		"MAX_QUEUE_SIZE should match configured queue capacity"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _enqueue_all() -> void:
	for customer: Customer in _customers:
		_queue.enqueue_customer(customer)


func _complete_checkout(
	customer: Customer, item: ItemInstance
) -> void:
	var item_id: String = item.instance_id
	var price: float = item.definition.base_price
	var category: String = item.definition.category
	EventBus.item_sold.emit(item_id, price, category)
	var cust_id: StringName = StringName(
		str(customer.get_instance_id())
	)
	EventBus.customer_purchased.emit(
		&"test_queue_store",
		StringName(item_id),
		price,
		cust_id,
	)
	EventBus.checkout_completed.emit(customer)


func _create_test_item(
	item_id: String, price: float
) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = item_id
	def.item_name = item_id.capitalize()
	def.base_price = price
	def.category = "test"
	def.store_type = TEST_STORE_ID
	def.rarity = "common"
	return ItemInstance.create_from_definition(def, "good")


func _on_dispatched(customer: Node) -> void:
	_dispatched.append(customer)


func _on_item_sold(
	item_id: String, _price: float, _category: String
) -> void:
	_item_sold_ids.append(item_id)


func _on_transaction(
	_amount: float, _success: bool, _message: String
) -> void:
	_transaction_count += 1


func _on_queue_advanced(_queue_size: int) -> void:
	_queue_advanced_count += 1


func _safe_disconnect(sig: Signal, handler: Callable) -> void:
	if sig.is_connected(handler):
		sig.disconnect(handler)


func _register_test_store() -> void:
	if ContentRegistry.exists(TEST_STORE_ID):
		return
	ContentRegistry.register_entry(
		{
			"id": TEST_STORE_ID,
			"name": "Test Queue Store",
			"scene_path": "",
			"backroom_capacity": 50,
		},
		"store",
	)


func _unregister_test_store() -> void:
	if not ContentRegistry.exists(TEST_STORE_ID):
		return
	var key: StringName = &"test_queue_store"
	ContentRegistry._entries.erase(key)
	ContentRegistry._types.erase(key)
	ContentRegistry._display_names.erase(key)
	ContentRegistry._scene_map.erase(key)
	for alias_key: StringName in ContentRegistry._aliases.keys():
		if ContentRegistry._aliases[alias_key] == key:
			ContentRegistry._aliases.erase(alias_key)
