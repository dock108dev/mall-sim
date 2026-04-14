## Unit tests for EconomySystem cash transactions, daily reset, and serialization.
extends GutTest


var _economy: EconomySystem


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(500.0)


func test_add_cash_increases_balance() -> void:
	var before: float = _economy.get_cash()
	_economy.add_cash(100.0, "test deposit")
	assert_almost_eq(
		_economy.get_cash(), before + 100.0, 0.01,
		"Balance should increase by exact amount added"
	)


func test_deduct_cash_decreases_balance() -> void:
	_economy._current_cash = 200.0
	var result: bool = _economy.deduct_cash(50.0, "test expense")
	assert_true(result, "deduct_cash should return true on success")
	assert_almost_eq(
		_economy.get_cash(), 150.0, 0.01,
		"Balance should decrease by exact amount deducted"
	)


func test_deduct_cash_insufficient_funds_returns_false() -> void:
	_economy._current_cash = 10.0
	var result: bool = _economy.deduct_cash(100.0, "too expensive")
	assert_false(result, "deduct_cash should return false on insufficient funds")
	assert_almost_eq(
		_economy.get_cash(), 10.0, 0.01,
		"Balance should remain unchanged after failed deduction"
	)


func test_money_changed_signal_fires_on_add() -> void:
	watch_signals(EventBus)
	_economy.add_cash(50.0, "signal test add")
	assert_signal_emitted(
		EventBus, "money_changed",
		"money_changed should fire on add_cash"
	)
	var params: Array = get_signal_parameters(EventBus, "money_changed")
	assert_almost_eq(
		params[1] as float, _economy.get_cash(), 0.01,
		"Signal new_amount should match current balance"
	)


func test_money_changed_signal_fires_on_deduct() -> void:
	_economy._current_cash = 200.0
	watch_signals(EventBus)
	_economy.deduct_cash(25.0, "signal test deduct")
	assert_signal_emitted(
		EventBus, "money_changed",
		"money_changed should fire on deduct_cash"
	)
	var params: Array = get_signal_parameters(EventBus, "money_changed")
	assert_almost_eq(
		params[1] as float, 175.0, 0.01,
		"Signal new_amount should equal 175.0 after deducting 25 from 200"
	)


func test_transaction_completed_signal_on_add() -> void:
	watch_signals(EventBus)
	_economy.add_cash(75.0, "revenue test")
	assert_signal_emitted(
		EventBus, "transaction_completed",
		"transaction_completed should fire on add_cash"
	)
	var params: Array = get_signal_parameters(
		EventBus, "transaction_completed"
	)
	assert_almost_eq(
		params[0] as float, 75.0, 0.01,
		"transaction amount should be 75.0"
	)
	assert_true(
		params[1] as bool,
		"transaction success should be true"
	)


func test_transaction_completed_signal_on_failed_deduct() -> void:
	_economy._current_cash = 5.0
	watch_signals(EventBus)
	_economy.deduct_cash(100.0, "too much")
	assert_signal_emitted(
		EventBus, "transaction_completed",
		"transaction_completed should fire even on failure"
	)
	var params: Array = get_signal_parameters(
		EventBus, "transaction_completed"
	)
	assert_false(
		params[1] as bool,
		"transaction success should be false on insufficient funds"
	)


func test_daily_revenue_reset_clears_session_data() -> void:
	_economy.record_store_revenue("test_store", 250.0)
	assert_gt(
		_economy.get_store_daily_revenue("test_store"), 0.0,
		"Revenue should be recorded before reset"
	)
	_economy.reset_daily_totals()
	assert_eq(
		_economy.get_store_daily_revenue("test_store"), 0.0,
		"Store daily revenue should be 0 after reset"
	)
	assert_eq(
		_economy.get_items_sold_today(), 0,
		"Items sold today should be 0 after reset"
	)


func test_transaction_history_records_entry() -> void:
	_economy.add_cash(42.0, "sale")
	var summary: Dictionary = _economy.get_daily_summary()
	assert_gt(
		summary["transaction_count"] as int, 0,
		"Transaction count should be > 0 after a transaction"
	)
	assert_almost_eq(
		summary["total_revenue"] as float, 42.0, 0.01,
		"Total revenue should include the recorded transaction"
	)


func test_transaction_history_records_expense() -> void:
	_economy._current_cash = 300.0
	_economy.deduct_cash(80.0, "expense test")
	var summary: Dictionary = _economy.get_daily_summary()
	assert_almost_eq(
		summary["total_expenses"] as float, 80.0, 0.01,
		"Total expenses should include the deducted amount"
	)


func test_balance_never_goes_negative_on_deduct() -> void:
	_economy._current_cash = 20.0
	_economy.deduct_cash(50.0, "over budget")
	assert_true(
		_economy.get_cash() >= 0.0,
		"Balance must never go negative after failed deduction"
	)
	assert_almost_eq(
		_economy.get_cash(), 20.0, 0.01,
		"Balance should remain at original value"
	)


func test_serialize_deserialize_preserves_balance() -> void:
	_economy._current_cash = 1234.56
	_economy.add_cash(100.0, "pre-save revenue")
	_economy.record_store_revenue("shop_a", 100.0)
	var save_data: Dictionary = _economy.get_save_data()

	var fresh_economy: EconomySystem = EconomySystem.new()
	add_child_autofree(fresh_economy)
	fresh_economy.load_save_data(save_data)

	assert_almost_eq(
		fresh_economy.get_cash(), _economy.get_cash(), 0.01,
		"Balance should match after save/load round-trip"
	)
	assert_almost_eq(
		fresh_economy.get_store_daily_revenue("shop_a"),
		_economy.get_store_daily_revenue("shop_a"),
		0.01,
		"Store revenue should match after save/load round-trip"
	)


func test_serialize_deserialize_preserves_transactions() -> void:
	_economy._current_cash = 500.0
	_economy.add_cash(50.0, "income")
	_economy.deduct_cash(30.0, "cost")
	var save_data: Dictionary = _economy.get_save_data()

	var fresh_economy: EconomySystem = EconomySystem.new()
	add_child_autofree(fresh_economy)
	fresh_economy.load_save_data(save_data)

	var original_summary: Dictionary = _economy.get_daily_summary()
	var loaded_summary: Dictionary = fresh_economy.get_daily_summary()
	assert_eq(
		loaded_summary["transaction_count"] as int,
		original_summary["transaction_count"] as int,
		"Transaction count should survive round-trip"
	)


func test_daily_profit_calculation() -> void:
	_economy._current_cash = 1000.0
	_economy.record_store_revenue("store_a", 200.0)
	_economy.deduct_cash(80.0, "expense")
	var profit: float = _economy.get_daily_profit()
	assert_almost_eq(
		profit, 120.0, 0.01,
		"Daily profit should be revenue (200) minus expenses (80)"
	)


func test_reset_clears_transaction_history() -> void:
	_economy.add_cash(100.0, "before reset")
	_economy.reset_daily_totals()
	var summary: Dictionary = _economy.get_daily_summary()
	assert_eq(
		summary["transaction_count"] as int, 0,
		"Transaction count should be 0 after reset"
	)
	assert_almost_eq(
		summary["total_revenue"] as float, 0.0, 0.01,
		"Total revenue should be 0 after reset"
	)
