## Manages player cash, transactions, and market value calculations.
class_name EconomySystem
extends Node


## Transaction types for categorization in daily history.
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

const APPRECIATION_RATE: float = 0.002
const APPRECIATION_CAP: float = 1.5
const DEPRECIATION_RATE: float = 0.008
const DEPRECIATION_FLOOR: float = 0.1

## Current player cash balance.
var _current_cash: float = 0.0

## Transaction log for the current day.
var _daily_transactions: Array[Dictionary] = []

## Current game-minute timestamp source (set via TimeSystem signal).
var _current_time_minutes: int = 0

## Number of items sold today, reset each day.
var _items_sold_today: int = 0

## Daily rent amount for the current store.
var _daily_rent: float = 50.0

## Total rent deducted today, tracked for summary display.
var _daily_rent_total: float = 0.0

## Reference to InventorySystem for querying shelf supply.
var _inventory_system: InventorySystem = null

## Reference to TrendSystem for category/tag trend multiplier queries.
var _trend_system: TrendSystem = null

## Reference to MetaShiftSystem for PocketCreatures meta shift queries.
var _meta_shift_system: MetaShiftSystem = null

## Reference to ReputationSystem for supplier tier determination.
var _reputation_system: ReputationSystem = null

## Reference to SeasonCycleSystem for sports memorabilia season multiplier.
var _season_cycle_system: SeasonCycleSystem = null

## Cached supplier tier to detect changes.
var _cached_supplier_tier: int = 1

## Sales count per category for each of the last N days.
## Array of Dictionaries: [{category: count, ...}, ...]
var _sales_history: Array[Dictionary] = []

## Sales count per category for the current day (not yet committed).
var _today_sales: Dictionary = {}

## Demand modifier per category. Starts at 1.0, updated daily.
var _demand_modifiers: Dictionary = {}

## Per-store daily revenue tracking: store_id -> float.
var _store_daily_revenue: Dictionary = {}

## Drift factor per item definition id. Updated daily at day_started.
var _drift_factors: Dictionary = {}

## Pending stock orders to be delivered at the start of the next day.
## Each entry: {definition_id, condition, wholesale_cost}
var _pending_orders: Array[Dictionary] = []

## Total amount spent on orders today (resets each day).
var _daily_order_spending: float = 0.0

## Number of trades completed today (card-for-card swaps).
var _trades_today: int = 0


func initialize(starting_cash: float = Constants.STARTING_CASH) -> void:
	_current_cash = starting_cash
	_daily_transactions = []
	_items_sold_today = 0
	_daily_rent_total = 0.0
	_sales_history = []
	_today_sales = {}
	_pending_orders = []
	_daily_order_spending = 0.0
	_trades_today = 0
	_drift_factors = {}
	EventBus.day_started.connect(_on_day_started)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.trade_accepted.connect(_on_trade_accepted)
	EventBus.reputation_changed.connect(_on_reputation_changed)


## Sets the InventorySystem reference for shelf supply queries.
func set_inventory_system(inv: InventorySystem) -> void:
	_inventory_system = inv


## Sets the TrendSystem reference for category/tag trend queries.
func set_trend_system(ts: TrendSystem) -> void:
	_trend_system = ts


## Sets the MetaShiftSystem reference for PocketCreatures meta shift queries.
func set_meta_shift_system(mss: MetaShiftSystem) -> void:
	_meta_shift_system = mss


## Sets the ReputationSystem reference for supplier tier lookups.
func set_reputation_system(rep: ReputationSystem) -> void:
	_reputation_system = rep


## Sets the SeasonCycleSystem reference for season multiplier queries.
func set_season_cycle_system(scs: SeasonCycleSystem) -> void:
	_season_cycle_system = scs


## Returns the current supplier tier (1-3) based on reputation score.
func get_supplier_tier() -> int:
	var rep: float = 0.0
	if _reputation_system:
		rep = _reputation_system.get_reputation()
	return SupplierTierSystem.get_tier_for_reputation(rep)


## Returns the configuration dictionary for the current supplier tier.
func get_supplier_tier_config() -> Dictionary:
	return SupplierTierSystem.get_config(get_supplier_tier())


## Returns info about the next supplier tier unlock requirement.
## Returns empty dictionary if already at max tier.
func get_next_tier_info() -> Dictionary:
	return SupplierTierSystem.get_next_tier_info(get_supplier_tier())


## Returns true if an item's rarity is available at the current tier.
func is_item_available_at_tier(item_def: ItemDefinition) -> bool:
	return SupplierTierSystem.is_rarity_available(
		item_def.rarity, get_supplier_tier()
	)


## Returns the current cash balance.
func get_cash() -> float:
	return _current_cash


## Returns the number of items sold today.
func get_items_sold_today() -> int:
	return _items_sold_today


## Sets the daily rent amount.
func set_daily_rent(amount: float) -> void:
	_daily_rent = amount


## Calculates full market value for an item instance.
## Formula: base * condition * rarity * demand * drift * time * trend * season * auth
func calculate_market_value(item: ItemInstance) -> float:
	if not item or not item.definition:
		return 0.0
	if item.authentication_status == "fake":
		return 0.50
	var base: float = item.definition.base_price
	var cond_mult: float = ItemInstance.CONDITION_MULTIPLIERS.get(
		item.condition, 1.0
	)
	var rarity_mult: float = ItemInstance.RARITY_MULTIPLIERS.get(
		item.definition.rarity, 1.0
	)
	var demand: float = get_demand_modifier(item.definition.category)
	var drift: float = get_drift_factor(item.definition.id)
	var time_mult: float = _calc_time_multiplier(item)
	var trend: float = _get_trend_multiplier(item)
	var meta_shift: float = _get_meta_shift_multiplier(item)
	var season: float = _get_season_multiplier(item)
	var auth: float = _get_authentication_multiplier(item)
	return (
		base * cond_mult * rarity_mult
		* demand * drift * time_mult * trend * meta_shift * season
		* auth
	)


## Returns the trend multiplier from TrendSystem.
func _get_trend_multiplier(item: ItemInstance) -> float:
	if not _trend_system:
		return 1.0
	return _trend_system.get_trend_multiplier(item)


## Returns the meta shift multiplier from MetaShiftSystem (1.0 if none).
func _get_meta_shift_multiplier(item: ItemInstance) -> float:
	if not _meta_shift_system:
		return 1.0
	return _meta_shift_system.get_meta_shift_multiplier(item)


## Returns the authentication multiplier for autograph items.
## Authenticated = 2.0x, otherwise 1.0. Fake is handled separately.
func _get_authentication_multiplier(item: ItemInstance) -> float:
	if item.authentication_status == "authenticated":
		return 2.0
	return 1.0


## Returns the season cycle multiplier from SeasonCycleSystem (1.0 if none).
func _get_season_multiplier(item: ItemInstance) -> float:
	if not _season_cycle_system:
		return 1.0
	return _season_cycle_system.get_season_multiplier(item)


## Returns the current demand modifier for a category.
func get_demand_modifier(category: String) -> float:
	return _demand_modifiers.get(category, DEFAULT_DEMAND)


## Returns the current drift factor for an item definition id.
func get_drift_factor(item_id: String) -> float:
	return _drift_factors.get(item_id, DRIFT_DEFAULT)


## Calculates appreciation or depreciation multiplier for an item.
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


## Adds cash to the player's balance and records the transaction.
func add_cash(amount: float, reason: String) -> void:
	if amount <= 0.0:
		push_warning(
			"EconomySystem: add_cash called with non-positive amount: %s"
			% amount
		)
		return

	var old_cash: float = _current_cash
	_current_cash += amount
	_record_transaction(amount, reason, TransactionType.REVENUE)
	EventBus.money_changed.emit(old_cash, _current_cash)


## Deducts cash from the player's balance if sufficient funds exist.
## Returns true if deduction succeeded, false if insufficient funds.
func deduct_cash(amount: float, reason: String) -> bool:
	if amount <= 0.0:
		push_warning(
			"EconomySystem: deduct_cash called with non-positive amount: %s"
			% amount
		)
		return false

	if _current_cash < amount:
		return false

	var old_cash: float = _current_cash
	_current_cash -= amount
	_record_transaction(amount, reason, TransactionType.EXPENSE)
	EventBus.money_changed.emit(old_cash, _current_cash)
	return true


## Deducts cash even if it results in negative balance (used for rent).
func force_deduct_cash(amount: float, reason: String) -> void:
	if amount <= 0.0:
		push_warning(
			"EconomySystem: force_deduct called with non-positive: %s"
			% amount
		)
		return
	var old_cash: float = _current_cash
	_current_cash -= amount
	_record_transaction(amount, reason, TransactionType.EXPENSE)
	EventBus.money_changed.emit(old_cash, _current_cash)
	if _current_cash < 0.0:
		push_warning(
			"EconomySystem: cash is negative ($%.2f) after: %s"
			% [_current_cash, reason]
		)
		EventBus.notification_requested.emit(
			"Warning: You are in debt! Cash: $%.2f" % _current_cash
		)


## Returns a summary of today's financial activity.
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


## Serializes economy state for saving.
func get_save_data() -> Dictionary:
	var serialized_transactions: Array[Dictionary] = []
	for txn: Dictionary in _daily_transactions:
		serialized_transactions.append(txn.duplicate())

	var serialized_history: Array[Dictionary] = []
	for day_sales: Dictionary in _sales_history:
		serialized_history.append(day_sales.duplicate())

	var serialized_orders: Array[Dictionary] = []
	for order: Dictionary in _pending_orders:
		serialized_orders.append(order.duplicate())

	return {
		"current_cash": _current_cash,
		"daily_transactions": serialized_transactions,
		"current_time_minutes": _current_time_minutes,
		"items_sold_today": _items_sold_today,
		"daily_rent": _daily_rent,
		"daily_rent_total": _daily_rent_total,
		"sales_history": serialized_history,
		"today_sales": _today_sales.duplicate(),
		"demand_modifiers": _demand_modifiers.duplicate(),
		"store_daily_revenue": _store_daily_revenue.duplicate(),
		"pending_orders": serialized_orders,
		"daily_order_spending": _daily_order_spending,
		"trades_today": _trades_today,
		"drift_factors": _drift_factors.duplicate(),
	}


## Restores economy state from saved data.
func load_save_data(data: Dictionary) -> void:
	_current_cash = data.get("current_cash", Constants.STARTING_CASH)
	_current_time_minutes = data.get("current_time_minutes", 0)
	_items_sold_today = data.get("items_sold_today", 0)
	_daily_rent = data.get("daily_rent", 50.0)
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

	_today_sales = {}
	var saved_today: Variant = data.get("today_sales", {})
	if saved_today is Dictionary:
		_today_sales = (saved_today as Dictionary).duplicate()

	_demand_modifiers = {}
	var saved_demand: Variant = data.get("demand_modifiers", {})
	if saved_demand is Dictionary:
		_demand_modifiers = (saved_demand as Dictionary).duplicate()

	_store_daily_revenue = {}
	var saved_store_rev: Variant = data.get("store_daily_revenue", {})
	if saved_store_rev is Dictionary:
		_store_daily_revenue = (saved_store_rev as Dictionary).duplicate()

	_daily_rent_total = float(data.get("daily_rent_total", 0.0))
	_daily_order_spending = float(
		data.get("daily_order_spending", 0.0)
	)
	_trades_today = int(data.get("trades_today", 0))

	_pending_orders = []
	var saved_orders: Array = data.get("pending_orders", [])
	for order: Variant in saved_orders:
		if order is Dictionary:
			_pending_orders.append(order as Dictionary)

	_drift_factors = {}
	var saved_drift: Variant = data.get("drift_factors", {})
	if saved_drift is Dictionary:
		_drift_factors = (saved_drift as Dictionary).duplicate()


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
	_deliver_pending_orders()
	var elapsed: int = Time.get_ticks_msec() - start_ticks
	if elapsed > 100:
		push_warning(
			"EconomySystem: day-start calculations took %dms"
			% elapsed
		)
	_daily_transactions = []
	_current_time_minutes = 0
	_items_sold_today = 0
	_trades_today = 0
	_daily_rent_total = 0.0
	_today_sales = {}
	_store_daily_revenue = {}
	_daily_order_spending = 0.0


func _on_day_ended(_day: int) -> void:
	var start_ticks: int = Time.get_ticks_msec()
	_commit_daily_sales()
	_update_demand_modifiers()
	_deduct_all_store_rents()
	var elapsed: int = Time.get_ticks_msec() - start_ticks
	if elapsed > 100:
		push_warning(
			"EconomySystem: day-end calculations took %dms"
			% elapsed
		)


## Deducts rent for every owned store based on their definitions.
func _deduct_all_store_rents() -> void:
	_daily_rent_total = 0.0
	for store_id: String in GameManager.owned_stores:
		var rent: float = _daily_rent
		if GameManager.data_loader:
			var store_def: StoreDefinition = (
				GameManager.data_loader.get_store(store_id)
			)
			if store_def:
				rent = store_def.daily_rent
		_daily_rent_total += rent
		force_deduct_cash(rent, "Rent: %s" % store_id)


func _on_hour_changed(hour: int) -> void:
	_current_time_minutes = hour * Constants.MINUTES_PER_HOUR


## Returns the daily revenue for a specific store.
func get_store_daily_revenue(store_id: String) -> float:
	return _store_daily_revenue.get(store_id, 0.0)


## Records revenue for a specific store.
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
	var active_store: String = GameManager.current_store_id
	if not active_store.is_empty():
		record_store_revenue(active_store, _price)
	if category.is_empty():
		return
	var current: int = _today_sales.get(category, 0) as int
	_today_sales[category] = current + 1


## Pushes today's sales into the rolling history window.
func _commit_daily_sales() -> void:
	_sales_history.append(_today_sales.duplicate())
	while _sales_history.size() > SALES_HISTORY_DAYS:
		_sales_history.pop_front()


## Recalculates demand modifiers based on sales ratio per category.
## Single-pass aggregation of sales history for efficiency.
func _update_demand_modifiers() -> void:
	# Aggregate all sales in a single pass over history
	var total_sales_by_cat: Dictionary = {}
	for day_sales: Dictionary in _sales_history:
		for cat: String in day_sales:
			var prev: int = total_sales_by_cat.get(cat, 0) as int
			total_sales_by_cat[cat] = prev + (day_sales[cat] as int)

	var shelf_supply: Dictionary = _count_shelf_supply_by_category()

	# Merge category sets
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


## Updates drift factors for all item definitions using a random walk
## with mean reversion. Called at day_started.
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


## Returns the wholesale price for an item definition at the current tier.
func get_wholesale_price(item_def: ItemDefinition) -> float:
	if not item_def:
		return 0.0
	var config: Dictionary = get_supplier_tier_config()
	var multiplier: float = config["wholesale"]
	return item_def.base_price * multiplier


## Returns the remaining order budget for today based on current tier.
func get_remaining_order_budget() -> float:
	var config: Dictionary = get_supplier_tier_config()
	var limit: float = config["daily_limit"]
	return maxf(0.0, limit - _daily_order_spending)


## Returns the daily order limit for the current tier.
func get_daily_order_limit() -> float:
	var config: Dictionary = get_supplier_tier_config()
	return config["daily_limit"]


## Returns the total spent on orders today.
func get_daily_order_spending() -> float:
	return _daily_order_spending


## Places a stock order for an item. Cost is deducted immediately.
## Returns true if order was placed, false otherwise.
func place_order(item_def: ItemDefinition) -> bool:
	if not item_def:
		push_warning("EconomySystem: place_order called with null def")
		return false
	if not is_item_available_at_tier(item_def):
		EventBus.notification_requested.emit(
			"'%s' not available at current supplier tier"
			% item_def.name
		)
		return false
	var cost: float = get_wholesale_price(item_def)
	if cost <= 0.0:
		return false
	var daily_limit: float = get_daily_order_limit()
	if _daily_order_spending + cost > daily_limit:
		EventBus.notification_requested.emit(
			"Daily order limit ($%.0f) exceeded" % daily_limit
		)
		return false
	if _current_cash < cost:
		EventBus.notification_requested.emit("Insufficient funds")
		return false
	if not deduct_cash(cost, "Order: %s" % item_def.name):
		return false
	_daily_order_spending += cost
	var config: Dictionary = get_supplier_tier_config()
	var delivery_days: int = config["delivery_days"]
	var order: Dictionary = {
		"definition_id": item_def.id,
		"condition": "good",
		"wholesale_cost": cost,
		"delivery_day": GameManager.current_day + delivery_days,
	}
	_pending_orders.append(order)
	EventBus.order_placed.emit(order)
	return true


## Returns the number of pending orders.
func get_pending_order_count() -> int:
	return _pending_orders.size()


## Delivers pending orders whose delivery day has arrived.
func _deliver_pending_orders() -> void:
	if _pending_orders.is_empty() or not _inventory_system:
		return
	var delivered: int = 0
	var remaining: Array[Dictionary] = []
	for order: Dictionary in _pending_orders:
		var delivery_day: int = order.get(
			"delivery_day", GameManager.current_day
		)
		if delivery_day > GameManager.current_day:
			remaining.append(order)
			continue
		var def_id: String = order.get("definition_id", "")
		var condition: String = order.get("condition", "good")
		var cost: float = order.get("wholesale_cost", 0.0)
		var item: ItemInstance = _inventory_system.create_item(
			def_id, condition, cost
		)
		if item:
			delivered += 1
			EventBus.order_delivered.emit(order)
		else:
			push_warning(
				"EconomySystem: failed to deliver order '%s'"
				% def_id
			)
	_pending_orders = remaining
	if delivered > 0:
		EventBus.notification_requested.emit(
			"%d order(s) delivered to backroom" % delivered
		)


func _on_reputation_changed(
	_old_value: float, _new_value: float
) -> void:
	_check_tier_change()


## Emits supplier_tier_changed if the tier changed since last check.
func _check_tier_change() -> void:
	var new_tier: int = get_supplier_tier()
	if new_tier != _cached_supplier_tier:
		var old_tier: int = _cached_supplier_tier
		_cached_supplier_tier = new_tier
		EventBus.supplier_tier_changed.emit(old_tier, new_tier)


## Counts items on shelves grouped by category.
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
