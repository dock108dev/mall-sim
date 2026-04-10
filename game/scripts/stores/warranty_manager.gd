## Tracks active warranties on sold electronics items and processes claims.
class_name WarrantyManager
extends RefCounted

const MIN_WARRANTY_PERCENT: float = 0.15
const MAX_WARRANTY_PERCENT: float = 0.25
const MIN_ITEM_PRICE: float = 50.0
const BASE_ACCEPTANCE_RATE: float = 0.40
const HIGH_PRICE_THRESHOLD: float = 100.0
const HIGH_PRICE_ACCEPTANCE_BONUS: float = 0.10
const CLAIM_PROBABILITY: float = 0.10
const WARRANTY_DURATION_DAYS: int = 30

var _active_warranties: Array[Dictionary] = []
var _claim_history: Array[Dictionary] = []
var _daily_warranty_revenue: float = 0.0
var _daily_claim_costs: float = 0.0


## Returns true if the item qualifies for a warranty offer.
static func is_eligible(sale_price: float) -> bool:
	return sale_price >= MIN_ITEM_PRICE


## Calculates the warranty fee from a sale price and percentage.
static func calculate_fee(
	sale_price: float, percent: float
) -> float:
	var clamped: float = clampf(
		percent, MIN_WARRANTY_PERCENT, MAX_WARRANTY_PERCENT
	)
	return sale_price * clamped


## Returns the customer acceptance probability for a given sale price.
static func get_acceptance_probability(sale_price: float) -> float:
	if sale_price >= HIGH_PRICE_THRESHOLD:
		return BASE_ACCEPTANCE_RATE + HIGH_PRICE_ACCEPTANCE_BONUS
	return BASE_ACCEPTANCE_RATE


## Rolls whether the customer accepts the warranty offer.
static func roll_acceptance(sale_price: float) -> bool:
	return randf() < get_acceptance_probability(sale_price)


## Records a purchased warranty. Returns the warranty record.
func add_warranty(
	item_id: String,
	sale_price: float,
	warranty_fee: float,
	wholesale_cost: float,
	purchase_day: int,
) -> Dictionary:
	var record: Dictionary = {
		"item_id": item_id,
		"sale_price": sale_price,
		"warranty_fee": warranty_fee,
		"wholesale_cost": wholesale_cost,
		"purchase_day": purchase_day,
		"expiry_day": purchase_day + WARRANTY_DURATION_DAYS,
		"claimed": false,
	}
	_active_warranties.append(record)
	_daily_warranty_revenue += warranty_fee
	return record


## Processes daily claim checks. Returns an array of triggered claims.
func process_daily_claims(current_day: int) -> Array[Dictionary]:
	var triggered: Array[Dictionary] = []
	var still_active: Array[Dictionary] = []
	for warranty: Dictionary in _active_warranties:
		if warranty.get("claimed", false):
			still_active.append(warranty)
			continue
		var expiry: int = warranty.get("expiry_day", 0)
		if current_day > expiry:
			continue
		if randf() < CLAIM_PROBABILITY:
			warranty["claimed"] = true
			var cost: float = warranty.get("wholesale_cost", 0.0)
			_daily_claim_costs += cost
			var claim: Dictionary = {
				"item_id": warranty.get("item_id", ""),
				"replacement_cost": cost,
				"claim_day": current_day,
			}
			_claim_history.append(claim)
			triggered.append(claim)
		still_active.append(warranty)
	_active_warranties = still_active
	return triggered


## Removes expired warranties that have passed their duration.
func purge_expired(current_day: int) -> void:
	var kept: Array[Dictionary] = []
	for warranty: Dictionary in _active_warranties:
		var expiry: int = warranty.get("expiry_day", 0)
		if current_day <= expiry:
			kept.append(warranty)
	_active_warranties = kept


## Returns today's warranty revenue total.
func get_daily_warranty_revenue() -> float:
	return _daily_warranty_revenue


## Returns today's warranty claim costs total.
func get_daily_claim_costs() -> float:
	return _daily_claim_costs


## Resets daily totals at the start of a new day.
func reset_daily_totals() -> void:
	_daily_warranty_revenue = 0.0
	_daily_claim_costs = 0.0


## Returns the number of active (non-expired, non-claimed) warranties.
func get_active_count() -> int:
	var count: int = 0
	for warranty: Dictionary in _active_warranties:
		if not warranty.get("claimed", false):
			count += 1
	return count


## Serializes warranty state for saving.
func get_save_data() -> Dictionary:
	var serialized_active: Array[Dictionary] = []
	for w: Dictionary in _active_warranties:
		serialized_active.append(w.duplicate())
	var serialized_claims: Array[Dictionary] = []
	for c: Dictionary in _claim_history:
		serialized_claims.append(c.duplicate())
	return {
		"active_warranties": serialized_active,
		"claim_history": serialized_claims,
		"daily_warranty_revenue": _daily_warranty_revenue,
		"daily_claim_costs": _daily_claim_costs,
	}


## Restores warranty state from saved data.
func load_save_data(data: Dictionary) -> void:
	_active_warranties = []
	var saved_active: Array = data.get("active_warranties", [])
	for entry: Variant in saved_active:
		if entry is Dictionary:
			_active_warranties.append(entry as Dictionary)
	_claim_history = []
	var saved_claims: Array = data.get("claim_history", [])
	for entry: Variant in saved_claims:
		if entry is Dictionary:
			_claim_history.append(entry as Dictionary)
	_daily_warranty_revenue = float(
		data.get("daily_warranty_revenue", 0.0)
	)
	_daily_claim_costs = float(
		data.get("daily_claim_costs", 0.0)
	)
