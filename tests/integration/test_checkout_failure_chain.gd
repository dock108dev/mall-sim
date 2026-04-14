## Integration test: checkout failure path — empty inventory causes customer_left_mall(false)
## and a reputation decrease, with no purchase signal and no cash or stock change.
extends GutTest

const CUSTOMER_SCENE: PackedScene = preload(
	"res://game/scenes/characters/customer.tscn"
)
const NPC_CHECKOUT: GDScript = preload("res://game/autoload/checkout_system.gd")

const TEST_STORE_ID: String = "test_failure_chain_store"
const STARTING_REPUTATION: float = 50.0

var _inventory: InventorySystem
var _queue: QueueSystem
var _reputation: ReputationSystem
var _economy: EconomySystem
var _checkout: Node
var _customer: Customer
var _desired_item: ItemInstance


func before_each() -> void:
	_register_test_store()
	GameManager.current_store_id = &"test_failure_chain_store"

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_economy = EconomySystem.new()
	add_child_autofree(_economy)

	_queue = QueueSystem.new()
	add_child_autofree(_queue)
	_queue.initialize()
	_queue.setup_queue_positions(Vector3.ZERO, Vector3(0.0, 0.0, 5.0))

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)
	_reputation.initialize_store(TEST_STORE_ID)
	_reputation._scores[TEST_STORE_ID] = STARTING_REPUTATION

	_checkout = NPC_CHECKOUT.new()
	add_child_autofree(_checkout)
	_checkout.initialize(null, _inventory, null)

	EventBus.checkout_queue_ready.connect(_on_checkout_queue_ready)

	_customer = CUSTOMER_SCENE.instantiate() as Customer
	add_child_autofree(_customer)
	_customer.current_state = Customer.State.PURCHASING

	_desired_item = _create_test_item("failure_test_item", 25.0)
	_customer._desired_item = _desired_item


func after_each() -> void:
	if EventBus.checkout_queue_ready.is_connected(_on_checkout_queue_ready):
		EventBus.checkout_queue_ready.disconnect(_on_checkout_queue_ready)
	_unregister_test_store()
	GameManager.current_store_id = &""


func _on_checkout_queue_ready(customer: Node) -> void:
	_checkout.call("process_transaction", customer as Customer)


# ── customer_purchased must NOT fire ─────────────────────────────────────────


func test_customer_purchased_not_emitted_when_inventory_empty() -> void:
	watch_signals(EventBus)

	EventBus.customer_reached_checkout.emit(_customer)

	assert_signal_emit_count(
		EventBus,
		"customer_purchased",
		0,
		"customer_purchased must not fire when store has zero stock"
	)


# ── customer_left_mall(npc, false) emitted exactly once ──────────────────────


func test_customer_left_mall_fires_on_checkout_failure() -> void:
	watch_signals(EventBus)

	EventBus.customer_reached_checkout.emit(_customer)

	assert_signal_emitted(
		EventBus,
		"customer_left_mall",
		"customer_left_mall must fire when checkout fails due to empty inventory"
	)


func test_customer_left_mall_carries_satisfied_false() -> void:
	watch_signals(EventBus)

	EventBus.customer_reached_checkout.emit(_customer)

	var params: Array = get_signal_parameters(EventBus, "customer_left_mall", 0)
	assert_false(
		bool(params[1]),
		"customer_left_mall satisfied must be false on checkout failure"
	)


func test_customer_left_mall_emitted_exactly_once() -> void:
	watch_signals(EventBus)

	EventBus.customer_reached_checkout.emit(_customer)

	assert_signal_emit_count(
		EventBus,
		"customer_left_mall",
		1,
		"customer_left_mall must fire exactly once on checkout failure"
	)


# ── EconomySystem cash unchanged ─────────────────────────────────────────────


func test_economy_cash_unchanged_after_failed_checkout() -> void:
	var cash_before: float = _economy.get_cash()

	EventBus.customer_reached_checkout.emit(_customer)

	assert_almost_eq(
		_economy.get_cash(),
		cash_before,
		0.01,
		"Player cash must not change when checkout fails due to empty inventory"
	)


# ── InventorySystem stock count unchanged ─────────────────────────────────────


func test_inventory_count_unchanged_after_failed_checkout() -> void:
	var count_before: int = _inventory.get_item_count()

	EventBus.customer_reached_checkout.emit(_customer)

	assert_eq(
		_inventory.get_item_count(),
		count_before,
		"Inventory item count must not change when checkout fails"
	)


func test_inventory_count_remains_zero_after_failed_checkout() -> void:
	EventBus.customer_reached_checkout.emit(_customer)

	assert_eq(
		_inventory.get_item_count(),
		0,
		"Inventory must remain empty — no phantom deduction on failure"
	)


# ── ReputationSystem score decreased ─────────────────────────────────────────


func test_reputation_decreased_after_dissatisfied_exit() -> void:
	var rep_before: float = _reputation.get_reputation(TEST_STORE_ID)

	EventBus.customer_reached_checkout.emit(_customer)

	assert_true(
		_reputation.get_reputation(TEST_STORE_ID) < rep_before,
		"Reputation must decrease after a dissatisfied customer leaves"
	)


func test_reputation_decreased_by_dissatisfaction_loss_constant() -> void:
	var rep_before: float = _reputation.get_reputation(TEST_STORE_ID)

	EventBus.customer_reached_checkout.emit(_customer)

	assert_almost_eq(
		_reputation.get_reputation(TEST_STORE_ID),
		rep_before + ReputationSystemSingleton.DISSATISFACTION_LOSS,
		0.01,
		"Reputation must decrease by exactly DISSATISFACTION_LOSS on checkout failure"
	)


func test_reputation_changed_signal_fires_after_checkout_failure() -> void:
	watch_signals(EventBus)

	EventBus.customer_reached_checkout.emit(_customer)

	assert_signal_emitted(
		EventBus,
		"reputation_changed",
		"reputation_changed must fire after a dissatisfied customer exits"
	)


# ── Full failure chain: all 5 signals in correct sequence ────────────────────


func test_full_failure_chain_signal_sequence() -> void:
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
	assert_signal_emit_count(
		EventBus, "customer_purchased", 0,
		"Signal 3: customer_purchased must NOT fire on inventory failure"
	)
	assert_signal_emitted(
		EventBus, "customer_left_mall",
		"Signal 4: customer_left_mall must fire on checkout failure"
	)
	assert_signal_emitted(
		EventBus, "reputation_changed",
		"Signal 5: reputation_changed must fire after dissatisfied exit"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


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
			"name": "Test Failure Chain Store",
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
