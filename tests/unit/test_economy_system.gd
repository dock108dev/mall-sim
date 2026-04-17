## Unit tests for EconomySystem cash flow, daily reset, and save/load behavior.
extends GutTest


var _economy: EconomySystem


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy._current_cash = 500.0
	EventBus.day_started.emit(1)


func test_add_cash_increases_balance() -> void:
	var initial_balance: float = _economy.get_cash()
	_economy.add_cash(100.0, "test deposit")

	assert_almost_eq(
		_economy.get_cash(), initial_balance + 100.0, 0.01,
		"Balance should increase by the exact amount added"
	)


func test_deduct_cash_decreases_balance() -> void:
	_economy._current_cash = 200.0

	var result: bool = _economy.deduct_cash(50.0, "test expense")

	assert_true(result, "deduct_cash should succeed when funds are available")
	assert_almost_eq(
		_economy.get_cash(), 150.0, 0.01,
		"Balance should decrease by the deducted amount"
	)


func test_deduct_cash_insufficient_funds_returns_false() -> void:
	_economy._current_cash = 10.0

	var result: bool = _economy.deduct_cash(100.0, "too expensive")

	assert_false(result, "deduct_cash should fail when funds are insufficient")
	assert_almost_eq(
		_economy.get_cash(), 10.0, 0.01,
		"Balance should stay unchanged after a failed deduction"
	)


func test_cash_changed_signal_fires_on_add() -> void:
	var initial_balance: float = _economy.get_cash()

	watch_signals(EventBus)
	_economy.add_cash(50.0, "signal test add")

	assert_signal_emitted(
		EventBus, "money_changed",
		"money_changed should fire when cash is added"
	)
	var params: Array = get_signal_parameters(EventBus, "money_changed")
	assert_almost_eq(params[0] as float, initial_balance, 0.01)
	assert_almost_eq(
		params[1] as float, initial_balance + 50.0, 0.01,
		"Signal should report the new balance after add_cash"
	)


func test_cash_changed_signal_fires_on_deduct() -> void:
	_economy._current_cash = 200.0

	watch_signals(EventBus)
	_economy.deduct_cash(25.0, "signal test deduct")

	assert_signal_emitted(
		EventBus, "money_changed",
		"money_changed should fire when cash is deducted"
	)
	var params: Array = get_signal_parameters(EventBus, "money_changed")
	assert_almost_eq(params[0] as float, 200.0, 0.01)
	assert_almost_eq(
		params[1] as float, 175.0, 0.01,
		"Signal should report the new balance after deduct_cash"
	)


func test_daily_revenue_reset_clears_session_revenue() -> void:
	_economy.add_cash(120.0, "sale")
	_economy.record_store_revenue("test_store", 120.0)

	_economy.reset_daily_totals()

	var summary: Dictionary = _economy.get_daily_summary()
	assert_almost_eq(
		summary["total_revenue"] as float, 0.0, 0.01,
		"Daily revenue total should be zero after reset"
	)
	assert_eq(
		_economy.get_store_daily_revenue("test_store"), 0.0,
		"Store session revenue should be cleared after reset"
	)


func test_transaction_history_records_entry() -> void:
	EventBus.day_started.emit(3)

	_economy.add_cash(42.0, "sale")

	var history: Array[Dictionary] = _economy.transaction_history
	assert_gt(history.size(), 0, "Transaction history should record completed transactions")
	var last_entry: Dictionary = history[history.size() - 1]
	assert_almost_eq(last_entry.get("amount", 0.0) as float, 42.0, 0.01)
	assert_eq(
		last_entry.get("type", -1) as int,
		EconomySystem.TransactionType.REVENUE,
		"Transaction type should mark the entry as revenue"
	)
	assert_eq(
		last_entry.get("day", -1) as int, 3,
		"Transaction history should record the current day"
	)


func test_balance_never_goes_negative_on_deduct() -> void:
	_economy._current_cash = 20.0

	_economy.deduct_cash(50.0, "over budget")

	assert_true(
		_economy.get_cash() >= 0.0,
		"Balance should never go negative after a failed deduction"
	)
	assert_almost_eq(_economy.get_cash(), 20.0, 0.01)


func test_serialize_deserialize_preserves_balance() -> void:
	_economy._current_cash = 321.5
	var save_data: Dictionary = _economy.get_save_data()

	var fresh_economy: EconomySystem = EconomySystem.new()
	add_child_autofree(fresh_economy)
	fresh_economy.load_save_data(save_data)

	assert_almost_eq(
		fresh_economy.get_cash(), 321.5, 0.01,
		"Cash should survive a save/load round trip"
	)
