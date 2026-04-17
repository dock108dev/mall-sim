## Controller for the video rental store with rental lifecycle, late fees, and tape wear.
class_name VideoRentalStoreController
extends StoreController

enum LateFeePolicy { STRICT, STANDARD, LENIENT }

const STORE_ID: StringName = &"rentals"
const SOLD_CATEGORIES: PackedStringArray = ["snacks", "merchandise"]
const RENTAL_CATEGORIES: PackedStringArray = [
	"vhs_tapes",
	"dvd_titles",
	"vhs_classic",
	"vhs_new_release",
	"vhs_cult",
	"dvd_new_release",
	"dvd_classic",
]
const MAX_STAFF_PICKS: int = 3
const STAFF_PICK_BOOST: float = 1.3
const RETURNS_BIN_LOCATION: String = "returns_bin"
const BACKROOM_LOCATION: String = "backroom"
const RENTED_LOCATION: String = "rented"
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

var rental_records: Dictionary = {}
var _staff_picks: Array[String] = []
var _late_fee_policy: LateFeePolicy = LateFeePolicy.STANDARD
var _rental_history: Array[Dictionary] = []
var _wear_tracker: TapeWearTracker = TapeWearTracker.new()
var _daily_late_fee_total: float = 0.0

var _economy_system: EconomySystem = null
var _reputation_system: ReputationSystem = null

var _base_late_fee: float = 1.0
var _per_day_rate: float = 0.5
var _max_late_fee: float = 15.0
var _grace_period_days: int = 1


func _ready() -> void:
	store_type = STORE_ID
	_load_late_fee_config()
	super._ready()


## Sets the EconomySystem reference for fee collection.
func set_economy_system(econ: EconomySystem) -> void:
	_economy_system = econ


## Sets the ReputationSystem reference for policy-based reputation.
func set_reputation_system(rep: ReputationSystem) -> void:
	_reputation_system = rep


## Returns true if the item category uses rental checkout instead of sale.
func is_rental_item(category: String) -> bool:
	return category in RENTAL_CATEGORIES


## Returns true if the item can still be rented.
func is_rentable(item: ItemInstance) -> bool:
	if not item:
		return false
	_wear_tracker.initialize_item(item.instance_id, item.condition)
	return _wear_tracker.is_rentable(item.instance_id)


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
	customer_id: String = "",
) -> Dictionary:
	var duration: int = RENTAL_DURATIONS.get(rental_tier, 3)
	var return_day: int = current_day + duration
	var rental_record: Dictionary = {
		"instance_id": item_instance_id,
		"customer_id": customer_id,
		"category": item_category,
		"rental_fee": rental_fee,
		"rental_tier": rental_tier,
		"checkout_day": current_day,
		"return_day": return_day,
	}
	rental_records[item_instance_id] = rental_record
	if _inventory_system:
		var item: ItemInstance = _inventory_system.get_item(
			item_instance_id
		)
		if item:
			item.rental_due_day = return_day
			_wear_tracker.initialize_item(item_instance_id, item.condition)
			_inventory_system.move_item(
				item_instance_id, RENTED_LOCATION
			)
	if _economy_system and rental_fee > 0.0:
		_economy_system.add_cash(
			rental_fee,
			"Rental: %s (%s)" % [item_instance_id, rental_tier]
		)
	EventBus.item_rented.emit(
		item_instance_id, rental_fee, rental_tier
	)
	return rental_record


## Returns all currently active (unreturned) rental records.
func get_active_rentals() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in rental_records.values():
		result.append(record)
	return result


## Returns rental records that are overdue as of the given day.
func get_overdue_rentals(current_day: int) -> Array[Dictionary]:
	var overdue: Array[Dictionary] = []
	for record: Dictionary in rental_records.values():
		var deadline: int = int(record["return_day"]) + _grace_period_days
		if current_day > deadline:
			overdue.append(record)
	return overdue

## Returns the total late fees collected today.
func get_daily_late_fee_total() -> float:
	return _daily_late_fee_total


## Returns items currently in the returns bin.
func get_returns_bin_items() -> Array[ItemInstance]:
	if not _inventory_system:
		return []
	return _inventory_system.get_items_at_location(
		RETURNS_BIN_LOCATION
	)


## Returns the number of currently rented copies.
func get_rented_count() -> int:
	return rental_records.size()


## Returns items currently rented out.
func get_rented_items() -> Array[ItemInstance]:
	if not _inventory_system:
		return []
	return _inventory_system.get_items_at_location(RENTED_LOCATION)


## Returns count of items available (not rented).
func get_available_count() -> int:
	if not _inventory_system:
		return 0
	var all_items: Array[ItemInstance] = (
		_inventory_system.get_items_for_store(String(STORE_ID))
	)
	var available: int = 0
	for item: ItemInstance in all_items:
		if item.current_location != RENTED_LOCATION and is_rentable(item):
			available += 1
	return available


## Returns the current play-count progress for an item.
func get_tape_wear(instance_id: String) -> int:
	return _wear_tracker.get_play_count(instance_id)


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
	var records_array: Array[Dictionary] = []
	for record: Dictionary in rental_records.values():
		records_array.append(record.duplicate())
	return {
		"rental_records": records_array,
		"staff_picks": _staff_picks.duplicate(),
		"tape_wear": _wear_tracker.get_save_data(),
		"late_fee_policy": _late_fee_policy,
		"rental_history": _rental_history.duplicate(true),
	}


## Restores rental state from save data.
func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	rental_records = {}
	if data.has("rental_records"):
		for entry: Variant in data["rental_records"]:
			if entry is Dictionary:
				var record: Dictionary = entry as Dictionary
				var iid: String = str(record.get("instance_id", ""))
				if not iid.is_empty():
					rental_records[iid] = record
	if data.has("active_rentals"):
		for entry: Variant in data["active_rentals"]:
			if entry is Dictionary:
				var record: Dictionary = entry as Dictionary
				if record.get("returned", false):
					continue
				var iid: String = str(record.get("instance_id", ""))
				if not iid.is_empty() and not rental_records.has(iid):
					rental_records[iid] = record
	_staff_picks.clear()
	if data.has("staff_picks"):
		for pick: Variant in data["staff_picks"]:
			if pick is String:
				_staff_picks.append(pick)
	var saved_wear: Variant = data.get("tape_wear", {})
	if saved_wear is Dictionary:
		_wear_tracker.load_save_data(saved_wear as Dictionary)
	_sync_wear_tracker()
	var saved_policy: Variant = data.get(
		"late_fee_policy", LateFeePolicy.STANDARD
	)
	_late_fee_policy = int(saved_policy) as LateFeePolicy
	_rental_history = []
	if data.has("rental_history"):
		for entry: Variant in data["rental_history"]:
			if entry is Dictionary:
				_rental_history.append(entry)


func _on_store_entered(store_id: StringName) -> void:
	if not _matches_store_id(store_id):
		return
	_sync_wear_tracker()


func _on_day_started(day: int) -> void:
	_daily_late_fee_total = 0.0
	_process_returns(day)
	_collect_overdue_late_fees(day)
	_update_returns_bin_count()
	if _daily_late_fee_total > 0.0:
		EventBus.toast_requested.emit(
			"+$%.2f late fees collected" % _daily_late_fee_total,
			&"system",
			3.0,
		)


## Checks all rental records and processes items due for return.
func _process_returns(current_day: int) -> void:
	var to_return: Array[String] = []
	for instance_id: String in rental_records:
		var record: Dictionary = rental_records[instance_id]
		if current_day >= int(record["return_day"]):
			to_return.append(instance_id)
	for instance_id: String in to_return:
		var record: Dictionary = rental_records[instance_id]
		var deadline: int = int(record["return_day"]) + _grace_period_days
		var days_overdue: int = maxi(0, current_day - deadline)
		rental_records.erase(instance_id)
		_handle_return(record, days_overdue)


## Handles a single item return: degradation, late fees, lost item check.
func _handle_return(rental: Dictionary, late_days: int) -> void:
	var instance_id: String = rental["instance_id"]
	if randf() < LOST_ITEM_CHANCE:
		_handle_lost_item(rental)
		return
	var degradation_result: Dictionary = _apply_degradation(rental)
	if late_days > 0:
		_collect_late_fee(rental, late_days)
	var worn_out: bool = bool(
		degradation_result.get("became_unrentable", false)
	)
	if _inventory_system:
		var item: ItemInstance = _inventory_system.get_item(instance_id)
		if item:
			item.rental_due_day = -1
			worn_out = worn_out or not is_rentable(item)
		if worn_out:
			_inventory_system.move_item(
				instance_id, BACKROOM_LOCATION
			)
			_emit_worn_out_notification(instance_id)
		else:
			_inventory_system.move_item(
				instance_id, RETURNS_BIN_LOCATION
			)
	_apply_rental_reputation()
	_rental_history.append({
		"instance_id": instance_id,
		"return_day": GameManager.current_day,
		"late_days": late_days,
		"lost": false,
	})
	EventBus.rental_returned.emit(instance_id, worn_out)


## Applies guaranteed wear degradation to a returned item.
func _apply_degradation(rental: Dictionary) -> Dictionary:
	var instance_id: String = rental["instance_id"]
	var item: ItemInstance = null
	if _inventory_system:
		item = _inventory_system.get_item(instance_id)
	if item:
		_wear_tracker.sync_condition(instance_id, item.condition)
	else:
		_wear_tracker.initialize_item(instance_id, "good")
	var result: Dictionary = _wear_tracker.record_return(instance_id)
	if bool(result.get("condition_changed", false)) and _inventory_system:
		var new_condition: String = str(result.get("new_condition", "good"))
		_inventory_system.update_item_condition(instance_id, new_condition)
	return result


## Collects late fees using formula: base + (days × per_day_rate), capped.
func _collect_late_fee(rental: Dictionary, days_overdue: int) -> void:
	var raw_fee: float = _base_late_fee + (float(days_overdue) * _per_day_rate)
	var late_fee: float = minf(raw_fee, _max_late_fee)
	if _economy_system and late_fee > 0.0:
		_economy_system.add_cash(
			late_fee,
			"Late fee: %s (%dd)" % [rental["instance_id"], days_overdue]
		)
		_economy_system.record_store_revenue(String(STORE_ID), late_fee)
	_daily_late_fee_total += late_fee
	EventBus.rental_late_fee.emit(
		rental["instance_id"], late_fee, days_overdue
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


## Collects daily late fees for rentals still out past the grace period.
func _collect_overdue_late_fees(current_day: int) -> void:
	for record: Dictionary in rental_records.values():
		var deadline: int = int(record["return_day"]) + _grace_period_days
		var days_overdue: int = current_day - deadline
		if days_overdue > 0:
			_collect_late_fee(record, days_overdue)


## Loads late fee formula constants from video_rental_config.json via DataLoaderSingleton.
func _load_late_fee_config() -> void:
	if not GameManager or not GameManager.data_loader:
		push_warning("VideoRentalStoreController: DataLoader not available, config not loaded")
		return
	var cfg: Dictionary = GameManager.data_loader.get_video_rental_config()
	if cfg.is_empty():
		push_warning("VideoRentalStoreController: video_rental_config.json not loaded")
		return
	_base_late_fee = float(cfg.get("base_late_fee", _base_late_fee))
	_per_day_rate = float(cfg.get("per_day_late_rate", _per_day_rate))
	_max_late_fee = float(cfg.get("max_late_fee", _max_late_fee))
	_grace_period_days = int(cfg.get("grace_period_days", _grace_period_days))


## Updates the ReturnsBin node count display if one exists in the scene.
func _update_returns_bin_count() -> void:
	var bin_items: Array[ItemInstance] = get_returns_bin_items()
	var bins: Array[Node] = get_tree().get_nodes_in_group("returns_bin")
	for bin_node: Node in bins:
		if bin_node.has_method("set_item_count"):
			bin_node.set_item_count(bin_items.size())


## Returns true if a tape is worn out and eligible for retirement.
func is_worn_out(item: ItemInstance) -> bool:
	if not item:
		return false
	_wear_tracker.initialize_item(item.instance_id, item.condition)
	return not _wear_tracker.is_rentable(item.instance_id)


## Retires a worn-out tape by selling at poor-condition price or writing off.
func retire_tape(instance_id: String, sell: bool) -> bool:
	if not _inventory_system:
		push_error("VideoRental: no inventory_system for retire_tape")
		return false
	var item: ItemInstance = _inventory_system.get_item(instance_id)
	if not item:
		push_error("VideoRental: item not found: %s" % instance_id)
		return false
	if not is_worn_out(item):
		push_error("VideoRental: item not worn out: %s" % instance_id)
		return false
	if sell:
		var sale_value: float = _get_retirement_sale_value(item)
		var category: String = ""
		if item.definition:
			category = item.definition.category
		EventBus.item_sold.emit(instance_id, sale_value, category)
		EventBus.customer_purchased.emit(
			STORE_ID, StringName(instance_id), sale_value, &""
		)
	else:
		_inventory_system.remove_item(instance_id)
	_wear_tracker.erase_item(instance_id)
	return true


func _emit_worn_out_notification(instance_id: String) -> void:
	var tape_name: String = instance_id
	if _inventory_system:
		var item: ItemInstance = _inventory_system.get_item(instance_id)
		if item and item.definition:
			tape_name = item.definition.item_name
	EventBus.notification_requested.emit(
		"'%s' is worn out — consider retiring it" % tape_name
	)


func _sync_wear_tracker() -> void:
	if not _inventory_system:
		return
	var items: Array[ItemInstance] = _inventory_system.get_items_for_store(
		String(STORE_ID)
	)
	_wear_tracker.initialize(items)


func _matches_store_id(store_id: StringName) -> bool:
	if store_id == STORE_ID:
		return true
	if not ContentRegistry.exists(String(STORE_ID)):
		return store_id == STORE_ID
	if not ContentRegistry.exists(String(store_id)):
		return false
	return (
		ContentRegistry.resolve(String(store_id))
		== ContentRegistry.resolve(String(STORE_ID))
	)


func _get_retirement_sale_value(item: ItemInstance) -> float:
	var original_condition: String = item.condition
	item.condition = "poor"
	var sale_value: float = item.get_current_value()
	item.condition = original_condition
	return sale_value
