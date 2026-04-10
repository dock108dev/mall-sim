## Controller for the video rental store with rental lifecycle, late fees, and tape wear.
class_name VideoRentalStoreController
extends StoreController

enum LateFeePolicy { STRICT, STANDARD, LENIENT }

const STORE_ID: String = "video_rental"
const SOLD_CATEGORIES: PackedStringArray = ["snacks", "merchandise"]
const RENTAL_CATEGORIES: PackedStringArray = ["vhs_tapes", "dvd_titles"]
const MAX_STAFF_PICKS: int = 3
const STAFF_PICK_BOOST: float = 1.3
const RETURNS_BIN_LOCATION: String = "returns_bin"
const LOST_ITEM_CHANCE: float = 0.02
const RENTAL_REP_GAIN: float = 1.5

const RENTAL_DURATIONS: Dictionary = {
	"overnight": 1, "three_day": 3, "weekly": 7,
}
const LATE_FEE_MULTIPLIERS: Dictionary = {
	LateFeePolicy.STRICT: 1.5,
	LateFeePolicy.STANDARD: 1.0,
	LateFeePolicy.LENIENT: 0.5,
}
const POLICY_REP_MULTIPLIERS: Dictionary = {
	LateFeePolicy.STRICT: 0.5,
	LateFeePolicy.STANDARD: 1.0,
	LateFeePolicy.LENIENT: 1.5,
}

var _active_rentals: Array[Dictionary] = []
var _staff_picks: Array[String] = []
var _late_fee_policy: LateFeePolicy = LateFeePolicy.STANDARD
var _rental_history: Array[Dictionary] = []
var _wear_tracker: TapeWearTracker = TapeWearTracker.new()

var _inventory_system: InventorySystem = null
var _economy_system: EconomySystem = null
var _reputation_system: ReputationSystem = null


func _ready() -> void:
	store_type = STORE_ID
	super._ready()
	EventBus.day_started.connect(_on_day_started)


## Sets the InventorySystem reference for item location management.
func set_inventory_system(inv: InventorySystem) -> void:
	_inventory_system = inv


## Sets the EconomySystem reference for fee collection.
func set_economy_system(econ: EconomySystem) -> void:
	_economy_system = econ


## Sets the ReputationSystem reference for policy-based reputation.
func set_reputation_system(rep: ReputationSystem) -> void:
	_reputation_system = rep


## Returns true if the item category uses rental checkout instead of sale.
func is_rental_item(category: String) -> bool:
	return category in RENTAL_CATEGORIES


## Returns true if the item can be rented (not at or below poor condition).
func is_rentable(item: ItemInstance) -> bool:
	if not item:
		return false
	return item.condition != "poor"


## Returns the rental probability boost (1.3x for staff picks, 1.0 otherwise).
func get_rental_boost(item_definition_id: String) -> float:
	if item_definition_id in _staff_picks:
		return STAFF_PICK_BOOST
	return 1.0


## Sets the late fee policy (STRICT, STANDARD, or LENIENT).
func set_late_fee_policy(policy: LateFeePolicy) -> void:
	_late_fee_policy = policy


## Returns the current late fee policy.
func get_late_fee_policy() -> LateFeePolicy:
	return _late_fee_policy


## Processes a rental checkout: records rental and initializes tape wear.
func process_rental(
	item_instance_id: String,
	item_category: String,
	rental_tier: String,
	rental_fee: float,
	current_day: int,
) -> Dictionary:
	var duration: int = RENTAL_DURATIONS.get(rental_tier, 3)
	var return_day: int = current_day + duration
	var rental_record: Dictionary = {
		"instance_id": item_instance_id,
		"category": item_category,
		"rental_fee": rental_fee,
		"rental_tier": rental_tier,
		"checkout_day": current_day,
		"return_day": return_day,
		"returned": false,
	}
	_active_rentals.append(rental_record)
	if _inventory_system:
		var item: ItemInstance = _inventory_system.get_item(item_instance_id)
		if item:
			_wear_tracker.initialize_item(item_instance_id, item.condition)
	EventBus.item_rented.emit(item_instance_id, rental_fee, rental_tier)
	return rental_record


## Returns all currently active (unreturned) rental records.
func get_active_rentals() -> Array[Dictionary]:
	return _active_rentals


## Returns rental records that are overdue as of the given day.
func get_overdue_rentals(current_day: int) -> Array[Dictionary]:
	var overdue: Array[Dictionary] = []
	for rental: Dictionary in _active_rentals:
		if not rental["returned"] and current_day > rental["return_day"]:
			overdue.append(rental)
	return overdue


## Returns items currently in the returns bin.
func get_returns_bin_items() -> Array[ItemInstance]:
	if not _inventory_system:
		return []
	return _inventory_system.get_items_at_location(RETURNS_BIN_LOCATION)


## Returns the current tape wear for an item.
func get_tape_wear(instance_id: String) -> float:
	return _wear_tracker.get_wear(instance_id)


## Sets a title as a staff pick (max 3). Returns true on success.
func add_staff_pick(item_definition_id: String) -> bool:
	if _staff_picks.size() >= MAX_STAFF_PICKS:
		return false
	if item_definition_id in _staff_picks:
		return false
	_staff_picks.append(item_definition_id)
	return true


## Removes a title from staff picks. Returns true if it was present.
func remove_staff_pick(item_definition_id: String) -> bool:
	var idx: int = _staff_picks.find(item_definition_id)
	if idx < 0:
		return false
	_staff_picks.remove_at(idx)
	return true


## Returns the current staff pick definition IDs.
func get_staff_picks() -> Array[String]:
	return _staff_picks


## Returns true if the given definition ID is a staff pick.
func is_staff_pick(item_definition_id: String) -> bool:
	return item_definition_id in _staff_picks


## Serializes rental state for saving.
func get_save_data() -> Dictionary:
	return {
		"active_rentals": _active_rentals.duplicate(true),
		"staff_picks": _staff_picks.duplicate(),
		"tape_wear": _wear_tracker.get_save_data(),
		"late_fee_policy": _late_fee_policy,
		"rental_history": _rental_history.duplicate(true),
	}


## Restores rental state from save data.
func load_save_data(data: Dictionary) -> void:
	_active_rentals.clear()
	if data.has("active_rentals"):
		for entry: Variant in data["active_rentals"]:
			if entry is Dictionary:
				_active_rentals.append(entry)
	_staff_picks.clear()
	if data.has("staff_picks"):
		for pick: Variant in data["staff_picks"]:
			if pick is String:
				_staff_picks.append(pick)
	var saved_wear: Variant = data.get("tape_wear", {})
	if saved_wear is Dictionary:
		_wear_tracker.load_save_data(saved_wear as Dictionary)
	var saved_policy: Variant = data.get(
		"late_fee_policy", LateFeePolicy.STANDARD
	)
	_late_fee_policy = int(saved_policy) as LateFeePolicy
	_rental_history = []
	if data.has("rental_history"):
		for entry: Variant in data["rental_history"]:
			if entry is Dictionary:
				_rental_history.append(entry)


func _on_day_started(day: int) -> void:
	_process_returns(day)
	_update_returns_bin_count()


## Checks all active rentals and processes items due for return.
func _process_returns(current_day: int) -> void:
	var still_active: Array[Dictionary] = []
	for rental: Dictionary in _active_rentals:
		if rental["returned"]:
			continue
		if current_day >= rental["return_day"]:
			rental["returned"] = true
			var late_days: int = current_day - rental["return_day"]
			_handle_return(rental, late_days)
		else:
			still_active.append(rental)
	_active_rentals = still_active


## Handles a single item return: degradation, late fees, lost item check.
func _handle_return(rental: Dictionary, late_days: int) -> void:
	var instance_id: String = rental["instance_id"]
	if randf() < LOST_ITEM_CHANCE:
		_handle_lost_item(rental)
		return
	_apply_degradation(rental)
	if late_days > 0:
		_collect_late_fee(rental, late_days)
	if _inventory_system:
		_inventory_system.move_item(instance_id, RETURNS_BIN_LOCATION)
	_apply_rental_reputation()
	_rental_history.append({
		"instance_id": instance_id,
		"return_day": GameManager.current_day,
		"late_days": late_days,
		"lost": false,
	})
	var degraded: bool = false
	if _inventory_system:
		var item: ItemInstance = _inventory_system.get_item(instance_id)
		if item:
			degraded = item.condition == "poor"
	EventBus.rental_returned.emit(instance_id, degraded)


## Applies guaranteed wear degradation to a returned item.
func _apply_degradation(rental: Dictionary) -> void:
	var instance_id: String = rental["instance_id"]
	var new_condition: String = _wear_tracker.apply_degradation(
		instance_id, rental["category"]
	)
	if _inventory_system:
		var item: ItemInstance = _inventory_system.get_item(instance_id)
		if item:
			item.condition = new_condition


## Collects late fees based on the current policy.
func _collect_late_fee(rental: Dictionary, late_days: int) -> void:
	var daily_rate: float = rental["rental_fee"]
	var multiplier: float = LATE_FEE_MULTIPLIERS.get(
		_late_fee_policy, 1.0
	)
	var late_fee: float = daily_rate * multiplier * float(late_days)
	if _economy_system and late_fee > 0.0:
		_economy_system.add_cash(
			late_fee,
			"Late fee: %s (%dd)" % [rental["instance_id"], late_days]
		)
	EventBus.rental_late_fee.emit(
		rental["instance_id"], late_fee, late_days
	)


## Handles a lost item: removes from inventory, collects replacement fee.
func _handle_lost_item(rental: Dictionary) -> void:
	var instance_id: String = rental["instance_id"]
	if _inventory_system and _economy_system:
		var item: ItemInstance = _inventory_system.get_item(instance_id)
		if item and item.definition:
			var replacement_fee: float = item.definition.base_price
			if replacement_fee > 0.0:
				_economy_system.add_cash(
					replacement_fee,
					"Replacement fee: %s" % instance_id
				)
		_inventory_system.remove_item(instance_id)
	_wear_tracker.erase_item(instance_id)
	_rental_history.append({
		"instance_id": instance_id,
		"return_day": GameManager.current_day,
		"late_days": 0,
		"lost": true,
	})
	EventBus.rental_item_lost.emit(instance_id)


## Applies reputation gain for a rental return, modified by policy.
func _apply_rental_reputation() -> void:
	if not _reputation_system:
		return
	var rep_mult: float = POLICY_REP_MULTIPLIERS.get(
		_late_fee_policy, 1.0
	)
	_reputation_system.modify_reputation(
		STORE_ID, RENTAL_REP_GAIN * rep_mult
	)


## Updates the ReturnsBin node count display if one exists in the scene.
func _update_returns_bin_count() -> void:
	var bin_items: Array[ItemInstance] = get_returns_bin_items()
	var bins: Array[Node] = get_tree().get_nodes_in_group("returns_bin")
	for bin_node: Node in bins:
		if bin_node.has_method("set_item_count"):
			bin_node.set_item_count(bin_items.size())
