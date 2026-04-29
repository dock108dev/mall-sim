# gdlint:disable=max-public-methods
## Manages player cash, transactions, and market value calculations.
## Value calculation helpers are in EconomyValueCalculator.
class_name EconomySystem
extends Node

enum TransactionType { REVENUE, EXPENSE }

const MAX_MARKET_VALUE: float = EconomyValueCalculator.MAX_MARKET_VALUE
const TRANSACTION_HISTORY_LIMIT: int = 100
## Monthly lease charged on day 30, 60, 90… (per owned store).
const MONTHLY_LEASE_BASE: float = 300.0
const DAYS_PER_MONTH: int = 30
const DAYS_PER_QUARTER: int = 90
## Constant pass-throughs for backwards compatibility with tests and external code.
const DEFAULT_DEMAND: float = EconomyValueCalculator.DEFAULT_DEMAND
const DEMAND_CAP: float = EconomyValueCalculator.DEMAND_CAP
const DEMAND_FLOOR: float = EconomyValueCalculator.DEMAND_FLOOR
const SALES_HISTORY_DAYS: int = EconomyValueCalculator.SALES_HISTORY_DAYS
const DRIFT_DEFAULT: float = EconomyValueCalculator.DRIFT_DEFAULT
const DRIFT_MIN: float = EconomyValueCalculator.DRIFT_MIN
const DRIFT_MAX: float = EconomyValueCalculator.DRIFT_MAX
const DRIFT_MEAN_REVERSION: float = EconomyValueCalculator.DRIFT_MEAN_REVERSION
const DRIFT_VOLATILITY: Dictionary = EconomyValueCalculator.DRIFT_VOLATILITY

var player_cash: float:
	get:
		return _current_cash
var daily_revenue: Dictionary:
	get:
		return _store_daily_revenue.duplicate()
var daily_expenses: float:
	get:
		return _daily_expenses
var transaction_history: Array[Dictionary]:
	get:
		return _duplicate_transactions(_transaction_history)

var _current_cash: float = 0.0
var _daily_transactions: Array[Dictionary] = []
var _transaction_history: Array[Dictionary] = []
var _current_time_minutes: int = 0
var _items_sold_today: int = 0
var _daily_rent: float = 50.0
var _daily_rent_total: float = 0.0
var _daily_revenue: float = 0.0
var _daily_expenses: float = 0.0

var _inventory_system: InventorySystem = null
var _trend_system: TrendSystem = null
var _meta_shift_system: MetaShiftSystem = null
var _market_event_system: MarketEventSystem = null
var _season_cycle_system: SeasonCycleSystem = null

## [{category: count, ...}, ...] per day, last N days.
var _sales_history: Array[Dictionary] = []
var _today_sales: Dictionary = {}
## Starts at 1.0, adjusted daily based on sales-to-supply ratio.
var _demand_modifiers: Dictionary = {}
## store_id -> float.
var _store_daily_revenue: Dictionary = {}
## Per item def id, random walk with mean reversion.
var _drift_factors: Dictionary = {}
var _bankruptcy_declared: bool = false
var _last_injection_day: int = -1
var _active_store_id: StringName = &""


func initialize(starting_cash: float = Constants.STARTING_CASH) -> void:
	var cash_mult: float = DifficultySystemSingleton.get_modifier(
		&"starting_cash_multiplier"
	)
	_bankruptcy_declared = false
	_last_injection_day = -1
	_active_store_id = _resolve_store_id(GameManager.get_active_store_id())
	_apply_state({"player_cash": starting_cash * cash_mult})
	_connect_runtime_signals()

func set_inventory_system(inv: InventorySystem) -> void: _inventory_system = inv
func set_trend_system(ts: TrendSystem) -> void: _trend_system = ts
func set_meta_shift_system(mss: MetaShiftSystem) -> void: _meta_shift_system = mss
func set_market_event_system(mes: MarketEventSystem) -> void: _market_event_system = mes
func set_season_cycle_system(scs: SeasonCycleSystem) -> void: _season_cycle_system = scs

func get_cash() -> float: return _current_cash
func get_items_sold_today() -> int: return _items_sold_today
func set_daily_rent(amount: float) -> void: _daily_rent = amount


## Deducts amount from player cash. Returns false if insufficient funds.
func charge(amount: float, reason: String) -> bool:
	if amount <= 0.0:
		push_warning(
			"EconomySystem: charge called with non-positive amount: %s"
			% amount
		)
		return false
	return _apply_charge(amount, reason, false)


## Adds amount to player cash and records revenue for the active store.
func credit(amount: float, source: StringName) -> void:
	if amount <= 0.0:
		push_warning(
			"EconomySystem: credit called with non-positive amount: %s"
			% amount
		)
		return
	_apply_credit(amount, String(source), _get_active_store_id())


## Resolves a single customer sale attempt using the full multiplier chain via
## CustomerSimulator.simulate_single(). Emits item_sold / customer_purchased on
## acceptance and customer_walked on rejection.
## Returns {item_id, item_name, accepted, price, walk_reason, market_price}.
func resolve_sale(item: ItemInstance, store_id: StringName) -> Dictionary:
	return CustomerSimulator.simulate_single(store_id, item)


## Returns total daily revenue minus daily expenses for the current day.
func get_daily_profit() -> float:
	return _get_daily_revenue_total() - _daily_expenses

## Zeroes daily revenue, expenses, and transaction log for a new day.
func reset_daily_totals() -> void:
	_daily_transactions = []
	_current_time_minutes = 0
	_items_sold_today = 0
	_daily_rent_total = 0.0
	_daily_revenue = 0.0
	_daily_expenses = 0.0
	_today_sales = {}
	_store_daily_revenue = {}


## Returns the end-of-day snapshot used by day-cycle listeners and tests.
func get_day_end_summary(day: int) -> Dictionary:
	var summary: Dictionary = get_daily_summary()
	summary["day"] = day
	summary["transactions"] = _duplicate_transactions(_daily_transactions)
	summary["store_daily_revenue"] = _store_daily_revenue.duplicate(true)
	return summary

## Returns a serializable snapshot of all economy state.
func serialize() -> Dictionary: return get_save_data()
func deserialize(data: Dictionary) -> void: load_save_data(data)
## Formula: base * demand * drift * time * trend * market_event * meta * season
func calculate_market_value(item: ItemInstance) -> float:
	return EconomyValueCalculator.calculate_market_value(
		item, _demand_modifiers, _drift_factors,
		_trend_system, _market_event_system,
		_meta_shift_system, _season_cycle_system
	)

## Returns PriceResolver-compatible multiplier dicts for each factor that
## calculate_market_value() applies. Pass to PriceResolver.resolve_for_item()
## to get a full audit trace. Base step is injected by resolve_for_item().
func get_item_multipliers(item: ItemInstance) -> Array:
	return EconomyValueCalculator.get_item_multipliers(
		item, _demand_modifiers, _drift_factors,
		_trend_system, _market_event_system,
		_meta_shift_system, _season_cycle_system
	)

func _get_trend_multiplier(item: ItemInstance) -> float:
	return EconomyValueCalculator.get_trend_multiplier(item, _trend_system)
func _get_market_event_multiplier(item: ItemInstance) -> float:
	if _market_event_system:
		return _market_event_system.get_trend_multiplier(item)
	return EconomyValueCalculator.get_market_event_multiplier(item, _market_event_system)
func get_demand_modifier(category: String) -> float:
	return _demand_modifiers.get(category, EconomyValueCalculator.DEFAULT_DEMAND)
func get_drift_factor(item_id: String) -> float:
	return _drift_factors.get(item_id, EconomyValueCalculator.DRIFT_DEFAULT)


func add_cash(amount: float, reason: String) -> void:
	if amount <= 0.0:
		push_warning(
			"EconomySystem: add_cash called with non-positive amount: %s"
			% amount
		)
		return
	_apply_credit(amount, reason)


## Returns false if insufficient funds.
func deduct_cash(amount: float, reason: String) -> bool:
	if amount <= 0.0:
		push_warning(
			"EconomySystem: deduct_cash called with non-positive amount: %s"
			% amount
		)
		return false
	return _apply_charge(amount, reason, false)


## Allows negative balance (used for mandatory deductions like rent).
func force_deduct_cash(amount: float, reason: String) -> void:
	if amount <= 0.0:
		push_warning(
			"EconomySystem: force_deduct called with non-positive: %s"
			% amount
		)
		return
	_apply_charge(amount, reason, true)


func get_daily_summary() -> Dictionary:
	var total_revenue: float = 0.0
	var total_expenses: float = 0.0
	var transaction_count: int = _daily_transactions.size()

	for txn: Dictionary in _daily_transactions:
		var txn_type: int = txn.get("type", -1)
		if txn_type == TransactionType.REVENUE:
			total_revenue += txn.get("amount", 0.0)
		elif txn_type == TransactionType.EXPENSE:
			total_expenses += txn.get("amount", 0.0)

	return {
		"total_revenue": total_revenue,
		"total_expenses": total_expenses,
		"net_profit": total_revenue - total_expenses,
		"transaction_count": transaction_count,
		"items_sold": _items_sold_today,
		"rent": _daily_rent_total,
	}


func get_save_data() -> Dictionary:
	var serialized_history: Array[Dictionary] = []
	for day_sales: Dictionary in _sales_history:
		serialized_history.append(day_sales.duplicate())

	return {
		"player_cash": _current_cash,
		"daily_revenue": _store_daily_revenue.duplicate(true),
		"daily_revenue_total": _daily_revenue,
		"daily_expenses": _daily_expenses,
		"transaction_history": _duplicate_transactions(
			_transaction_history
		),
		"current_cash": _current_cash,
		"daily_transactions": _duplicate_transactions(
			_daily_transactions
		),
		"current_time_minutes": _current_time_minutes,
		"items_sold_today": _items_sold_today,
		"daily_rent": _daily_rent,
		"daily_rent_total": _daily_rent_total,
		"sales_history": serialized_history,
		"today_sales": _today_sales.duplicate(),
		"demand_modifiers": _demand_modifiers.duplicate(),
		"store_daily_revenue": _store_daily_revenue.duplicate(),
		"drift_factors": _drift_factors.duplicate(),
		"last_injection_day": _last_injection_day,
	}


func load_save_data(data: Dictionary) -> void:
	_bankruptcy_declared = false
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_current_cash = float(
		data.get("player_cash", data.get("current_cash", Constants.STARTING_CASH))
	)
	_current_time_minutes = int(
		data.get("current_time_minutes", 0)
	)
	_items_sold_today = int(data.get("items_sold_today", 0))
	_daily_rent = float(data.get("daily_rent", 50.0))
	_daily_rent_total = float(data.get("daily_rent_total", 0.0))
	_daily_expenses = float(data.get("daily_expenses", 0.0))
	_last_injection_day = int(data.get("last_injection_day", -1))
	_active_store_id = _resolve_store_id(GameManager.get_active_store_id())

	_daily_transactions = _restore_transactions(
		data.get("daily_transactions", [])
	)
	_transaction_history = _restore_transactions(
		data.get("transaction_history", [])
	)
	if _transaction_history.is_empty() and not _daily_transactions.is_empty():
		_transaction_history = _duplicate_transactions(
			_daily_transactions
		)

	_sales_history = []
	var saved_history: Array = data.get("sales_history", [])
	for entry: Variant in saved_history:
		if entry is Dictionary:
			_sales_history.append(entry as Dictionary)

	_today_sales = _restore_dict(data, "today_sales")
	_demand_modifiers = _restore_dict(data, "demand_modifiers")
	_store_daily_revenue = _restore_daily_revenue(data)
	_daily_revenue = _restore_daily_revenue_total(data)
	_drift_factors = _restore_dict(data, "drift_factors")


func _connect_runtime_signals() -> void:
	_connect_signal(EventBus.day_started, _on_day_started)
	_connect_signal(EventBus.hour_changed, _on_hour_changed)
	_connect_signal(EventBus.day_ended, _on_day_ended)
	_connect_signal(EventBus.item_sold, _on_item_sold)
	_connect_signal(EventBus.order_cash_check, _on_order_cash_check)
	_connect_signal(EventBus.order_cash_deduct, _on_order_cash_deduct)
	_connect_signal(EventBus.order_refund_issued, _on_order_refund_issued)
	_connect_signal(EventBus.payroll_cash_check, _on_payroll_cash_check)
	_connect_signal(EventBus.payroll_cash_deduct, _on_payroll_cash_deduct)
	_connect_signal(EventBus.customer_purchased, _on_customer_purchased)
	_connect_signal(EventBus.active_store_changed, _on_active_store_changed)
	_connect_signal(
		EventBus.emergency_cash_injected,
		_on_emergency_cash_injected
	)
	_connect_signal(EventBus.milestone_unlocked, _on_milestone_unlocked)


func _connect_signal(signal_ref: Signal, callable: Callable) -> void:
	if not signal_ref.is_connected(callable):
		signal_ref.connect(callable)


func _record_transaction(
	amount: float, reason: String, type: TransactionType
) -> void:
	var transaction: Dictionary = {
		"amount": amount,
		"day": GameManager.get_current_day(),
		"reason": reason,
		"type": type,
		"timestamp": _current_time_minutes,
	}
	_daily_transactions.append(transaction)
	_transaction_history.append(transaction.duplicate())
	while _transaction_history.size() > TRANSACTION_HISTORY_LIMIT:
		_transaction_history.pop_front()


func _on_day_started(_day: int) -> void:
	var start_ticks: int = Time.get_ticks_msec()
	_update_drift_factors()
	var elapsed_start: int = Time.get_ticks_msec() - start_ticks
	if elapsed_start > 100:
		push_warning(
			"EconomySystem: day-start calculations took %dms" % elapsed_start
		)
	reset_daily_totals()

func _on_day_ended(day: int) -> void:
	var start_ticks: int = Time.get_ticks_msec()
	_commit_daily_sales()
	_update_demand_modifiers()
	_deduct_all_store_rents()
	_check_monthly_lease(day)
	_check_emergency_injection(day)
	_emit_daily_financials_snapshot()
	var elapsed_end: int = Time.get_ticks_msec() - start_ticks
	if elapsed_end > 100:
		push_warning(
			"EconomySystem: day-end calculations took %dms" % elapsed_end
		)

func _emit_daily_financials_snapshot() -> void:
	var total_revenue: float = _get_daily_revenue_total()
	EventBus.daily_financials_snapshot.emit(
		total_revenue, _daily_expenses, total_revenue - _daily_expenses
	)

func _deduct_all_store_rents() -> void:
	_daily_rent_total = 0.0
	var rent_mult: float = DifficultySystemSingleton.get_modifier(&"daily_rent_multiplier")
	for store_id: StringName in GameManager.get_owned_store_ids():
		var store_key: String = String(store_id)
		var rent: float = _daily_rent
		if GameManager.data_loader:
			var store_def: StoreDefinition = GameManager.data_loader.get_store(store_key)
			if store_def:
				rent = store_def.daily_rent
		rent *= rent_mult
		_daily_rent_total += rent
		force_deduct_cash(rent, "Rent: %s" % store_key)

func _on_hour_changed(hour: int) -> void:
	_current_time_minutes = hour * Constants.MINUTES_PER_HOUR

func get_store_daily_revenue(store_id: String) -> float:
	var canonical: StringName = _resolve_store_id(store_id)
	if canonical.is_empty():
		return _store_daily_revenue.get(store_id, 0.0)
	return _store_daily_revenue.get(String(canonical), 0.0)

func record_store_revenue(store_id: String, amount: float) -> void:
	if amount <= 0.0:
		return
	var canonical: StringName = _resolve_store_id(store_id)
	var key: String = store_id if canonical.is_empty() else String(canonical)
	_store_daily_revenue[key] = (
		_store_daily_revenue.get(key, 0.0) as float
	) + amount

func _on_item_sold(_item_id: String, _price: float, category: String) -> void:
	_items_sold_today += 1
	if not GameState.get_flag(&"first_sale_complete"):
		GameState.set_flag(&"first_sale_complete", true)
	if category.is_empty():
		return
	var current: int = _today_sales.get(category, 0) as int
	_today_sales[category] = current + 1


func _commit_daily_sales() -> void:
	_sales_history.append(_today_sales.duplicate())
	while _sales_history.size() > SALES_HISTORY_DAYS:
		_sales_history.pop_front()


func _update_demand_modifiers() -> void:
	var shelf_supply: Dictionary = _count_shelf_supply_by_category()
	EconomyValueCalculator.update_demand_modifiers(
		_sales_history, shelf_supply, _demand_modifiers
	)


func _update_drift_factors() -> void:
	if not GameManager.data_loader:
		return
	var all_items: Array[ItemDefinition] = (
		GameManager.data_loader.get_all_items()
	)
	EconomyValueCalculator.update_drift_factors(all_items, _drift_factors)


func _restore_dict(data: Dictionary, key: String) -> Dictionary:
	var saved: Variant = data.get(key, {})
	if saved is Dictionary:
		return (saved as Dictionary).duplicate()
	return {}


func _restore_transactions(saved_txns: Variant) -> Array[Dictionary]:
	var restored: Array[Dictionary] = []
	if saved_txns is not Array:
		return restored
	for txn: Variant in saved_txns:
		if txn is Dictionary:
			var t: Dictionary = txn as Dictionary
			restored.append({
				"amount": float(t.get("amount", 0.0)),
				"day": int(t.get("day", 1)),
				"reason": str(t.get("reason", "")),
				"type": int(t.get("type", 0)),
				"timestamp": int(t.get("timestamp", 0)),
			})
	return restored


func _restore_daily_revenue(data: Dictionary) -> Dictionary:
	var saved_daily_revenue: Variant = data.get(
		"daily_revenue", data.get("store_daily_revenue", {})
	)
	var restored: Dictionary = {}
	if saved_daily_revenue is not Dictionary:
		return restored
	for raw_store_id: Variant in saved_daily_revenue:
		var resolved: StringName = _resolve_store_id(raw_store_id)
		var key: String = str(raw_store_id)
		if not resolved.is_empty():
			key = String(resolved)
		restored[key] = float(
			(saved_daily_revenue as Dictionary).get(raw_store_id, 0.0)
		)
	return restored


func _restore_daily_revenue_total(data: Dictionary) -> float:
	if data.has("daily_revenue_total"):
		return float(data.get("daily_revenue_total", 0.0))
	var saved_daily_revenue: Variant = data.get("daily_revenue", null)
	if saved_daily_revenue is Dictionary:
		return _sum_revenue(saved_daily_revenue as Dictionary)
	if saved_daily_revenue != null:
		return float(saved_daily_revenue)
	return float(data.get("daily_revenue", 0.0))


func _duplicate_transactions(
	transactions: Array[Dictionary]
) -> Array[Dictionary]:
	var duplicated: Array[Dictionary] = []
	for txn: Dictionary in transactions:
		duplicated.append(txn.duplicate())
	return duplicated


func _sum_revenue(revenue_by_store: Dictionary) -> float:
	var total: float = 0.0
	for store_id: Variant in revenue_by_store:
		total += float(revenue_by_store.get(store_id, 0.0))
	return total


func _get_daily_revenue_total() -> float:
	return _daily_revenue


func _get_active_store_id() -> StringName:
	if not _active_store_id.is_empty():
		return _active_store_id
	return _resolve_store_id(GameManager.get_active_store_id())


func _resolve_store_id(raw_store_id: Variant) -> StringName:
	var store_id: String = str(raw_store_id)
	if store_id.is_empty():
		return &""
	if ContentRegistry.exists(store_id):
		return ContentRegistry.resolve(store_id)
	return StringName(store_id)


func _apply_credit(
	amount: float, reason: String, revenue_store_id: StringName = &""
) -> void:
	var old_cash: float = _current_cash
	_current_cash += amount
	_daily_revenue += amount
	if not revenue_store_id.is_empty():
		record_store_revenue(String(revenue_store_id), amount)
	_record_transaction(amount, reason, TransactionType.REVENUE)
	EventBus.money_changed.emit(old_cash, _current_cash)
	EventBus.transaction_completed.emit(amount, true, reason)


func _apply_charge(
	amount: float, reason: String, allow_negative: bool
) -> bool:
	if not allow_negative and _current_cash < amount:
		EventBus.transaction_completed.emit(
			amount, false, "Insufficient funds"
		)
		return false
	var old_cash: float = _current_cash
	_current_cash -= amount
	_daily_expenses += amount
	_record_transaction(amount, reason, TransactionType.EXPENSE)
	EventBus.money_changed.emit(old_cash, _current_cash)
	EventBus.transaction_completed.emit(amount, true, reason)
	if allow_negative and _current_cash < 0.0:
		push_warning(
			"EconomySystem: cash is negative ($%.2f) after: %s"
			% [_current_cash, reason]
		)
		EventBus.notification_requested.emit(
			"Warning: You are in debt! Cash: $%.2f" % _current_cash
		)
	_check_bankruptcy()
	return true


func _on_order_cash_check(amount: float, result: Array) -> void:
	var adjusted: float = amount * DifficultySystemSingleton.get_modifier(&"wholesale_cost_multiplier")
	result.append(_current_cash >= adjusted)

func _on_order_cash_deduct(amount: float, reason: String, result: Array) -> void:
	var adjusted: float = amount * DifficultySystemSingleton.get_modifier(&"wholesale_cost_multiplier")
	result.append(deduct_cash(adjusted, reason))

func _on_order_refund_issued(amount: float, reason: String) -> void:
	var adjusted: float = amount * DifficultySystemSingleton.get_modifier(&"wholesale_cost_multiplier")
	add_cash(adjusted, reason)

func _on_payroll_cash_check(amount: float, result: Array) -> void:
	result.append(_current_cash >= amount)

func _on_payroll_cash_deduct(amount: float, reason: String, result: Array) -> void:
	result.append(deduct_cash(amount, reason))


func _on_active_store_changed(store_id: StringName) -> void:
	_active_store_id = _resolve_store_id(store_id)

func _count_shelf_supply_by_category() -> Dictionary:
	var counts: Dictionary = {}
	if not _inventory_system:
		return counts
	for item: ItemInstance in _inventory_system.get_shelf_items():
		if item.definition:
			var cat: String = item.definition.category
			counts[cat] = (counts.get(cat, 0) as int) + 1
	return counts


func _check_bankruptcy() -> void:
	if _current_cash <= 0.0 and not _bankruptcy_declared:
		_bankruptcy_declared = true
		EventBus.bankruptcy_declared.emit()

func _check_emergency_injection(day: int) -> void:
	if not DifficultySystemSingleton.get_flag(&"emergency_cash_injection_enabled"):
		return
	var threshold: float = _daily_rent * 2.0
	if _current_cash >= threshold or not _can_inject_this_week(day):
		return
	var amount: float = threshold * 3.0
	_last_injection_day = day
	add_cash(amount, "Emergency cash injection")
	EventBus.emergency_cash_injected.emit(amount, "A loyal customer paid their tab early.")

func _can_inject_this_week(current_day: int) -> bool:
	return _last_injection_day < 0 or (current_day - _last_injection_day) >= 7


## Deducts a monthly lease payment on every DAYS_PER_MONTH multiple.
## Announces the deduction via toast and emits monthly_rent_posted.
## On quarterly intervals also emits quarterly_lease_review.
func _check_monthly_lease(day: int) -> void:
	if day <= 0 or day % DAYS_PER_MONTH != 0:
		return
	var owned: Array[StringName] = GameManager.get_owned_store_ids()
	if owned.is_empty():
		return
	var rent_mult: float = DifficultySystemSingleton.get_modifier(
		&"daily_rent_multiplier"
	)
	var total_lease: float = 0.0
	for store_id: StringName in owned:
		total_lease += MONTHLY_LEASE_BASE * rent_mult
	force_deduct_cash(total_lease, "Monthly Lease (Day %d)" % day)
	var month_num: int = day / DAYS_PER_MONTH
	EventBus.toast_requested.emit(
		"Month %d lease: -$%.0f" % [month_num, total_lease],
		&"expense",
		4.0
	)
	EventBus.monthly_rent_posted.emit(day, total_lease)
	if day % DAYS_PER_QUARTER == 0:
		EventBus.quarterly_lease_review.emit(day)
		EventBus.toast_requested.emit(
			"Quarterly lease review — management is watching.",
			&"warning",
			5.0
		)

func _on_customer_purchased(
	store_id: StringName, item_id: StringName, price: float, _customer_id: StringName
) -> void:
	if price <= 0.0:
		return
	add_cash(price, "Sale: %s at %s" % [item_id, store_id])
	if not String(store_id).is_empty():
		record_store_revenue(String(store_id), price)

func _on_emergency_cash_injected(amount: float, _reason: String) -> void:
	if amount > 0.0 and _current_cash > 0.0 and _bankruptcy_declared:
		_bankruptcy_declared = false

func _on_milestone_unlocked(milestone_id: StringName, reward: Dictionary) -> void:
	if str(reward.get("reward_type", "")) not in ["cash", "cash_bonus"]:
		return
	var amount: float = float(reward.get("reward_value", 0.0))
	if amount > 0.0:
		add_cash(amount, "Milestone reward: %s" % milestone_id)
