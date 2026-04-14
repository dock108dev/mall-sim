## Tests that CustomerSystem reads difficulty modifiers per-call for foot traffic,
## purchase probability, and customer budget.
extends GutTest


var _system: CustomerSystem
var _profile: CustomerTypeDefinition
var _original_tier: StringName


func before_each() -> void:
	_original_tier = DifficultySystemSingleton.get_current_tier_id()

	_system = CustomerSystem.new()
	add_child_autofree(_system)
	_system.max_customers_in_mall = 1000

	_profile = CustomerTypeDefinition.new()
	_profile.id = "test_customer"
	_profile.customer_name = "Test Customer"
	_profile.budget_range = [5.0, 100.0]
	_profile.patience = 0.5
	_profile.price_sensitivity = 0.5
	_profile.preferred_categories = PackedStringArray(["cards"])
	_profile.preferred_tags = PackedStringArray([])
	_profile.condition_preference = "good"
	_profile.browse_time_range = [30.0, 60.0]
	_profile.purchase_probability_base = 0.8
	_profile.impulse_buy_chance = 0.1
	_profile.mood_tags = PackedStringArray([])


func after_each() -> void:
	DifficultySystemSingleton.set_tier(_original_tier)


# --- foot_traffic_multiplier ---


func test_easy_foot_traffic_is_1_30x_normal() -> void:
	_system._current_hour = 12
	_system._current_day_of_week = 0

	DifficultySystemSingleton.set_tier(&"normal")
	var normal_target: int = _system.get_spawn_target()

	DifficultySystemSingleton.set_tier(&"easy")
	var easy_target: int = _system.get_spawn_target()

	assert_gt(normal_target, 0, "Normal spawn target must be positive")
	var ratio: float = float(easy_target) / float(normal_target)
	assert_almost_eq(ratio, 1.30, 0.05, "Easy foot traffic should be ~1.30x Normal")


func test_hard_foot_traffic_is_0_75x_normal() -> void:
	_system._current_hour = 12
	_system._current_day_of_week = 0

	DifficultySystemSingleton.set_tier(&"normal")
	var normal_target: int = _system.get_spawn_target()

	DifficultySystemSingleton.set_tier(&"hard")
	var hard_target: int = _system.get_spawn_target()

	assert_gt(normal_target, 0, "Normal spawn target must be positive")
	var ratio: float = float(hard_target) / float(normal_target)
	assert_almost_eq(ratio, 0.75, 0.05, "Hard foot traffic should be ~0.75x Normal")


func test_normal_foot_traffic_matches_baseline() -> void:
	_system._current_hour = 12
	_system._current_day_of_week = 0

	DifficultySystemSingleton.set_tier(&"normal")
	var first: int = _system.get_spawn_target()
	var second: int = _system.get_spawn_target()
	assert_eq(first, second, "Normal repeated calls must return the same target")


# --- purchase_probability_multiplier ---


func test_easy_purchase_intent_is_1_25x_normal() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	var normal_intent: float = _system.get_purchase_intent_for_category(
		_profile, &"cards"
	)

	DifficultySystemSingleton.set_tier(&"easy")
	var easy_intent: float = _system.get_purchase_intent_for_category(
		_profile, &"cards"
	)

	assert_almost_eq(
		easy_intent, clampf(normal_intent * 1.25, 0.0, 1.0), 0.01,
		"Easy purchase intent should be normal * 1.25 (clamped to 1.0)"
	)


func test_hard_purchase_intent_is_0_70x_normal() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	var normal_intent: float = _system.get_purchase_intent_for_category(
		_profile, &"cards"
	)

	DifficultySystemSingleton.set_tier(&"hard")
	var hard_intent: float = _system.get_purchase_intent_for_category(
		_profile, &"cards"
	)

	assert_almost_eq(
		hard_intent, normal_intent * 0.70, 0.01,
		"Hard purchase intent should be normal * 0.70"
	)


func test_purchase_intent_clamped_to_1() -> void:
	_profile.purchase_probability_base = 0.9
	DifficultySystemSingleton.set_tier(&"easy")
	var intent: float = _system.get_purchase_intent_for_category(
		_profile, &"cards"
	)
	assert_true(
		intent <= 1.0,
		"Purchase intent must never exceed 1.0 (got %.3f)" % intent
	)


func test_normal_purchase_intent_matches_baseline() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	var intent: float = _system.get_purchase_intent_for_category(
		_profile, &"cards"
	)
	assert_almost_eq(
		intent, _profile.purchase_probability_base, 0.001,
		"Normal purchase intent should equal base probability (no modifier)"
	)


# --- customer_budget_multiplier ---


func test_easy_budget_modifier_is_1_20() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	var mult: float = DifficultySystemSingleton.get_modifier(&"customer_budget_multiplier")
	assert_almost_eq(mult, 1.20, 0.001, "Easy customer_budget_multiplier should be 1.20")


func test_hard_budget_modifier_is_0_80() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	var mult: float = DifficultySystemSingleton.get_modifier(&"customer_budget_multiplier")
	assert_almost_eq(mult, 0.80, 0.001, "Hard customer_budget_multiplier should be 0.80")


func test_normal_budget_modifier_is_1_00() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	var mult: float = DifficultySystemSingleton.get_modifier(&"customer_budget_multiplier")
	assert_almost_eq(mult, 1.00, 0.001, "Normal customer_budget_multiplier should be 1.00")


# --- modifiers read per-call, not cached ---


func test_foot_traffic_reflects_mid_playthrough_change() -> void:
	_system._current_hour = 12
	_system._current_day_of_week = 0

	DifficultySystemSingleton.set_tier(&"easy")
	var easy_target: int = _system.get_spawn_target()

	DifficultySystemSingleton.set_tier(&"hard")
	var hard_target: int = _system.get_spawn_target()

	assert_lt(
		hard_target, easy_target,
		"Switching Easy→Hard mid-playthrough must reduce spawn target immediately"
	)


func test_purchase_intent_reflects_mid_playthrough_change() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	var easy_intent: float = _system.get_purchase_intent_for_category(
		_profile, &"cards"
	)

	DifficultySystemSingleton.set_tier(&"hard")
	var hard_intent: float = _system.get_purchase_intent_for_category(
		_profile, &"cards"
	)

	assert_lt(
		hard_intent, easy_intent,
		"Switching Easy→Hard mid-playthrough must reduce purchase intent immediately"
	)
