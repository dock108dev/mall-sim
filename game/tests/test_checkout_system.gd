## GUT unit tests for CheckoutSystem sale pipeline, queue integration,
## and failure cases.
extends GutTest


var _checkout: PlayerCheckout
var _economy: EconomySystem
var _inventory: InventorySystem
var _reputation: ReputationSystem
var _customer_system: CustomerSystem
var _definition: ItemDefinition
var _item: ItemInstance
var _customer_scene: PackedScene
var _profile: CustomerTypeDefinition

var _sold_signals: Array[Dictionary] = []
var _purchased_signals: Array[Dictionary] = []
var _queue_signals: Array[int] = []


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(1000.0)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)

	_customer_system = CustomerSystem.new()
	add_child_autofree(_customer_system)

	_checkout = PlayerCheckout.new()
	add_child_autofree(_checkout)
	_checkout.initialize(
		_economy, _inventory, _customer_system, _reputation
	)

	_profile = CustomerTypeDefinition.new()
	_profile.id = "test_buyer"
	_profile.customer_name = "Test Buyer"
	_profile.budget_range = [5.0, 500.0]
	_profile.patience = 0.8
	_profile.price_sensitivity = 0.5
	_profile.preferred_categories = PackedStringArray([])
	_profile.preferred_tags = PackedStringArray([])
	_profile.condition_preference = "good"
	_profile.browse_time_range = [30.0, 60.0]
	_profile.purchase_probability_base = 0.9
	_profile.impulse_buy_chance = 0.1
	_profile.mood_tags = PackedStringArray([])

	_definition = ItemDefinition.new()
	_definition.id = "test_item"
	_definition.item_name = "Test Item"
	_definition.category = "cards"
	_definition.base_price = 100.0
	_definition.rarity = "common"
	_definition.tags = PackedStringArray([])
	_definition.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)
	_definition.store_type = "pocket_creatures"

	_item = ItemInstance.create_from_definition(_definition, "good")
	_item.player_set_price = 100.0
	_inventory._items[_item.instance_id] = _item

	_customer_scene = preload(
		"res://game/scenes/characters/customer.tscn"
	)

	_sold_signals = []
	_purchased_signals = []
	_queue_signals = []

	EventBus.item_sold.connect(_on_item_sold)
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.queue_advanced.connect(_on_queue_advanced)


func after_each() -> void:
	_safe_disconnect(EventBus.item_sold, _on_item_sold)
	_safe_disconnect(
		EventBus.customer_purchased, _on_customer_purchased
	)
	_safe_disconnect(EventBus.queue_advanced, _on_queue_advanced)


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _make_customer() -> Customer:
	var customer: Customer = _customer_scene.instantiate()
	add_child_autofree(customer)
	customer.profile = _profile
	return customer


func _on_item_sold(
	item_id: String, price: float, category: String
) -> void:
	_sold_signals.append({
		"item_id": item_id,
		"price": price,
		"category": category,
	})


func _on_customer_purchased(
	_store_id: StringName, item_id: StringName,
	price: float, _customer_id: StringName
) -> void:
	_purchased_signals.append({
		"item_id": item_id,
		"price": price,
	})


func _on_queue_advanced(queue_size: int) -> void:
	_queue_signals.append(queue_size)


## Stops the checkout timer and fires its callback to complete the sale
## synchronously within a test.
func _force_complete_checkout() -> void:
	_checkout._checkout_timer.stop()
	_checkout._on_checkout_timer_timeout()


# --- Successful sale completes with valid item and sufficient budget ---


func test_successful_sale_increases_player_cash() -> void:
	var customer: Customer = _make_customer()
	var initial_cash: float = _economy.get_cash()
	var sale_price: float = 80.0
	_checkout.initiate_sale(customer, _item, sale_price)
	_force_complete_checkout()
	assert_almost_eq(
		_economy.get_cash(), initial_cash + sale_price, 0.01,
		"Player cash should increase by the sold price"
	)


func test_successful_sale_removes_item_from_inventory() -> void:
	var customer: Customer = _make_customer()
	var item_id: String = _item.instance_id
	_checkout.initiate_sale(customer, _item, 80.0)
	_force_complete_checkout()
	assert_false(
		_inventory._items.has(item_id),
		"Item should be removed from inventory after sale"
	)


# --- Declined sale: price above budget leaves state unchanged ---


func test_declined_sale_cash_unchanged() -> void:
	var customer: Customer = _make_customer()
	var initial_cash: float = _economy.get_cash()
	_checkout._active_customer = customer
	_checkout._active_item = _item
	_checkout._active_offer = 999.0
	_checkout._on_sale_declined()
	assert_almost_eq(
		_economy.get_cash(), initial_cash, 0.01,
		"Cash should not change when sale is declined"
	)


func test_declined_sale_item_remains_in_inventory() -> void:
	var customer: Customer = _make_customer()
	_checkout._active_customer = customer
	_checkout._active_item = _item
	_checkout._active_offer = 999.0
	_checkout._on_sale_declined()
	assert_true(
		_inventory._items.has(_item.instance_id),
		"Item should remain in inventory after declined sale"
	)


# --- Signal emission with correct data ---


func test_item_sold_signal_carries_correct_data() -> void:
	var customer: Customer = _make_customer()
	var sale_price: float = 80.0
	var item_id: String = _item.instance_id
	_checkout.initiate_sale(customer, _item, sale_price)
	_force_complete_checkout()
	assert_eq(
		_sold_signals.size(), 1,
		"item_sold signal should fire exactly once"
	)
	assert_eq(
		_sold_signals[0]["item_id"], item_id,
		"item_sold should carry the correct item_id"
	)
	assert_almost_eq(
		_sold_signals[0]["price"] as float, sale_price, 0.01,
		"item_sold should carry the correct price"
	)
	assert_eq(
		_sold_signals[0]["category"], "cards",
		"item_sold should carry the correct category"
	)


func test_customer_purchased_signal_carries_correct_price() -> void:
	var customer: Customer = _make_customer()
	var sale_price: float = 80.0
	_checkout.initiate_sale(customer, _item, sale_price)
	_force_complete_checkout()
	assert_eq(
		_purchased_signals.size(), 1,
		"customer_purchased should fire exactly once"
	)
	assert_almost_eq(
		_purchased_signals[0]["price"] as float, sale_price, 0.01,
		"customer_purchased should carry the agreed price"
	)


func test_declined_sale_does_not_emit_item_sold() -> void:
	var customer: Customer = _make_customer()
	_checkout._active_customer = customer
	_checkout._active_item = _item
	_checkout._active_offer = 999.0
	_checkout._on_sale_declined()
	assert_eq(
		_sold_signals.size(), 0,
		"item_sold should not fire on declined sale"
	)


# --- Queue advancement ---


func test_queue_advances_after_checkout_completes() -> void:
	var customer1: Customer = _make_customer()
	var customer2: Customer = _make_customer()
	_checkout._register_queue.try_add(customer1)
	_checkout._register_queue.try_add(customer2)
	assert_eq(
		_checkout._register_queue.get_size(), 2,
		"Queue should have 2 customers before sale"
	)
	_checkout.initiate_sale(customer1, _item, 80.0)
	_force_complete_checkout()
	assert_eq(
		_checkout._register_queue.get_size(), 1,
		"Queue should have 1 customer after sale completes"
	)


func test_queue_advanced_signal_reports_correct_size() -> void:
	var customer: Customer = _make_customer()
	_checkout._register_queue.try_add(customer)
	_checkout.initiate_sale(customer, _item, 80.0)
	_force_complete_checkout()
	assert_true(
		_queue_signals.size() > 0,
		"queue_advanced signal should fire"
	)
	assert_eq(
		_queue_signals.back(), 0,
		"queue_advanced should report 0 after last customer served"
	)


# --- Double checkout of same item ---


func test_double_checkout_same_item_fails_cleanly() -> void:
	var customer1: Customer = _make_customer()
	_checkout.initiate_sale(customer1, _item, 80.0)
	_force_complete_checkout()
	var cash_after_first: float = _economy.get_cash()
	var customer2: Customer = _make_customer()
	_checkout.initiate_sale(customer2, _item, 80.0)
	assert_false(
		_checkout._is_processing,
		"Should not process sale of already-sold item"
	)
	assert_almost_eq(
		_economy.get_cash(), cash_after_first, 0.01,
		"Cash should not change on double checkout attempt"
	)
	assert_eq(
		_sold_signals.size(), 1,
		"item_sold should only fire once across both attempts"
	)
