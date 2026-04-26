## Tests late fee calculation in VideoRentalStoreController.
extends GutTest


var _controller: VideoRentalStoreController
var _economy: EconomySystem


func before_each() -> void:
	_controller = VideoRentalStoreController.new()
	add_child_autofree(_controller)
	# _collect_late_fee fails loud without an economy_system (it parks the fee
	# in _pending_late_fees instead of bumping _daily_late_fee_total). Wire one
	# so the cash-flow path the formula tests assert against actually runs.
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_controller.set_economy_system(_economy)


func test_no_late_fee_on_exact_return_day() -> void:
	_controller._grace_period_days = 0
	var rental: Dictionary = _make_rental("item_1", 2.0, 5, 5)
	_controller.rental_records["item_1"] = rental
	var overdue: Array[Dictionary] = _controller.get_overdue_rentals(5)
	assert_eq(
		overdue.size(), 0,
		"Returning on exact return_day should not be overdue"
	)


func test_grace_period_prevents_early_overdue() -> void:
	_controller._grace_period_days = 1
	var rental: Dictionary = _make_rental("item_1", 2.0, 5, 5)
	_controller.rental_records["item_1"] = rental
	var overdue: Array[Dictionary] = _controller.get_overdue_rentals(6)
	assert_eq(
		overdue.size(), 0,
		"Within grace period should not be overdue"
	)


func test_overdue_after_grace_period() -> void:
	_controller._grace_period_days = 1
	var rental: Dictionary = _make_rental("item_1", 2.0, 5, 5)
	_controller.rental_records["item_1"] = rental
	var overdue: Array[Dictionary] = _controller.get_overdue_rentals(7)
	assert_eq(
		overdue.size(), 1,
		"Past grace period should be overdue"
	)


func test_late_fee_formula_basic() -> void:
	_controller._base_late_fee = 1.0
	_controller._per_day_rate = 0.5
	_controller._max_late_fee = 15.0
	var rental: Dictionary = _make_rental("item_1", 2.0, 3, 3)
	_controller._collect_late_fee(rental, 2)
	assert_almost_eq(
		_controller._daily_late_fee_total, 2.0, 0.001,
		"Late fee should be base(1.0) + 2*per_day(0.5) = 2.0"
	)


func test_late_fee_capped_at_max() -> void:
	_controller._base_late_fee = 1.0
	_controller._per_day_rate = 0.5
	_controller._max_late_fee = 3.0
	var rental: Dictionary = _make_rental("item_1", 2.0, 3, 3)
	_controller._collect_late_fee(rental, 10)
	assert_almost_eq(
		_controller._daily_late_fee_total, 3.0, 0.001,
		"Late fee should be capped at max_late_fee"
	)


func test_late_fee_one_day_overdue() -> void:
	_controller._base_late_fee = 1.0
	_controller._per_day_rate = 0.5
	_controller._max_late_fee = 15.0
	var rental: Dictionary = _make_rental("item_1", 2.0, 3, 3)
	_controller._collect_late_fee(rental, 1)
	assert_almost_eq(
		_controller._daily_late_fee_total, 1.5, 0.001,
		"1 day overdue: base(1.0) + 1*per_day(0.5) = 1.5"
	)


func test_daily_total_accumulates() -> void:
	_controller._base_late_fee = 1.0
	_controller._per_day_rate = 0.5
	_controller._max_late_fee = 15.0
	var r1: Dictionary = _make_rental("item_1", 2.0, 3, 3)
	var r2: Dictionary = _make_rental("item_2", 3.0, 4, 4)
	_controller._collect_late_fee(r1, 1)
	_controller._collect_late_fee(r2, 2)
	assert_almost_eq(
		_controller._daily_late_fee_total, 3.5, 0.001,
		"Daily total should accumulate: 1.5 + 2.0 = 3.5"
	)


func test_get_daily_late_fee_total() -> void:
	_controller._daily_late_fee_total = 5.5
	assert_almost_eq(
		_controller.get_daily_late_fee_total(), 5.5, 0.001,
		"get_daily_late_fee_total should return accumulated value"
	)


func _make_rental(
	instance_id: String,
	rental_fee: float,
	checkout_day: int,
	return_day: int,
) -> Dictionary:
	return {
		"instance_id": instance_id,
		"customer_id": "",
		"category": "vhs_tapes",
		"rental_fee": rental_fee,
		"rental_tier": "three_day",
		"checkout_day": checkout_day,
		"return_day": return_day,
	}
