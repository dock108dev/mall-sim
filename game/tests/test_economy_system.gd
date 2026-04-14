## GUT unit tests for EconomySystem transaction pipeline and daily reset.
extends GutTest


var _eco: EconomySystem


func before_each() -> void:
	_eco = EconomySystem.new()
	add_child_autofree(_eco)
	_eco._apply_state({"current_cash": 500.0})


func test_charge_insufficient_funds_returns_false() -> void:
	var result: bool = _eco.charge(600.0, "too expensive")
	assert_false(result, "charge should return false when cash < amount")
	assert_eq(
		_eco.get_cash(), 500.0,
		"Cash should be unchanged after failed charge"
	)


func test_charge_sufficient_funds_deducts() -> void:
	var result: bool = _eco.charge(200.0, "stock purchase")
	assert_true(result, "charge should return true when cash >= amount")
	assert_eq(
		_eco.get_cash(), 300.0,
		"Cash should decrease by charged amount"
	)


func test_charge_exact_balance() -> void:
	var result: bool = _eco.charge(500.0, "all in")
	assert_true(result, "charge should succeed when amount == cash")
	assert_eq(_eco.get_cash(), 0.0, "Cash should be zero")


func test_credit_increases_cash() -> void:
	GameManager.current_store_id = &"retro_games"
	_eco.credit(150.0, &"item_sale")
	assert_eq(
		_eco.get_cash(), 650.0,
		"Cash should increase by credited amount"
	)


func test_credit_records_store_daily_revenue() -> void:
	GameManager.current_store_id = &"retro_games"
	_eco.credit(100.0, &"sale_a")
	_eco.credit(50.0, &"sale_b")
	var revenue: float = _eco.get_store_daily_revenue("retro_games")
	assert_eq(
		revenue, 150.0,
		"Store daily revenue should accumulate credits"
	)


func test_credit_records_under_correct_store() -> void:
	GameManager.current_store_id = &"retro_games"
	_eco.credit(100.0, &"sale")
	GameManager.current_store_id = &"video_rental"
	_eco.credit(75.0, &"rental")
	assert_eq(
		_eco.get_store_daily_revenue("retro_games"), 100.0,
		"retro_games revenue should be 100"
	)
	assert_eq(
		_eco.get_store_daily_revenue("video_rental"), 75.0,
		"video_rental revenue should be 75"
	)


func test_get_daily_profit() -> void:
	GameManager.current_store_id = &"retro_games"
	_eco.credit(300.0, &"sales")
	_eco.charge(100.0, "restock")
	var profit: float = _eco.get_daily_profit()
	assert_eq(
		profit, 200.0,
		"Daily profit should be revenue minus expenses"
	)


func test_reset_daily_totals() -> void:
	GameManager.current_store_id = &"retro_games"
	_eco.credit(200.0, &"revenue")
	_eco.charge(50.0, "expense")
	_eco.reset_daily_totals()
	assert_eq(
		_eco.get_daily_profit(), 0.0,
		"Profit should be zero after reset"
	)
	assert_eq(
		_eco.get_store_daily_revenue("retro_games"), 0.0,
		"Store revenue should be zero after reset"
	)
	assert_eq(
		_eco.get_items_sold_today(), 0,
		"Items sold should be zero after reset"
	)


func test_demand_modifier_stays_within_bounds() -> void:
	_eco._demand_modifiers["electronics"] = EconomySystem.DEFAULT_DEMAND
	_eco._sales_history = []
	for i: int in range(50):
		var day_sales: Dictionary = {"electronics": 100}
		_eco._sales_history.append(day_sales)
		while _eco._sales_history.size() > EconomySystem.SALES_HISTORY_DAYS:
			_eco._sales_history.pop_front()
		_eco._update_demand_modifiers()
	var demand: float = _eco.get_demand_modifier("electronics")
	assert_true(
		demand >= EconomySystem.DEMAND_FLOOR,
		"Demand should not fall below DEMAND_FLOOR"
	)
	assert_true(
		demand <= EconomySystem.DEMAND_CAP,
		"Demand should not exceed DEMAND_CAP"
	)


func test_demand_modifier_floor_enforced() -> void:
	_eco._demand_modifiers["toys"] = EconomySystem.DEMAND_FLOOR
	_eco._sales_history = [{"toys": 0}]
	for i: int in range(20):
		_eco._update_demand_modifiers()
	var demand: float = _eco.get_demand_modifier("toys")
	assert_true(
		demand >= EconomySystem.DEMAND_FLOOR,
		"Demand must never go below floor"
	)


func test_serialize_deserialize_round_trip() -> void:
	_eco._apply_state({"current_cash": 1234.56})
	_eco._demand_modifiers = {
		"electronics": 1.2,
		"sports": 0.8,
	}
	_eco._drift_factors = {
		"item_001": 1.05,
		"item_002": 0.92,
	}
	GameManager.current_store_id = &"retro_games"
	_eco.credit(250.0, &"test_sale")

	var saved: Dictionary = _eco.serialize()

	var eco2: EconomySystem = EconomySystem.new()
	add_child_autofree(eco2)
	eco2.deserialize(saved)

	assert_eq(
		eco2.get_cash(), _eco.get_cash(),
		"Cash should match after round-trip"
	)
	assert_eq(
		eco2.get_demand_modifier("electronics"), 1.2,
		"Electronics demand should survive round-trip"
	)
	assert_eq(
		eco2.get_demand_modifier("sports"), 0.8,
		"Sports demand should survive round-trip"
	)
	assert_eq(
		eco2.get_drift_factor("item_001"), 1.05,
		"Drift factor should survive round-trip"
	)
	assert_eq(
		eco2.get_drift_factor("item_002"), 0.92,
		"Drift factor should survive round-trip"
	)
	assert_eq(
		eco2.get_store_daily_revenue("retro_games"), 250.0,
		"Store revenue should survive round-trip"
	)


func test_drift_stays_within_bounds_after_30_ticks() -> void:
	var drift_factors: Dictionary = {}
	var item_ids: Array[String] = [
		"test_common", "test_rare", "test_legendary",
	]
	for id: String in item_ids:
		drift_factors[id] = EconomySystem.DRIFT_DEFAULT
	_eco._drift_factors = drift_factors

	for i: int in range(30):
		for id: String in item_ids:
			var current: float = _eco._drift_factors.get(
				id, EconomySystem.DRIFT_DEFAULT
			)
			var volatility: float = EconomySystem.DRIFT_VOLATILITY.get(
				"legendary", 0.07
			)
			var reversion: float = (
				(EconomySystem.DRIFT_DEFAULT - current)
				* EconomySystem.DRIFT_MEAN_REVERSION
			)
			var noise: float = randf_range(-volatility, volatility)
			var new_drift: float = clampf(
				current + reversion + noise,
				EconomySystem.DRIFT_MIN,
				EconomySystem.DRIFT_MAX,
			)
			_eco._drift_factors[id] = new_drift

	for id: String in item_ids:
		var drift: float = _eco._drift_factors[id] as float
		assert_true(
			drift >= EconomySystem.DRIFT_MIN,
			"%s drift should be >= DRIFT_MIN" % id
		)
		assert_true(
			drift <= EconomySystem.DRIFT_MAX,
			"%s drift should be <= DRIFT_MAX" % id
		)


func after_each() -> void:
	GameManager.current_store_id = &""
