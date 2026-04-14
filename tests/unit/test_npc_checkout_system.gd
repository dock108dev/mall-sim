## Unit tests for NPC CheckoutSystem — transaction success, failure, and idempotency.
extends GutTest

const _CHECKOUT_SCRIPT := preload("res://game/autoload/checkout_system.gd")
const _CUSTOMER_SCENE := preload("res://game/scenes/characters/customer.tscn")

var _checkout: Node
var _inv: InventorySystem
var _market: MarketValueSystem
var _definition: ItemDefinition
var _item: ItemInstance
var _reentrant_npc: Customer = null


func before_each() -> void:
	_checkout = _CHECKOUT_SCRIPT.new()
	add_child_autofree(_checkout)

	_inv = double(InventorySystem).new()
	add_child_autofree(_inv)

	_market = double(MarketValueSystem).new()
	add_child_autofree(_market)

	var diff: DifficultySystem = double(DifficultySystem).new()
	add_child_autofree(diff)
	stub(diff, "get_modifier").to_return(1.0)

	stub(_market, "calculate_item_value").to_return(50.0)

	_checkout.initialize(_market, _inv, diff)

	_definition = ItemDefinition.new()
	_definition.id = "test_item"
	_definition.item_name = "Test Item"
	_definition.category = "cards"
	_definition.base_price = 50.0
	_definition.rarity = "common"
	_definition.tags = PackedStringArray([])
	_definition.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)
	_definition.store_type = "pocket_creatures"

	_item = ItemInstance.create_from_definition(_definition, "good")
	_reentrant_npc = null
	# Ensure pocket_creatures is resolvable so store_id propagates correctly in signals.
	# Safe to call multiple times — skips if already registered.
	if ContentRegistry.resolve("pocket_creatures").is_empty():
		ContentRegistry.register_entry(
			{"id": "pocket_creatures", "name": "Pocket Creatures"}, "store"
		)


func after_each() -> void:
	if EventBus.customer_purchased.is_connected(_on_reentrant_purchased):
		EventBus.customer_purchased.disconnect(_on_reentrant_purchased)


func _make_customer(budget: float = 200.0) -> Customer:
	var customer: Customer = _CUSTOMER_SCENE.instantiate()
	add_child_autofree(customer)
	var profile := CustomerTypeDefinition.new()
	profile.id = "test_buyer"
	profile.customer_name = "Test Buyer"
	profile.budget_range = [5.0, budget]
	profile.patience = 0.8
	profile.price_sensitivity = 0.5
	profile.preferred_categories = PackedStringArray([])
	profile.preferred_tags = PackedStringArray([])
	profile.condition_preference = "good"
	profile.browse_time_range = [30.0, 60.0]
	profile.purchase_probability_base = 1.0
	profile.impulse_buy_chance = 0.1
	profile.mood_tags = PackedStringArray([])
	customer.profile = profile
	customer._desired_item = _item
	return customer


func _with_stock() -> void:
	var stock: Array[ItemInstance] = [_item]
	stub(_inv, "get_stock").to_return(stock)


func _without_stock() -> void:
	var empty: Array[ItemInstance] = []
	stub(_inv, "get_stock").to_return(empty)


func _on_reentrant_purchased(
	_store_id: StringName, _item_id: StringName,
	_price: float, _customer_id: StringName
) -> void:
	if _reentrant_npc:
		_checkout.process_transaction(_reentrant_npc)


# --- Success ---


func test_successful_transaction() -> void:
	watch_signals(EventBus)
	_with_stock()
	var npc: Customer = _make_customer(200.0)
	_checkout.process_transaction(npc)
	assert_signal_emitted(
		EventBus, "customer_purchased",
		"customer_purchased should fire on successful transaction"
	)
	assert_signal_not_emitted(
		EventBus, "customer_left_mall",
		"customer_left_mall should not fire on success"
	)


# --- Budget failure ---


func test_budget_insufficient() -> void:
	watch_signals(EventBus)
	_with_stock()
	# Price is 50.0 (stubbed); budget max is 49.0 — just below threshold
	var npc: Customer = _make_customer(49.0)
	_checkout.process_transaction(npc)
	assert_signal_emitted(
		EventBus, "customer_left_mall",
		"customer_left_mall should fire when budget is insufficient"
	)
	assert_signal_not_emitted(
		EventBus, "customer_purchased",
		"customer_purchased should not fire on budget failure"
	)
	var params: Array = get_signal_parameters(EventBus, "customer_left_mall")
	assert_false(
		params[1] as bool,
		"satisfied should be false when budget is insufficient"
	)


# --- Out-of-stock failure ---


func test_out_of_stock() -> void:
	watch_signals(EventBus)
	_without_stock()
	var npc: Customer = _make_customer(200.0)
	_checkout.process_transaction(npc)
	assert_signal_emitted(
		EventBus, "customer_left_mall",
		"customer_left_mall should fire when item is out of stock"
	)
	assert_signal_not_emitted(
		EventBus, "customer_purchased",
		"customer_purchased should not fire when out of stock"
	)
	var params: Array = get_signal_parameters(EventBus, "customer_left_mall")
	assert_false(
		params[1] as bool,
		"satisfied should be false when out of stock"
	)


# --- Both failures simultaneously ---


func test_both_failures() -> void:
	watch_signals(EventBus)
	_without_stock()
	# Both constraints fail: no stock and budget too low
	var npc: Customer = _make_customer(49.0)
	_checkout.process_transaction(npc)
	assert_signal_emitted(
		EventBus, "customer_left_mall",
		"customer_left_mall should fire when both stock and budget fail"
	)
	assert_signal_not_emitted(
		EventBus, "customer_purchased",
		"customer_purchased should not fire when both conditions fail"
	)
	var params: Array = get_signal_parameters(EventBus, "customer_left_mall")
	assert_false(
		params[1] as bool,
		"satisfied should be false when both conditions fail"
	)


# --- Signal payload ---


func test_signal_payload() -> void:
	watch_signals(EventBus)
	_with_stock()
	var npc: Customer = _make_customer(200.0)
	var expected_store_id: StringName = &"pocket_creatures"
	var expected_item_id: StringName = StringName(_item.instance_id)
	var expected_customer_id: StringName = StringName(str(npc.get_instance_id()))
	_checkout.process_transaction(npc)
	assert_signal_emitted(EventBus, "customer_purchased", "signal should fire")
	var params: Array = get_signal_parameters(EventBus, "customer_purchased")
	assert_eq(
		params[0],
		expected_store_id,
		"store_id in signal should be the resolved canonical ID"
	)
	assert_eq(
		params[1],
		expected_item_id,
		"item_id in signal should match the desired item's instance_id"
	)
	assert_almost_eq(
		params[2] as float, 50.0, 0.01,
		"price in signal should match the market value"
	)
	assert_eq(
		params[3],
		expected_customer_id,
		"customer_id in signal should match npc.get_instance_id()"
	)


# --- Idempotency: reentrant call during signal emission fires signal only once ---


func test_idempotency() -> void:
	watch_signals(EventBus)
	_with_stock()
	var npc: Customer = _make_customer(200.0)
	_reentrant_npc = npc
	EventBus.customer_purchased.connect(_on_reentrant_purchased)
	_checkout.process_transaction(npc)
	assert_signal_emit_count(
		EventBus, "customer_purchased", 1,
		"customer_purchased should fire exactly once despite reentrant call with same customer"
	)


# --- Clean state: processing guard cleared after completion ---


func test_clean_state_after_transaction() -> void:
	watch_signals(EventBus)
	_with_stock()
	var npc1: Customer = _make_customer(200.0)
	_checkout.process_transaction(npc1)
	# A second distinct customer should be processed after the first completes
	var npc2: Customer = _make_customer(200.0)
	_checkout.process_transaction(npc2)
	assert_signal_emit_count(
		EventBus, "customer_purchased", 2,
		"second customer should succeed after first transaction clears the processing guard"
	)
