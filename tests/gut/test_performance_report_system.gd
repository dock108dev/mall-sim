## Tests PerformanceReportSystem: daily accumulation, report generation,
## field presence, profit arithmetic, economy expense integration,
## record flags, history management, and save/load round-trip.
extends GutTest


var _system: PerformanceReportSystem
var _economy: EconomySystem
var _saved_tier: StringName = &"normal"
var _saved_owned_stores: Array = []
var _saved_current_store_id: StringName = &""
var _saved_day_started_connections: Array[Callable] = []
var _saved_day_ended_connections: Array[Callable] = []


func before_each() -> void:
	_saved_tier = DifficultySystemSingleton.get_current_tier_id()
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_current_store_id = GameManager.current_store_id
	DifficultySystemSingleton.set_tier(&"normal")
	GameManager.owned_stores = []
	GameManager.current_store_id = &""
	_saved_day_started_connections = _disconnect_signal(EventBus.day_started)
	_saved_day_ended_connections = _disconnect_signal(EventBus.day_ended)
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize()

	_system = PerformanceReportSystem.new()
	add_child_autofree(_system)
	_system.initialize()


func after_each() -> void:
	_system = null
	_economy = null
	_restore_signal(EventBus.day_started, _saved_day_started_connections)
	_restore_signal(EventBus.day_ended, _saved_day_ended_connections)
	GameManager.owned_stores = _saved_owned_stores.duplicate()
	GameManager.current_store_id = _saved_current_store_id
	DifficultySystemSingleton.set_tier(_saved_tier)


func _disconnect_signal(signal_ref: Signal) -> Array[Callable]:
	var callables: Array[Callable] = []
	for connection: Dictionary in signal_ref.get_connections():
		var callable: Callable = connection.get("callable", Callable()) as Callable
		if callable.is_valid():
			callables.append(callable)
			signal_ref.disconnect(callable)
	return callables


func _restore_signal(signal_ref: Signal, callables: Array[Callable]) -> void:
	for callable: Callable in callables:
		if callable.is_valid() and not signal_ref.is_connected(callable):
			signal_ref.connect(callable)


func test_generate_report_contains_required_fields() -> void:
	EventBus.day_started.emit(1)
	var report: Dictionary = _system.generate_report()
	assert_true(report.has("gross_revenue"), "report missing gross_revenue")
	assert_true(report.has("total_expenses"), "report missing total_expenses")
	assert_true(report.has("net_profit"), "report missing net_profit")
	assert_true(report.has("units_sold"), "report missing units_sold")
	assert_true(report.has("day"), "report missing day")


func test_generate_report_net_profit_equals_revenue_minus_expenses() -> void:
	EventBus.day_started.emit(1)
	EventBus.transaction_completed.emit(200.0, true, "card sale")
	_economy.charge(30.0, "order cost")
	var report: Dictionary = _system.generate_report()
	assert_almost_eq(
		report.get("net_profit", 0.0),
		float(report.get("gross_revenue", 0.0))
			- float(report.get("total_expenses", 0.0)),
		0.01,
	)


func test_successful_transaction_completed_increments_gross_revenue() -> void:
	EventBus.day_started.emit(1)
	EventBus.transaction_completed.emit(25.0, true, "card sale")
	EventBus.transaction_completed.emit(75.0, true, "poster sale")
	var report: Dictionary = _system.generate_report()
	assert_almost_eq(report.get("gross_revenue", 0.0), 100.0, 0.01)


func test_failed_transaction_does_not_affect_gross_revenue() -> void:
	EventBus.day_started.emit(1)
	EventBus.transaction_completed.emit(25.0, true, "card sale")
	EventBus.transaction_completed.emit(999.0, false, "Insufficient funds")
	var report: Dictionary = _system.generate_report()
	assert_almost_eq(report.get("gross_revenue", 0.0), 25.0, 0.01)


func test_snapshot_revenue_populates_report() -> void:
	EventBus.day_started.emit(1)
	_economy.credit(150.0, &"sales")
	_economy.charge(40.0, "order cost")
	var report: Dictionary = _system.generate_report()
	assert_almost_eq(report.get("gross_revenue", 0.0), 150.0, 0.01)
	assert_almost_eq(report.get("total_expenses", 0.0), 40.0, 0.01)
	assert_almost_eq(report.get("net_profit", 0.0), 110.0, 0.01)


func test_economy_expense_appears_in_total_expenses() -> void:
	EventBus.day_started.emit(1)
	_economy.charge(40.0, "staff wages")
	_economy.charge(60.0, "order cost")
	var report: Dictionary = _system.generate_report()
	assert_almost_eq(report.get("total_expenses", 0.0), 100.0, 0.01)


func test_rent_expense_appears_in_total_expenses() -> void:
	EventBus.day_started.emit(1)
	_economy.force_deduct_cash(75.0, "Rent: test_store")
	var report: Dictionary = _system.generate_report()
	assert_almost_eq(report.get("total_expenses", 0.0), 75.0, 0.01)


func test_failed_transaction_does_not_affect_expenses() -> void:
	EventBus.day_started.emit(1)
	_economy.deduct_cash(999999.0, "impossible purchase")
	var report: Dictionary = _system.generate_report()
	assert_almost_eq(
		report.get("total_expenses", 0.0), 0.0, 0.01,
		"failed deduction should not appear in expenses"
	)


func test_generate_report_resets_on_day_started() -> void:
	EventBus.day_started.emit(1)
	EventBus.transaction_completed.emit(25.0, true, "card sale")
	_economy.charge(10.0, "order cost")
	EventBus.customer_purchased.emit(&"store", &"item_a", 25.0, &"c1")
	EventBus.day_started.emit(2)
	var report: Dictionary = _system.generate_report()
	assert_almost_eq(report.get("gross_revenue", 0.0), 0.0, 0.01)
	assert_almost_eq(report.get("total_expenses", 0.0), 0.0, 0.01)
	assert_almost_eq(report.get("net_profit", 0.0), 0.0, 0.01)
	assert_eq(report.get("units_sold", -1), 0)


func test_generate_report_resets_snapshot_backed_values_on_day_started() -> void:
	EventBus.day_started.emit(1)
	EventBus.daily_financials_snapshot.emit(125.0, 50.0, 75.0)
	EventBus.customer_purchased.emit(&"store", &"item_a", 20.0, &"c1")
	var pre_reset_report: Dictionary = _system.generate_report()
	assert_almost_eq(pre_reset_report.get("gross_revenue", 0.0), 125.0, 0.01)
	assert_almost_eq(pre_reset_report.get("total_expenses", 0.0), 50.0, 0.01)
	assert_eq(pre_reset_report.get("units_sold", -1), 1)

	EventBus.day_started.emit(2)

	var reset_report: Dictionary = _system.generate_report()
	assert_almost_eq(reset_report.get("gross_revenue", 0.0), 0.0, 0.01)
	assert_almost_eq(reset_report.get("total_expenses", 0.0), 0.0, 0.01)
	assert_almost_eq(reset_report.get("net_profit", 0.0), 0.0, 0.01)
	assert_eq(reset_report.get("units_sold", -1), 0)
	assert_eq(reset_report.get("day", -1), 2)


func test_generate_report_day_field_matches_current_day() -> void:
	EventBus.day_started.emit(7)
	var report: Dictionary = _system.generate_report()
	assert_eq(report.get("day", -1), 7)


func test_item_sold_increments_items_sold_count() -> void:
	EventBus.day_started.emit(1)
	EventBus.item_sold.emit("card_a", 25.0, "cards")
	EventBus.item_sold.emit("card_b", 75.0, "cards")
	EventBus.item_sold.emit("card_a", 25.0, "cards")
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.items_sold, 3)


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


func test_top_item_sold_uses_highest_single_unit_revenue() -> void:
	EventBus.day_started.emit(1)
	EventBus.item_sold.emit("steady_item", 40.0, "misc")
	EventBus.item_sold.emit("steady_item", 40.0, "misc")
	EventBus.item_sold.emit("premium_item", 60.0, "misc")
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.top_item_sold, "premium_item")


func test_customer_satisfaction_rate() -> void:
	EventBus.day_started.emit(1)
	EventBus.customer_left.emit({"customer_id": 1, "satisfied": true})
	EventBus.customer_left.emit({"customer_id": 2, "satisfied": true})
	EventBus.customer_left.emit({"customer_id": 3, "satisfied": false})
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.customers_served, 3)
	assert_eq(report.walkouts, 1)
	assert_almost_eq(report.satisfaction_rate, 0.667, 0.01)


func test_purchase_and_matching_leave_do_not_double_count_customer() -> void:
	EventBus.day_started.emit(1)
	EventBus.customer_purchased.emit(&"store", &"item_a", 10.0, &"42")
	EventBus.customer_left.emit({"customer_id": 42, "satisfied": true})
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.customers_served, 1)
	assert_almost_eq(report.satisfaction_rate, 1.0, 0.01)


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
	EventBus.reputation_changed.emit("test_store", 0.0, 55.0)
	EventBus.reputation_changed.emit("test_store", 0.0, 60.0)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_almost_eq(report.reputation_delta, 5.0, 0.01)


func test_record_flags_best_day() -> void:
	EventBus.day_started.emit(1)
	_economy.credit(50.0, &"sales")
	EventBus.day_ended.emit(1)

	EventBus.day_started.emit(2)
	_economy.credit(100.0, &"sales")
	EventBus.day_ended.emit(2)

	var history: Array[PerformanceReport] = _system.get_history()
	assert_true(history[1].record_flags.get("best_day_revenue", false))
	assert_false(history[1].record_flags.get("worst_day_revenue", true))


func test_record_flags_worst_day() -> void:
	EventBus.day_started.emit(1)
	_economy.credit(50.0, &"sales")
	EventBus.day_ended.emit(1)

	EventBus.day_started.emit(2)
	_economy.credit(10.0, &"sales")
	EventBus.day_ended.emit(2)

	var history: Array[PerformanceReport] = _system.get_history()
	assert_true(history[1].record_flags.get("worst_day_revenue", false))
	assert_false(history[1].record_flags.get("best_day_revenue", true))


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
	EventBus.reputation_changed.emit("test_store", 0.0, 55.0)
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
