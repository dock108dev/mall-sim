## Tests that DifficultySystem modifiers apply to OrderSystem calculations.
extends GutTest


var _order_system: OrderSystem
var _saved_tier: StringName


func before_all() -> void:
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()


func before_each() -> void:
	_saved_tier = DifficultySystemSingleton.get_current_tier_id()
	_order_system = OrderSystem.new()
	add_child_autofree(_order_system)


func after_each() -> void:
	DifficultySystemSingleton.set_tier(_saved_tier)


# --- Supplier lead time ---


func test_easy_lead_time_reduces_delivery_days() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	# LIQUIDATOR base = 3 days; 3 × 0.80 = 2.4 → rounds to 2
	var days: int = _order_system.get_effective_delivery_days(
		OrderSystem.SupplierTier.LIQUIDATOR
	)
	assert_eq(days, 2, "Easy LIQUIDATOR lead time should round to 2 days")


func test_hard_lead_time_increases_delivery_days() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	# LIQUIDATOR base = 3 days; 3 × 1.30 = 3.9 → rounds to 4
	var days: int = _order_system.get_effective_delivery_days(
		OrderSystem.SupplierTier.LIQUIDATOR
	)
	assert_eq(days, 4, "Hard LIQUIDATOR lead time should round to 4 days")


func test_normal_lead_time_unchanged() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	# LIQUIDATOR base = 3 days; 3 × 1.0 = 3
	var days: int = _order_system.get_effective_delivery_days(
		OrderSystem.SupplierTier.LIQUIDATOR
	)
	assert_eq(days, 3, "Normal LIQUIDATOR lead time should equal base 3 days")


func test_easy_basic_lead_time_at_least_one() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	# BASIC base = 1 day; 1 × 0.80 = 0.8 → rounds to 1, clamped to >= 1
	var days: int = _order_system.get_effective_delivery_days(
		OrderSystem.SupplierTier.BASIC
	)
	assert_gte(days, 1, "Effective delivery days should never be less than 1")


func test_specialty_hard_lead_time_rounds_correctly() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	# SPECIALTY base = 2 days; 2 × 1.30 = 2.6 → rounds to 3
	var days: int = _order_system.get_effective_delivery_days(
		OrderSystem.SupplierTier.SPECIALTY
	)
	assert_eq(days, 3, "Hard SPECIALTY lead time should round to 3 days")


# --- Daily order limit ---


func test_easy_daily_limit_increased() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	# BASIC base = 500; 500 × 1.25 = 625
	var limit: float = _order_system.get_daily_limit(
		OrderSystem.SupplierTier.BASIC
	)
	assert_almost_eq(limit, 625.0, 0.01,
		"Easy BASIC daily limit should be 500 × 1.25 = 625"
	)


func test_hard_daily_limit_decreased() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	# BASIC base = 500; 500 × 0.75 = 375
	var limit: float = _order_system.get_daily_limit(
		OrderSystem.SupplierTier.BASIC
	)
	assert_almost_eq(limit, 375.0, 0.01,
		"Hard BASIC daily limit should be 500 × 0.75 = 375"
	)


func test_normal_daily_limit_unchanged() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	# BASIC base = 500; 500 × 1.0 = 500
	var limit: float = _order_system.get_daily_limit(
		OrderSystem.SupplierTier.BASIC
	)
	assert_almost_eq(limit, 500.0, 0.01,
		"Normal BASIC daily limit should equal base 500"
	)


func test_daily_limit_never_below_one() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	for tier_key: int in OrderSystem.TIER_CONFIG:
		var limit: float = _order_system.get_daily_limit(
			tier_key as OrderSystem.SupplierTier
		)
		assert_gte(limit, 1.0,
			"Daily limit should never be below 1 for tier %d" % tier_key
		)


# --- Stockout probability ---


func test_easy_stockout_probability() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	var prob: float = _order_system.get_stockout_probability()
	assert_almost_eq(
		prob, 0.00, 0.0001,
		"Easy stockout probability should be 0.00 (no stockouts)"
	)


func test_hard_stockout_probability() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	var prob: float = _order_system.get_stockout_probability()
	assert_almost_eq(
		prob, 0.15, 0.0001,
		"Hard stockout probability should be 0.15"
	)


func test_normal_stockout_probability() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	var prob: float = _order_system.get_stockout_probability()
	assert_almost_eq(
		prob, 0.05, 0.0001,
		"Normal stockout probability should be 0.05"
	)


func test_stockout_probability_non_negative() -> void:
	for tier_id: StringName in [&"easy", &"normal", &"hard"]:
		DifficultySystemSingleton.set_tier(tier_id)
		var prob: float = _order_system.get_stockout_probability()
		assert_gte(prob, 0.0,
			"Stockout probability should be non-negative on %s" % tier_id
		)
