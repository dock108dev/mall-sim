# gdlint:disable=max-public-methods
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
## Pending late fees awaiting player waive/collect decision {item_id: {amount, days_late}}.
var _pending_late_fees: Dictionary = {}

var _economy_system: EconomySystem = null
var _reputation_system: ReputationSystem = null

var _base_late_fee: float = 1.0
var _per_day_rate: float = 0.5
var _max_late_fee: float = 15.0
var _grace_period_days: int = 1
var _new_release_window_days: int = 7


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


## Returns the selectable rental duration options for an item, ordered by length.
## Each entry: {tier, days, price, label}. Price is the effective rental fee for
## that tier on the given day; tiers inherit the item's base rental_fee and
## scale by duration multiplier so UIs can show at least two meaningful choices.
func get_rental_duration_options(
	item: ItemInstance, current_day: int
) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if not item or not item.definition:
		return options
	var base_fee: float = resolve_rental_price(item, current_day)
	if base_fee <= 0.0:
		base_fee = item.definition.rental_fee
	var tiers: Array = [
		{"tier": "overnight", "label": "Overnight (1 day)", "scale": 1.0},
		{"tier": "three_day", "label": "Three-day", "scale": 2.0},
		{"tier": "weekly", "label": "Weekly (7 days)", "scale": 3.5},
	]
	for row: Dictionary in tiers:
		var tier: String = row["tier"]
		var days: int = int(RENTAL_DURATIONS.get(tier, 3))
		var price: float = snappedf(base_fee * float(row["scale"]), 0.01)
		options.append({
			"tier": tier,
			"days": days,
			"price": price,
			"label": row["label"],
		})
	return options


## Rents an item using the chosen tier. Returns a rental record with
## tape_id, due_day, and price keys (matches ISSUE-014 acceptance language).
## Returns an empty dict when the item is missing, unrentable, or already out.
## Returns {blocked_by_late_fees: true, customer_id, pending_total, pending_items}
## when the customer has unresolved pending late fees (ISSUE-015).
# gdlint:disable=max-returns
func rent_item(
	item_instance_id: String,
	rental_tier: String,
	current_day: int,
	customer_id: String = "",
) -> Dictionary:
	if item_instance_id.is_empty():
		push_warning("VideoRental: rent_item called with empty instance_id")
		return {}
	if not customer_id.is_empty():
		var pending: Dictionary = get_pending_fees_for_customer(customer_id)
		if float(pending.get("total", 0.0)) > 0.0:
			return {
				"blocked_by_late_fees": true,
				"customer_id": customer_id,
				"pending_total": pending["total"],
				"pending_items": pending["items"],
			}
	if rental_records.has(item_instance_id):
		push_warning(
			"VideoRental: item %s already rented" % item_instance_id
		)
		return {}
	if not _inventory_system:
		push_warning("VideoRental: rent_item without inventory_system")
		return {}
	var item: ItemInstance = _inventory_system.get_item(item_instance_id)
	if not item or not item.definition:
		push_warning(
			"VideoRental: rent_item unknown item %s" % item_instance_id
		)
		return {}
	if not is_rentable(item):
		return {}
	if not RENTAL_DURATIONS.has(rental_tier):
		rental_tier = "three_day"
	var options: Array[Dictionary] = get_rental_duration_options(item, current_day)
	var price: float = item.definition.rental_fee
	for opt: Dictionary in options:
		if String(opt.get("tier", "")) == rental_tier:
			price = float(opt.get("price", price))
			break
	var record: Dictionary = process_rental(
		item_instance_id,
		String(item.definition.category),
		rental_tier,
		price,
		current_day,
		customer_id,
	)
	return {
		"tape_id": item_instance_id,
		"due_day": int(record.get("return_day", -1)),
		"price": price,
		"rental_tier": rental_tier,
		"record": record,
	}
# gdlint:enable=max-returns


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
	EventBus.item_rented.emit(item_instance_id, rental_fee, rental_tier)
	EventBus.title_rented.emit(item_instance_id, rental_fee, rental_tier)
	EventBus.store_rental_started.emit(item_instance_id, customer_id, return_day)
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


## Returns the active rental price for an item on the given day.
## New-release titles decay to catalog_price after _new_release_window_days.
func get_effective_rental_price(item: ItemInstance, current_day: int) -> float:
	if not item or not item.definition:
		return 0.0
	var def: ItemDefinition = item.definition
	var is_new_release: bool = (
		def.category == &"vhs_new_release" or def.category == &"dvd_new_release"
	)
	if is_new_release and def.catalog_price > 0.0 and def.release_day > 0:
		var days_since_release: int = current_day - def.release_day
		if days_since_release >= _new_release_window_days:
			return def.catalog_price
	return def.rental_fee


## Player-initiated: waive the pending late fee for item_id.
## Awards reputation instead of cash and emits late_fee_waived.
func waive_late_fee(item_id: String) -> bool:
	if not _pending_late_fees.has(item_id):
		return false
	var pending: Dictionary = _pending_late_fees[item_id]
	var amount: float = float(pending.get("amount", 0.0))
	_pending_late_fees.erase(item_id)
	var rep_mult: float = POLICY_REP_MULTIPLIERS.get(_late_fee_policy, 1.0)
	var rep_delta: float = RENTAL_REP_GAIN * rep_mult * 2.0
	if _reputation_system:
		_reputation_system.add_reputation(STORE_ID, rep_delta)
	if rental_records.has(item_id):
		var record: Dictionary = rental_records[item_id]
		rental_records.erase(item_id)
		_handle_return(record, 0)
	EventBus.late_fee_waived.emit(item_id, amount, rep_delta)
	return true


## Player-initiated: collect the pending late fee for item_id.
## Adds cash, emits late_fee_collected, and clears overdue flag on the record.
func collect_late_fee(item_id: String) -> bool:
	if not _pending_late_fees.has(item_id):
		return false
	var pending: Dictionary = _pending_late_fees[item_id]
	var amount: float = float(pending.get("amount", 0.0))
	var days_late: int = int(pending.get("days_late", 0))
	_pending_late_fees.erase(item_id)
	if _economy_system and amount > 0.0:
		_economy_system.add_cash(
			amount, "Late fee collected: %s (%dd)" % [item_id, days_late]
		)
		_economy_system.record_store_revenue(String(STORE_ID), amount)
	_daily_late_fee_total += amount
	if rental_records.has(item_id):
		var record: Dictionary = rental_records[item_id]
		rental_records.erase(item_id)
		_handle_return(record, 0)
	EventBus.late_fee_collected.emit(item_id, amount, days_late)
	return true


## Returns pending late fees awaiting player decision {item_id: {amount, days_late}}.
func get_pending_late_fees() -> Dictionary:
	return _pending_late_fees.duplicate()


## Returns pending late-fee summary for a given customer_id.
## Result: {total: float, items: Array[{item_id, amount, days_late}]}.
func get_pending_fees_for_customer(customer_id: String) -> Dictionary:
	var items: Array[Dictionary] = []
	var total: float = 0.0
	if customer_id.is_empty():
		return {"total": 0.0, "items": items}
	for item_id: String in _pending_late_fees:
		var record: Dictionary = rental_records.get(item_id, {})
		if str(record.get("customer_id", "")) != customer_id:
			continue
		var pending: Dictionary = _pending_late_fees[item_id]
		var amount: float = float(pending.get("amount", 0.0))
		total += amount
		items.append({
			"item_id": item_id,
			"amount": amount,
			"days_late": int(pending.get("days_late", 0)),
		})
	return {"total": total, "items": items}


## Resolves all pending late fees for a customer. When pay is true, calls
## collect_late_fee for each item; when false, leaves pending intact so the
## block persists into the next rental attempt. Returns {paid, total, items}.
func resolve_customer_late_fees(
	customer_id: String, pay: bool
) -> Dictionary:
	var summary: Dictionary = get_pending_fees_for_customer(customer_id)
	var total_paid: float = 0.0
	var count: int = 0
	if pay:
		for entry: Dictionary in summary.get("items", []):
			var iid: String = str(entry.get("item_id", ""))
			if collect_late_fee(iid):
				total_paid += float(entry.get("amount", 0.0))
				count += 1
	return {"paid": pay, "total": total_paid, "items_resolved": count}


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


## Returns the accumulated wear value in [0, 1] for a tracked tape.
func get_tape_wear_amount(instance_id: String) -> float:
	return _wear_tracker.get_wear(instance_id)


## Returns the customer appeal factor [0.5, 1.0] for a tape based on wear.
## Used by the rental customer appeal formula; a pristine tape returns 1.0
## while a maximally worn tape returns 0.5.
func get_tape_appeal_factor(item: ItemInstance) -> float:
	if not item:
		return 1.0
	_wear_tracker.initialize_item(item.instance_id, item.condition)
	return TapeWearTracker.compute_appeal_factor(
		_wear_tracker.get_wear(item.instance_id)
	)


## Returns a UI wear classification: pristine, light, moderate, heavy, worn_out.
func get_tape_wear_class(item: ItemInstance) -> String:
	if not item:
		return "pristine"
	_wear_tracker.initialize_item(item.instance_id, item.condition)
	return TapeWearTracker.classify_wear(
		_wear_tracker.get_wear(item.instance_id)
	)


## Returns an empty string if the tape can be rented; otherwise a player-facing
## reason the tape is blocked (currently: worn out, must be retired).
func get_rentability_reason(item: ItemInstance) -> String:
	if not item:
		return "No item"
	if not item.definition:
		return ""
	if not is_rental_item(String(item.definition.category)):
		return ""
	_wear_tracker.initialize_item(item.instance_id, item.condition)
	if _wear_tracker.is_rentable(item.instance_id):
		return ""
	return "Worn out — retire to remove from shelf"


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
	_seed_starter_inventory()
	EventBus.store_opened.emit(String(STORE_ID))


func get_store_actions() -> Array:
	var actions: Array = super()
	actions.append({"id": &"rent", "label": "Rent", "icon": ""})
	actions.append({"id": &"process_returns", "label": "Process Returns", "icon": ""})
	return actions


## Processes on-time returns for the given day. Called from _on_day_started;
## also available as a named entry point for testing and tooling.
func _process_daily_returns(day: int) -> void:
	_process_returns(day)


## Detects rentals past their deadline and accrues pending late fees.
## Called from _on_day_started after _process_daily_returns.
func _check_overdue_rentals(day: int) -> void:
	_collect_overdue_late_fees(day)


func _on_day_started(day: int) -> void:
	_daily_late_fee_total = 0.0
	_process_daily_returns(day)
	_check_overdue_rentals(day)
	_update_returns_bin_count()
	if _daily_late_fee_total > 0.0:
		EventBus.toast_requested.emit(
			"+$%.2f late fees collected" % _daily_late_fee_total,
			&"system",
			3.0,
		)


## Auto-processes on-time returns (return_day through end of grace window).
## Past-deadline rentals stay in rental_records and are flagged overdue by
## _collect_overdue_late_fees so the customer must resolve the fee before
## their next rental (ISSUE-015).
func _process_returns(current_day: int) -> void:
	var to_return: Array[String] = []
	for instance_id: String in rental_records:
		var record: Dictionary = rental_records[instance_id]
		var return_day: int = int(record["return_day"])
		var deadline: int = return_day + _grace_period_days
		if current_day >= return_day and current_day <= deadline:
			to_return.append(instance_id)
	for instance_id: String in to_return:
		var record: Dictionary = rental_records[instance_id]
		rental_records.erase(instance_id)
		_handle_return(record, 0)


## Handles a single item return: degradation, late fees, lost item check.
func _handle_return(rental: Dictionary, late_days: int) -> void:
	var instance_id: String = rental["instance_id"]
	if randf() < LOST_ITEM_CHANCE:
		_handle_lost_item(rental)
		return
	var degradation_result: Dictionary = _apply_degradation(rental)
	if late_days > 0:
		EventBus.rental_overdue.emit(
			str(rental.get("customer_id", "")),
			str(rental.get("instance_id", ""))
		)
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
	EventBus.title_returned.emit(instance_id, worn_out)
	EventBus.store_rental_returned.emit(instance_id, late_days)


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


## Calculates the late fee for a rental.
## When the item definition has late_fee_per_day > 0, uses the simple formula:
##   late_fee_per_day × days_overdue × policy_multiplier
## Otherwise falls back to: (base_late_fee + days × per_day_rate) × policy_multiplier
func _calculate_late_fee(rental: Dictionary, days_overdue: int) -> float:
	var per_day_new: float = -1.0
	var item_rate: float = -1.0
	if _inventory_system:
		var item: ItemInstance = _inventory_system.get_item(
			str(rental.get("instance_id", ""))
		)
		if item and item.definition:
			per_day_new = item.definition.late_fee_per_day
			item_rate = item.definition.late_fee_rate
	var policy_mult: float = LATE_FEE_MULTIPLIERS.get(_late_fee_policy, 1.0)
	if per_day_new > 0.0:
		return minf(per_day_new * float(days_overdue) * policy_mult, _max_late_fee)
	var per_day: float = _per_day_rate if item_rate < 0.0 else item_rate
	var raw_fee: float = (_base_late_fee + float(days_overdue) * per_day) * policy_mult
	return minf(raw_fee, _max_late_fee)


## Records a late fee as pending (auto-collected on day start) and emits signals.
func _collect_late_fee(rental: Dictionary, days_overdue: int) -> void:
	var late_fee: float = _calculate_late_fee(rental, days_overdue)
	var item_id: String = str(rental.get("instance_id", ""))
	if late_fee <= 0.0:
		return
	if not _economy_system:
		# Without an economy system the cash never lands; emitting
		# late_fee_collected and bumping daily totals here would lie about
		# revenue and silently drop the pending fee. Fail loud instead. The
		# fee is parked in _pending_late_fees so a downstream day-cycle
		# handler can settle it once economy_system is wired. See
		# docs/audits/error-handling-report.md §A2.
		push_error(
			(
				"VideoRental: _collect_late_fee called without economy_system "
				+ "(item=%s, fee=%.2f) — fee not collected"
			)
			% [item_id, late_fee]
		)
		_pending_late_fees[item_id] = {"amount": late_fee, "days_late": days_overdue}
		EventBus.rental_late_fee.emit(item_id, late_fee, days_overdue)
		return
	_pending_late_fees[item_id] = {"amount": late_fee, "days_late": days_overdue}
	_economy_system.add_cash(
		late_fee,
		"Late fee: %s (%dd)" % [item_id, days_overdue]
	)
	_economy_system.record_store_revenue(String(STORE_ID), late_fee)
	_pending_late_fees.erase(item_id)
	_daily_late_fee_total += late_fee
	EventBus.rental_late_fee.emit(item_id, late_fee, days_overdue)
	EventBus.late_fee_collected.emit(item_id, late_fee, days_overdue)


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
	_reputation_system.add_reputation(
		STORE_ID, RENTAL_REP_GAIN * rep_mult
	)


## Processes overdue rentals still out past the grace period. Tags each record
## with overdue=true + days_overdue, accrues the late fee as pending (awaiting
## the customer's next interaction), and emits rental_overdue + rental_late_fee.
func _collect_overdue_late_fees(current_day: int) -> void:
	for record: Dictionary in rental_records.values():
		var deadline: int = int(record["return_day"]) + _grace_period_days
		var days_overdue: int = current_day - deadline
		if days_overdue <= 0:
			continue
		record["overdue"] = true
		record["days_overdue"] = days_overdue
		EventBus.rental_overdue.emit(
			str(record.get("customer_id", "")),
			str(record.get("instance_id", ""))
		)
		EventBus.store_rental_overdue.emit(
			str(record.get("customer_id", "")),
			str(record.get("instance_id", ""))
		)
		_accrue_pending_late_fee(record, days_overdue)


## Records a late fee as pending on the given rental without collecting cash.
## The fee is resolved at the customer's next rental interaction via
## collect_late_fee / waive_late_fee / resolve_customer_late_fees.
func _accrue_pending_late_fee(rental: Dictionary, days_overdue: int) -> void:
	var late_fee: float = _calculate_late_fee(rental, days_overdue)
	if late_fee <= 0.0:
		return
	var item_id: String = str(rental.get("instance_id", ""))
	_pending_late_fees[item_id] = {
		"amount": late_fee,
		"days_late": days_overdue,
	}
	EventBus.rental_late_fee.emit(item_id, late_fee, days_overdue)


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
	_new_release_window_days = int(
		cfg.get("new_release_window_days", _new_release_window_days)
	)


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
		push_warning("VideoRental: no inventory_system for retire_tape")
		return false
	var item: ItemInstance = _inventory_system.get_item(instance_id)
	if not item:
		push_warning("VideoRental: item not found: %s" % instance_id)
		return false
	if not is_worn_out(item):
		push_warning("VideoRental: item not worn out: %s" % instance_id)
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


## Resolves the effective rental price via PriceResolver, applying lifecycle
## and condition multipliers. Use this for auditable price display at checkout.
## Falls back to get_effective_rental_price() when no multipliers apply.
func resolve_rental_price(item: ItemInstance, current_day: int) -> float:
	if not item or not item.definition:
		return 0.0
	var base_fee: float = get_effective_rental_price(item, current_day)
	var multipliers: Array = []
	var lifecycle_factor: float = _compute_lifecycle_factor(item.definition, current_day)
	if lifecycle_factor != 1.0:
		multipliers.append({
			"slot": "lifecycle",
			"label": "Lifecycle",
			"factor": lifecycle_factor,
			"detail": "rarity:%s" % item.definition.rarity,
		})
	var condition_factor: float = _compute_condition_factor(item.condition)
	if condition_factor != 1.0:
		multipliers.append({
			"slot": "condition",
			"label": "Condition",
			"factor": condition_factor,
			"detail": item.condition,
		})
	if multipliers.is_empty():
		return base_fee
	var result: PriceResolver.Result = PriceResolver.resolve(base_fee, multipliers)
	return result.final_price


## Returns the lifecycle multiplier for a rental item definition on the given day.
func _compute_lifecycle_factor(def: ItemDefinition, current_day: int) -> float:
	var phase: String = def.lifecycle_phase if not def.lifecycle_phase.is_empty() else def.rarity
	if phase == "ultra_new" or phase == "new":
		var release: int = def.release_day if def.release_day > 0 else def.release_date
		if release > 0:
			var age: int = current_day - release
			if age < 0:
				return PriceResolver.LIFECYCLE_MULTIPLIERS.get("ultra_new", 1.35)
			if age < 7:
				return PriceResolver.LIFECYCLE_MULTIPLIERS.get("ultra_new", 1.35)
			if age < 21:
				return PriceResolver.LIFECYCLE_MULTIPLIERS.get("new", 1.15)
	if phase == "ultra_new":
		return PriceResolver.LIFECYCLE_MULTIPLIERS.get("ultra_new", 1.35)
	if phase == "new":
		return PriceResolver.LIFECYCLE_MULTIPLIERS.get("new", 1.15)
	return PriceResolver.LIFECYCLE_MULTIPLIERS.get("common", 1.0)


## Returns a condition-based rental price factor: worn items rent for less.
func _compute_condition_factor(condition: String) -> float:
	match condition:
		"mint", "near_mint":
			return 1.0
		"good":
			return 1.0
		"fair":
			return 0.90
		"poor":
			return 0.80
	return 1.0


func _seed_starter_inventory() -> void:
	if not _inventory_system:
		return
	var existing: Array[ItemInstance] = (
		_inventory_system.get_items_for_store(String(STORE_ID))
	)
	if not existing.is_empty():
		return
	var entry: Dictionary = ContentRegistry.get_entry(STORE_ID)
	if entry.is_empty():
		push_error(
			"VideoRentalStoreController: no ContentRegistry entry for %s" % STORE_ID
		)
		return
	var starter_items: Variant = entry.get("starting_inventory", [])
	if starter_items is Array:
		for item_id: Variant in starter_items:
			if item_id is String:
				_add_starter_item(item_id as String)


func _add_starter_item(raw_id: String) -> void:
	if raw_id.is_empty():
		return
	var canonical: StringName = ContentRegistry.resolve(raw_id)
	if canonical.is_empty():
		push_error(
			"VideoRentalStoreController: unknown item_id '%s'" % raw_id
		)
		return
	var entry: Dictionary = ContentRegistry.get_entry(canonical)
	if entry.is_empty():
		return
	var def: ItemDefinition = _build_item_definition(canonical, entry)
	var instance: ItemInstance = ItemInstance.create_from_definition(def)
	_inventory_system.add_item(STORE_ID, instance)


func _build_item_definition(
	canonical_id: StringName, data: Dictionary
) -> ItemDefinition:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = String(canonical_id)
	if data.has("item_name"):
		def.item_name = str(data["item_name"])
	if data.has("base_price"):
		def.base_price = float(data["base_price"])
	if data.has("category"):
		def.category = str(data["category"])
	if data.has("rarity"):
		def.rarity = str(data["rarity"])
	if data.has("store_type"):
		def.store_type = str(data["store_type"])
	if data.has("rental_fee"):
		def.rental_fee = float(data["rental_fee"])
	if data.has("rental_period_days"):
		def.rental_period_days = int(data["rental_period_days"])
	return def


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
