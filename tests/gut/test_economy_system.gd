## Tests EconomySystem charge, credit, daily profit, and save/load.
extends GutTest


var _economy: EconomySystem
var _last_txn_amount: float = 0.0
var _last_txn_success: bool = false
var _last_txn_message: String = ""
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
	_economy.initialize(1000.0)
	_last_txn_amount = 0.0
	_last_txn_success = false
	_last_txn_message = ""
	EventBus.transaction_completed.connect(_on_transaction_completed)


func after_each() -> void:
	if EventBus.transaction_completed.is_connected(
		_on_transaction_completed
	):
		EventBus.transaction_completed.disconnect(
			_on_transaction_completed
		)
	if _economy != null:
		_economy.free()
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


func _on_transaction_completed(
	amount: float, success: bool, message: String
) -> void:
	_last_txn_amount = amount
	_last_txn_success = success
	_last_txn_message = message


func test_charge_succeeds_with_sufficient_funds() -> void:
	var result: bool = _economy.charge(200.0, "Test purchase")
	assert_true(result, "charge should succeed with sufficient funds")
	assert_almost_eq(
		_economy.get_cash(), 800.0, 0.01,
		"Cash should decrease by charged amount"
	)
	assert_almost_eq(_last_txn_amount, 200.0, 0.01)
	assert_true(_last_txn_success)
	assert_eq(_last_txn_message, "Test purchase")


func test_charge_fails_with_insufficient_funds() -> void:
	var result: bool = _economy.charge(2000.0, "Too expensive")
	assert_false(result, "charge should fail with insufficient funds")
	assert_almost_eq(
		_economy.get_cash(), 1000.0, 0.01,
		"Cash should remain unchanged on failed charge"
	)
	assert_almost_eq(_last_txn_amount, 2000.0, 0.01)
	assert_false(_last_txn_success)
	assert_eq(_last_txn_message, "Insufficient funds")


func test_charge_rejects_non_positive_amount() -> void:
	var result: bool = _economy.charge(0.0, "Zero charge")
	assert_false(result)
	assert_almost_eq(_economy.get_cash(), 1000.0, 0.01)


func test_credit_adds_cash() -> void:
	_economy.credit(500.0, &"sale_revenue")
	assert_almost_eq(
		_economy.get_cash(), 1500.0, 0.01,
		"Cash should increase by credited amount"
	)
	assert_almost_eq(_last_txn_amount, 500.0, 0.01)
	assert_true(_last_txn_success)


func test_credit_rejects_non_positive_amount() -> void:
	_economy.credit(-10.0, &"bad_credit")
	assert_almost_eq(_economy.get_cash(), 1000.0, 0.01)


func test_get_daily_profit_revenue_minus_expenses() -> void:
	_economy.credit(300.0, &"sales")
	_economy.charge(100.0, "supplies")
	var profit: float = _economy.get_daily_profit()
	assert_almost_eq(
		profit, 200.0, 0.01,
		"Daily profit should be revenue - expenses"
	)


func test_get_daily_profit_with_no_activity() -> void:
	assert_almost_eq(
		_economy.get_daily_profit(), 0.0, 0.01,
		"Daily profit should be zero with no activity"
	)


func test_reset_daily_totals_zeroes_tracking() -> void:
	_economy.credit(500.0, &"sales")
	_economy.charge(200.0, "expense")
	_economy.reset_daily_totals()
	assert_almost_eq(
		_economy.get_daily_profit(), 0.0, 0.01,
		"Profit should be zero after reset"
	)
	assert_eq(
		_economy.get_items_sold_today(), 0,
		"Items sold should be zero after reset"
	)


func test_reset_daily_totals_on_day_started() -> void:
	_economy.charge(100.0, "expense")
	EventBus.day_started.emit(2)
	assert_almost_eq(
		_economy.get_daily_profit(), 0.0, 0.01,
		"Daily totals should reset on day_started"
	)


func test_serialize_deserialize_round_trip() -> void:
	_economy.charge(250.0, "order")
	_economy.credit(100.0, &"sale")
	var saved: Dictionary = _economy.serialize()
	var new_economy: EconomySystem = EconomySystem.new()
	add_child_autofree(new_economy)
	new_economy.deserialize(saved)
	assert_almost_eq(
		new_economy.get_cash(), _economy.get_cash(), 0.01,
		"Deserialized cash should match saved cash"
	)


func test_serialize_contains_daily_expenses() -> void:
	_economy.charge(150.0, "rent")
	var saved: Dictionary = _economy.serialize()
	assert_true(
		saved.has("daily_expenses"),
		"Serialized data should include daily_expenses"
	)
	assert_almost_eq(
		saved["daily_expenses"] as float, 150.0, 0.01
	)


func test_deduct_cash_emits_transaction_completed() -> void:
	_economy.deduct_cash(50.0, "test deduction")
	assert_almost_eq(_last_txn_amount, 50.0, 0.01)
	assert_true(_last_txn_success)


func test_deduct_cash_failure_emits_transaction_completed() -> void:
	var result: bool = _economy.deduct_cash(5000.0, "too much")
	assert_false(result)
	assert_almost_eq(_last_txn_amount, 5000.0, 0.01)
	assert_false(_last_txn_success)


func test_add_cash_emits_transaction_completed() -> void:
	_economy.add_cash(75.0, "bonus")
	assert_almost_eq(_last_txn_amount, 75.0, 0.01)
	assert_true(_last_txn_success)


func test_daily_expenses_tracked_across_methods() -> void:
	_economy.charge(100.0, "charge expense")
	_economy.deduct_cash(50.0, "deduct expense")
	_economy.force_deduct_cash(25.0, "forced expense")
	var saved: Dictionary = _economy.serialize()
	assert_almost_eq(
		saved["daily_expenses"] as float, 175.0, 0.01,
		"All expense methods should accumulate daily_expenses"
	)


func test_charge_exact_balance() -> void:
	var result: bool = _economy.charge(1000.0, "All in")
	assert_true(result)
	assert_almost_eq(_economy.get_cash(), 0.0, 0.01)


func test_daily_financials_snapshot_emitted_on_day_ended() -> void:
	var snapshot_revenue: Array = [-1.0]
	var snapshot_expenses: Array = [-1.0]
	var snapshot_net: Array = [-1.0]
	var received: Array = [false]
	var capture: Callable = func(
		rev: float, exp: float, net: float
	) -> void:
		snapshot_revenue[0] = rev
		snapshot_expenses[0] = exp
		snapshot_net[0] = net
		received[0] = true
	EventBus.daily_financials_snapshot.connect(capture)

	EventBus.day_started.emit(1)
	_economy.credit(200.0, &"sales")
	_economy.charge(50.0, "supplies")
	EventBus.day_ended.emit(1)

	EventBus.daily_financials_snapshot.disconnect(capture)
	assert_true(received[0], "daily_financials_snapshot should be emitted")
	assert_almost_eq(snapshot_revenue[0], 200.0, 0.01)
	assert_almost_eq(snapshot_expenses[0], 50.0, 0.01)
	assert_almost_eq(snapshot_net[0], 150.0, 0.01)


func test_daily_revenue_resets_on_day_started() -> void:
	_economy.credit(500.0, &"sales")
	EventBus.day_started.emit(2)
	var snapshot_revenue: Array = [-1.0]
	var capture: Callable = func(
		rev: float, _exp: float, _net: float
	) -> void:
		snapshot_revenue[0] = rev
	EventBus.daily_financials_snapshot.connect(capture)
	EventBus.day_ended.emit(2)
	EventBus.daily_financials_snapshot.disconnect(capture)
	assert_almost_eq(
		snapshot_revenue[0], 0.0, 0.01,
		"daily revenue should reset to 0 on day_started"
	)
