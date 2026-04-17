## Manages staff hiring, firing, daily wages, and automated store tasks.
class_name StaffSystem
extends Node


const MAX_STAFF_PER_STORE: int = 2
const MIN_REPUTATION_TO_HIRE: float = 20.0
const PRICING_ERROR_SKILL_1: float = 0.30
const PRICING_ERROR_SKILL_5: float = 0.05
const HAGGLE_SKILL_PENALTY_BASE: float = 0.30
const HAGGLE_SKILL_PENALTY_PER_LEVEL: float = 0.06

var _economy_system: EconomySystem = null
var _reputation_system: ReputationSystem = null
var _inventory_system: InventorySystem = null
var _data_loader: DataLoader = null

## store_id -> Array of staff dictionaries
## Each staff dict: {instance_id, definition_id, store_id, hired_day}
var _hired_staff: Dictionary = {}

## Per-store price policy: store_id -> {min_ratio, max_ratio}
var _price_policies: Dictionary = {}

## Auto-incrementing staff instance id counter.
var _next_staff_id: int = 0
var _stocker_behavior: StockerBehavior = null


func initialize(
	economy: EconomySystem,
	reputation: ReputationSystem,
	inventory: InventorySystem,
	data_loader: DataLoader,
) -> void:
	_economy_system = economy
	_reputation_system = reputation
	_inventory_system = inventory
	_data_loader = data_loader
	_apply_state({})
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	_stocker_behavior = StockerBehavior.new()
	add_child(_stocker_behavior)
	_stocker_behavior.initialize(inventory, self, data_loader)


## Returns true if the player meets the reputation requirement to hire.
func can_hire() -> bool:
	if not _reputation_system:
		return false
	return _reputation_system.get_reputation() >= MIN_REPUTATION_TO_HIRE


## Returns the staff list for a store, or an empty array.
func get_staff_for_store(
	store_id: String
) -> Array[Dictionary]:
	if not _hired_staff.has(store_id):
		return []
	var result: Array[Dictionary] = []
	for entry: Variant in _hired_staff[store_id]:
		if entry is Dictionary:
			result.append(entry as Dictionary)
	return result


## Returns the count of hired staff at a store.
func get_staff_count(store_id: String) -> int:
	return get_staff_for_store(store_id).size()


## Returns the StaffDefinition for the first hired staff matching the given
## definition id, searching all stores. Returns null if not found.
func get_staff(definition_id: StringName) -> StaffDefinition:
	var target: String = String(definition_id)
	for store_id: String in _hired_staff:
		for entry: Variant in _hired_staff[store_id]:
			if entry is Dictionary:
				if (entry as Dictionary).get("definition_id", "") == target:
					return _get_staff_definition(target)
	return null


## Returns all store IDs that currently have hired staff.
func get_staffed_store_ids() -> Array[String]:
	var result: Array[String] = []
	for store_id: String in _hired_staff:
		if not (_hired_staff[store_id] as Array).is_empty():
			result.append(store_id)
	return result


## Hires a staff member for a store. Returns the staff instance dict
## or an empty dictionary on failure.
func hire_staff(
	definition_id: String, store_id: String
) -> Dictionary:
	if not can_hire():
		EventBus.notification_requested.emit(
			"Reputation too low to hire staff (need %.0f)"
			% MIN_REPUTATION_TO_HIRE
		)
		return {}
	if get_staff_count(store_id) >= MAX_STAFF_PER_STORE:
		EventBus.notification_requested.emit(
			"Store already has maximum staff (%d)"
			% MAX_STAFF_PER_STORE
		)
		return {}
	var def: StaffDefinition = _get_staff_definition(definition_id)
	if not def:
		push_warning(
			"StaffSystem: definition '%s' not found" % definition_id
		)
		return {}
	_next_staff_id += 1
	var staff_data: Dictionary = {
		"instance_id": "staff_%d" % _next_staff_id,
		"definition_id": definition_id,
		"store_id": store_id,
		"hired_day": GameManager.current_day,
	}
	if not _hired_staff.has(store_id):
		_hired_staff[store_id] = []
	(_hired_staff[store_id] as Array).append(staff_data)
	EventBus.staff_hired.emit(
		staff_data["instance_id"], store_id
	)
	EventBus.notification_requested.emit(
		"Hired %s for $%.0f/day" % [def.name, def.daily_wage]
	)
	return staff_data


## Fires a staff member by instance_id from a store.
func fire_staff(instance_id: String, store_id: String) -> bool:
	if not _hired_staff.has(store_id):
		return false
	var staff_list: Array = _hired_staff[store_id]
	for i: int in range(staff_list.size()):
		var entry: Dictionary = staff_list[i] as Dictionary
		if entry.get("instance_id", "") == instance_id:
			staff_list.remove_at(i)
			EventBus.staff_fired.emit(instance_id, store_id)
			var def: StaffDefinition = _get_staff_definition(
				entry.get("definition_id", "")
			)
			var staff_name: String = def.name if def else "Staff"
			EventBus.notification_requested.emit(
				"%s has been let go" % staff_name
			)
			return true
	return false


## Sets the price policy for a store (min/max ratio of market value).
func set_price_policy(
	store_id: String, min_ratio: float, max_ratio: float
) -> void:
	_price_policies[store_id] = {
		"min_ratio": clampf(min_ratio, 0.1, 5.0),
		"max_ratio": clampf(max_ratio, 0.1, 5.0),
	}


## Returns the price policy for a store.
func get_price_policy(store_id: String) -> Dictionary:
	return _price_policies.get(
		store_id, {"min_ratio": 0.5, "max_ratio": 2.0}
	)


## Returns the total daily wages for all staff across all stores.
func get_total_daily_wages() -> float:
	var total: float = 0.0
	for store_id: String in _hired_staff:
		total += get_store_daily_wages(store_id)
	return total


## Returns the total daily wages for staff at a specific store.
func get_store_daily_wages(store_id: String) -> float:
	var total: float = 0.0
	for entry: Dictionary in get_staff_for_store(store_id):
		var def: StaffDefinition = _get_staff_definition(
			entry.get("definition_id", "")
		)
		if def:
			total += def.daily_wage
	return total


## Returns the StaffDefinition for a given id from the DataLoaderSingleton.
func _get_staff_definition(
	definition_id: String
) -> StaffDefinition:
	if _data_loader:
		return _data_loader.get_staff_definition(definition_id)
	return null


func _on_day_started(_day: int) -> void:
	_run_staff_pricing()


func _on_day_ended(_day: int) -> void:
	pass


## Deducts wages for all hired staff across all owned stores.
## Called by DayCycleController after the player dismisses the day summary.
func process_daily_wages() -> void:
	_deduct_staff_wages()


func _deduct_staff_wages() -> void:
	if not _economy_system:
		return
	var wage_mult: float = DifficultySystemSingleton.get_modifier(&"staff_wage_multiplier")
	var total_wages: float = 0.0
	for store_id: String in _hired_staff:
		var store_wages: float = get_store_daily_wages(store_id) * wage_mult
		if store_wages > 0.0:
			total_wages += store_wages
	if total_wages > 0.0:
		_economy_system.force_deduct_cash(
			total_wages, "Staff wages"
		)
		EventBus.staff_wages_paid.emit(total_wages)


## Staff set prices on unpriced shelf items based on skill level.
func _run_staff_pricing() -> void:
	if not _economy_system or not _inventory_system:
		return
	for store_id: String in _hired_staff:
		var best_skill: int = _get_best_pricing_skill(store_id)
		if best_skill <= 0:
			continue
		_price_store_items(store_id, best_skill)


## Returns the highest pricing skill among staff at a store.
func _get_best_pricing_skill(store_id: String) -> int:
	var best: int = 0
	for entry: Dictionary in get_staff_for_store(store_id):
		var def: StaffDefinition = _get_staff_definition(
			entry.get("definition_id", "")
		)
		if not def:
			continue
		if def.specialization == "pricing":
			best = maxi(best, def.skill_level)
		else:
			best = maxi(best, maxi(1, def.skill_level - 1))
	return best


## Prices unpriced items on shelves using skill-adjusted market value.
func _price_store_items(store_id: String, skill: int) -> void:
	var store_def: StoreDefinition = null
	if _data_loader:
		store_def = _data_loader.get_store(store_id)
	if not store_def:
		return
	var store_type: String = store_def.store_type
	var shelf_items: Array[ItemInstance] = (
		_inventory_system.get_shelf_items_for_store(store_type)
	)
	var policy: Dictionary = get_price_policy(store_id)
	var min_ratio: float = policy.get("min_ratio", 0.5)
	var max_ratio: float = policy.get("max_ratio", 2.0)
	for item: ItemInstance in shelf_items:
		if item.player_set_price > 0.0:
			continue
		var market_val: float = _economy_system.calculate_market_value(
			item
		)
		if market_val <= 0.0:
			continue
		var error_range: float = _get_pricing_error(skill)
		var error: float = randf_range(-error_range, error_range)
		var staff_price: float = market_val * (1.0 + error)
		var min_price: float = market_val * min_ratio
		var max_price: float = market_val * max_ratio
		staff_price = clampf(staff_price, min_price, max_price)
		staff_price = maxf(staff_price, 0.01)
		item.player_set_price = staff_price
		EventBus.price_set.emit(item.instance_id, staff_price)


## Returns the pricing error range for a skill level (1-5).
func _get_pricing_error(skill: int) -> float:
	var t: float = clampf(
		float(skill - 1) / 4.0, 0.0, 1.0
	)
	return lerpf(PRICING_ERROR_SKILL_1, PRICING_ERROR_SKILL_5, t)


## Returns the haggle penalty factor for staff skill. Lower skill =
## accepts lower offers. Returns 0.0 for skill 5 (no penalty).
func get_haggle_penalty(store_id: String) -> float:
	var best_service_skill: int = 0
	for entry: Dictionary in get_staff_for_store(store_id):
		var def: StaffDefinition = _get_staff_definition(
			entry.get("definition_id", "")
		)
		if not def:
			continue
		if def.specialization == "customer_service":
			best_service_skill = maxi(
				best_service_skill, def.skill_level
			)
		else:
			best_service_skill = maxi(
				best_service_skill,
				maxi(1, def.skill_level - 1)
			)
	if best_service_skill <= 0:
		return 0.0
	return maxf(
		0.0,
		HAGGLE_SKILL_PENALTY_BASE
		- (float(best_service_skill) * HAGGLE_SKILL_PENALTY_PER_LEVEL)
	)


## Serializes staff state for saving.
func get_save_data() -> Dictionary:
	var staff_data: Dictionary = {}
	for store_id: String in _hired_staff:
		var entries: Array[Dictionary] = []
		for entry: Variant in _hired_staff[store_id]:
			if entry is Dictionary:
				entries.append((entry as Dictionary).duplicate())
		staff_data[store_id] = entries
	var policies: Dictionary = {}
	for store_id: String in _price_policies:
		policies[store_id] = (
			_price_policies[store_id] as Dictionary
		).duplicate()
	return {
		"hired_staff": staff_data,
		"price_policies": policies,
		"next_staff_id": _next_staff_id,
	}


## Restores staff state from saved data.
func load_save_data(data: Dictionary) -> void:
	_apply_state(data)
	if _stocker_behavior:
		_stocker_behavior.refresh_all_stores()


func _apply_state(data: Dictionary) -> void:
	_hired_staff = {}
	_price_policies = {}
	_next_staff_id = int(data.get("next_staff_id", 0))
	var saved_staff: Variant = data.get("hired_staff", {})
	if saved_staff is Dictionary:
		for store_id: String in saved_staff:
			var entries: Array = []
			var raw: Variant = (saved_staff as Dictionary)[store_id]
			if raw is Array:
				for entry: Variant in raw:
					if entry is Dictionary:
						var e: Dictionary = entry as Dictionary
						# Reconstruct with canonical key order and restore int types.
						entries.append({
							"instance_id": str(e.get("instance_id", "")),
							"definition_id": str(e.get("definition_id", "")),
							"store_id": str(e.get("store_id", "")),
							"hired_day": int(e.get("hired_day", 0)),
						})
			_hired_staff[store_id] = entries
	var saved_policies: Variant = data.get("price_policies", {})
	if saved_policies is Dictionary:
		for store_id: String in saved_policies:
			var raw: Variant = (
				saved_policies as Dictionary
			)[store_id]
			if raw is Dictionary:
				_price_policies[store_id] = (
					raw as Dictionary
				).duplicate()
