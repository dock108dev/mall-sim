## Manages the refurbishment queue for the retro game store.
class_name RefurbishmentSystem
extends Node

const STORE_TYPE: String = "retro_games"
const MAX_CONCURRENT: int = 3
const MIN_PARTS_COST: float = 5.0
const MAX_PARTS_COST: float = 20.0
const COST_THRESHOLD_LOW: float = 15.0
const COST_THRESHOLD_HIGH: float = 50.0
const MIN_DURATION: int = 1
const MAX_DURATION: int = 2
const DURATION_PRICE_THRESHOLD: float = 30.0
const REFURBISHING_LOCATION: String = "refurbishing"
const CONDITION_TIERS: PackedStringArray = [
	"poor", "fair", "good", "near_mint", "mint",
]

var _queue: Array[Dictionary] = []
var _inventory_system: InventorySystem = null
var _economy_system: EconomySystem = null
var _active_max_queue_size: int = MAX_CONCURRENT
var _active_duration_days: int = MIN_DURATION
var _active_condition_tiers: PackedStringArray = CONDITION_TIERS
var _refurb_cost_by_tier: Dictionary = {}


func initialize(
	inventory: InventorySystem, economy: EconomySystem
) -> void:
	_inventory_system = inventory
	_economy_system = economy
	_load_config()
	_apply_state({})
	EventBus.day_started.connect(_on_day_started)


## Returns true if the item is eligible for refurbishment.
func can_refurbish(item: ItemInstance) -> bool:
	if not item or not item.definition:
		return false
	if item.definition.store_type != STORE_TYPE:
		return false
	if item.current_location == REFURBISHING_LOCATION:
		return false
	if item.current_location != "backroom":
		return false
	if _queue.size() >= _active_max_queue_size:
		return false
	for entry: Dictionary in _queue:
		if entry.get("instance_id", "") == item.instance_id:
			return false
	var is_not_working: bool = (
		item.tested and item.test_result == "tested_not_working"
	)
	var is_poor: bool = item.condition == "poor"
	if not is_not_working and not is_poor:
		return false
	if _get_next_condition(item.condition) == "":
		return false
	return true


## Calculates the parts cost based on condition tier or item base price.
func get_parts_cost(item: ItemInstance) -> float:
	if not item or not item.definition:
		return MAX_PARTS_COST
	if not _refurb_cost_by_tier.is_empty():
		var tier_cost: Variant = _refurb_cost_by_tier.get(
			item.condition, MAX_PARTS_COST
		)
		return float(tier_cost)
	var base: float = item.definition.base_price
	var t: float = clampf(
		(base - COST_THRESHOLD_LOW)
		/ (COST_THRESHOLD_HIGH - COST_THRESHOLD_LOW),
		0.0, 1.0
	)
	return lerpf(MIN_PARTS_COST, MAX_PARTS_COST, t)


## Calculates the duration in days from config or item base price.
func get_duration(item: ItemInstance) -> int:
	if not item or not item.definition:
		return _active_duration_days
	if _active_duration_days != MIN_DURATION:
		return _active_duration_days
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
		cost, "Refurbishment parts: %s" % item.definition.item_name
	):
		EventBus.notification_requested.emit(
			"Insufficient funds for refurbishment ($%.2f)" % cost
		)
		return false
	var duration: int = get_duration(item)
	var entry: Dictionary = {
		"instance_id": instance_id,
		"parts_cost": cost,
		"days_remaining": duration,
		"start_day": GameManager.current_day,
	}
	_queue.append(entry)
	_inventory_system.move_item(instance_id, REFURBISHING_LOCATION)
	EventBus.refurbishment_started.emit(instance_id, cost, duration)
	EventBus.notification_requested.emit(
		"Refurbishment started: %s (%d day%s)"
		% [item.definition.item_name, duration, "" if duration == 1 else "s"]
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
	_apply_state(data)


func _load_config() -> void:
	var cfg: Dictionary = DataLoader.get_retro_games_config()
	if cfg.is_empty():
		return
	_active_max_queue_size = int(
		cfg.get("max_refurb_queue_size", MAX_CONCURRENT)
	)
	_active_duration_days = int(
		cfg.get("refurb_duration_days", MIN_DURATION)
	)
	var cost_tiers: Variant = cfg.get("refurb_cost_by_tier", {})
	if cost_tiers is Dictionary:
		_refurb_cost_by_tier = cost_tiers as Dictionary
	var cond_tiers: Variant = cfg.get("item_condition_tiers", [])
	if cond_tiers is Array and not (cond_tiers as Array).is_empty():
		_active_condition_tiers = PackedStringArray(cond_tiers as Array)


func _apply_state(data: Dictionary) -> void:
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
	if not _inventory_system:
		return
	var item: ItemInstance = _inventory_system.get_item(instance_id)
	if not item:
		push_warning(
			"RefurbishmentSystem: item '%s' missing at resolution"
			% instance_id
		)
		return
	var old_condition: String = item.condition
	var new_condition: String = _get_next_condition(old_condition)
	if new_condition.is_empty():
		new_condition = old_condition
	item.condition = new_condition
	if item.tested and item.test_result == "tested_not_working":
		item.test_result = "tested_working"
	_inventory_system.move_item(item.instance_id, "backroom")
	EventBus.refurbishment_completed.emit(
		item.instance_id, true, new_condition
	)
	EventBus.inventory_changed.emit()
	EventBus.notification_requested.emit(
		"Refurbishment complete! %s is now %s"
		% [
			item.definition.item_name,
			new_condition.replace("_", " "),
		]
	)


## Returns the next condition tier, or empty string if already at max.
func _get_next_condition(current: String) -> String:
	for i: int in range(_active_condition_tiers.size() - 1):
		if _active_condition_tiers[i] == current:
			return _active_condition_tiers[i + 1]
	return ""
