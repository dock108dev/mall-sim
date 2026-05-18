class_name BetaCustomerInventoryEffects
extends RefCounted

const OP_REMOVE_STOCK: String = "remove_stock"
const OP_CREATE_ITEM: String = "create_item"
const OP_MOVE_EXISTING: String = "move_existing"
const OP_ADJUST_CONDITION: String = "adjust_condition"
const OP_NO_INVENTORY_CHANGE: String = "no_inventory_change"
const LOCATION_BACKROOM: String = "backroom"

var _inventory_system: InventorySystem
var _shelf_root: Node


func _init(inventory_system: InventorySystem = null, shelf_root: Node = null) -> void:
	_inventory_system = inventory_system
	_shelf_root = shelf_root


## Applies a customer choice's inventory intent through InventorySystem and
## returns an honest transaction dictionary for result/summary consumers.
func apply(effects: Dictionary) -> Dictionary:
	var operations: Array = _operation_list(effects.get("inventory", []))
	var store_id: StringName = _store_id_for_operations(operations)
	var result: Dictionary = _base_result(store_id)
	if operations.is_empty():
		return result

	var plans: Array[Dictionary] = []
	var reserved: Dictionary = {}
	for op_variant: Variant in operations:
		if op_variant is not Dictionary:
			_append_failure(result, {}, "invalid_operation")
			continue
		var operation: Dictionary = op_variant as Dictionary
		var plan: Dictionary = _plan_operation(operation, reserved)
		if not bool(plan.get("ok", false)):
			result["ok"] = false
			result["failed"].append(plan.get("failure", {}))
			continue
		plans.append(plan)

	if not bool(result.get("ok", true)):
		result["inventory_counts"] = _inventory_counts(store_id)
		return result

	for plan: Dictionary in plans:
		if not _apply_plan(plan, result):
			result["ok"] = false
			break
	result["inventory_counts"] = _inventory_counts(store_id)
	return result


func _operation_list(raw: Variant) -> Array:
	if raw is Array:
		return raw as Array
	if raw is Dictionary:
		return [raw]
	return []


func _base_result(store_id: StringName) -> Dictionary:
	return {
		"ok": true,
		"applied": [],
		"failed": [],
		"inventory_counts": _inventory_counts(store_id),
	}


func _plan_operation(operation: Dictionary, reserved: Dictionary) -> Dictionary:
	var op: String = str(operation.get("op", ""))
	match op:
		OP_NO_INVENTORY_CHANGE:
			return {"ok": true, "operation": operation, "items": []}
		OP_CREATE_ITEM:
			return _plan_create(operation)
		OP_REMOVE_STOCK, OP_MOVE_EXISTING, OP_ADJUST_CONDITION:
			return _plan_existing_items(operation, reserved)
		_:
			return {
				"ok": false,
				"failure": _failure(operation, "unsupported_operation"),
			}


func _plan_create(operation: Dictionary) -> Dictionary:
	if _inventory_system == null:
		return {"ok": false, "failure": _failure(operation, "missing_inventory_system")}
	var definition_id: String = str(operation.get("definition_id", ""))
	if definition_id.is_empty():
		return {"ok": false, "failure": _failure(operation, "missing_definition_id")}
	var location: String = str(operation.get("location", LOCATION_BACKROOM))
	if not [LOCATION_BACKROOM, InventorySystem.DAMAGED_BIN_LOCATION].has(location):
		return {"ok": false, "failure": _failure(operation, "unsupported_location")}
	return {"ok": true, "operation": operation, "items": []}


func _plan_existing_items(operation: Dictionary, reserved: Dictionary) -> Dictionary:
	if _inventory_system == null:
		return {"ok": false, "failure": _failure(operation, "missing_inventory_system")}
	var quantity: int = maxi(1, int(operation.get("quantity", 1)))
	var items: Array[ItemInstance] = _resolve_items(operation, quantity, reserved)
	if items.size() < quantity:
		var reason: String = (
			"insufficient_quantity" if not items.is_empty() else "missing_matching_stock"
		)
		return {"ok": false, "failure": _failure(operation, reason)}
	for item: ItemInstance in items:
		reserved[item.instance_id] = true
	return {"ok": true, "operation": operation, "items": items}


func _resolve_items(
	operation: Dictionary, quantity: int, reserved: Dictionary
) -> Array[ItemInstance]:
	var selector: Dictionary = operation.get("selector", {}) as Dictionary
	var store_id: StringName = StringName(str(operation.get("store_id", "retro_games")))
	var candidates: Array[ItemInstance] = _allowed_candidates(
		store_id, str(operation.get("from", "any_stock"))
	)
	var sorted: Array[ItemInstance] = _sort_candidates(candidates, operation, selector)
	var matches: Array[ItemInstance] = []
	for item: ItemInstance in sorted:
		if reserved.has(item.instance_id):
			continue
		if not _matches_selector(item, selector):
			continue
		matches.append(item)
		if matches.size() >= quantity:
			break
	return matches


func _allowed_candidates(store_id: StringName, source: String) -> Array[ItemInstance]:
	if _inventory_system == null:
		return []
	var result: Array[ItemInstance] = []
	for item: ItemInstance in _inventory_system.get_stock(store_id):
		if item.current_location == InventorySystem.DAMAGED_BIN_LOCATION:
			continue
		if item.current_location == "sold":
			continue
		match source:
			"shelf_only":
				if item.current_location.begins_with("shelf:"):
					result.append(item)
			"backroom_only":
				if item.current_location == LOCATION_BACKROOM:
					result.append(item)
			_:
				result.append(item)
	return result


func _sort_candidates(
	candidates: Array[ItemInstance], operation: Dictionary, selector: Dictionary
) -> Array[ItemInstance]:
	var preferred: String = str(selector.get("prefer_location", ""))
	if preferred.is_empty():
		var source: String = str(operation.get("from", "any_stock"))
		preferred = "shelf" if source == "shelf_first" else "any"
	var sorted: Array[ItemInstance] = candidates.duplicate()
	sorted.sort_custom(
		func(a: ItemInstance, b: ItemInstance) -> bool:
			return _location_score(a, preferred) < _location_score(b, preferred)
	)
	return sorted


func _location_score(item: ItemInstance, preferred: String) -> int:
	var is_shelf: bool = item.current_location.begins_with("shelf:")
	var is_backroom: bool = item.current_location == LOCATION_BACKROOM
	match preferred:
		"shelf":
			return 0 if is_shelf else 1
		"backroom":
			return 0 if is_backroom else 1
		_:
			return 0


func _matches_selector(item: ItemInstance, selector: Dictionary) -> bool:
	var instance_id: String = str(selector.get("instance_id", ""))
	if not instance_id.is_empty():
		return item.instance_id == instance_id
	if item.definition == null:
		return false
	var definition_id: String = str(selector.get("definition_id", ""))
	var category: String = str(selector.get("category", ""))
	var fallback_category: String = str(selector.get("fallback_category", ""))
	var condition: String = str(selector.get("condition", ""))
	var allow_any_condition: bool = bool(selector.get("allow_any_condition", false))
	if not definition_id.is_empty() and item.definition.id != definition_id:
		if fallback_category.is_empty() or item.definition.category != fallback_category:
			return false
	elif definition_id.is_empty() and not category.is_empty():
		if item.definition.category != category:
			return false
	elif definition_id.is_empty() and not fallback_category.is_empty():
		if item.definition.category != fallback_category:
			return false
	if not condition.is_empty() and not allow_any_condition:
		return item.condition == condition
	return true


func _apply_plan(plan: Dictionary, result: Dictionary) -> bool:
	var operation: Dictionary = plan.get("operation", {}) as Dictionary
	var op: String = str(operation.get("op", ""))
	match op:
		OP_NO_INVENTORY_CHANGE:
			result["applied"].append(_applied_noop(operation))
			return true
		OP_CREATE_ITEM:
			return _apply_create(operation, result)
		OP_REMOVE_STOCK:
			return _apply_remove(operation, plan.get("items", []) as Array, result)
		OP_MOVE_EXISTING:
			return _apply_move(operation, plan.get("items", []) as Array, result)
		OP_ADJUST_CONDITION:
			return _apply_condition(operation, plan.get("items", []) as Array, result)
		_:
			result["failed"].append(_failure(operation, "unsupported_operation"))
			return false


func _apply_create(operation: Dictionary, result: Dictionary) -> bool:
	var quantity: int = maxi(1, int(operation.get("quantity", 1)))
	var definition_id: String = str(operation.get("definition_id", ""))
	var condition: String = str(operation.get("condition", "good"))
	var acquired_price: float = float(operation.get("acquired_price", 0.0))
	var location: String = str(operation.get("location", LOCATION_BACKROOM))
	for _i: int in range(quantity):
		var item: ItemInstance = _inventory_system.create_item(
			definition_id, condition, acquired_price
		)
		if item == null:
			result["failed"].append(_failure(operation, "create_item_failed"))
			return false
		if location == InventorySystem.DAMAGED_BIN_LOCATION:
			if not _inventory_system.move_to_damaged_bin(item.instance_id):
				result["failed"].append(_failure(operation, "damaged_bin_move_failed"))
				return false
		result["applied"].append(_applied(operation, item, "", item.current_location))
	return true


func _apply_remove(operation: Dictionary, items: Array, result: Dictionary) -> bool:
	for item: ItemInstance in items:
		var from_location: String = item.current_location
		if not _inventory_system.remove_item(item.instance_id):
			result["failed"].append(_failure(operation, "remove_item_failed"))
			return false
		_clear_shelf_slot(item.instance_id, from_location)
		result["applied"].append(_applied(operation, item, from_location, "sold"))
	return true


func _apply_move(operation: Dictionary, items: Array, result: Dictionary) -> bool:
	var to_location: String = str(operation.get("to", LOCATION_BACKROOM))
	for item: ItemInstance in items:
		var from_location: String = item.current_location
		var ok: bool = true
		if to_location == InventorySystem.DAMAGED_BIN_LOCATION:
			ok = _inventory_system.move_to_damaged_bin(item.instance_id)
		else:
			_inventory_system.move_item(item.instance_id, to_location)
			ok = item.current_location == to_location
		if not ok:
			result["failed"].append(_failure(operation, "move_item_failed"))
			return false
		_clear_shelf_slot(item.instance_id, from_location)
		result["applied"].append(_applied(operation, item, from_location, to_location))
	return true


func _apply_condition(operation: Dictionary, items: Array, result: Dictionary) -> bool:
	var new_condition: String = str(operation.get("new_condition", ""))
	for item: ItemInstance in items:
		var from_condition: String = item.condition
		if not _inventory_system.update_item_condition(item.instance_id, new_condition):
			result["failed"].append(_failure(operation, "condition_update_failed"))
			return false
		if bool(operation.get("move_to_damaged_bin", false)):
			if not _inventory_system.move_to_damaged_bin(item.instance_id):
				result["failed"].append(_failure(operation, "damaged_bin_move_failed"))
				return false
		var applied: Dictionary = _applied(
			operation, item, item.current_location, item.current_location
		)
		applied["from_condition"] = from_condition
		applied["to_condition"] = item.condition
		result["applied"].append(applied)
	return true


func _clear_shelf_slot(instance_id: String, from_location: String) -> void:
	if _shelf_root == null or not from_location.begins_with("shelf:"):
		return
	var slot_id: String = from_location.substr(6)
	for node: Node in _shelf_root.find_children("*", "ShelfSlot", true, false):
		var slot: ShelfSlot = node as ShelfSlot
		if slot == null:
			continue
		if slot.slot_id != slot_id:
			continue
		if slot.get_item_instance_id() != instance_id:
			continue
		slot.remove_item()
		return


func _applied(
	operation: Dictionary, item: ItemInstance, from_location: String, to_location: String
) -> Dictionary:
	return {
		"op": str(operation.get("op", "")),
		"instance_id": item.instance_id,
		"definition_id": item.definition.id if item.definition else "",
		"from_location": from_location,
		"to_location": to_location,
		"reason": str(operation.get("reason", "")),
	}


func _applied_noop(operation: Dictionary) -> Dictionary:
	return {
		"op": OP_NO_INVENTORY_CHANGE,
		"reason": str(operation.get("reason", "")),
	}


func _failure(operation: Dictionary, reason: String) -> Dictionary:
	return {
		"op": str(operation.get("op", "")),
		"reason": reason,
		"selector": (operation.get("selector", {}) as Dictionary).duplicate(true),
	}


func _append_failure(result: Dictionary, operation: Dictionary, reason: String) -> void:
	result["ok"] = false
	result["failed"].append(_failure(operation, reason))


func _store_id_for_operations(operations: Array) -> StringName:
	for op_variant: Variant in operations:
		if op_variant is not Dictionary:
			continue
		var operation: Dictionary = op_variant as Dictionary
		var store_id: String = str(operation.get("store_id", ""))
		if not store_id.is_empty():
			return StringName(store_id)
	return &"retro_games"


func _inventory_counts(store_id: StringName) -> Dictionary:
	var counts: Dictionary = {"shelf": 0, "backroom": 0, "damaged": 0}
	if _inventory_system == null:
		return counts
	for item: ItemInstance in _inventory_system.get_stock(store_id):
		if item.current_location.begins_with("shelf:"):
			counts["shelf"] = int(counts["shelf"]) + 1
		elif item.current_location == LOCATION_BACKROOM:
			counts["backroom"] = int(counts["backroom"]) + 1
	for item: ItemInstance in _inventory_system.get_damaged_bin_items():
		if _inventory_system.get_stock(store_id).has(item):
			counts["damaged"] = int(counts["damaged"]) + 1
	return counts
