# gdlint:disable=max-public-methods
## GUT unit tests for CustomerSystem — spawn, state machine, and satisfaction.
extends GutTest

const TEST_SIGNAL_UTILS: GDScript = preload("res://game/tests/test_signal_utils.gd")

var _system: CustomerSystem
var _economy: EconomySystem
var _inventory: InventorySystem
var _reputation: ReputationSystem
var _checkout: PlayerCheckout
var _profile: CustomerTypeDefinition
var _customer_scene: PackedScene

var _entered_signals: Array[Dictionary] = []
var _left_signals: Array[Dictionary] = []
var _purchased_signals: Array[Dictionary] = []
var _greeted_signals: Array[Dictionary] = []


func before_each() -> void:
	_system = CustomerSystem.new()
	add_child_autofree(_system)

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(1000.0)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)

	_checkout = PlayerCheckout.new()
	add_child_autofree(_checkout)
	_checkout.initialize(
		_economy, _inventory, _system, _reputation
	)

	_profile = _make_profile()
	_customer_scene = preload(
		"res://game/scenes/characters/customer.tscn"
	)

	_system._customer_scene = _customer_scene
	_system._max_customers = 5

	_entered_signals = []
	_left_signals = []
	_purchased_signals = []
	_greeted_signals = []

	EventBus.customer_entered.connect(_on_entered)
	EventBus.customer_left.connect(_on_left)
	EventBus.customer_purchased.connect(_on_purchased)
	EventBus.customer_greeted.connect(_on_greeted)


func after_each() -> void:
	TEST_SIGNAL_UTILS.safe_disconnect(EventBus.customer_entered, _on_entered)
	TEST_SIGNAL_UTILS.safe_disconnect(EventBus.customer_left, _on_left)
	TEST_SIGNAL_UTILS.safe_disconnect(
		EventBus.customer_purchased, _on_purchased
	)
	TEST_SIGNAL_UTILS.safe_disconnect(EventBus.customer_greeted, _on_greeted)


func _make_profile() -> CustomerTypeDefinition:
	var p := CustomerTypeDefinition.new()
	p.id = "test_customer"
	p.customer_name = "Test Customer"
	p.budget_range = [10.0, 200.0]
	p.patience = 0.5
	p.price_sensitivity = 0.5
	p.preferred_categories = PackedStringArray([])
	p.preferred_tags = PackedStringArray([])
	p.condition_preference = "good"
	p.browse_time_range = [1.0, 2.0]
	p.purchase_probability_base = 0.9
	p.impulse_buy_chance = 0.1
	p.mood_tags = PackedStringArray([])
	return p


func _make_item(
	item_id: String = "test_item", price: float = 50.0
) -> ItemInstance:
	var definition := ItemDefinition.new()
	definition.id = item_id
	definition.item_name = "Test Item"
	definition.category = "cards"
	definition.base_price = price
	definition.rarity = "common"
	definition.tags = PackedStringArray([])
	definition.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)
	definition.store_type = "pocket_creatures"
	var item := ItemInstance.create_from_definition(
		definition, "good"
	)
	item.player_set_price = price
	return item


func _make_customer() -> Customer:
	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	customer.profile = _profile
	return customer


func _on_entered(data: Dictionary) -> void:
	_entered_signals.append(data)


func _on_left(data: Dictionary) -> void:
	_left_signals.append(data)


func _on_purchased(
	_store_id: StringName, item_id: StringName,
	price: float, _customer_id: StringName
) -> void:
	_purchased_signals.append(
		{"item_id": item_id, "price": price}
	)


func _on_greeted(
	customer_id: StringName, store_id: StringName
) -> void:
	_greeted_signals.append(
		{"customer_id": customer_id, "store_id": store_id}
	)


# --- Spawn tests ---


func test_spawn_creates_customer_with_entering_state() -> void:
	_system.spawn_customer(_profile, "test_store")
	var customers: Array[Customer] = (
		_system.get_active_customers()
	)
	assert_eq(
		customers.size(), 1,
		"Should have 1 active customer"
	)
	assert_eq(
		customers[0].current_state,
		Customer.State.ENTERING,
		"Spawned customer should start in ENTERING state"
	)


func test_spawn_returns_non_null_customer() -> void:
	_system.spawn_customer(_profile, "test_store")
	var customers: Array[Customer] = (
		_system.get_active_customers()
	)
	assert_eq(customers.size(), 1)
	assert_not_null(
		customers[0], "Spawned customer should be non-null"
	)


func test_spawn_emits_customer_entered_signal() -> void:
	_system.spawn_customer(_profile, "test_store")
	assert_eq(
		_entered_signals.size(), 1,
		"customer_entered should fire once on spawn"
	)
	assert_eq(
		_entered_signals[0]["profile_id"], "test_customer",
		"Signal should include correct profile_id"
	)


func test_spawn_increments_active_count() -> void:
	assert_eq(_system.get_active_customer_count(), 0)
	_system.spawn_customer(_profile, "test_store")
	assert_eq(_system.get_active_customer_count(), 1)
	_system.spawn_customer(_profile, "test_store")
	assert_eq(_system.get_active_customer_count(), 2)


# --- State machine tests ---


func test_customer_transitions_to_leaving_on_patience_timeout() -> void:
	var customer: Customer = _make_customer()
	customer.current_state = Customer.State.BROWSING
	customer.patience_timer = 0.0
	customer._initialized = true
	customer._process_browsing(0.1)
	assert_true(
		customer.current_state == Customer.State.LEAVING
		or customer.current_state == Customer.State.DECIDING,
		"Should transition away from BROWSING when patience expires"
	)


func test_customer_leaves_when_no_desired_item() -> void:
	var customer: Customer = _make_customer()
	customer._desired_item = null
	customer.current_state = Customer.State.DECIDING
	customer._initialized = true
	customer._process_deciding()
	assert_eq(
		customer.current_state, Customer.State.LEAVING,
		"Should LEAVE when no desired item exists"
	)


func test_customer_evaluates_affordable_item() -> void:
	var customer: Customer = _make_customer()
	var item: ItemInstance = _make_item("test_item", 50.0)
	customer._desired_item = item
	customer._budget_multiplier = 1.0
	customer.current_state = Customer.State.DECIDING
	customer._initialized = true
	customer._process_deciding()
	assert_true(
		customer.current_state == Customer.State.PURCHASING
		or customer.current_state == Customer.State.LEAVING,
		"Should evaluate item and transition to PURCHASING or LEAVING"
	)


# --- Satisfaction tracking ---


func test_satisfaction_true_after_purchase() -> void:
	var customer: Customer = _make_customer()
	customer._initialized = true
	assert_false(
		customer._made_purchase,
		"Should start unsatisfied"
	)
	customer.complete_purchase()
	assert_true(
		customer._made_purchase,
		"Satisfaction should be true after purchase"
	)
	assert_eq(
		customer.current_state, Customer.State.LEAVING,
		"Should transition to LEAVING after purchase"
	)


func test_satisfaction_false_when_leaving_without_purchase() -> void:
	var customer: Customer = _make_customer()
	customer._initialized = true
	customer._desired_item = null
	customer.current_state = Customer.State.DECIDING
	customer._process_deciding()
	assert_false(
		customer._made_purchase,
		"Should remain unsatisfied when leaving without purchase"
	)
	assert_eq(
		customer.current_state, Customer.State.LEAVING
	)


# --- customer_left signal with satisfied flag ---


func test_customer_left_satisfied_after_purchase() -> void:
	_system.spawn_customer(_profile, "test_store")
	var customers: Array[Customer] = (
		_system.get_active_customers()
	)
	var customer: Customer = customers[0]
	customer.complete_purchase()
	_system.despawn_customer(customer)
	assert_eq(
		_left_signals.size(), 1,
		"customer_left should fire once"
	)
	assert_true(
		_left_signals[0].get("satisfied", false) as bool,
		"satisfied should be true after purchase"
	)
	assert_eq(
		_left_signals[0].get("reason"), &"purchase_complete",
		"reason should be purchase_complete after sale"
	)


func test_customer_left_unsatisfied_without_purchase() -> void:
	_system.spawn_customer(_profile, "test_store")
	var customers: Array[Customer] = (
		_system.get_active_customers()
	)
	var customer: Customer = customers[0]
	_system.despawn_customer(customer)
	assert_eq(
		_left_signals.size(), 1,
		"customer_left should fire once"
	)
	assert_false(
		_left_signals[0].get("satisfied", true) as bool,
		"satisfied should be false without purchase"
	)
	assert_eq(
		_left_signals[0].get("reason"), &"patience_expired",
		"reason should be set on customer_left"
	)


func test_customer_left_includes_profile_data() -> void:
	_system.set_store_id("test_store")
	_system.spawn_customer(_profile, "test_store")
	var customers: Array[Customer] = (
		_system.get_active_customers()
	)
	_system.despawn_customer(customers[0])
	assert_eq(
		_left_signals[0]["profile_id"], "test_customer"
	)
	assert_eq(
		_left_signals[0]["store_id"], "test_store"
	)


# --- customer_purchased signal via CheckoutSystem ---


func test_customer_purchased_signal_fires_on_sale() -> void:
	var item: ItemInstance = _make_item("sale_item", 50.0)
	_inventory._items[item.instance_id] = item
	var customer: Customer = _make_customer()
	_checkout.initiate_sale(customer, item, 50.0)
	_checkout._checkout_timer.stop()
	_checkout._on_checkout_timer_timeout()
	assert_eq(
		_purchased_signals.size(), 1,
		"customer_purchased should fire once"
	)
	assert_almost_eq(
		_purchased_signals[0]["price"] as float, 50.0, 0.01,
		"customer_purchased should carry the correct price"
	)


# --- Concurrent customer cap ---


func test_max_concurrent_customers_enforced() -> void:
	_system._max_customers = 3
	_system.spawn_customer(_profile, "test_store")
	_system.spawn_customer(_profile, "test_store")
	_system.spawn_customer(_profile, "test_store")
	assert_eq(
		_system.get_active_customer_count(), 3,
		"Should have 3 active customers at capacity"
	)
	_system.spawn_customer(_profile, "test_store")
	assert_eq(
		_system.get_active_customer_count(), 3,
		"Should not exceed max customer cap"
	)
	assert_eq(
		_entered_signals.size(), 3,
		"customer_entered should only fire for successful spawns"
	)


func test_spawn_after_despawn_succeeds_at_cap() -> void:
	_system._max_customers = 2
	_system.spawn_customer(_profile, "test_store")
	_system.spawn_customer(_profile, "test_store")
	assert_eq(_system.get_active_customer_count(), 2)
	var first: Customer = _system.get_active_customers()[0]
	_system.despawn_customer(first)
	assert_eq(_system.get_active_customer_count(), 1)
	_system.spawn_customer(_profile, "test_store")
	assert_eq(
		_system.get_active_customer_count(), 2,
		"Should allow spawn after despawn frees a slot"
	)


func test_despawn_reduces_active_count() -> void:
	_system.spawn_customer(_profile, "test_store")
	_system.spawn_customer(_profile, "test_store")
	assert_eq(_system.get_active_customer_count(), 2)
	var customer: Customer = _system.get_active_customers()[0]
	_system.despawn_customer(customer)
	assert_eq(
		_system.get_active_customer_count(), 1,
		"Active count should decrease after despawn"
	)


func test_day_ended_despawns_all_customers() -> void:
	_system.spawn_customer(_profile, "test_store")
	_system.spawn_customer(_profile, "test_store")
	assert_eq(_system.get_active_customer_count(), 2)
	_system._on_day_ended(1)
	assert_eq(
		_system.get_active_customer_count(), 0,
		"All customers should be despawned on day end"
	)


# --- Greeter staff effect tests ---


func _make_greeter(morale: float = 1.0) -> StaffDefinition:
	var g := StaffDefinition.new()
	g.staff_id = "greeter_test"
	g.display_name = "Test Greeter"
	g.role = StaffDefinition.StaffRole.GREETER
	g.morale = morale
	return g


func test_customer_greeted_emitted_when_greeter_assigned() -> void:
	_system._store_id = "test_store"
	_system._cached_greeter = _make_greeter(1.0)
	_system.spawn_customer(_profile, "test_store")
	assert_true(
		_greeted_signals.size() > 0,
		"customer_greeted should fire when greeter is assigned and customer enters"
	)
	if _greeted_signals.size() > 0:
		assert_eq(
			_greeted_signals[0]["store_id"],
			StringName("test_store"),
			"customer_greeted should include the correct store_id"
		)


func test_customer_greeted_not_emitted_without_greeter() -> void:
	_system._cached_greeter = null
	_system.spawn_customer(_profile, "test_store")
	assert_eq(
		_greeted_signals.size(), 0,
		"customer_greeted should not fire when no greeter is assigned"
	)


func test_browse_min_multiplier_applied_with_greeter() -> void:
	var greeter: StaffDefinition = _make_greeter(1.0)
	var perf: float = greeter.performance_multiplier()
	var expected_mult: float = (
		1.0 + CustomerSystem.GREETER_BROWSE_BONUS * perf
	)
	_system._store_id = "test_store"
	_system._cached_greeter = greeter
	_system.spawn_customer(_profile, "test_store")
	var customers: Array[Customer] = _system.get_active_customers()
	if customers.is_empty():
		return
	var customer: Customer = customers[0]
	assert_almost_eq(
		customer._browse_min_multiplier,
		expected_mult,
		0.001,
		"Browse min multiplier should match greeter performance bonus"
	)


func test_browse_min_multiplier_is_one_without_greeter() -> void:
	_system._cached_greeter = null
	_system.spawn_customer(_profile, "test_store")
	var customers: Array[Customer] = _system.get_active_customers()
	assert_false(customers.is_empty(), "Customer should have spawned")
	if customers.is_empty():
		return
	assert_almost_eq(
		customers[0]._browse_min_multiplier,
		1.0,
		0.001,
		"Browse min multiplier should be 1.0 without a greeter"
	)


func test_greeter_refresh_clears_cache_on_store_id_change() -> void:
	_system._cached_greeter = _make_greeter(1.0)
	_system.set_store_id("")
	assert_null(
		_system._cached_greeter,
		"Cached greeter should be cleared when store_id is empty"
	)
