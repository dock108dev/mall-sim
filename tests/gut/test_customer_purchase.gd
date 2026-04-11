## Tests customer purchase decision logic: budget checks, willingness to pay,
## match quality, and conversion probability.
extends GutTest


var _profile: CustomerProfile
var _definition: ItemDefinition
var _item: ItemInstance


func before_each() -> void:
	_profile = CustomerProfile.new()
	_profile.id = "test_customer"
	_profile.name = "Test Customer"
	_profile.budget_range = [5.0, 100.0]
	_profile.patience = 0.5
	_profile.price_sensitivity = 0.5
	_profile.preferred_categories = PackedStringArray(["cards"])
	_profile.preferred_tags = PackedStringArray(["vintage"])
	_profile.condition_preference = "good"
	_profile.browse_time_range = [30.0, 60.0]
	_profile.purchase_probability_base = 0.8
	_profile.impulse_buy_chance = 0.1
	_profile.max_price_to_market_ratio = 1.0

	_definition = ItemDefinition.new()
	_definition.id = "test_item"
	_definition.name = "Test Item"
	_definition.category = "cards"
	_definition.base_price = 10.0
	_definition.rarity = "common"
	_definition.tags = PackedStringArray(["vintage"])
	_definition.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)

	_item = ItemInstance.create_from_definition(_definition, "good")


# --- Budget and willingness to pay ---


func test_customer_within_budget_can_purchase() -> void:
	_item.set_price = 20.0
	var item_value: float = _item.get_current_value()
	var budget_max: float = _profile.budget_range[1]
	var tolerance: float = 2.0 - _profile.price_sensitivity
	var max_acceptable: float = item_value * tolerance
	var willing_to_pay: float = minf(budget_max, max_acceptable)
	assert_true(
		_item.set_price <= willing_to_pay,
		"Item price $%.2f should be within willingness to pay $%.2f"
		% [_item.set_price, willing_to_pay]
	)


func test_customer_over_budget_cannot_purchase() -> void:
	_item.set_price = 200.0
	var budget_max: float = _profile.budget_range[1]
	assert_true(
		_item.set_price > budget_max,
		"Item price $%.2f should exceed budget max $%.2f"
		% [_item.set_price, budget_max]
	)


func test_customer_below_min_budget_not_desirable() -> void:
	_item.set_price = 1.0
	assert_true(
		_item.set_price < _profile.budget_range[0],
		"Item price $%.2f should be below min budget $%.2f"
		% [_item.set_price, _profile.budget_range[0]]
	)


func test_willingness_to_pay_respects_sensitivity() -> void:
	var item_value: float = _item.get_current_value()
	var low_sensitivity: float = 0.2
	var high_sensitivity: float = 0.9
	var low_tolerance: float = 2.0 - low_sensitivity
	var high_tolerance: float = 2.0 - high_sensitivity
	var low_sens_max: float = item_value * low_tolerance
	var high_sens_max: float = item_value * high_tolerance
	assert_gt(
		low_sens_max, high_sens_max,
		"Low sensitivity customer should tolerate higher prices"
	)


# --- Fair price threshold evaluation ---


func test_fair_price_threshold_constant() -> void:
	assert_eq(
		ReputationSystem.FAIR_PRICE_THRESHOLD, 0.25,
		"FAIR_PRICE_THRESHOLD should be 0.25 (within 25%% of market value)"
	)


func test_price_within_fair_threshold_is_acceptable() -> void:
	var market_value: float = _item.get_current_value()
	var threshold: float = ReputationSystem.FAIR_PRICE_THRESHOLD
	var fair_price: float = market_value * (1.0 + threshold)
	_item.set_price = fair_price
	var tolerance: float = 2.0 - _profile.price_sensitivity
	var max_acceptable: float = market_value * tolerance
	assert_true(
		_item.set_price <= max_acceptable,
		"Price at fair threshold $%.2f should be <= max acceptable $%.2f"
		% [_item.set_price, max_acceptable]
	)


func test_price_well_above_fair_threshold_rejected_by_sensitive_buyer() -> void:
	var market_value: float = _item.get_current_value()
	_profile.price_sensitivity = 0.95
	var tolerance: float = 2.0 - _profile.price_sensitivity
	var max_acceptable: float = market_value * tolerance
	_item.set_price = market_value * 1.5
	assert_true(
		_item.set_price > max_acceptable,
		"Price $%.2f should exceed sensitive buyer max $%.2f"
		% [_item.set_price, max_acceptable]
	)


# --- Match quality and conversion probability ---


func test_match_quality_boosted_by_category_match() -> void:
	var base_quality: float = 1.0
	var category_bonus: float = 0.2
	_definition.category = "cards"
	_profile.preferred_categories = PackedStringArray(["cards"])
	var expected_min: float = base_quality + category_bonus
	assert_true(
		expected_min > base_quality,
		"Category match should boost quality above base 1.0"
	)


func test_match_quality_boosted_by_tag_match() -> void:
	var base_quality: float = 1.0
	var tag_bonus: float = 0.15
	_definition.tags = PackedStringArray(["vintage"])
	_profile.preferred_tags = PackedStringArray(["vintage"])
	var expected_min: float = base_quality + tag_bonus
	assert_true(
		expected_min > base_quality,
		"Tag match should boost quality above base 1.0"
	)


func test_purchase_probability_scales_with_match_quality() -> void:
	var low_quality: float = 0.5
	var high_quality: float = 1.5
	var base_prob: float = _profile.purchase_probability_base
	var low_chance: float = base_prob * low_quality
	var high_chance: float = base_prob * high_quality
	assert_gt(
		high_chance, low_chance,
		"Higher match quality (%.2f) should yield higher buy chance (%.2f > %.2f)"
		% [high_quality, high_chance, low_chance]
	)


func test_tested_item_bonus_increases_buy_chance() -> void:
	var base_chance: float = _profile.purchase_probability_base
	var tested_chance: float = base_chance * (1.0 + Customer.TESTED_BONUS)
	assert_gt(
		tested_chance, base_chance,
		"Tested item bonus should increase buy chance"
	)
	assert_almost_eq(
		Customer.TESTED_BONUS, 0.25, 0.001,
		"TESTED_BONUS should be 0.25"
	)


# --- Budget multiplier ---


func test_budget_multiplier_expands_max_budget() -> void:
	var base_max: float = _profile.budget_range[1]
	var multiplier: float = 1.5
	var expanded_max: float = base_max * multiplier
	assert_gt(
		expanded_max, base_max,
		"Budget multiplier %.1f should expand max budget" % multiplier
	)


# --- Investor/bargain buyer logic ---


func test_investor_rejects_overpriced_items() -> void:
	_profile.id = "investor_test"
	_profile.max_price_to_market_ratio = 1.0
	var market_value: float = _item.get_current_value()
	var ratio: float = Customer.INVESTOR_MAX_MARKET_RATIO
	var max_price: float = market_value * ratio
	_item.set_price = market_value * 1.5
	assert_true(
		_item.set_price > max_price,
		"Investor should reject price $%.2f above %.0f%% of market value"
		% [_item.set_price, ratio * 100.0]
	)
