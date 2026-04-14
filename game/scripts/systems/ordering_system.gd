## Manages stock ordering, delivery queues, and supplier tier filtering.
class_name OrderingSystem
extends Node


var _inventory_system: InventorySystem = null
var _reputation_system: ReputationSystem = null
var _cached_supplier_tier: int = 1
var _pending_orders: Array[Dictionary] = []
var _daily_order_spending: float = 0.0


func initialize(
	inventory: InventorySystem,
	reputation: ReputationSystem,
) -> void:
	_inventory_system = inventory
	_reputation_system = reputation
	_apply_state({})
	EventBus.day_started.connect(_on_day_started)
	EventBus.reputation_changed.connect(_on_reputation_changed)


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
func get_next_tier_info() -> Dictionary:
	return SupplierTierSystem.get_next_tier_info(get_supplier_tier())


## Returns true if an item's rarity is available at the current tier.
func is_item_available_at_tier(item_def: ItemDefinition) -> bool:
	return SupplierTierSystem.is_rarity_available(
		item_def.rarity, get_supplier_tier()
	)


## Returns the wholesale price for an item at the current tier.
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
		push_warning("OrderingSystem: place_order called with null def")
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
	var check_result: Array = []
	EventBus.order_cash_check.emit(cost, check_result)
	if check_result.is_empty() or not check_result[0]:
		EventBus.notification_requested.emit("Insufficient funds")
		return false
	var deduct_result: Array = []
	EventBus.order_cash_deduct.emit(
		cost, "Order: %s" % item_def.name, deduct_result
	)
	if deduct_result.is_empty() or not deduct_result[0]:
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


## Serializes ordering state for saving.
func get_save_data() -> Dictionary:
	var serialized_orders: Array[Dictionary] = []
	for order: Dictionary in _pending_orders:
		serialized_orders.append(order.duplicate())
	return {
		"pending_orders": serialized_orders,
		"daily_order_spending": _daily_order_spending,
	}


## Restores ordering state from saved data.
func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_daily_order_spending = float(
		data.get("daily_order_spending", 0.0)
	)
	_pending_orders = []
	var saved_orders: Array = data.get("pending_orders", [])
	for order: Variant in saved_orders:
		if order is Dictionary:
			_pending_orders.append(order as Dictionary)


func _on_day_started(_day: int) -> void:
	_deliver_pending_orders()
	_daily_order_spending = 0.0


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
				"OrderingSystem: failed to deliver order '%s'"
				% def_id
			)
	_pending_orders = remaining
	if delivered > 0:
		EventBus.notification_requested.emit(
			"%d order(s) delivered to backroom" % delivered
		)


func _on_reputation_changed(
	_store_id: String, _new_value: float
) -> void:
	_check_tier_change()


## Emits supplier_tier_changed if the tier changed since last check.
func _check_tier_change() -> void:
	var new_tier: int = get_supplier_tier()
	if new_tier != _cached_supplier_tier:
		var old_tier: int = _cached_supplier_tier
		_cached_supplier_tier = new_tier
		EventBus.supplier_tier_changed.emit(old_tier, new_tier)
