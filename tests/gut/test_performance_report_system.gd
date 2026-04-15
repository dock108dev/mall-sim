## Tests PerformanceReportSystem: daily accumulation, report generation,
## field presence, profit arithmetic, economy expense integration,
## record flags, history management, and save/load round-trip.
extends GutTest


var _system: PerformanceReportSystem
var _economy: EconomySystem
var _saved_tier: StringName = &"normal"
var _saved_owned_stores: Array = []
var _saved_current_store_id: StringName = &""


func before_each() -> void:
	_saved_tier = DifficultySystemSingleton.get_current_tier_id()
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_current_store_id = GameManager.current_store_id
	DifficultySystemSingleton.set_tier(&"normal")
	GameManager.owned_stores = []
	GameManager.current_store_id = &""
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize()

	_system = PerformanceReportSystem.new()
	add_child_autofree(_system)
	_system.initialize()


func after_each() -> void:
	GameManager.owned_stores = _saved_owned_stores.duplicate()
	GameManager.current_store_id = _saved_current_store_id
	DifficultySystemSingleton.set_tier(_saved_tier)


func test_report_contains_required_fields() -> void:
	EventBus.day_started.emit(1)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	var data: Dictionary = report.to_dict()
	assert_true(data.has("revenue"), "report missing revenue")
	assert_true(data.has("expenses"), "report missing expenses")
	assert_true(data.has("profit"), "report missing profit")
	assert_true(data.has("items_sold"), "report missing items_sold")
	assert_true(data.has("day"), "report missing day")


func test_profit_equals_revenue_minus_expenses() -> void:
	EventBus.day_started.emit(1)
	EventBus.item_sold.emit("card_a", 200.0, "cards")
	_economy.charge(30.0, "order cost")
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_almost_eq(
		report.profit,
		report.revenue - report.expenses,
		0.01,
	)


func test_item_sold_increments_items_sold_count() -> void:
	EventBus.day_started.emit(1)
	EventBus.item_sold.emit("card_a", 25.0, "cards")
	EventBus.item_sold.emit("card_b", 75.0, "cards")
	EventBus.item_sold.emit("card_a", 25.0, "cards")
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.items_sold, 3)


func test_snapshot_revenue_populates_report() -> void:
	EventBus.day_started.emit(1)
	_economy.credit(150.0, &"sales")
	_economy.charge(40.0, "order cost")
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_almost_eq(report.revenue, 150.0, 0.01)
	assert_almost_eq(report.expenses, 40.0, 0.01)
	assert_almost_eq(report.profit, 110.0, 0.01)


func test_economy_expense_appears_in_total_expenses() -> void:
	EventBus.day_started.emit(1)
	_economy.charge(40.0, "staff wages")
	_economy.charge(60.0, "order cost")
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_almost_eq(report.expenses, 100.0, 0.01)


func test_rent_expense_appears_in_total_expenses() -> void:
	EventBus.day_started.emit(1)
	_economy.force_deduct_cash(75.0, "Rent: test_store")
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_true(
		report.expenses >= 75.0,
		"rent should appear in expenses",
	)


func test_failed_transaction_does_not_affect_expenses() -> void:
	EventBus.day_started.emit(1)
	_economy.deduct_cash(999999.0, "impossible purchase")
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_almost_eq(
		report.expenses, 0.0, 0.01,
		"failed deduction should not appear in expenses"
	)


func test_report_reset_on_day_started() -> void:
	EventBus.item_sold.emit("card_a", 25.0, "cards")
	EventBus.item_sold.emit("card_b", 15.0, "cards")
	_economy.charge(10.0, "some cost")
	EventBus.day_started.emit(2)
	EventBus.day_ended.emit(2)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.items_sold, 0)
	assert_almost_eq(report.revenue, 0.0, 0.01)
	assert_almost_eq(report.expenses, 0.0, 0.01)
	assert_almost_eq(report.profit, 0.0, 0.01)


func test_day_field_matches_emitted_day() -> void:
	EventBus.day_started.emit(7)
	EventBus.day_ended.emit(7)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.day, 7)


func test_day_field_matches_across_multiple_days() -> void:
	for d: int in [3, 4, 5]:
		EventBus.day_started.emit(d)
		EventBus.day_ended.emit(d)
	var history: Array[PerformanceReport] = _system.get_history()
	assert_eq(history[0].day, 3)
	assert_eq(history[1].day, 4)
	assert_eq(history[2].day, 5)


func test_top_item_sold_tracks_highest_revenue() -> void:
	EventBus.day_started.emit(1)
	EventBus.item_sold.emit("cheap_item", 10.0, "misc")
	EventBus.item_sold.emit("cheap_item", 10.0, "misc")
	EventBus.item_sold.emit("expensive_item", 100.0, "misc")
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.top_item_sold, "expensive_item")


func test_customer_satisfaction_rate() -> void:
	EventBus.day_started.emit(1)
	EventBus.customer_purchased.emit(&"store", &"item_a", 10.0, &"c1")
	EventBus.customer_purchased.emit(&"store", &"item_b", 20.0, &"c2")
	EventBus.customer_purchased.emit(&"store", &"item_c", 30.0, &"c3")
	EventBus.customer_left.emit({"satisfied": false})
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.customers_served, 3)
	assert_eq(report.walkouts, 1)
	assert_almost_eq(report.satisfaction_rate, 0.5, 0.01)


func test_satisfaction_rate_zero_when_no_customers() -> void:
	EventBus.day_started.emit(1)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.customers_served, 0)
	assert_eq(report.walkouts, 0)
	assert_almost_eq(report.satisfaction_rate, 0.0, 0.01)


func test_three_purchases_revenue_equals_sum_of_prices() -> void:
	EventBus.day_started.emit(1)
	EventBus.customer_purchased.emit(&"store", &"item_a", 15.0, &"c1")
	EventBus.customer_purchased.emit(&"store", &"item_b", 25.0, &"c2")
	EventBus.customer_purchased.emit(&"store", &"item_c", 60.0, &"c3")
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.customers_served, 3)
	assert_eq(report.units_sold, 3)
	assert_almost_eq(report.revenue, 100.0, 0.01)


func test_walkouts_not_incremented_on_satisfied_leave() -> void:
	EventBus.day_started.emit(1)
	EventBus.customer_left.emit({"satisfied": true})
	EventBus.customer_left.emit({"satisfied": true})
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.walkouts, 0)


func test_reputation_delta_tracked() -> void:
	EventBus.day_started.emit(1)
	EventBus.reputation_changed.emit("test_store", 55.0)
	EventBus.reputation_changed.emit("test_store", 60.0)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_almost_eq(report.reputation_delta, 10.0, 0.01)


func test_record_flags_best_day() -> void:
	EventBus.day_started.emit(1)
	_economy.credit(50.0, &"sales")
	EventBus.day_ended.emit(1)

	EventBus.day_started.emit(2)
	_economy.credit(100.0, &"sales")
	EventBus.day_ended.emit(2)

	var history: Array[PerformanceReport] = _system.get_history()
	assert_true(history[1].record_flags.get("best_day_revenue", false))


func test_record_flags_worst_day() -> void:
	EventBus.day_started.emit(1)
	_economy.credit(50.0, &"sales")
	EventBus.day_ended.emit(1)

	EventBus.day_started.emit(2)
	_economy.credit(10.0, &"sales")
	EventBus.day_ended.emit(2)

	var history: Array[PerformanceReport] = _system.get_history()
	assert_true(history[1].record_flags.get("worst_day_revenue", false))


func test_rolling_history_capped_at_30() -> void:
	for i: int in range(35):
		EventBus.day_started.emit(i + 1)
		EventBus.item_sold.emit("item", 10.0, "misc")
		EventBus.day_ended.emit(i + 1)
	var history: Array[PerformanceReport] = _system.get_history()
	assert_eq(history.size(), 30)
	assert_eq(history[0].day, 6)
	assert_eq(history[29].day, 35)


func test_history_sorted_ascending() -> void:
	for i: int in range(5):
		EventBus.day_started.emit(i + 1)
		EventBus.day_ended.emit(i + 1)
	var history: Array[PerformanceReport] = _system.get_history()
	for i: int in range(history.size() - 1):
		assert_lt(history[i].day, history[i + 1].day)


func test_save_load_round_trip() -> void:
	EventBus.day_started.emit(1)
	EventBus.item_sold.emit("card_a", 50.0, "cards")
	EventBus.customer_purchased.emit(&"store", &"card_a", 50.0, &"c1")
	EventBus.reputation_changed.emit("test_store", 55.0)
	EventBus.day_ended.emit(1)

	var save_data: Dictionary = _system.get_save_data()

	var loaded_system := PerformanceReportSystem.new()
	add_child_autofree(loaded_system)
	loaded_system.initialize()
	loaded_system.load_save_data(save_data)

	var loaded_history: Array[PerformanceReport] = (
		loaded_system.get_history()
	)
	assert_eq(loaded_history.size(), 1)
	var report: PerformanceReport = loaded_history[0]
	assert_eq(report.day, 1)
	assert_eq(report.items_sold, 1)
	assert_eq(report.units_sold, 1)
	assert_eq(report.customers_served, 1)
	assert_eq(report.walkouts, 0)
	assert_almost_eq(report.satisfaction_rate, 1.0, 0.01)
	assert_eq(report.top_item_sold, "card_a")


func test_performance_report_resource_serialization() -> void:
	var report := PerformanceReport.new()
	report.day = 5
	report.revenue = 123.45
	report.expenses = 50.0
	report.profit = 73.45
	report.items_sold = 10
	report.customers_served = 8
	report.satisfaction_rate = 0.75
	report.reputation_delta = 3.5
	report.top_item_sold = "rare_card"
	report.record_flags = {"best_day_revenue": true}

	var data: Dictionary = report.to_dict()
	var restored: PerformanceReport = PerformanceReport.from_dict(data)

	assert_eq(restored.day, 5)
	assert_almost_eq(restored.revenue, 123.45, 0.01)
	assert_almost_eq(restored.expenses, 50.0, 0.01)
	assert_almost_eq(restored.profit, 73.45, 0.01)
	assert_eq(restored.items_sold, 10)
	assert_eq(restored.customers_served, 8)
	assert_almost_eq(restored.satisfaction_rate, 0.75, 0.01)
	assert_almost_eq(restored.reputation_delta, 3.5, 0.01)
	assert_eq(restored.top_item_sold, "rare_card")
	assert_true(restored.record_flags.get("best_day_revenue", false))
