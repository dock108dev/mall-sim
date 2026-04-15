## Unit tests for CheckoutSystem sale processing, receipt signals, and inventory deduction.
extends GutTest


var _checkout: PlayerCheckout
var _economy: EconomySystem
var _inventory: InventorySystem
var _reputation: ReputationSystem
var _customer_system: CustomerSystem
var _definition: ItemDefinition
var _item: ItemInstance
var _profile: CustomerTypeDefinition

var _sold_signals: Array[Dictionary] = []


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

	_sold_signals = []
	EventBus.item_sold.connect(_on_item_sold)


func after_each() -> void:
	_safe_disconnect(EventBus.item_sold, _on_item_sold)


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _make_customer() -> Customer:
	var customer: Customer = Customer.new()
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


func _force_complete_checkout() -> void:
	_checkout._checkout_timer.stop()
	_checkout._on_checkout_timer_timeout()


# --- Sale processing and economy ---


func test_process_sale_adds_cash_to_economy() -> void:
	var customer: Customer = _make_customer()
	var initial_cash: float = _economy.get_cash()
	var sale_price: float = 80.0
	_checkout.initiate_sale(customer, _item, sale_price)
	_force_complete_checkout()
	assert_almost_eq(
		_economy.get_cash(), initial_cash + sale_price, 0.01,
		"Balance should increase by the sale price"
	)


func test_process_sale_removes_item_from_inventory() -> void:
	var customer: Customer = _make_customer()
	var item_id: String = _item.instance_id
	_checkout.initiate_sale(customer, _item, 80.0)
	_force_complete_checkout()
	assert_false(
		_inventory._items.has(item_id),
		"Item should be removed from inventory after sale"
	)


# --- Receipt signal ---


func test_receipt_signal_emitted_with_correct_data() -> void:
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
		"item_sold should carry the correct final_price"
	)
	assert_eq(
		_sold_signals[0]["category"], "cards",
		"item_sold should carry the correct category"
	)


# --- Failure cases ---


func test_sale_fails_on_item_not_in_inventory() -> void:
	var customer: Customer = _make_customer()
	var initial_cash: float = _economy.get_cash()
	_inventory._items.erase(_item.instance_id)
	_checkout.initiate_sale(customer, _item, 100.0)
	assert_false(
		_checkout._is_processing,
		"Should not be processing a sale for missing item"
	)
	assert_eq(
		_sold_signals.size(), 0,
		"item_sold should not fire for missing inventory item"
	)
	assert_almost_eq(
		_economy.get_cash(), initial_cash, 0.01,
		"Balance should remain unchanged on failed sale"
	)


func test_sale_fails_on_invalid_price() -> void:
	var customer: Customer = _make_customer()
	_checkout.initiate_sale(customer, _item, 0.0)
	assert_false(
		_checkout._is_processing,
		"Should not process sale with zero price"
	)
	_checkout.initiate_sale(customer, _item, -5.0)
	assert_false(
		_checkout._is_processing,
		"Should not process sale with negative price"
	)


# --- Haggle price ---


func test_haggle_price_used_when_provided() -> void:
	var customer: Customer = _make_customer()
	var haggle_price: float = 80.0
	var initial_cash: float = _economy.get_cash()
	_checkout.initiate_sale(customer, _item, haggle_price)
	_force_complete_checkout()
	assert_almost_eq(
		_economy.get_cash(), initial_cash + haggle_price, 0.01,
		"Economy should receive haggle price (80), not base price (100)"
	)
	assert_eq(
		_sold_signals.size(), 1,
		"item_sold should fire once"
	)
	assert_almost_eq(
		_sold_signals[0]["price"] as float, haggle_price, 0.01,
		"item_sold signal should carry haggle price, not base price"
	)


# --- Daily revenue tracking ---


func test_daily_revenue_updated_on_sale() -> void:
	var customer: Customer = _make_customer()
	var sale_price: float = 95.0
	var summary_before: Dictionary = _economy.get_daily_summary()
	var revenue_before: float = summary_before.get(
		"total_revenue", 0.0
	) as float
	_checkout.initiate_sale(customer, _item, sale_price)
	_force_complete_checkout()
	var summary_after: Dictionary = _economy.get_daily_summary()
	var revenue_after: float = summary_after.get(
		"total_revenue", 0.0
	) as float
	assert_almost_eq(
		revenue_after, revenue_before + sale_price, 0.01,
		"Daily revenue should increase by the sale amount"
	)
