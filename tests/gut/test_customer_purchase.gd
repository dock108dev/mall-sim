## ISSUE-028: Customer purchase decision coverage.
extends GutTest


const SAMPLE_SIZE: int = 2000
const CONVERSION_TOLERANCE: float = 0.04

var _profile: CustomerTypeDefinition
var _definition: ItemDefinition
var _item: ItemInstance


func before_each() -> void:
	_profile = CustomerTypeDefinition.new()
	_profile.id = "test_customer"
	_profile.customer_name = "Test Customer"
	_profile.budget_range = [5.0, 100.0]
	_profile.patience = 0.5
	_profile.price_sensitivity = 0.75
	_profile.preferred_categories = PackedStringArray(["cards"])
	_profile.preferred_tags = PackedStringArray([])
	_profile.condition_preference = "good"
	_profile.browse_time_range = [30.0, 60.0]
	_profile.purchase_probability_base = 1.0
	_profile.impulse_buy_chance = 0.0
	_profile.max_price_to_market_ratio = 1.0

	_definition = ItemDefinition.new()
	_definition.id = "test_card"
	_definition.item_name = "Test Card"
	_definition.category = "cards"
	_definition.base_price = 40.0
	_definition.rarity = "common"
	_definition.tags = PackedStringArray([])
	_definition.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)

	_item = ItemInstance.create_from_definition(_definition, "good")


func test_customer_with_budget_above_item_price_attempts_purchase() -> void:
	_item.player_set_price = 40.0
	var customer: Customer = _make_customer()

	customer._desired_item = _item
	customer._process_deciding()

	assert_eq(
		customer.current_state,
		Customer.State.PURCHASING,
		"Affordable desirable item should move customer to purchase"
	)


func test_customer_with_insufficient_budget_does_not_attempt_purchase() -> void:
	_item.player_set_price = 150.0
	var customer: Customer = _make_customer()

	customer._desired_item = _item
	customer._process_deciding()

	assert_eq(
		customer.current_state,
		Customer.State.LEAVING,
		"Item above budget should make customer leave instead of purchase"
	)


func test_fair_price_threshold_matches_decision_boundary() -> void:
	var market_value: float = _item.get_current_value()
	var threshold: float = ReputationSystemSingleton.FAIR_PRICE_THRESHOLD
	var fair_price: float = market_value * (1.0 + threshold)
	var unfair_price: float = market_value * (1.0 + threshold + 0.01)

	var fair_customer: Customer = _make_customer()
	_item.player_set_price = fair_price
	fair_customer._desired_item = _item
	fair_customer._process_deciding()

	assert_eq(
		fair_customer.current_state,
		Customer.State.PURCHASING,
		"Price at FAIR_PRICE_THRESHOLD should still be acceptable"
	)

	var unfair_customer: Customer = _make_customer()
	_item.player_set_price = unfair_price
	unfair_customer._desired_item = _item
	unfair_customer._process_deciding()

	assert_eq(
		unfair_customer.current_state,
		Customer.State.LEAVING,
		"Price above FAIR_PRICE_THRESHOLD should exceed this buyer's limit"
	)


func test_conversion_rate_matches_expected_probability() -> void:
	# Bypass the Day 1 tutorial guarantee in Customer._process_deciding so this
	# test exercises the standard profile/match-quality formula it asserts on.
	GameState.set_flag(&"first_sale_complete", true)
	_profile.purchase_probability_base = 0.4
	_profile.price_sensitivity = 0.75
	_item.player_set_price = 40.0
	var customer: Customer = _make_customer()
	var expected_probability: float = (
		_profile.purchase_probability_base
		* customer._calculate_match_quality(_item)
	)
	var purchases: int = 0

	seed(12345)
	for _i: int in range(SAMPLE_SIZE):
		customer.current_state = Customer.State.DECIDING
		customer._desired_item = _item
		customer._process_deciding()
		if customer.current_state == Customer.State.PURCHASING:
			purchases += 1

	var actual_probability: float = float(purchases) / float(SAMPLE_SIZE)
	assert_almost_eq(
		actual_probability,
		expected_probability,
		CONVERSION_TOLERANCE,
		"Observed conversion rate should match purchase_probability_base * match_quality"
	)


func _make_customer() -> Customer:
	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	customer.profile = _profile
	customer._budget_multiplier = 1.0
	return customer
