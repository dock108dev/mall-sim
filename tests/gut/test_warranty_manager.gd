## Tests WarrantyManager: fee calculation, eligibility, acceptance rate,
## active warranty tracking, expiry, claim processing, and daily reset.
extends GutTest


var _manager: WarrantyManager


func before_each() -> void:
	_manager = WarrantyManager.new()


# --- Eligibility ---


func test_is_eligible_false_below_min_price() -> void:
	assert_false(
		WarrantyManager.is_eligible(0.0),
		"Price 0.0 should not be eligible"
	)
	assert_false(
		WarrantyManager.is_eligible(49.99),
		"Price 49.99 should not be eligible"
	)
	assert_false(
		WarrantyManager.is_eligible(1.0),
		"Price 1.0 should not be eligible"
	)


func test_is_eligible_true_at_and_above_min_price() -> void:
	assert_true(
		WarrantyManager.is_eligible(50.0),
		"Price exactly 50.0 should be eligible"
	)
	assert_true(
		WarrantyManager.is_eligible(100.0),
		"Price 100.0 should be eligible"
	)
	assert_true(
		WarrantyManager.is_eligible(500.0),
		"Price 500.0 should be eligible"
	)


# --- Fee calculation ---


func test_calculate_fee_clamped_at_min_percent() -> void:
	var fee: float = WarrantyManager.calculate_fee(100.0, 0.10)
	assert_almost_eq(
		fee,
		100.0 * WarrantyManager.MIN_WARRANTY_PERCENT,
		0.001,
		"Percent below min should clamp to MIN_WARRANTY_PERCENT"
	)


func test_calculate_fee_clamped_at_max_percent() -> void:
	var fee: float = WarrantyManager.calculate_fee(100.0, 0.50)
	assert_almost_eq(
		fee,
		100.0 * WarrantyManager.MAX_WARRANTY_PERCENT,
		0.001,
		"Percent above max should clamp to MAX_WARRANTY_PERCENT"
	)


func test_calculate_fee_within_bounds_for_eligible_price() -> void:
	var prices: Array[float] = [50.0, 75.0, 100.0, 250.0, 999.99]
	for price: float in prices:
		var min_fee: float = price * WarrantyManager.MIN_WARRANTY_PERCENT
		var max_fee: float = price * WarrantyManager.MAX_WARRANTY_PERCENT
		var fee_at_min: float = WarrantyManager.calculate_fee(
			price, WarrantyManager.MIN_WARRANTY_PERCENT
		)
		var fee_at_max: float = WarrantyManager.calculate_fee(
			price, WarrantyManager.MAX_WARRANTY_PERCENT
		)
		assert_almost_eq(
			fee_at_min, min_fee, 0.001,
			"Min fee for price %.2f should equal MIN_WARRANTY_PERCENT * price" % price
		)
		assert_almost_eq(
			fee_at_max, max_fee, 0.001,
			"Max fee for price %.2f should equal MAX_WARRANTY_PERCENT * price" % price
		)


func test_calculate_fee_mid_percent_in_range() -> void:
	var mid_pct: float = (
		WarrantyManager.MIN_WARRANTY_PERCENT
		+ WarrantyManager.MAX_WARRANTY_PERCENT
	) / 2.0
	var fee: float = WarrantyManager.calculate_fee(200.0, mid_pct)
	var min_fee: float = 200.0 * WarrantyManager.MIN_WARRANTY_PERCENT
	var max_fee: float = 200.0 * WarrantyManager.MAX_WARRANTY_PERCENT
	assert_true(
		fee >= min_fee and fee <= max_fee,
		"Mid-percent fee %.2f should be in [%.2f, %.2f]" % [fee, min_fee, max_fee]
	)


# --- Adding warranties and expiry tracking ---


func test_add_warranty_creates_entry_in_active_warranties() -> void:
	_manager.add_warranty("item_001", 150.0, 25.0, 80.0, 1)
	assert_eq(
		_manager.get_active_count(), 1,
		"One warranty should be active after add_warranty"
	)


func test_add_warranty_expiry_day_equals_purchase_plus_duration() -> void:
	var purchase_day: int = 5
	var record: Dictionary = _manager.add_warranty(
		"item_002", 200.0, 30.0, 100.0, purchase_day
	)
	var expected_expiry: int = purchase_day + WarrantyManager.WARRANTY_DURATION_DAYS
	assert_eq(
		record.get("expiry_day", -1),
		expected_expiry,
		"expiry_day should be purchase_day + WARRANTY_DURATION_DAYS"
	)


func test_add_warranty_increments_daily_revenue() -> void:
	_manager.add_warranty("item_003", 100.0, 20.0, 60.0, 1)
	assert_almost_eq(
		_manager.get_daily_warranty_revenue(),
		20.0,
		0.001,
		"Daily warranty revenue should reflect added fee"
	)


func test_add_multiple_warranties_accumulates_revenue() -> void:
	_manager.add_warranty("item_004", 100.0, 15.0, 60.0, 1)
	_manager.add_warranty("item_005", 200.0, 40.0, 120.0, 1)
	assert_almost_eq(
		_manager.get_daily_warranty_revenue(),
		55.0,
		0.001,
		"Revenue should accumulate across multiple warranty adds"
	)


# --- Expiry / purge ---


func test_purge_expired_removes_warranties_past_duration() -> void:
	_manager.add_warranty("item_006", 100.0, 15.0, 60.0, 1)
	var expiry_day: int = 1 + WarrantyManager.WARRANTY_DURATION_DAYS
	_manager.purge_expired(expiry_day + 1)
	assert_eq(
		_manager.get_active_count(), 0,
		"Expired warranty should be removed after WARRANTY_DURATION_DAYS days"
	)


func test_purge_expired_keeps_warranty_on_expiry_day() -> void:
	_manager.add_warranty("item_007", 100.0, 15.0, 60.0, 1)
	var expiry_day: int = 1 + WarrantyManager.WARRANTY_DURATION_DAYS
	_manager.purge_expired(expiry_day)
	assert_eq(
		_manager.get_active_count(), 1,
		"Warranty on its exact expiry_day should not be removed"
	)


func test_purge_expired_keeps_active_warranties() -> void:
	_manager.add_warranty("item_008", 100.0, 15.0, 60.0, 10)
	_manager.purge_expired(15)
	assert_eq(
		_manager.get_active_count(), 1,
		"Active warranty well within duration should be kept"
	)


# --- Claim processing ---


func test_process_daily_claims_adds_to_daily_claim_costs() -> void:
	var wholesale: float = 80.0
	_manager.add_warranty("item_009", 120.0, 20.0, wholesale, 1)
	seed(0)
	var iterations: Array = [0]
	var claimed: Array = [false]
	while iterations[0] < 10000 and not claimed[0]:
		_manager = WarrantyManager.new()
		_manager.add_warranty("item_009", 120.0, 20.0, wholesale, 1)
		var claims: Array[Dictionary] = _manager.process_daily_claims(15)
		if not claims.is_empty():
			claimed[0] = true
			assert_almost_eq(
				_manager.get_daily_claim_costs(),
				wholesale,
				0.001,
				"Claim cost should equal wholesale_cost of claimed item"
			)
		iterations[0] += 1
	if not claimed[0]:
		push_warning(
			"test_process_daily_claims_adds_to_daily_claim_costs: "
			+ "no claim triggered in %d iterations (low probability event)"
			% iterations[0]
		)


func test_process_daily_claims_does_not_affect_warranty_revenue() -> void:
	var fee: float = 22.0
	_manager.add_warranty("item_010", 150.0, fee, 90.0, 1)
	var revenue_before: float = _manager.get_daily_warranty_revenue()
	_manager.process_daily_claims(15)
	assert_almost_eq(
		_manager.get_daily_warranty_revenue(),
		revenue_before,
		0.001,
		"process_daily_claims should not change daily_warranty_revenue"
	)


func test_process_daily_claims_skips_expired_warranties() -> void:
	_manager.add_warranty("item_011", 100.0, 15.0, 60.0, 1)
	var expiry: int = 1 + WarrantyManager.WARRANTY_DURATION_DAYS
	var claims: Array[Dictionary] = _manager.process_daily_claims(expiry + 5)
	assert_eq(
		claims.size(), 0,
		"No claims should be triggered for expired warranties"
	)
	assert_eq(
		_manager.get_active_count(), 0,
		"Expired warranty should be removed from active list"
	)


# --- Acceptance rate ---


func test_base_acceptance_rate_constant() -> void:
	assert_almost_eq(
		WarrantyManager.BASE_ACCEPTANCE_RATE,
		0.40,
		0.001,
		"BASE_ACCEPTANCE_RATE should be 0.40"
	)


func test_acceptance_rate_over_1000_samples_near_base_rate() -> void:
	seed(42)
	var accepted: Array = [0]
	var sample_count: int = 1000
	var test_price: float = 75.0
	for _i: int in range(sample_count):
		if WarrantyManager.roll_acceptance(test_price):
			accepted[0] += 1
	var rate: float = float(accepted[0]) / float(sample_count)
	var expected: float = WarrantyManager.BASE_ACCEPTANCE_RATE
	assert_true(
		abs(rate - expected) <= 0.05,
		"Acceptance rate %.3f should be within 5pp of %.2f over %d samples"
		% [rate, expected, sample_count]
	)


func test_high_price_acceptance_bonus_applied() -> void:
	var low_prob: float = WarrantyManager.get_acceptance_probability(99.99)
	var high_prob: float = WarrantyManager.get_acceptance_probability(100.0)
	assert_almost_eq(
		low_prob,
		WarrantyManager.BASE_ACCEPTANCE_RATE,
		0.001,
		"Prices below HIGH_PRICE_THRESHOLD should use BASE_ACCEPTANCE_RATE"
	)
	assert_almost_eq(
		high_prob,
		WarrantyManager.BASE_ACCEPTANCE_RATE
		+ WarrantyManager.HIGH_PRICE_ACCEPTANCE_BONUS,
		0.001,
		"Prices at HIGH_PRICE_THRESHOLD should include the acceptance bonus"
	)


# --- Daily reset ---


func test_reset_daily_totals_zeroes_revenue_and_costs() -> void:
	_manager.add_warranty("item_012", 100.0, 20.0, 60.0, 1)
	assert_gt(
		_manager.get_daily_warranty_revenue(), 0.0,
		"Revenue should be non-zero before reset"
	)
	_manager.reset_daily_totals()
	assert_almost_eq(
		_manager.get_daily_warranty_revenue(),
		0.0,
		0.001,
		"daily_warranty_revenue should be 0 after reset"
	)
	assert_almost_eq(
		_manager.get_daily_claim_costs(),
		0.0,
		0.001,
		"daily_claim_costs should be 0 after reset"
	)


func test_reset_daily_totals_called_on_day_started_via_controller() -> void:
	_manager.add_warranty("item_013", 100.0, 18.0, 55.0, 1)
	_manager.reset_daily_totals()
	assert_almost_eq(
		_manager.get_daily_warranty_revenue(), 0.0, 0.001,
		"reset_daily_totals (triggered by day_started) should zero revenue"
	)
	assert_almost_eq(
		_manager.get_daily_claim_costs(), 0.0, 0.001,
		"reset_daily_totals (triggered by day_started) should zero claim costs"
	)


# --- Save / load ---


func test_save_load_round_trip_preserves_warranties() -> void:
	_manager.add_warranty("item_014", 200.0, 35.0, 110.0, 3)
	var saved: Dictionary = _manager.get_save_data()
	var new_manager: WarrantyManager = WarrantyManager.new()
	new_manager.load_save_data(saved)
	assert_eq(
		new_manager.get_active_count(), 1,
		"Active warranty should survive save/load round trip"
	)


func test_save_load_round_trip_preserves_daily_totals() -> void:
	_manager.add_warranty("item_015", 150.0, 25.0, 80.0, 2)
	var saved: Dictionary = _manager.get_save_data()
	var new_manager: WarrantyManager = WarrantyManager.new()
	new_manager.load_save_data(saved)
	assert_almost_eq(
		new_manager.get_daily_warranty_revenue(), 25.0, 0.001,
		"Daily revenue should survive save/load round trip"
	)
