## Manages stock ordering with tiered suppliers, delivery queues, and unlock gates.
class_name OrderSystem
extends Node


enum SupplierTier { BASIC, SPECIALTY, LIQUIDATOR, PREMIUM }
const TIER_CONFIG: Dictionary = {
	SupplierTier.BASIC: {
		"name": "Basic",
		"price_multiplier": 1.25,
		"delivery_days": 1,
		"daily_limit": 500.0,
		"rarities": ["common", "uncommon"],
		"required_reputation_tier": 0,
		"required_store_level": 0,
	},
	SupplierTier.SPECIALTY: {
		"name": "Specialty",
		"price_multiplier": 1.125,
		"delivery_days": 2,
		"daily_limit": 1000.0,
		"rarities": ["common", "uncommon", "rare"],
		"required_reputation_tier": 2,
		"required_store_level": 0,
	},
	SupplierTier.LIQUIDATOR: {
		"name": "Liquidator",
		"price_multiplier": 0.6,
		"delivery_days": 3,
		"daily_limit": 750.0,
		"rarities": ["common", "uncommon", "rare", "very_rare"],
		"required_reputation_tier": 0,
		"required_store_level": 3,
	},
	SupplierTier.PREMIUM: {
		"name": "Premium",
		"price_multiplier": 1.0,
		"delivery_days": 1,
		"daily_limit": 2000.0,
		"rarities": ["uncommon", "rare", "very_rare", "legendary"],
		"required_reputation_tier": 4,
		"required_store_level": 0,
	},
}

var _inventory_system: InventorySystem = null
var _reputation_system: ReputationSystem = null
var _progression_system: ProgressionSystem = null
var _pending_orders: Array[Dictionary] = []
var _daily_spending: Dictionary = {}
## When true, forces every delivery to be a partial stockout (for testing only).
var _force_stockout_for_test: bool = false


func initialize(
	inventory: InventorySystem,
	reputation: ReputationSystem,
	progression: ProgressionSystem,
) -> void:
	_inventory_system = inventory
	_reputation_system = reputation
	_progression_system = progression
	_apply_state({})
	EventBus.day_started.connect(_on_day_started)
	EventBus.order_delivered.connect(_on_order_delivered)
	EventBus.difficulty_changed.connect(_on_difficulty_changed)
	EventBus.restock_requested.connect(_on_restock_requested)


## Returns true if the given supplier tier is currently unlocked.
func is_tier_unlocked(tier: SupplierTier) -> bool:
	var config: Dictionary = TIER_CONFIG[tier]
	var req_rep: int = config["required_reputation_tier"]
	var req_level: int = config["required_store_level"]
	if req_rep > 0 and _reputation_system:
		if int(_reputation_system.get_tier()) < req_rep:
			return false
	if req_level > 0 and _progression_system:
		if _progression_system.get_unlocked_store_slots() < req_level:
			return false
	return true


## Returns the wholesale cost for an item at a given supplier tier.
func get_order_cost(
	item_def: ItemDefinition, tier: SupplierTier
) -> float:
	if not item_def:
		return 0.0
	var config: Dictionary = TIER_CONFIG[tier]
	var multiplier: float = config["price_multiplier"]
	return item_def.base_price * multiplier


## Returns true if an item's rarity is available at the given tier.
func is_item_in_tier_catalog(
	item_def: ItemDefinition, tier: SupplierTier
) -> bool:
	if not item_def:
		return false
	var config: Dictionary = TIER_CONFIG[tier]
	var allowed: Array = config["rarities"]
	return item_def.rarity in allowed


## Returns the tier configuration dictionary for the given tier.
func get_tier_config(tier: SupplierTier) -> Dictionary:
	return TIER_CONFIG[tier]


## Returns all unlocked supplier tiers.
func get_unlocked_tiers() -> Array[int]:
	var result: Array[int] = []
	for tier_key: int in TIER_CONFIG:
		if is_tier_unlocked(tier_key as SupplierTier):
			result.append(tier_key)
	return result


## Places a stock order. Returns true on success, false on failure.
func place_order(
	store_id: StringName,
	supplier_tier: SupplierTier,
	item_id: StringName,
	quantity: int,
) -> bool:
	if quantity <= 0:
		EventBus.order_failed.emit("Invalid quantity")
		return false
	if not is_tier_unlocked(supplier_tier):
		EventBus.order_failed.emit("Supplier tier locked")
		return false
	var item_def: ItemDefinition = _resolve_item(item_id)
	if not item_def:
		EventBus.order_failed.emit(
			"Item '%s' not found" % item_id
		)
		return false
	if not is_item_in_tier_catalog(item_def, supplier_tier):
		EventBus.order_failed.emit(
			"'%s' not available at %s tier"
			% [item_def.name, TIER_CONFIG[supplier_tier]["name"]]
		)
		return false
	if _has_pending_order(store_id, item_id):
		EventBus.order_failed.emit("Order for '%s' already pending" % item_id)
		return false
	var unit_cost: float = get_order_cost(item_def, supplier_tier)
	var total_cost: float = unit_cost * quantity
	var daily_limit: float = get_daily_limit(supplier_tier)
	var spent: float = _get_tier_spending(supplier_tier)
	if spent + total_cost > daily_limit:
		EventBus.order_failed.emit(
			"Daily order limit ($%.0f) exceeded" % daily_limit
		)
		return false
	var check_result: Array = []
	EventBus.order_cash_check.emit(total_cost, check_result)
	if check_result.is_empty() or not check_result[0]:
		EventBus.order_failed.emit("Insufficient funds")
		return false
	var deduct_result: Array = []
	EventBus.order_cash_deduct.emit(
		total_cost,
		"Order: %dx %s" % [quantity, item_def.name],
		deduct_result,
	)
	if deduct_result.is_empty() or not deduct_result[0]:
		EventBus.order_failed.emit("Payment failed")
		return false
	_add_tier_spending(supplier_tier, total_cost)
	var delivery_day: int = (
		GameManager.current_day + get_effective_delivery_days(supplier_tier)
	)
	var order: Dictionary = {
		"store_id": String(store_id),
		"supplier_tier": supplier_tier,
		"item_id": String(item_id),
		"quantity": quantity,
		"unit_cost": unit_cost,
		"delivery_day": delivery_day,
	}
	_pending_orders.append(order)
	EventBus.order_placed.emit(
		store_id, item_id, quantity, delivery_day
	)
	return true


## Returns the number of pending orders.
func get_pending_order_count() -> int:
	return _pending_orders.size()


## Returns a copy of all pending orders.
func get_pending_orders() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for order: Dictionary in _pending_orders:
		result.append(order.duplicate())
	return result


## Returns a copy of pending orders filtered to a specific store.
func get_pending_orders_for_store(store_id: StringName) -> Array[Dictionary]:
	var canonical: String = String(store_id)
	var result: Array[Dictionary] = []
	for order: Dictionary in _pending_orders:
		if order.get("store_id", "") == canonical:
			result.append(order.duplicate())
	return result


## Returns the daily spending for a given supplier tier.
func get_daily_spending(tier: SupplierTier) -> float:
	return _get_tier_spending(tier)


## Returns the daily order limit for a given supplier tier after applying the difficulty modifier.
func get_daily_limit(tier: SupplierTier) -> float:
	var base_limit: float = TIER_CONFIG[tier]["daily_limit"]
	var mult: float = DifficultySystemSingleton.get_modifier(&"daily_order_limit_multiplier")
	return maxf(1.0, base_limit * mult)


## Returns the effective delivery days for a tier after applying the difficulty modifier.
func get_effective_delivery_days(tier: SupplierTier) -> int:
	var base_days: int = TIER_CONFIG[tier]["delivery_days"]
	var mult: float = DifficultySystemSingleton.get_modifier(&"supplier_lead_time_multiplier")
	return maxi(1, roundi(float(base_days) * mult))


## Returns the per-order stockout probability for the current difficulty tier.
func get_stockout_probability() -> float:
	return DifficultySystemSingleton.get_modifier(&"supplier_stockout_probability")


## Recalculates delivery days for all pending orders using current difficulty.
func recalculate_pending_delivery_times() -> void:
	for order: Dictionary in _pending_orders:
		var tier_val: int = int(order.get("supplier_tier", 0))
		var tier: SupplierTier = tier_val as SupplierTier
		var placed_day: int = (
			int(order.get("delivery_day", 0))
			- TIER_CONFIG[tier]["delivery_days"]
		)
		var new_delivery: int = (
			placed_day + get_effective_delivery_days(tier)
		)
		order["delivery_day"] = new_delivery


## Returns remaining daily budget for a given supplier tier.
func get_remaining_daily_budget(tier: SupplierTier) -> float:
	var limit: float = get_daily_limit(tier)
	return maxf(0.0, limit - _get_tier_spending(tier))


## Serializes order state for saving.
func get_save_data() -> Dictionary:
	var serialized: Array[Dictionary] = []
	for order: Dictionary in _pending_orders:
		serialized.append(order.duplicate())
	return {
		"pending_orders": serialized,
		"daily_spending": _daily_spending.duplicate(),
	}


## Restores order state from saved data.
func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_pending_orders = []
	_daily_spending = {}
	var saved: Array = data.get("pending_orders", [])
	for entry: Variant in saved:
		if entry is Dictionary:
			_pending_orders.append(entry as Dictionary)
	var saved_spending: Variant = data.get("daily_spending", {})
	if saved_spending is Dictionary:
		_daily_spending = (saved_spending as Dictionary).duplicate()


func _on_day_started(day: int) -> void:
	_daily_spending = {}
	_deliver_pending_orders(day)


func _deliver_pending_orders(current_day: int) -> void:
	if _pending_orders.is_empty() or not _inventory_system:
		return
	var remaining: Array[Dictionary] = []
	var delivered_by_store: Dictionary = {}
	var stockout_prob: float = get_stockout_probability()
	for order: Dictionary in _pending_orders:
		if int(order.get("delivery_day", current_day)) > current_day:
			remaining.append(order)
			continue
		_process_order_delivery(order, stockout_prob, delivered_by_store)
	_pending_orders = remaining
	_emit_delivery_results(delivered_by_store)


func _process_order_delivery(
	order: Dictionary,
	stockout_prob: float,
	delivered_by_store: Dictionary,
) -> void:
	var sid: String = order.get("store_id", "")
	var iid: String = order.get("item_id", "")
	var qty: int = int(order.get("quantity", 1))
	var cost: float = float(order.get("unit_cost", 0.0))
	if _force_stockout_for_test or randf() < stockout_prob:
		var fulfilled: int = _calculate_partial_fill(qty)
		EventBus.order_stockout.emit(StringName(iid), qty, fulfilled)
		_issue_partial_refund(order, fulfilled)
		_create_and_collect_items(sid, iid, fulfilled, cost, delivered_by_store)
	else:
		_create_and_collect_items(sid, iid, qty, cost, delivered_by_store)


func _calculate_partial_fill(requested: int) -> int:
	var min_fill: int = ceili(requested * 0.40)
	var max_fill: int = ceili(requested * 0.75)
	return randi_range(min_fill, max_fill)


func _issue_partial_refund(order: Dictionary, fulfilled: int) -> void:
	var qty: int = int(order.get("quantity", 1))
	var unit_cost: float = float(order.get("unit_cost", 0.0))
	var undelivered: int = qty - fulfilled
	var refund: float = unit_cost * float(undelivered)
	if refund <= 0.0:
		return
	var item_id: String = order.get("item_id", "unknown")
	EventBus.order_refund_issued.emit(
		refund,
		"Stockout: %dx %s undelivered" % [undelivered, item_id],
	)


func _create_and_collect_items(
	sid: String,
	iid: String,
	qty: int,
	unit_cost: float,
	delivered_by_store: Dictionary,
) -> void:
	var items_created: Array[String] = []
	for i: int in range(qty):
		var item: ItemInstance = _inventory_system.create_item(iid, "good", unit_cost)
		if item:
			items_created.append(item.instance_id)
		else:
			push_warning(
				"OrderSystem: failed to create item '%s' (%d/%d)" % [iid, i + 1, qty]
			)
	if not delivered_by_store.has(sid):
		delivered_by_store[sid] = []
	delivered_by_store[sid].append_array(items_created)


func _emit_delivery_results(delivered_by_store: Dictionary) -> void:
	var total: int = 0
	for sid: String in delivered_by_store:
		var items: Array = delivered_by_store[sid]
		if not items.is_empty():
			EventBus.order_delivered.emit(StringName(sid), items)
		total += items.size()
	if total > 0:
		EventBus.notification_requested.emit("%d item(s) delivered to backroom" % total)


func _on_difficulty_changed(
	_old_tier: int, _new_tier: int
) -> void:
	recalculate_pending_delivery_times()


func _on_order_delivered(
	store_id: StringName, items: Array
) -> void:
	if items.is_empty():
		return
	var store_name: String = ContentRegistry.get_display_name(store_id)
	var message: String = _build_delivery_message(items, store_name)
	EventBus.toast_requested.emit(message, &"system", 4.0)


func _build_delivery_message(
	items: Array, store_name: String
) -> String:
	var unique_ids: Dictionary = {}
	for instance_id: Variant in items:
		if not _inventory_system:
			break
		var item: ItemInstance = _inventory_system.get_item(
			str(instance_id)
		)
		if item and item.definition:
			var def_id: String = item.definition.id
			if not unique_ids.has(def_id):
				unique_ids[def_id] = {
					"name": item.definition.name, "count": 0,
				}
			unique_ids[def_id]["count"] += 1
	if unique_ids.size() == 1:
		var info: Dictionary = unique_ids.values()[0]
		var item_name: String = info["name"]
		var count: int = info["count"]
		return "%s (x%d) delivered to %s" % [
			item_name, count, store_name,
		]
	return "Order arrived: %d item(s) delivered to %s" % [
		items.size(), store_name,
	]


func _on_restock_requested(
	store_id: StringName, item_id: StringName, quantity: int
) -> void:
	var delivery_day: int = GameManager.current_day + 1
	var order: Dictionary = {
		"store_id": String(store_id),
		"supplier_tier": SupplierTier.BASIC,
		"item_id": String(item_id),
		"quantity": quantity,
		"unit_cost": 0.0,
		"delivery_day": delivery_day,
		"auto_restock": true,
	}
	_pending_orders.append(order)
	EventBus.order_placed.emit(store_id, item_id, quantity, delivery_day)


func _resolve_item(item_id: StringName) -> ItemDefinition:
	if not GameManager.data_loader:
		return null
	return GameManager.data_loader.get_item(String(item_id))


func _get_tier_spending(tier: SupplierTier) -> float:
	var key: String = str(tier)
	if _daily_spending.has(key):
		return float(_daily_spending[key])
	return 0.0


func _add_tier_spending(tier: SupplierTier, amount: float) -> void:
	var key: String = str(tier)
	var current: float = _get_tier_spending(tier)
	_daily_spending[key] = current + amount


## Returns true if a non-auto-restock order for the same store+item is already pending.
func _has_pending_order(store_id: StringName, item_id: StringName) -> bool:
	var sid: String = String(store_id)
	var iid: String = String(item_id)
	for existing: Dictionary in _pending_orders:
		if (not existing.get("auto_restock", false)
				and existing.get("store_id", "") == sid
				and existing.get("item_id", "") == iid):
			return true
	return false
