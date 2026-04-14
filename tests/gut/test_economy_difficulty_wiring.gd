## Tests that DifficultySystem modifiers apply to EconomySystem operations.
extends GutTest


var _economy: EconomySystem
var _saved_tier: StringName


func before_each() -> void:
	_saved_tier = DifficultySystemSingleton.get_current_tier_id()
	_economy = EconomySystem.new()
	add_child_autofree(_economy)


func after_each() -> void:
	DifficultySystemSingleton.set_tier(_saved_tier)


func test_easy_starting_cash_multiplied_by_1_50() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	_economy.initialize(1000.0)
	assert_almost_eq(
		_economy.get_cash(), 1500.0, 0.01,
		"Easy starting cash should be 1000 × 1.50 = 1500"
	)


func test_hard_starting_cash_multiplied_by_0_70() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	_economy.initialize(1000.0)
	assert_almost_eq(
		_economy.get_cash(), 700.0, 0.01,
		"Hard starting cash should be 1000 × 0.70 = 700"
	)


func test_normal_starting_cash_unchanged() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	_economy.initialize(1000.0)
	assert_almost_eq(
		_economy.get_cash(), 1000.0, 0.01,
		"Normal starting cash should be 1000 × 1.0 = 1000"
	)


func test_easy_wholesale_cost_reduced() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	_economy.initialize(1000.0)
	var result: Array = []
	_economy._on_order_cash_deduct(100.0, "test order", result)
	assert_true(result[0] as bool, "Deduction should succeed")
	assert_almost_eq(
		_economy.get_cash(), 1500.0 - 85.0, 0.01,
		"Easy wholesale cost should be 100 × 0.85 = 85"
	)


func test_hard_wholesale_cost_increased() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	_economy.initialize(2000.0)
	var result: Array = []
	_economy._on_order_cash_deduct(100.0, "test order", result)
	assert_true(result[0] as bool, "Deduction should succeed")
	var expected_cash: float = 2000.0 * 0.70 - 100.0 * 1.15
	assert_almost_eq(
		_economy.get_cash(), expected_cash, 0.01,
		"Hard wholesale cost should be 100 × 1.15 = 115"
	)


func test_easy_order_cash_check_uses_adjusted_cost() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	_economy.initialize(100.0)
	var result: Array = []
	_economy._on_order_cash_check(160.0, result)
	assert_true(
		result[0] as bool,
		"Easy check: 150 cash >= 160 × 0.85 (136) should pass"
	)


func test_hard_order_cash_check_uses_adjusted_cost() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	_economy.initialize(100.0)
	var result: Array = []
	_economy._on_order_cash_check(65.0, result)
	assert_false(
		result[0] as bool,
		"Hard check: 70 cash < 65 × 1.15 (74.75) should fail"
	)
