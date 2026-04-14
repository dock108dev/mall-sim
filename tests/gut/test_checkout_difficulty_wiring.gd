## Tests that CheckoutSystem autoload applies DifficultySystem
## purchase_probability_multiplier to NPC transaction success rolls.
extends GutTest


var _system: Node
var _inventory: InventorySystem
var _market: MarketValueSystem
var _difficulty: DifficultySystem
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

	_difficulty = DifficultySystem.new()
	add_child_autofree(_difficulty)

	var script: GDScript = load(
		"res://game/autoload/checkout_system.gd"
	)
	_system = script.new()
	add_child_autofree(_system)
	_system.initialize(_market, _inventory, _difficulty)

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


func _set_difficulty_modifier(value: float) -> void:
	_difficulty._tiers = {
		&"mock": {
			"id": "mock",
			"display_name": "Mock",
			"modifiers": {
				"purchase_probability_multiplier": value,
			},
			"flags": {},
		}
	}
	_difficulty._tier_order = [&"mock"]
	_difficulty._current_tier_id = &"mock"


# --- Zero modifier: all transactions fail ---


func test_zero_modifier_all_transactions_fail() -> void:
	_set_difficulty_modifier(0.0)
	var trials: int = 50
	for i: int in range(trials):
		_inventory._items[_item.instance_id] = _item
		var customer: Customer = _make_customer_with_item()
		_system.process_transaction(customer)

	assert_eq(
		_purchased_signals.size(), 0,
		"Zero modifier: no transactions should succeed"
	)
	assert_eq(
		_left_signals.size(), trials,
		"Zero modifier: all customers should leave"
	)
	for sig: Dictionary in _left_signals:
		assert_false(
			sig["satisfied"] as bool,
			"Customer should leave unsatisfied"
		)


# --- High modifier (clamped to 1.0): all transactions succeed ---


func test_high_modifier_clamped_all_transactions_succeed() -> void:
	_set_difficulty_modifier(2.0)
	_profile.purchase_probability_base = 1.0
	var trials: int = 50
	for i: int in range(trials):
		_inventory._items[_item.instance_id] = _item
		var customer: Customer = _make_customer_with_item()
		_system.process_transaction(customer)

	assert_eq(
		_purchased_signals.size(), trials,
		"Modifier 2.0 clamped to 1.0: all transactions should succeed"
	)
	assert_eq(
		_left_signals.size(), 0,
		"Modifier 2.0: no customers should leave unsatisfied"
	)


# --- Modifier read at transaction time, not cached ---


func test_modifier_read_at_transaction_time() -> void:
	_set_difficulty_modifier(0.0)
	_inventory._items[_item.instance_id] = _item
	var customer1: Customer = _make_customer_with_item()
	_system.process_transaction(customer1)
	assert_eq(
		_purchased_signals.size(), 0,
		"First transaction with 0.0 modifier should fail"
	)

	_set_difficulty_modifier(2.0)
	_profile.purchase_probability_base = 1.0
	_inventory._items[_item.instance_id] = _item
	var customer2: Customer = _make_customer_with_item()
	_system.process_transaction(customer2)
	assert_eq(
		_purchased_signals.size(), 1,
		"Second transaction with 2.0 modifier should succeed"
	)


# --- Easy difficulty increases purchase rate ---


func test_easy_modifier_increases_probability() -> void:
	_set_difficulty_modifier(1.25)
	_profile.purchase_probability_base = 0.5
	var success_count: Array = [0]
	var trials: int = 2000
	for i: int in range(trials):
		_purchased_signals = []
		_left_signals = []
		_inventory._items[_item.instance_id] = _item
		var customer: Customer = _make_customer_with_item()
		_system.process_transaction(customer)
		if _purchased_signals.size() > 0:
			success_count[0] += 1

	var actual_rate: float = float(success_count[0]) / float(trials)
	var expected: float = 0.5 * 1.25
	assert_almost_eq(
		actual_rate, expected, 0.06,
		"Easy (1.25x) with 0.5 base should yield ~%.0f%% success"
		% [expected * 100.0]
	)


# --- Hard difficulty decreases purchase rate ---


func test_hard_modifier_decreases_probability() -> void:
	_set_difficulty_modifier(0.75)
	_profile.purchase_probability_base = 0.5
	var success_count: Array = [0]
	var trials: int = 2000
	for i: int in range(trials):
		_purchased_signals = []
		_left_signals = []
		_inventory._items[_item.instance_id] = _item
		var customer: Customer = _make_customer_with_item()
		_system.process_transaction(customer)
		if _purchased_signals.size() > 0:
			success_count[0] += 1

	var actual_rate: float = float(success_count[0]) / float(trials)
	var expected: float = 0.5 * 0.75
	assert_almost_eq(
		actual_rate, expected, 0.06,
		"Hard (0.75x) with 0.5 base should yield ~%.0f%% success"
		% [expected * 100.0]
	)
