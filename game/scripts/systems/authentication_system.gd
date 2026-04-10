## Manages autograph authentication for the sports memorabilia store.
class_name AuthenticationSystem
extends RefCounted

const STORE_TYPE: String = "sports_memorabilia"
const ELIGIBLE_SUBCATEGORY: String = "autographs"
const AUTHENTICATING_LOCATION: String = "authenticating"
const GENUINE_CHANCE: float = 0.80
const MIN_COST: float = 20.0
const MAX_COST: float = 50.0
const COST_BASE_LOW: float = 50.0
const COST_BASE_HIGH: float = 300.0
const DURATION_DAYS: int = 1

var _queue: Array[Dictionary] = []
var _inventory_system: InventorySystem = null
var _economy_system: EconomySystem = null


## Initializes system references and connects to day_started.
func initialize(
	inventory: InventorySystem, economy: EconomySystem
) -> void:
	_inventory_system = inventory
	_economy_system = economy
	EventBus.day_started.connect(_on_day_started)


## Returns true if the item can be sent for authentication.
func can_authenticate(item: ItemInstance) -> bool:
	if not item or not item.definition:
		return false
	if item.definition.store_type != STORE_TYPE:
		return false
	if item.definition.subcategory != ELIGIBLE_SUBCATEGORY:
		return false
	if item.authentication_status != "none":
		return false
	if item.current_location != "backroom":
		return false
	for entry: Dictionary in _queue:
		if entry.get("instance_id", "") == item.instance_id:
			return false
	return true


## Calculates the authentication cost scaled by base_price ($20-$50).
func get_cost(item: ItemInstance) -> float:
	if not item or not item.definition:
		return MAX_COST
	var base: float = item.definition.base_price
	var t: float = clampf(
		(base - COST_BASE_LOW) / (COST_BASE_HIGH - COST_BASE_LOW),
		0.0, 1.0
	)
	return lerpf(MIN_COST, MAX_COST, t)


## Starts authentication for the given item. Returns true on success.
func start_authentication(instance_id: String) -> bool:
	if not _inventory_system or not _economy_system:
		push_warning("AuthenticationSystem: systems not initialized")
		return false
	var item: ItemInstance = _inventory_system.get_item(instance_id)
	if not can_authenticate(item):
		push_warning(
			"AuthenticationSystem: item '%s' not eligible"
			% instance_id
		)
		return false
	var cost: float = get_cost(item)
	if not _economy_system.deduct_cash(
		cost, "Authentication: %s" % item.definition.name
	):
		EventBus.notification_requested.emit(
			"Insufficient funds for authentication ($%.2f)" % cost
		)
		return false
	var entry: Dictionary = {
		"instance_id": instance_id,
		"cost": cost,
		"days_remaining": DURATION_DAYS,
	}
	_queue.append(entry)
	item.authentication_status = "authenticating"
	_inventory_system.move_item(
		instance_id, AUTHENTICATING_LOCATION
	)
	EventBus.authentication_started.emit(instance_id, cost)
	EventBus.notification_requested.emit(
		"Authentication started: %s (1 day)"
		% item.definition.name
	)
	return true


## Returns the number of items currently being authenticated.
func get_active_count() -> int:
	return _queue.size()


## Serializes authentication state for saving.
func get_save_data() -> Dictionary:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in _queue:
		entries.append(entry.duplicate())
	return {"queue": entries}


## Restores authentication state from saved data.
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
		_resolve_authentication(entry)
	_queue = remaining


func _resolve_authentication(entry: Dictionary) -> void:
	var instance_id: String = entry.get("instance_id", "")
	if not _inventory_system:
		return
	var item: ItemInstance = _inventory_system.get_item(instance_id)
	if not item:
		push_warning(
			"AuthenticationSystem: item '%s' missing at resolution"
			% instance_id
		)
		return
	var roll: float = randf()
	if roll <= GENUINE_CHANCE:
		_apply_genuine(item)
	else:
		_apply_fake(item)


func _apply_genuine(item: ItemInstance) -> void:
	item.authentication_status = "authenticated"
	_inventory_system.move_item(item.instance_id, "backroom")
	EventBus.authentication_completed.emit(
		item.instance_id, true
	)
	EventBus.notification_requested.emit(
		"Authenticated! %s is genuine (2x value)"
		% item.definition.name
	)


func _apply_fake(item: ItemInstance) -> void:
	item.authentication_status = "fake"
	_inventory_system.move_item(item.instance_id, "backroom")
	EventBus.authentication_completed.emit(
		item.instance_id, false
	)
	EventBus.notification_requested.emit(
		"Fake! %s autograph is not genuine (near worthless)"
		% item.definition.name
	)
