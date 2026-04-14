## Tests for CheckoutSystem autoload — NPC transaction processing.
extends GutTest


var _system: Node
var _inventory: InventorySystem
var _market: MarketValueSystem
var _definition: ItemDefinition
var _item: ItemInstance
var _customer_scene: PackedScene
var _profile: CustomerTypeDefinition

var _purchased_signals: Array[Dictionary] = []
var _left_signals: Array[Dictionary] = []


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_market = MarketValueSystem.new()
	add_child_autofree(_market)

	var script: GDScript = load(
		"res://game/autoload/checkout_system.gd"
	)
	_system = script.new()
	add_child_autofree(_system)
	_system.initialize(_market, _inventory)

	_definition = ItemDefinition.new()
	_definition.id = "test_card"
	_definition.item_name = "Test Card"
	_definition.base_price = 10.0
	_definition.rarity = "common"
	_definition.category = "cards"
	_definition.store_type = "pocket_creatures"

	_item = ItemInstance.create(_definition, "good", 0, 10.0)
	_item.current_location = "shelf:slot_1"

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
	_profile.purchase_probability_base = 1.0
	_profile.impulse_buy_chance = 0.0
	_profile.max_price_to_market_ratio = 1.5

	_customer_scene = preload(
		"res://game/scenes/characters/customer.tscn"
	)

	_purchased_signals = []
	_left_signals = []

	EventBus.customer_purchased.connect(_on_purchased)
	EventBus.customer_left_mall.connect(_on_left_mall)


func after_each() -> void:
	_safe_disconnect(
		EventBus.customer_purchased, _on_purchased
	)
	_safe_disconnect(
		EventBus.customer_left_mall, _on_left_mall
	)


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_purchased(
	store_id: StringName, item_id: StringName,
	price: float, customer_id: StringName
) -> void:
	_purchased_signals.append({
		"store_id": store_id,
		"item_id": item_id,
		"price": price,
		"customer_id": customer_id,
	})


func _on_left_mall(customer: Node, satisfied: bool) -> void:
	_left_signals.append({
		"customer": customer,
		"satisfied": satisfied,
	})


func _make_customer_with_item() -> Customer:
	var customer: Customer = _customer_scene.instantiate()
	add_child_autofree(customer)
	customer.profile = _profile
	customer._desired_item = _item
	return customer


func test_successful_transaction_emits_customer_purchased() -> void:
	_inventory._items[_item.instance_id] = _item
	var customer: Customer = _make_customer_with_item()

	var result: bool = _system.process_transaction(customer)

	assert_true(result, "Transaction should succeed")
	assert_eq(
		_purchased_signals.size(), 1,
		"customer_purchased should fire once"
	)


func test_successful_transaction_includes_all_signal_params() -> void:
	_inventory._items[_item.instance_id] = _item
	var customer: Customer = _make_customer_with_item()

	_system.process_transaction(customer)

	assert_eq(_purchased_signals.size(), 1)
	var sig: Dictionary = _purchased_signals[0]
	assert_eq(
		sig["item_id"],
		StringName(_item.instance_id),
		"Signal should carry item_id"
	)
	assert_true(
		sig["price"] > 0.0,
		"Signal should carry positive price"
	)
	assert_false(
		StringName(sig["customer_id"]).is_empty(),
		"Signal should carry customer_id"
	)


func test_budget_too_low_returns_false() -> void:
	_definition.base_price = 9999.0
	_item = ItemInstance.create(_definition, "good", 0, 9999.0)
	_item.current_location = "shelf:slot_1"
	_inventory._items[_item.instance_id] = _item

	var customer: Customer = _make_customer_with_item()

	var result: bool = _system.process_transaction(customer)

	assert_false(result, "Should fail when budget < price")
	assert_eq(
		_purchased_signals.size(), 0,
		"customer_purchased should NOT fire"
	)
	assert_eq(
		_left_signals.size(), 1,
		"customer_left_mall should fire"
	)
	assert_false(
		_left_signals[0]["satisfied"],
		"Customer should leave unsatisfied"
	)


func test_out_of_stock_returns_false() -> void:
	var customer: Customer = _make_customer_with_item()

	var result: bool = _system.process_transaction(customer)

	assert_false(result, "Should fail when item not in stock")
	assert_eq(
		_purchased_signals.size(), 0,
		"customer_purchased should NOT fire"
	)
	assert_eq(
		_left_signals.size(), 1,
		"customer_left_mall should fire on out of stock"
	)


func test_duplicate_customer_id_silently_ignored() -> void:
	_inventory._items[_item.instance_id] = _item
	var customer: Customer = _make_customer_with_item()

	_system._processing_ids[
		StringName(str(customer.get_instance_id()))
	] = true

	var result: bool = _system.process_transaction(customer)

	assert_false(
		result,
		"Duplicate customer_id should return false"
	)
	assert_eq(
		_purchased_signals.size(), 0,
		"No signals on duplicate"
	)
	assert_eq(
		_left_signals.size(), 0,
		"No left signal on duplicate"
	)


func test_null_customer_returns_false() -> void:
	var result: bool = _system.process_transaction(null)

	assert_false(result, "Null customer should return false")
	assert_eq(_purchased_signals.size(), 0)
	assert_eq(_left_signals.size(), 0)


func test_customer_without_desired_item_returns_false() -> void:
	var customer: Customer = _customer_scene.instantiate()
	add_child_autofree(customer)
	customer.profile = _profile

	var result: bool = _system.process_transaction(customer)

	assert_false(
		result, "No desired item should return false"
	)
	assert_eq(
		_left_signals.size(), 1,
		"customer_left_mall should fire"
	)
