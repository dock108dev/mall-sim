## Per-store reputation tracking with tier thresholds and daily decay.
class_name ReputationSystem
extends Node

enum ReputationTier {
	NOTORIOUS,
	UNREMARKABLE,
	REPUTABLE,
	LEGENDARY,
}

const TIER_THRESHOLDS: Dictionary = {
	ReputationTier.NOTORIOUS: 0.0,
	ReputationTier.UNREMARKABLE: 26.0,
	ReputationTier.REPUTABLE: 51.0,
	ReputationTier.LEGENDARY: 76.0,
}

const BUDGET_MULTIPLIERS: Dictionary = {
	ReputationTier.NOTORIOUS: 0.8,
	ReputationTier.UNREMARKABLE: 1.0,
	ReputationTier.REPUTABLE: 1.3,
	ReputationTier.LEGENDARY: 2.0,
}

const CUSTOMER_MULTIPLIERS: Dictionary = {
	ReputationTier.NOTORIOUS: 0.7,
	ReputationTier.UNREMARKABLE: 1.0,
	ReputationTier.REPUTABLE: 1.5,
	ReputationTier.LEGENDARY: 2.5,
}

const MAX_CUSTOMERS_BY_TIER_SMALL: Dictionary = {
	ReputationTier.NOTORIOUS: 3,
	ReputationTier.UNREMARKABLE: 5,
	ReputationTier.REPUTABLE: 7,
	ReputationTier.LEGENDARY: 10,
}

const MAX_CUSTOMERS_BY_TIER_MEDIUM: Dictionary = {
	ReputationTier.NOTORIOUS: 5,
	ReputationTier.UNREMARKABLE: 8,
	ReputationTier.REPUTABLE: 11,
	ReputationTier.LEGENDARY: 15,
}

const MAX_REPUTATION: float = 100.0
const MIN_REPUTATION: float = 0.0
const DEFAULT_REPUTATION: float = 50.0
const DAILY_DECAY: float = 0.3
const DECAY_FLOOR: float = 50.0

const REP_FAIR_SALE: float = 2.5
const REP_OVERPRICED_SALE: float = 0.5
const REP_HAGGLE_ACCEPTED: float = 1.5
const REP_HAGGLE_REJECTED: float = -0.5
const REP_NO_PURCHASE: float = -0.5

const SATISFACTION_GAIN: float = 1.5
const DISSATISFACTION_LOSS: float = -2.0

const REP_PATIENCE_EXPIRED: float = -1.5
const REP_OVERPRICED_REJECTED: float = -1.0
const FAIR_PRICE_THRESHOLD: float = 0.25
const FAIR_MARKUP_MIN: float = 1.2
const FAIR_MARKUP_MAX: float = 1.5
const OVERPRICED_THRESHOLD: float = 1.8

var _scores: Dictionary = {}
var _tiers: Dictionary = {}
var _pending_buyer_exits: Dictionary = {}
## Set to false before add_child() in tests to prevent EventBus auto-connections.
var auto_connect_bus: bool = true


func _ready() -> void:
	if not auto_connect_bus:
		return
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.customer_left.connect(_on_customer_left)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.haggle_completed.connect(_on_haggle_completed)
	EventBus.haggle_failed.connect(_on_haggle_failed)
	EventBus.customer_left_mall.connect(_on_customer_left_mall)


func get_reputation(store_id: String = "") -> float:
	var sid: String = _resolve_store_id(store_id)
	if sid.is_empty():
		return DEFAULT_REPUTATION
	return _scores.get(sid, DEFAULT_REPUTATION) as float


func add_reputation(store_id: String, delta: float) -> void:
	var sid: String = _resolve_store_id(store_id)
	if sid.is_empty():
		return
	var old_score: float = _scores.get(sid, DEFAULT_REPUTATION) as float
	var old_tier: ReputationTier = _tiers.get(sid, _score_to_tier(old_score))
	var new_score: float = clampf(
		old_score + delta, MIN_REPUTATION, MAX_REPUTATION
	)
	_scores[sid] = new_score
	var new_tier: ReputationTier = _score_to_tier(new_score)
	_tiers[sid] = new_tier
	if not is_equal_approx(old_score, new_score):
		EventBus.reputation_changed.emit(sid, new_score)
	if new_tier != old_tier:
		_emit_tier_change_toast(sid, old_tier, new_tier)


func get_tier(store_id: String = "") -> ReputationTier:
	var score: float = get_reputation(store_id)
	return _score_to_tier(score)


func get_global_reputation() -> float:
	if _scores.is_empty():
		return DEFAULT_REPUTATION
	var total: float = 0.0
	var count: int = 0
	for sid: String in _scores:
		total += _scores[sid] as float
		count += 1
	if count == 0:
		return DEFAULT_REPUTATION
	return total / float(count)


func get_tier_name(store_id: String = "") -> String:
	return _tier_to_name(get_tier(store_id))


func get_budget_multiplier(store_id: String = "") -> float:
	var tier: ReputationTier = get_tier(store_id)
	return BUDGET_MULTIPLIERS.get(tier, 1.0) as float


func get_customer_multiplier(store_id: String = "") -> float:
	var tier: ReputationTier = get_tier(store_id)
	return CUSTOMER_MULTIPLIERS.get(tier, 1.0) as float


func get_max_customers(
	size_category: String, store_id: String = ""
) -> int:
	var tier: ReputationTier = get_tier(store_id)
	if size_category == "medium" or size_category == "large":
		return MAX_CUSTOMERS_BY_TIER_MEDIUM.get(tier, 8) as int
	return MAX_CUSTOMERS_BY_TIER_SMALL.get(tier, 5) as int


## Alias for add_reputation to maintain backward compatibility.
func modify_reputation(store_id: String, delta: float) -> void:
	add_reputation(store_id, delta)


func initialize_store(store_id: String) -> void:
	var sid: String = _resolve_store_id(store_id)
	if sid.is_empty():
		return
	if sid not in _scores:
		_scores[sid] = DEFAULT_REPUTATION
		_tiers[sid] = _score_to_tier(DEFAULT_REPUTATION)


func get_save_data() -> Dictionary:
	return {
		"scores": _scores.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	_scores.clear()
	_tiers.clear()
	_pending_buyer_exits.clear()
	var scores_data: Variant = data.get("scores", {})
	if scores_data is Dictionary:
		for key: Variant in scores_data:
			var sid: String = str(key)
			_scores[sid] = clampf(
				float(scores_data[key]),
				MIN_REPUTATION, MAX_REPUTATION
			)
	elif data.has("score"):
		var active: String = String(GameManager.current_store_id)
		if active.is_empty():
			active = "default"
		_scores[active] = clampf(
			float(data["score"]), MIN_REPUTATION, MAX_REPUTATION
		)
	for sid: String in _scores:
		_tiers[sid] = _score_to_tier(_scores[sid] as float)


func reset() -> void:
	_scores.clear()
	_tiers.clear()
	_pending_buyer_exits.clear()


func _emit_tier_change_toast(
	store_id: String, old_tier: ReputationTier, new_tier: ReputationTier
) -> void:
	var store_display: String = _get_store_display_name(store_id)
	var tier_name: String = _tier_to_name(new_tier)
	var is_upgrade: bool = new_tier > old_tier
	if is_upgrade:
		var msg: String = "%s reputation up: now %s" % [
			store_display, tier_name
		]
		EventBus.toast_requested.emit(msg, &"reputation_up", 4.0)
	else:
		var msg: String = "%s reputation dropped to %s" % [
			store_display, tier_name
		]
		EventBus.toast_requested.emit(msg, &"reputation_down", 5.0)


func _get_store_display_name(store_id: String) -> String:
	var canonical: StringName = ContentRegistry.resolve(store_id)
	if canonical.is_empty():
		return store_id
	return ContentRegistry.get_display_name(canonical)


func _tier_to_name(tier: ReputationTier) -> String:
	match tier:
		ReputationTier.NOTORIOUS:
			return "Notorious"
		ReputationTier.UNREMARKABLE:
			return "Unremarkable"
		ReputationTier.REPUTABLE:
			return "Reputable"
		ReputationTier.LEGENDARY:
			return "Legendary"
	return "Unremarkable"


func _resolve_store_id(store_id: String) -> String:
	if not store_id.is_empty():
		return store_id
	var active: StringName = GameManager.current_store_id
	if not active.is_empty():
		return String(active)
	return ""


func _score_to_tier(score: float) -> ReputationTier:
	if score >= TIER_THRESHOLDS[ReputationTier.LEGENDARY]:
		return ReputationTier.LEGENDARY
	if score >= TIER_THRESHOLDS[ReputationTier.REPUTABLE]:
		return ReputationTier.REPUTABLE
	if score >= TIER_THRESHOLDS[ReputationTier.UNREMARKABLE]:
		return ReputationTier.UNREMARKABLE
	return ReputationTier.NOTORIOUS


func _on_item_sold(
	_item_id: String, _price: float, _category: String
) -> void:
	var sid: String = _resolve_store_id("")
	if sid.is_empty():
		return
	var count: int = _pending_buyer_exits.get(sid, 0) as int
	_pending_buyer_exits[sid] = count + 1
	add_reputation(sid, REP_FAIR_SALE)


func _on_customer_left(customer_data: Dictionary) -> void:
	var sid: String = customer_data.get("store_id", "") as String
	if sid.is_empty():
		sid = _resolve_store_id("")
	if sid.is_empty():
		return
	var count: int = _pending_buyer_exits.get(sid, 0) as int
	if count > 0:
		_pending_buyer_exits[sid] = count - 1
		return
	add_reputation(sid, REP_NO_PURCHASE)


func _on_customer_left_mall(
	_customer: Node, satisfied: bool
) -> void:
	var sid: String = _resolve_store_id("")
	if sid.is_empty():
		return
	var delta: float = SATISFACTION_GAIN if satisfied else DISSATISFACTION_LOSS
	add_reputation(sid, delta)


func _on_day_ended(_day: int) -> void:
	for sid: String in _scores:
		var score: float = _scores[sid] as float
		if score > DECAY_FLOOR:
			add_reputation(sid, -DAILY_DECAY)
	_pending_buyer_exits.clear()


func _on_haggle_completed(
	_store_id: StringName, _item_id: StringName,
	_final_price: float, _asking_price: float,
	_accepted: bool, _offer_count: int
) -> void:
	var sid: String = _resolve_store_id("")
	if sid.is_empty():
		return
	add_reputation(sid, REP_HAGGLE_ACCEPTED)


func _on_haggle_failed(
	_item_id: String, _customer_id: int
) -> void:
	var sid: String = _resolve_store_id("")
	if sid.is_empty():
		return
	add_reputation(sid, REP_HAGGLE_REJECTED)
