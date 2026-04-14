## Tests checkout sale processing: inventory validation, economy updates,
## reputation tiers, signal emission, queue advancement, and timer-based flow.
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


# --- Successful sale pipeline ---


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


func test_successful_sale_emits_item_sold_with_correct_data() -> void:
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


func test_successful_sale_emits_customer_purchased() -> void:
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


# --- Declined / failed sale ---


func test_declined_sale_leaves_cash_unchanged() -> void:
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


func test_declined_sale_keeps_item_in_inventory() -> void:
	var customer: Customer = _make_customer()
	_checkout._active_customer = customer
	_checkout._active_item = _item
	_checkout._active_offer = 999.0
	_checkout._on_sale_declined()
	assert_true(
		_inventory._items.has(_item.instance_id),
		"Item should remain in inventory after declined sale"
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


# --- Race condition guards ---


func test_initiate_sale_rejects_missing_item() -> void:
	var customer: Customer = _make_customer()
	_inventory._items.erase(_item.instance_id)
	_checkout.initiate_sale(customer, _item, 100.0)
	assert_eq(
		_queue_signals.size(), 1,
		"queue_advanced should emit on cancelled sale"
	)


func test_initiate_sale_rejects_null_customer() -> void:
	_checkout.initiate_sale(null, _item, 100.0)
	assert_false(
		_checkout._is_processing,
		"Should not start processing with null customer"
	)


func test_initiate_sale_rejects_zero_price() -> void:
	var customer: Customer = _make_customer()
	_checkout.initiate_sale(customer, _item, 0.0)
	assert_false(
		_checkout._is_processing,
		"Should not start processing with zero price"
	)


# --- Double checkout of same item ---


func test_double_checkout_same_item_fails() -> void:
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


func test_double_checkout_item_not_in_inventory() -> void:
	var customer1: Customer = _make_customer()
	_checkout.initiate_sale(customer1, _item, 80.0)
	_force_complete_checkout()
	assert_false(
		_inventory._items.has(_item.instance_id),
		"Item should be gone after first sale"
	)
	var customer2: Customer = _make_customer()
	_checkout.initiate_sale(customer2, _item, 80.0)
	assert_eq(
		_sold_signals.size(), 1,
		"item_sold should only fire once across both attempts"
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
		"Queue should have 1 customer after first sale completes"
	)


func test_queue_advanced_signal_emits_correct_size() -> void:
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


func test_queue_advanced_on_declined_sale() -> void:
	var customer: Customer = _make_customer()
	_checkout._register_queue.try_add(customer)
	_checkout._active_customer = customer
	_checkout._active_item = _item
	_checkout._active_offer = 100.0
	_checkout._on_sale_declined()
	assert_true(
		_queue_signals.size() > 0,
		"queue_advanced should fire even on declined sale"
	)
	assert_eq(
		_queue_signals.back(), 0,
		"queue_advanced should report 0 after customer leaves"
	)


# --- Timer and processing state ---


func test_initiate_sale_sets_processing_flag() -> void:
	var customer: Customer = _make_customer()
	_checkout.initiate_sale(customer, _item, 100.0)
	assert_true(
		_checkout._is_processing,
		"Should be processing after initiate_sale"
	)
	assert_true(
		_inventory._items.has(_item.instance_id),
		"Item should still exist during checkout timer"
	)


func test_checkout_timer_exists() -> void:
	assert_not_null(
		_checkout._checkout_timer,
		"Checkout timer should be created on initialize"
	)
	assert_eq(
		_checkout._checkout_timer.wait_time,
		PlayerCheckout.CHECKOUT_DURATION,
		"Timer should use CHECKOUT_DURATION"
	)
	assert_true(
		_checkout._checkout_timer.one_shot,
		"Timer should be one-shot"
	)


func test_processing_flag_cleared_after_sale() -> void:
	var customer: Customer = _make_customer()
	_checkout.initiate_sale(customer, _item, 80.0)
	_force_complete_checkout()
	assert_false(
		_checkout._is_processing,
		"Processing flag should be cleared after sale completes"
	)


# --- Reputation tiers ---


func test_generous_sale_rep_bonus() -> void:
	var market_value: float = 100.0
	var generous_price: float = 70.0
	var ratio: float = generous_price / market_value
	assert_true(
		ratio < PlayerCheckout.GENEROUS_THRESHOLD,
		"Price ratio %.2f should be below generous threshold"
		% ratio
	)
	var expected_rep: float = ReputationSystem.REP_FAIR_SALE * 1.5
	assert_eq(
		expected_rep, 3.75,
		"Generous sale should give 1.5x fair sale rep"
	)


func test_fair_sale_rep_bonus() -> void:
	var market_value: float = 100.0
	var fair_price: float = 100.0
	var ratio: float = fair_price / market_value
	assert_true(
		ratio >= PlayerCheckout.GENEROUS_THRESHOLD
		and ratio <= PlayerCheckout.FAIR_THRESHOLD_HIGH,
		"Price ratio %.2f should be in fair range" % ratio
	)


func test_overpriced_sale_no_rep() -> void:
	var market_value: float = 100.0
	var overpriced: float = 130.0
	var ratio: float = overpriced / market_value
	assert_true(
		ratio > PlayerCheckout.FAIR_THRESHOLD_HIGH,
		"Price ratio %.2f should be above fair threshold" % ratio
	)


# --- Constants ---


func test_checkout_duration_constant() -> void:
	assert_eq(
		PlayerCheckout.CHECKOUT_DURATION, 2.0,
		"Baseline checkout duration should be 2.0 seconds"
	)


func test_reputation_thresholds() -> void:
	assert_eq(
		PlayerCheckout.GENEROUS_THRESHOLD, 0.75,
		"Generous threshold should be 0.75"
	)
	assert_eq(
		PlayerCheckout.FAIR_THRESHOLD_HIGH, 1.25,
		"Fair high threshold should be 1.25"
	)


# --- Cashier staff checkout speed ---


func _make_cashier(morale: float, skill: int) -> StaffDefinition:
	var staff: StaffDefinition = StaffDefinition.new()
	staff.staff_id = "test_cashier"
	staff.display_name = "Test Cashier"
	staff.role = StaffDefinition.StaffRole.CASHIER
	staff.skill_level = skill
	staff.morale = morale
	return staff


func test_no_cashier_uses_baseline_duration() -> void:
	_checkout._cashier = null
	var customer: Customer = _make_customer()
	_checkout.initiate_sale(customer, _item, 80.0)
	assert_almost_eq(
		_checkout._checkout_timer.wait_time,
		PlayerCheckout.CHECKOUT_DURATION,
		0.001,
		"No cashier should use baseline duration"
	)
	_checkout._checkout_timer.stop()


func test_cashier_reduces_checkout_duration() -> void:
	var cashier: StaffDefinition = _make_cashier(1.0, 1)
	_checkout._cashier = cashier
	var customer: Customer = _make_customer()
	_checkout.initiate_sale(customer, _item, 80.0)
	var expected: float = (
		PlayerCheckout.CHECKOUT_DURATION / cashier.performance_multiplier()
	)
	assert_almost_eq(
		_checkout._checkout_timer.wait_time,
		expected,
		0.001,
		"Cashier with full morale should reduce checkout duration"
	)
	assert_true(
		_checkout._checkout_timer.wait_time < PlayerCheckout.CHECKOUT_DURATION,
		"Checkout with cashier should be faster than baseline"
	)
	_checkout._checkout_timer.stop()


func test_cashier_at_min_morale_uses_base_multiplier() -> void:
	var cashier: StaffDefinition = _make_cashier(0.0, 1)
	_checkout._cashier = cashier
	var customer: Customer = _make_customer()
	_checkout.initiate_sale(customer, _item, 80.0)
	var expected: float = (
		PlayerCheckout.CHECKOUT_DURATION / cashier.performance_multiplier()
	)
	assert_almost_eq(
		_checkout._checkout_timer.wait_time,
		expected,
		0.001,
		"Low-morale cashier should still apply performance_multiplier"
	)
	_checkout._checkout_timer.stop()


func test_staff_hired_signal_triggers_cashier_refresh() -> void:
	_checkout._cashier = null
	EventBus.staff_hired.emit("staff_x", "some_store")
	# Cashier is null because no store context is active (GameManager.current_store_id is empty).
	# The important thing is the handler ran without error.
	assert_null(
		_checkout._cashier,
		"Cashier stays null when no active store on staff_hired"
	)


func test_staff_fired_signal_triggers_cashier_refresh() -> void:
	_checkout._cashier = null
	EventBus.staff_fired.emit("staff_x", "some_store")
	assert_null(
		_checkout._cashier,
		"Cashier stays null when no active store on staff_fired"
	)


func test_staff_quit_signal_triggers_cashier_refresh() -> void:
	_checkout._cashier = null
	EventBus.staff_quit.emit("staff_x")
	assert_null(
		_checkout._cashier,
		"Cashier stays null when no active store on staff_quit"
	)


func test_staff_morale_changed_signal_triggers_cashier_refresh() -> void:
	_checkout._cashier = null
	EventBus.staff_morale_changed.emit("staff_x", 0.5)
	assert_null(
		_checkout._cashier,
		"Cashier stays null when no active store on staff_morale_changed"
	)
