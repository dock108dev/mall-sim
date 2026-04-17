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
var _signals_connected: bool = false
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
	_connect_runtime_signals()


func _exit_tree() -> void:
	_disconnect_runtime_signals()


## Returns true if the given supplier tier is currently unlocked.
func is_tier_unlocked(
	tier: SupplierTier, store_id: StringName = &""
) -> bool:
	var config: Dictionary = TIER_CONFIG[tier]
	var req_rep: int = config["required_reputation_tier"]
	var req_level: int = config["required_store_level"]
	var canonical_store_id: StringName = _resolve_store_id(store_id)
	if req_rep > 0:
		if not _reputation_system:
			return false
		if _get_supplier_reputation_level(canonical_store_id) < req_rep:
			return false
	if req_level > 0:
		if not _progression_system:
			return false
		if _get_store_level(canonical_store_id) < req_level:
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


## Submits a cart of items as a single atomic order transaction.
func submit_order(
	store_id: StringName,
	supplier_tier: SupplierTier,
	cart_items: Array[Dictionary],
) -> bool:
	var submission: Dictionary = _prepare_submission(
		store_id, supplier_tier, cart_items
	)
	if submission.is_empty():
		return false
	return _commit_submission(submission)


## Places a stock order. Returns true on success, false on failure.
func place_order(
	store_id: StringName,
	supplier_tier: SupplierTier,
	item_id: StringName,
	quantity: int,
) -> bool:
	var cart_items: Array[Dictionary] = [
		{"item_id": String(item_id), "quantity": quantity},
	]
	return submit_order(store_id, supplier_tier, cart_items)


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
			var restored: Dictionary = (entry as Dictionary).duplicate()
			var store_id: StringName = _resolve_store_id(
				StringName(str(restored.get("store_id", "")))
			)
			var item_id: StringName = _resolve_item_id(
				StringName(str(restored.get("item_id", "")))
			)
			restored["store_id"] = String(store_id)
			restored["item_id"] = String(item_id)
			restored["quantity"] = maxi(0, int(restored.get("quantity", 0)))
			restored["unit_cost"] = maxf(0.0, float(restored.get("unit_cost", 0.0)))
			restored["delivery_day"] = int(restored.get("delivery_day", 0))
			_pending_orders.append(restored)
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
					"name": _get_item_display_name(item.definition), "count": 0,
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


func _resolve_item_id(item_id: StringName) -> StringName:
	if not GameManager.data_loader:
		return item_id
	var canonical: StringName = ContentRegistry.resolve(String(item_id))
	if canonical.is_empty():
		return item_id
	return canonical


func _prepare_submission(
	store_id: StringName,
	supplier_tier: SupplierTier,
	cart_items: Array[Dictionary],
) -> Dictionary:
	var canonical_store_id: StringName = _resolve_store_id(store_id)
	if canonical_store_id.is_empty():
		push_error("OrderSystem: invalid store_id '%s'" % store_id)
		return _emit_order_failed("Invalid store")
	if cart_items.is_empty():
		return _emit_order_failed("Cart is empty")
	if not is_tier_unlocked(supplier_tier, canonical_store_id):
		return _emit_order_failed("Supplier tier locked")
	var normalized_items: Array[Dictionary] = _normalize_cart_items(cart_items)
	if normalized_items.is_empty():
		return {}
	var prepared_orders: Array[Dictionary] = []
	var total_cost: float = 0.0
	for entry: Dictionary in normalized_items:
		var canonical_item_id: StringName = entry["item_id"] as StringName
		var quantity: int = int(entry["quantity"])
		var item_def: ItemDefinition = _resolve_item(canonical_item_id)
		if not item_def:
			return _emit_order_failed(
				"Item '%s' not found" % canonical_item_id
			)
		if not is_item_in_tier_catalog(item_def, supplier_tier):
			return _emit_order_failed(
				"'%s' not available at %s tier"
				% [
					_get_item_display_name(item_def),
					TIER_CONFIG[supplier_tier]["name"],
				]
			)
		if not _can_store_order_item(canonical_store_id, item_def):
			return _emit_order_failed(
				"'%s' not available for %s"
				% [
					_get_item_display_name(item_def),
					ContentRegistry.get_display_name(canonical_store_id),
				]
			)
		if _has_pending_order(canonical_store_id, canonical_item_id):
			return _emit_order_failed(
				"Order for '%s' already pending" % canonical_item_id
			)
		var unit_cost: float = get_order_cost(item_def, supplier_tier)
		var line_total: float = unit_cost * quantity
		total_cost += line_total
		prepared_orders.append({
			"item_id": canonical_item_id,
			"quantity": quantity,
			"unit_cost": unit_cost,
			"item_name": _get_item_display_name(item_def),
		})
	var daily_limit: float = get_daily_limit(supplier_tier)
	var spent: float = _get_tier_spending(supplier_tier)
	if spent + total_cost > daily_limit:
		return _emit_order_failed(
			"Daily order limit ($%.0f) exceeded" % daily_limit
		)
	var check_result: Array = []
	EventBus.order_cash_check.emit(total_cost, check_result)
	if check_result.is_empty() or not check_result[0]:
		return _emit_order_failed("Insufficient funds")
	return {
		"store_id": canonical_store_id,
		"supplier_tier": supplier_tier,
		"orders": prepared_orders,
		"total_cost": total_cost,
	}


func _commit_submission(submission: Dictionary) -> bool:
	var total_cost: float = float(submission.get("total_cost", 0.0))
	var deduct_result: Array = []
	EventBus.order_cash_deduct.emit(
		total_cost,
		_build_submission_reason(submission),
		deduct_result,
	)
	if deduct_result.is_empty() or not deduct_result[0]:
		_emit_order_failed("Payment failed")
		return false
	var store_id: StringName = submission["store_id"] as StringName
	var supplier_tier: SupplierTier = (
		int(submission["supplier_tier"]) as SupplierTier
	)
	var delivery_day: int = (
		GameManager.current_day + get_effective_delivery_days(supplier_tier)
	)
	_add_tier_spending(supplier_tier, total_cost)
	var prepared_orders: Array = submission.get("orders", [])
	for entry_value: Variant in prepared_orders:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value as Dictionary
		var item_id: StringName = entry["item_id"] as StringName
		var quantity: int = int(entry["quantity"])
		var order: Dictionary = {
			"store_id": String(store_id),
			"supplier_tier": supplier_tier,
			"item_id": String(item_id),
			"quantity": quantity,
			"unit_cost": float(entry["unit_cost"]),
			"delivery_day": delivery_day,
		}
		_pending_orders.append(order)
		EventBus.order_placed.emit(
			store_id, item_id, quantity, delivery_day
		)
	return true


func _normalize_cart_items(
	cart_items: Array[Dictionary],
) -> Array[Dictionary]:
	var ordered_item_ids: Array[StringName] = []
	var item_quantities: Dictionary = {}
	for entry: Dictionary in cart_items:
		var item_id: StringName = _extract_cart_item_id(entry)
		if item_id.is_empty():
			_emit_order_failed("Invalid item")
			return []
		var quantity: int = int(entry.get("quantity", 0))
		if quantity <= 0:
			_emit_order_failed("Invalid quantity")
			return []
		if not item_quantities.has(item_id):
			item_quantities[item_id] = 0
			ordered_item_ids.append(item_id)
		item_quantities[item_id] = int(item_quantities[item_id]) + quantity
	var normalized: Array[Dictionary] = []
	for item_id: StringName in ordered_item_ids:
		normalized.append({
			"item_id": item_id,
			"quantity": int(item_quantities[item_id]),
		})
	return normalized


func _extract_cart_item_id(entry: Dictionary) -> StringName:
	if entry.has("item_id"):
		return _resolve_item_id(
			StringName(str(entry.get("item_id", "")))
		)
	var item_def: ItemDefinition = entry.get("item_def", null) as ItemDefinition
	if item_def:
		return _resolve_item_id(StringName(item_def.id))
	return &""


func _build_submission_reason(submission: Dictionary) -> String:
	var prepared_orders: Array = submission.get("orders", [])
	if prepared_orders.size() == 1:
		var only_entry: Dictionary = prepared_orders[0] as Dictionary
		return "Order: %dx %s" % [
			int(only_entry.get("quantity", 0)),
			str(only_entry.get("item_name", "Unknown Item")),
		]
	var tier: SupplierTier = int(submission.get("supplier_tier", 0)) as SupplierTier
	return "Stock order (%s)" % TIER_CONFIG[tier]["name"]


func _emit_order_failed(reason: String) -> Dictionary:
	EventBus.order_failed.emit(reason)
	return {}


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


func _connect_runtime_signals() -> void:
	if _signals_connected:
		return
	EventBus.day_started.connect(_on_day_started)
	EventBus.order_delivered.connect(_on_order_delivered)
	EventBus.difficulty_changed.connect(_on_difficulty_changed)
	EventBus.restock_requested.connect(_on_restock_requested)
	_signals_connected = true


func _disconnect_runtime_signals() -> void:
	if not _signals_connected:
		return
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)
	if EventBus.order_delivered.is_connected(_on_order_delivered):
		EventBus.order_delivered.disconnect(_on_order_delivered)
	if EventBus.difficulty_changed.is_connected(_on_difficulty_changed):
		EventBus.difficulty_changed.disconnect(_on_difficulty_changed)
	if EventBus.restock_requested.is_connected(_on_restock_requested):
		EventBus.restock_requested.disconnect(_on_restock_requested)
	_signals_connected = false


func _resolve_store_id(store_id: StringName) -> StringName:
	if store_id.is_empty():
		if not GameManager.current_store_id.is_empty():
			return GameManager.current_store_id
		return &""
	var canonical: StringName = ContentRegistry.resolve(String(store_id))
	if canonical.is_empty():
		return store_id
	return canonical


func _get_supplier_reputation_level(store_id: StringName) -> int:
	var tier: int = int(_reputation_system.get_tier(String(store_id)))
	match tier:
		ReputationSystem.ReputationTier.LEGENDARY:
			return 4
		ReputationSystem.ReputationTier.REPUTABLE:
			return 2
		ReputationSystem.ReputationTier.UNREMARKABLE:
			return 1
		_:
			return 0


func _get_store_level(_store_id: StringName) -> int:
	return maxi(1, _progression_system.get_unlocked_store_slots())


func _can_store_order_item(
	store_id: StringName, item_def: ItemDefinition
) -> bool:
	if not item_def:
		return false
	var item_store_id: StringName = ContentRegistry.resolve(item_def.store_type)
	return item_store_id == store_id


func _get_item_display_name(item_def: ItemDefinition) -> String:
	if not item_def:
		return "Unknown Item"
	if not item_def.item_name.is_empty():
		return item_def.item_name
	return item_def.id
