## Integration test verifying customer_purchased updates EconomySystem and
## PerformanceReportSystem atomically with no double-counting.
extends GutTest


var _economy: EconomySystem
var _perf_report: PerformanceReportSystem


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(500.0)

	_perf_report = PerformanceReportSystem.new()
	add_child_autofree(_perf_report)
	_perf_report.initialize()


func test_single_purchase_increases_economy_cash() -> void:
	EventBus.customer_purchased.emit(
		&"store_01", &"item_boots", 24.99, &"npc_001"
	)
	assert_almost_eq(
		_economy.get_cash(), 524.99, 0.01,
		"EconomySystem cash should increase by exact sale price"
	)


func test_single_purchase_updates_perf_daily_revenue() -> void:
	EventBus.customer_purchased.emit(
		&"store_01", &"item_boots", 24.99, &"npc_001"
	)
	assert_almost_eq(
		_perf_report.get_daily_revenue(), 24.99, 0.01,
		"PerformanceReportSystem daily_revenue should equal sale price"
	)


func test_single_purchase_increments_units_sold() -> void:
	EventBus.customer_purchased.emit(
		&"store_01", &"item_boots", 24.99, &"npc_001"
	)
	assert_eq(
		_perf_report.get_daily_units_sold(), 1,
		"PerformanceReportSystem daily_units_sold should be 1"
	)


func test_single_purchase_increments_customers_served() -> void:
	EventBus.customer_purchased.emit(
		&"store_01", &"item_boots", 24.99, &"npc_001"
	)
	assert_eq(
		_perf_report.get_daily_customers_served(), 1,
		"PerformanceReportSystem daily_customers_served should be 1"
	)


func test_four_purchases_accumulate_in_both_systems() -> void:
	var prices: Array[float] = [24.99, 15.00, 8.50, 31.25]
	EventBus.customer_purchased.emit(&"store_01", &"item_boots", prices[0], &"npc_001")
	EventBus.customer_purchased.emit(&"store_01", &"item_hat", prices[1], &"npc_002")
	EventBus.customer_purchased.emit(&"store_01", &"item_shirt", prices[2], &"npc_003")
	EventBus.customer_purchased.emit(&"store_01", &"item_jeans", prices[3], &"npc_004")

	var total: float = prices[0] + prices[1] + prices[2] + prices[3]
	assert_almost_eq(
		_economy.get_cash(), 500.0 + total, 0.01,
		"EconomySystem cash should equal starting cash plus sum of all prices"
	)
	assert_almost_eq(
		_perf_report.get_daily_revenue(), total, 0.01,
		"PerformanceReportSystem daily_revenue should equal sum of all prices"
	)


func test_no_double_counting_one_signal_increments_each_system_once() -> void:
	EventBus.customer_purchased.emit(
		&"store_01", &"item_boots", 24.99, &"npc_001"
	)
	assert_eq(
		_perf_report.get_daily_units_sold(), 1,
		"One customer_purchased should produce exactly one unit increment"
	)
	assert_eq(
		_perf_report.get_daily_customers_served(), 1,
		"One customer_purchased should produce exactly one customer increment"
	)
	assert_almost_eq(
		_perf_report.get_daily_revenue(), 24.99, 0.01,
		"One customer_purchased should produce exactly one revenue increment"
	)
	assert_almost_eq(
		_economy.get_cash(), 524.99, 0.01,
		"One customer_purchased should increment cash exactly once"
	)
