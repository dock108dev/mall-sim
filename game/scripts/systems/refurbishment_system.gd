## Manages the refurbishment queue for the retro game store.
class_name RefurbishmentSystem
extends Node

const STORE_TYPE: String = "retro_games"
const MAX_CONCURRENT: int = 3
const MIN_PARTS_COST: float = 5.0
const MAX_PARTS_COST: float = 20.0
const MIN_SUCCESS_CHANCE: float = 0.75
const MAX_SUCCESS_CHANCE: float = 0.85
const COST_THRESHOLD_LOW: float = 15.0
const COST_THRESHOLD_HIGH: float = 50.0
const MIN_DURATION: int = 1
const MAX_DURATION: int = 2
const DURATION_PRICE_THRESHOLD: float = 30.0
const ELIGIBLE_SUBCATEGORY: String = "for_parts"
const REFURBISHING_LOCATION: String = "refurbishing"

var _queue: Array[Dictionary] = []
var _inventory_system: InventorySystem = null
var _economy_system: EconomySystem = null


func initialize(
	inventory: InventorySystem, economy: EconomySystem
) -> void:
	_inventory_system = inventory
	_economy_system = economy
	EventBus.day_started.connect(_on_day_started)


## Returns true if the item is eligible for refurbishment.
func can_refurbish(item: ItemInstance) -> bool:
	if not item or not item.definition:
		return false
	if item.definition.store_type != STORE_TYPE:
		return false
	if item.definition.subcategory != ELIGIBLE_SUBCATEGORY:
		return false
	if item.current_location == REFURBISHING_LOCATION:
		return false
	if item.current_location != "backroom":
		return false
	if _queue.size() >= MAX_CONCURRENT:
		return false
	for entry: Dictionary in _queue:
		if entry.get("instance_id", "") == item.instance_id:
			return false
	return true


## Calculates the parts cost based on item base price.
func get_parts_cost(item: ItemInstance) -> float:
	if not item or not item.definition:
		return MAX_PARTS_COST
	var base: float = item.definition.base_price
	var t: float = clampf(
		(base - COST_THRESHOLD_LOW)
		/ (COST_THRESHOLD_HIGH - COST_THRESHOLD_LOW),
		0.0, 1.0
	)
	return lerpf(MIN_PARTS_COST, MAX_PARTS_COST, t)


## Calculates success chance based on item base price.
func get_success_chance(item: ItemInstance) -> float:
	if not item or not item.definition:
		return MIN_SUCCESS_CHANCE
	var base: float = item.definition.base_price
	var t: float = clampf(
		(base - COST_THRESHOLD_LOW)
		/ (COST_THRESHOLD_HIGH - COST_THRESHOLD_LOW),
		0.0, 1.0
	)
	return lerpf(MAX_SUCCESS_CHANCE, MIN_SUCCESS_CHANCE, t)


## Calculates the duration in days based on item base price.
func get_duration(item: ItemInstance) -> int:
	if not item or not item.definition:
		return MAX_DURATION
	if item.definition.base_price >= DURATION_PRICE_THRESHOLD:
		return MAX_DURATION
	return MIN_DURATION


## Starts refurbishment for the given item. Returns true on success.
func start_refurbishment(instance_id: String) -> bool:
	if not _inventory_system or not _economy_system:
		push_warning("RefurbishmentSystem: systems not initialized")
		return false
	var item: ItemInstance = _inventory_system.get_item(instance_id)
	if not can_refurbish(item):
		push_warning(
			"RefurbishmentSystem: item '%s' not eligible"
			% instance_id
		)
		return false
	var cost: float = get_parts_cost(item)
	if not _economy_system.deduct_cash(
		cost, "Refurbishment parts: %s" % item.definition.name
	):
		EventBus.notification_requested.emit(
			"Insufficient funds for refurbishment ($%.2f)" % cost
		)
		return false
	var duration: int = get_duration(item)
	var chance: float = get_success_chance(item)
	var entry: Dictionary = {
		"instance_id": instance_id,
		"parts_cost": cost,
		"days_remaining": duration,
		"success_chance": chance,
		"start_day": GameManager.current_day,
	}
	_queue.append(entry)
	_inventory_system.move_item(instance_id, REFURBISHING_LOCATION)
	EventBus.refurbishment_started.emit(instance_id, cost, duration)
	EventBus.notification_requested.emit(
		"Refurbishment started: %s (%d day%s)"
		% [item.definition.name, duration, "" if duration == 1 else "s"]
	)
	return true


## Returns the number of items currently being refurbished.
func get_active_count() -> int:
	return _queue.size()


## Returns the refurbishment queue entries (read-only copies).
func get_queue() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _queue:
		result.append(entry.duplicate())
	return result


## Serializes refurbishment state for saving.
func get_save_data() -> Dictionary:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in _queue:
		entries.append(entry.duplicate())
	return {"queue": entries}


## Restores refurbishment state from saved data.
func load_save_data(data: Dictionary) -> void:
	_queue.clear()
	var saved_queue: Array = data.get("queue", [])
	for entry: Variant in saved_queue:
		if entry is not Dictionary:
			continue
		var dict: Dictionary = entry as Dictionary
		if not dict.has("instance_id"):
			continue
		_queue.append(dict.duplicate())


func _on_day_started(_day: int) -> void:
	_process_queue()


func _process_queue() -> void:
	if _queue.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for entry: Dictionary in _queue:
		var days_left: int = entry.get("days_remaining", 0) - 1
		if days_left > 0:
			entry["days_remaining"] = days_left
			remaining.append(entry)
			continue
		_resolve_refurbishment(entry)
	_queue = remaining


func _resolve_refurbishment(entry: Dictionary) -> void:
	var instance_id: String = entry.get("instance_id", "")
	var chance: float = entry.get("success_chance", MIN_SUCCESS_CHANCE)
	if not _inventory_system:
		return
	var item: ItemInstance = _inventory_system.get_item(instance_id)
	if not item:
		push_warning(
			"RefurbishmentSystem: item '%s' missing at resolution"
			% instance_id
		)
		return
	var roll: float = randf()
	if roll <= chance:
		_apply_success(item)
	else:
		_apply_failure(item)


func _apply_success(item: ItemInstance) -> void:
	var old_condition: String = item.condition
	var new_condition: String = _pick_success_condition()
	item.condition = new_condition
	_inventory_system.move_item(item.instance_id, "backroom")
	EventBus.refurbishment_completed.emit(
		item.instance_id, true, new_condition
	)
	EventBus.notification_requested.emit(
		"Refurbishment success! %s is now %s"
		% [item.definition.name, new_condition.replace("_", " ")]
	)


func _apply_failure(item: ItemInstance) -> void:
	var item_name: String = item.definition.name if item.definition else ""
	EventBus.refurbishment_completed.emit(item.instance_id, false, "")
	EventBus.refurbishment_failed.emit(item.instance_id)
	EventBus.item_lost.emit(
		item.instance_id, "Refurbishment failed"
	)
	_inventory_system.remove_item(item.instance_id)
	EventBus.notification_requested.emit(
		"Refurbishment failed! %s was destroyed" % item_name
	)


func _pick_success_condition() -> String:
	if randf() < 0.5:
		return "near_mint"
	return "good"
