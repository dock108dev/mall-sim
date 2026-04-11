## Tracks store reputation, affecting customer flow via tier multipliers.
class_name ReputationSystem
extends Node

enum Tier {
	UNKNOWN,
	LOCAL_FAVORITE,
	DESTINATION_SHOP,
	LEGENDARY,
}

const TIER_THRESHOLDS: Dictionary = {
	Tier.UNKNOWN: 0.0,
	Tier.LOCAL_FAVORITE: 25.0,
	Tier.DESTINATION_SHOP: 50.0,
	Tier.LEGENDARY: 80.0,
}

const TIER_MULTIPLIERS: Dictionary = {
	Tier.UNKNOWN: 1.0,
	Tier.LOCAL_FAVORITE: 1.5,
	Tier.DESTINATION_SHOP: 2.0,
	Tier.LEGENDARY: 3.0,
}

const BUDGET_MULTIPLIERS: Dictionary = {
	Tier.UNKNOWN: 1.0,
	Tier.LOCAL_FAVORITE: 1.2,
	Tier.DESTINATION_SHOP: 1.5,
	Tier.LEGENDARY: 2.0,
}

## Tier-scaled customer caps for small stores (map Tier -> max count).
const MAX_CUSTOMERS_BY_TIER_SMALL: Dictionary = {
	Tier.UNKNOWN: 5,
	Tier.LOCAL_FAVORITE: 6,
	Tier.DESTINATION_SHOP: 8,
	Tier.LEGENDARY: 10,
}

## Tier-scaled customer caps for medium/large stores (map Tier -> max count).
const MAX_CUSTOMERS_BY_TIER_MEDIUM: Dictionary = {
	Tier.UNKNOWN: 8,
	Tier.LOCAL_FAVORITE: 10,
	Tier.DESTINATION_SHOP: 12,
	Tier.LEGENDARY: 15,
}

const MAX_REPUTATION: float = 100.0
const MIN_REPUTATION: float = 0.0
const DAILY_DECAY: float = 0.3

const REP_SALE_MIN: float = 1.0
const REP_SALE_MAX: float = 3.0
const REP_FAIR_SALE: float = 2.5
const REP_NO_PURCHASE: float = -0.5
const REP_PATIENCE_EXPIRED: float = -1.5
const REP_OVERPRICED_REJECTED: float = -1.0

## How close to market value counts as "fair" (within 25%).
const FAIR_PRICE_THRESHOLD: float = 0.25

var _score: float = 0.0
var _current_tier: Tier = Tier.UNKNOWN
var _had_positive_event_today: bool = false
## Tracks how many customers bought but haven't left yet.
var _pending_buyer_exits: int = 0


func initialize() -> void:
	_score = 0.0
	_current_tier = Tier.UNKNOWN
	_had_positive_event_today = false
	_pending_buyer_exits = 0
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.customer_left.connect(_on_customer_left)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.day_started.connect(_on_day_started)


## Returns the current reputation score.
func get_reputation(_store_id: String = "") -> float:
	return _score


## Returns the current tier enum value.
func get_tier() -> Tier:
	return _current_tier


## Returns the customer spawn multiplier for the current tier.
func get_customer_multiplier() -> float:
	return TIER_MULTIPLIERS.get(_current_tier, 1.0)


## Returns the budget multiplier for the current reputation tier.
func get_budget_multiplier() -> float:
	return BUDGET_MULTIPLIERS.get(_current_tier, 1.0)


## Returns the max customer count for the current tier and store size.
func get_max_customers(size_category: String) -> int:
	if size_category == "medium" or size_category == "large":
		return MAX_CUSTOMERS_BY_TIER_MEDIUM.get(_current_tier, 8) as int
	return MAX_CUSTOMERS_BY_TIER_SMALL.get(_current_tier, 5) as int


## Returns a human-readable tier name.
func get_tier_name() -> String:
	match _current_tier:
		Tier.UNKNOWN:
			return "Unknown"
		Tier.LOCAL_FAVORITE:
			return "Local Favorite"
		Tier.DESTINATION_SHOP:
			return "Destination Shop"
		Tier.LEGENDARY:
			return "Legendary"
	return "Unknown"


## Modifies reputation by delta, clamped to 0-100.
func modify_reputation(
	_store_id: String, delta: float
) -> void:
	var old_score: float = _score
	_score = clampf(
		_score + delta, MIN_REPUTATION, MAX_REPUTATION
	)
	if delta > 0.0:
		_had_positive_event_today = true
	if not is_equal_approx(old_score, _score):
		_update_tier()
		EventBus.reputation_changed.emit(old_score, _score)


## Serializes reputation state for saving.
func get_save_data() -> Dictionary:
	return {
		"score": _score,
		"tier": _current_tier,
		"had_positive_event_today": _had_positive_event_today,
	}


## Restores reputation state from saved data.
func load_save_data(data: Dictionary) -> void:
	_score = clampf(
		data.get("score", 0.0) as float,
		MIN_REPUTATION, MAX_REPUTATION
	)
	_had_positive_event_today = data.get(
		"had_positive_event_today", false
	) as bool
	_update_tier()


func _update_tier() -> void:
	var new_tier: Tier = Tier.UNKNOWN
	if _score >= TIER_THRESHOLDS[Tier.LEGENDARY]:
		new_tier = Tier.LEGENDARY
	elif _score >= TIER_THRESHOLDS[Tier.DESTINATION_SHOP]:
		new_tier = Tier.DESTINATION_SHOP
	elif _score >= TIER_THRESHOLDS[Tier.LOCAL_FAVORITE]:
		new_tier = Tier.LOCAL_FAVORITE
	_current_tier = new_tier


func _on_item_sold(
	_item_id: String, price: float, _category: String
) -> void:
	_pending_buyer_exits += 1
	_add_sale_reputation(price)


func _on_customer_left(customer_data: Dictionary) -> void:
	if _pending_buyer_exits > 0:
		_pending_buyer_exits -= 1
		return
	var store_id: String = customer_data.get("store_id", "") as String
	modify_reputation(store_id, REP_NO_PURCHASE)


func _on_day_ended(_day: int) -> void:
	if not _had_positive_event_today:
		modify_reputation("", -DAILY_DECAY)


func _on_day_started(_day: int) -> void:
	_had_positive_event_today = false


## Calculates rep gain from a sale based on pricing fairness.
func _add_sale_reputation(sale_price: float) -> void:
	if sale_price <= 0.0:
		return
	# Fair sales get +2, others get +1 to +3 based on fairness
	# Without market value context, default to fair sale bonus
	modify_reputation("", REP_FAIR_SALE)
