## Manages player cash, transactions, and market value calculations.
class_name EconomySystem
extends Node


enum TransactionType {
	REVENUE,
	EXPENSE,
}

const DEFAULT_DEMAND: float = 1.0
const DEMAND_STEP: float = 0.1
const DEMAND_CAP: float = 1.5
const DEMAND_FLOOR: float = 0.3
const HIGH_SALES_RATIO: float = 3.0
const LOW_SALES_RATIO: float = 0.5
const SALES_HISTORY_DAYS: int = 5

const DRIFT_MIN: float = 0.85
const DRIFT_MAX: float = 1.15
const DRIFT_DEFAULT: float = 1.0
## Mean reversion strength per day (~10-day half-life: ln(2)/10 ≈ 0.07).
const DRIFT_MEAN_REVERSION: float = 0.1

const DRIFT_VOLATILITY: Dictionary = {
	"common": 0.01,
	"uncommon": 0.02,
	"rare": 0.03,
	"very_rare": 0.05,
	"legendary": 0.07,
}

const MAX_MARKET_VALUE: float = 1000.0

const APPRECIATION_RATE: float = 0.002
const APPRECIATION_CAP: float = 1.5
const DEPRECIATION_RATE: float = 0.008
const DEPRECIATION_FLOOR: float = 0.1

var _current_cash: float = 0.0
var _daily_transactions: Array[Dictionary] = []
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
var _trades_today: int = 0
var _bankruptcy_declared: bool = false
var _last_injection_day: int = -1


func initialize(starting_cash: float = Constants.STARTING_CASH) -> void:
	var cash_mult: float = DifficultySystem.get_modifier(
		&"starting_cash_multiplier"
	)
	_bankruptcy_declared = false
	_last_injection_day = -1
	_apply_state({"current_cash": starting_cash * cash_mult})
	EventBus.day_started.connect(_on_day_started)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.trade_accepted.connect(_on_trade_accepted)
	EventBus.order_cash_check.connect(_on_order_cash_check)
	EventBus.order_cash_deduct.connect(_on_order_cash_deduct)
	EventBus.order_refund_issued.connect(_on_order_refund_issued)
	EventBus.payroll_cash_check.connect(_on_payroll_cash_check)
	EventBus.payroll_cash_deduct.connect(_on_payroll_cash_deduct)
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.emergency_cash_injected.connect(
		_on_emergency_cash_injected
	)
	EventBus.milestone_unlocked.connect(_on_milestone_unlocked)


func set_inventory_system(inv: InventorySystem) -> void:
	_inventory_system = inv

func set_trend_system(ts: TrendSystem) -> void:
	_trend_system = ts

func set_meta_shift_system(mss: MetaShiftSystem) -> void:
	_meta_shift_system = mss

func set_market_event_system(mes: MarketEventSystem) -> void:
	_market_event_system = mes

func set_season_cycle_system(scs: SeasonCycleSystem) -> void:
	_season_cycle_system = scs


func get_cash() -> float:
	return _current_cash

func get_items_sold_today() -> int:
	return _items_sold_today

func set_daily_rent(amount: float) -> void:
	_daily_rent = amount


## Deducts amount from player cash. Returns false if insufficient funds.
func charge(amount: float, reason: String) -> bool:
	if amount <= 0.0:
		push_warning(
			"EconomySystem: charge called with non-positive amount: %s"
			% amount
		)
		return false
	if _current_cash < amount:
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
	return true


## Adds amount to player cash and records revenue for the active store.
func credit(amount: float, source: StringName) -> void:
	if amount <= 0.0:
		push_warning(
			"EconomySystem: credit called with non-positive amount: %s"
			% amount
		)
		return
	var old_cash: float = _current_cash
	_current_cash += amount
	_daily_revenue += amount
	var active_store: String = GameManager.current_store_id
	if not active_store.is_empty():
		record_store_revenue(active_store, amount)
	_record_transaction(amount, String(source), TransactionType.REVENUE)
	EventBus.money_changed.emit(old_cash, _current_cash)
	EventBus.transaction_completed.emit(amount, true, String(source))


## Returns total daily revenue minus daily expenses for the current day.
func get_daily_profit() -> float:
	var total_revenue: float = 0.0
	for store_id: String in _store_daily_revenue:
		total_revenue += _store_daily_revenue[store_id] as float
	return total_revenue - _daily_expenses


## Zeroes daily revenue, expenses, and transaction log for a new day.
func reset_daily_totals() -> void:
	_daily_transactions = []
	_current_time_minutes = 0
	_items_sold_today = 0
	_trades_today = 0
	_daily_rent_total = 0.0
	_daily_revenue = 0.0
	_daily_expenses = 0.0
	_today_sales = {}
	_store_daily_revenue = {}


## Returns a serializable snapshot of all economy state.
func serialize() -> Dictionary:
	return get_save_data()


## Restores economy state from a previously serialized dictionary.
func deserialize(data: Dictionary) -> void:
	load_save_data(data)


## Calculates full market value with diminishing rarity returns and a hard cap.
func calculate_market_value(item: ItemInstance) -> float:
	if not item or not item.definition:
		return 0.0
	if item.authentication_status == "fake":
		return 0.50
	var base: float = item.definition.base_price
	var cond_mult: float = ItemInstance.CONDITION_MULTIPLIERS.get(
		item.condition, 1.0
	)
	var rarity_mult: float = ItemInstance.calculate_effective_rarity(
		base, item.definition.rarity
	)
	var demand: float = get_demand_modifier(item.definition.category)
	var drift: float = get_drift_factor(item.definition.id)
	var time_mult: float = _calc_time_multiplier(item)
	var trend: float = _get_trend_multiplier(item)
	var market_event: float = _get_market_event_multiplier(item)
	var meta_shift: float = _get_meta_shift_multiplier(item)
	var season: float = _get_season_multiplier(item)
	var auth: float = _get_authentication_multiplier(item)
	var value: float = (
		base * cond_mult * rarity_mult
		* demand * drift * time_mult * trend * market_event
		* meta_shift * season * auth
	)
	return minf(value, MAX_MARKET_VALUE)


func _get_trend_multiplier(item: ItemInstance) -> float:
	if not _trend_system:
		return 1.0
	return _trend_system.get_trend_multiplier(item)

func _get_market_event_multiplier(item: ItemInstance) -> float:
	if not _market_event_system:
		return 1.0
	return _market_event_system.get_trend_multiplier(item)

func _get_meta_shift_multiplier(item: ItemInstance) -> float:
	if not _meta_shift_system:
		return 1.0
	return _meta_shift_system.get_meta_shift_multiplier(item)

func _get_authentication_multiplier(item: ItemInstance) -> float:
	if item.authentication_status == "authenticated":
		return _get_auth_multiplier_from_config()
	return 1.0


func _get_auth_multiplier_from_config() -> float:
	var entry: Dictionary = ContentRegistry.get_entry(&"sports")
	if entry.is_empty():
		return 2.0
	var config: Variant = entry.get("authentication_config", {})
	if config is not Dictionary:
		return 2.0
	return float((config as Dictionary).get("auth_multiplier", 2.0))

func _get_season_multiplier(item: ItemInstance) -> float:
	if not _season_cycle_system:
		return 1.0
	return _season_cycle_system.get_season_multiplier(item)

func get_demand_modifier(category: String) -> float:
	return _demand_modifiers.get(category, DEFAULT_DEMAND)
func get_drift_factor(item_id: String) -> float:
	return _drift_factors.get(item_id, DRIFT_DEFAULT)


func _calc_time_multiplier(item: ItemInstance) -> float:
	var current_day: int = GameManager.current_day
	var days_owned: int = maxi(0, current_day - item.acquired_day)
	if item.definition.appreciates:
		return minf(
			1.0 + float(days_owned) * APPRECIATION_RATE,
			APPRECIATION_CAP
		)
	if item.definition.depreciates:
		return maxf(
			DEPRECIATION_FLOOR,
			1.0 - float(days_owned) * DEPRECIATION_RATE
		)
	return 1.0


func add_cash(amount: float, reason: String) -> void:
	if amount <= 0.0:
		push_warning(
			"EconomySystem: add_cash called with non-positive amount: %s"
			% amount
		)
		return

	var old_cash: float = _current_cash
	_current_cash += amount
	_daily_revenue += amount
	_record_transaction(amount, reason, TransactionType.REVENUE)
	EventBus.money_changed.emit(old_cash, _current_cash)
	EventBus.transaction_completed.emit(amount, true, reason)


## Returns false if insufficient funds.
func deduct_cash(amount: float, reason: String) -> bool:
	if amount <= 0.0:
		push_warning(
			"EconomySystem: deduct_cash called with non-positive amount: %s"
			% amount
		)
		return false

	if _current_cash < amount:
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
	return true


## Allows negative balance (used for mandatory deductions like rent).
func force_deduct_cash(amount: float, reason: String) -> void:
	if amount <= 0.0:
		push_warning(
			"EconomySystem: force_deduct called with non-positive: %s"
			% amount
		)
		return
	var old_cash: float = _current_cash
	_current_cash -= amount
	_daily_expenses += amount
	_record_transaction(amount, reason, TransactionType.EXPENSE)
	EventBus.money_changed.emit(old_cash, _current_cash)
	EventBus.transaction_completed.emit(amount, true, reason)
	if _current_cash < 0.0:
		push_warning(
			"EconomySystem: cash is negative ($%.2f) after: %s"
			% [_current_cash, reason]
		)
		EventBus.notification_requested.emit(
			"Warning: You are in debt! Cash: $%.2f" % _current_cash
		)
	_check_bankruptcy()


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
		"trades": _trades_today,
		"rent": _daily_rent_total,
	}


func get_save_data() -> Dictionary:
	var serialized_transactions: Array[Dictionary] = []
	for txn: Dictionary in _daily_transactions:
		serialized_transactions.append(txn.duplicate())

	var serialized_history: Array[Dictionary] = []
	for day_sales: Dictionary in _sales_history:
		serialized_history.append(day_sales.duplicate())

	return {
		"current_cash": _current_cash,
		"daily_transactions": serialized_transactions,
		"current_time_minutes": _current_time_minutes,
		"items_sold_today": _items_sold_today,
		"daily_rent": _daily_rent,
		"daily_rent_total": _daily_rent_total,
		"daily_revenue": _daily_revenue,
		"daily_expenses": _daily_expenses,
		"sales_history": serialized_history,
		"today_sales": _today_sales.duplicate(),
		"demand_modifiers": _demand_modifiers.duplicate(),
		"store_daily_revenue": _store_daily_revenue.duplicate(),
		"trades_today": _trades_today,
		"drift_factors": _drift_factors.duplicate(),
		"last_injection_day": _last_injection_day,
	}


func load_save_data(data: Dictionary) -> void:
	_bankruptcy_declared = false
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_current_cash = float(
		data.get("current_cash", Constants.STARTING_CASH)
	)
	_current_time_minutes = int(
		data.get("current_time_minutes", 0)
	)
	_items_sold_today = int(data.get("items_sold_today", 0))
	_daily_rent = float(data.get("daily_rent", 50.0))
	_daily_rent_total = float(data.get("daily_rent_total", 0.0))
	_daily_revenue = float(data.get("daily_revenue", 0.0))
	_daily_expenses = float(data.get("daily_expenses", 0.0))
	_trades_today = int(data.get("trades_today", 0))
	_last_injection_day = int(data.get("last_injection_day", -1))

	_daily_transactions = []
	var saved_txns: Array = data.get("daily_transactions", [])
	for txn: Variant in saved_txns:
		if txn is Dictionary:
			_daily_transactions.append(txn as Dictionary)

	_sales_history = []
	var saved_history: Array = data.get("sales_history", [])
	for entry: Variant in saved_history:
		if entry is Dictionary:
			_sales_history.append(entry as Dictionary)

	_today_sales = _restore_dict(data, "today_sales")
	_demand_modifiers = _restore_dict(data, "demand_modifiers")
	_store_daily_revenue = _restore_dict(
		data, "store_daily_revenue"
	)
	_drift_factors = _restore_dict(data, "drift_factors")


func _record_transaction(
	amount: float, reason: String, type: TransactionType
) -> void:
	var transaction: Dictionary = {
		"amount": amount,
		"reason": reason,
		"type": type,
		"timestamp": _current_time_minutes,
	}
	_daily_transactions.append(transaction)


func _on_day_started(_day: int) -> void:
	var start_ticks: int = Time.get_ticks_msec()
	_update_drift_factors()
	var elapsed: int = Time.get_ticks_msec() - start_ticks
	if elapsed > 100:
		push_warning(
			"EconomySystem: day-start calculations took %dms"
			% elapsed
		)
	reset_daily_totals()


func _on_day_ended(day: int) -> void:
	var start_ticks: int = Time.get_ticks_msec()
	_commit_daily_sales()
	_update_demand_modifiers()
	_deduct_all_store_rents()
	_check_emergency_injection(day)
	_emit_daily_financials_snapshot()
	var elapsed: int = Time.get_ticks_msec() - start_ticks
	if elapsed > 100:
		push_warning(
			"EconomySystem: day-end calculations took %dms"
			% elapsed
		)


func _emit_daily_financials_snapshot() -> void:
	var net: float = _daily_revenue - _daily_expenses
	EventBus.daily_financials_snapshot.emit(
		_daily_revenue, _daily_expenses, net
	)


func _deduct_all_store_rents() -> void:
	_daily_rent_total = 0.0
	var rent_mult: float = DifficultySystem.get_modifier(
		&"daily_rent_multiplier"
	)
	for store_id: String in GameManager.owned_stores:
		var rent: float = _daily_rent
		if GameManager.data_loader:
			var store_def: StoreDefinition = (
				GameManager.data_loader.get_store(store_id)
			)
			if store_def:
				rent = store_def.daily_rent
		rent *= rent_mult
		_daily_rent_total += rent
		force_deduct_cash(rent, "Rent: %s" % store_id)


func _on_hour_changed(hour: int) -> void:
	_current_time_minutes = hour * Constants.MINUTES_PER_HOUR


func get_store_daily_revenue(store_id: String) -> float:
	return _store_daily_revenue.get(store_id, 0.0)


func record_store_revenue(
	store_id: String, amount: float
) -> void:
	var current: float = _store_daily_revenue.get(store_id, 0.0)
	_store_daily_revenue[store_id] = current + amount


func _on_trade_accepted(
	_wanted_id: String, _offered_id: String
) -> void:
	_trades_today += 1


func _on_item_sold(
	_item_id: String, _price: float, category: String
) -> void:
	_items_sold_today += 1
	if category.is_empty():
		return
	var current: int = _today_sales.get(category, 0) as int
	_today_sales[category] = current + 1


func _commit_daily_sales() -> void:
	_sales_history.append(_today_sales.duplicate())
	while _sales_history.size() > SALES_HISTORY_DAYS:
		_sales_history.pop_front()


func _update_demand_modifiers() -> void:
	var total_sales_by_cat: Dictionary = {}
	for day_sales: Dictionary in _sales_history:
		for cat: String in day_sales:
			var prev: int = total_sales_by_cat.get(cat, 0) as int
			total_sales_by_cat[cat] = prev + (day_sales[cat] as int)

	var shelf_supply: Dictionary = _count_shelf_supply_by_category()

	var all_categories: Dictionary = total_sales_by_cat.duplicate()
	for cat: String in shelf_supply:
		all_categories[cat] = true

	for cat: String in all_categories:
		var total_sales: int = total_sales_by_cat.get(cat, 0) as int
		var supply: int = shelf_supply.get(cat, 0) as int
		var current_demand: float = _demand_modifiers.get(
			cat, DEFAULT_DEMAND
		)

		if supply <= 0:
			continue

		var sales_ratio: float = float(total_sales) / float(supply)

		if sales_ratio > HIGH_SALES_RATIO:
			current_demand = minf(
				current_demand + DEMAND_STEP, DEMAND_CAP
			)
		elif sales_ratio < LOW_SALES_RATIO:
			current_demand = maxf(
				current_demand - DEMAND_STEP, DEMAND_FLOOR
			)

		_demand_modifiers[cat] = current_demand


func _update_drift_factors() -> void:
	if not GameManager.data_loader:
		return
	var all_items: Array[ItemDefinition] = (
		GameManager.data_loader.get_all_items()
	)
	for item_def: ItemDefinition in all_items:
		var current: float = _drift_factors.get(
			item_def.id, DRIFT_DEFAULT
		)
		var volatility: float = DRIFT_VOLATILITY.get(
			item_def.rarity, 0.01
		)
		var reversion: float = (DRIFT_DEFAULT - current) * DRIFT_MEAN_REVERSION
		var noise: float = randf_range(-volatility, volatility)
		var new_drift: float = clampf(
			current + reversion + noise, DRIFT_MIN, DRIFT_MAX
		)
		_drift_factors[item_def.id] = new_drift


func _restore_dict(data: Dictionary, key: String) -> Dictionary:
	var saved: Variant = data.get(key, {})
	if saved is Dictionary:
		return (saved as Dictionary).duplicate()
	return {}


func _on_order_cash_check(amount: float, result: Array) -> void:
	var adjusted: float = amount * DifficultySystem.get_modifier(
		&"wholesale_cost_multiplier"
	)
	result.append(_current_cash >= adjusted)


func _on_order_cash_deduct(
	amount: float, reason: String, result: Array
) -> void:
	var adjusted: float = amount * DifficultySystem.get_modifier(
		&"wholesale_cost_multiplier"
	)
	result.append(deduct_cash(adjusted, reason))


func _on_order_refund_issued(amount: float, reason: String) -> void:
	var adjusted: float = amount * DifficultySystem.get_modifier(
		&"wholesale_cost_multiplier"
	)
	add_cash(adjusted, reason)


func _on_payroll_cash_check(amount: float, result: Array) -> void:
	result.append(_current_cash >= amount)


func _on_payroll_cash_deduct(
	amount: float, reason: String, result: Array
) -> void:
	result.append(deduct_cash(amount, reason))


func _count_shelf_supply_by_category() -> Dictionary:
	var counts: Dictionary = {}
	if not _inventory_system:
		return counts
	var shelf_items: Array[ItemInstance] = (
		_inventory_system.get_shelf_items()
	)
	for item: ItemInstance in shelf_items:
		if not item.definition:
			continue
		var cat: String = item.definition.category
		var current: int = counts.get(cat, 0) as int
		counts[cat] = current + 1
	return counts


func _check_bankruptcy() -> void:
	if _current_cash <= 0.0 and not _bankruptcy_declared:
		_bankruptcy_declared = true
		EventBus.bankruptcy_declared.emit()


func _check_emergency_injection(day: int) -> void:
	if not DifficultySystem.get_flag(&"emergency_cash_injection_enabled"):
		return
	var threshold: float = _daily_rent * 2.0
	if _current_cash >= threshold:
		return
	if not _can_inject_this_week(day):
		return
	_perform_cash_injection(threshold, day)


func _can_inject_this_week(current_day: int) -> bool:
	if _last_injection_day < 0:
		return true
	return (current_day - _last_injection_day) >= 7


func _perform_cash_injection(threshold: float, day: int) -> void:
	var amount: float = threshold * 3.0
	_last_injection_day = day
	add_cash(amount, "Emergency cash injection")
	EventBus.emergency_cash_injected.emit(
		amount, "A loyal customer paid their tab early."
	)


func _on_customer_purchased(
	store_id: StringName,
	item_id: StringName,
	price: float,
	_customer_id: StringName
) -> void:
	if price <= 0.0:
		return
	add_cash(price, "Sale: %s at %s" % [item_id, store_id])
	if not String(store_id).is_empty():
		record_store_revenue(String(store_id), price)


func _on_emergency_cash_injected(
	amount: float, _reason: String
) -> void:
	if amount > 0.0 and _current_cash > 0.0 and _bankruptcy_declared:
		_bankruptcy_declared = false


func _on_milestone_unlocked(
	milestone_id: StringName, reward: Dictionary
) -> void:
	var reward_type: String = str(reward.get("reward_type", ""))
	if reward_type != "cash" and reward_type != "cash_bonus":
		return
	var amount: float = float(reward.get("reward_value", 0.0))
	if amount <= 0.0:
		return
	add_cash(amount, "Milestone reward: %s" % milestone_id)
