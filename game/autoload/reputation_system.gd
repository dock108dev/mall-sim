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
	ReputationTier.UNREMARKABLE: 25.0,
	ReputationTier.REPUTABLE: 50.0,
	ReputationTier.LEGENDARY: 80.0,
}

const BUDGET_MULTIPLIERS: Dictionary = {
	ReputationTier.NOTORIOUS: 1.0,
	ReputationTier.UNREMARKABLE: 1.2,
	ReputationTier.REPUTABLE: 1.5,
	ReputationTier.LEGENDARY: 2.0,
}

const CUSTOMER_MULTIPLIERS: Dictionary = {
	ReputationTier.NOTORIOUS: 1.0,
	ReputationTier.UNREMARKABLE: 1.2,
	ReputationTier.REPUTABLE: 1.5,
	ReputationTier.LEGENDARY: 2.0,
}

const MAX_CUSTOMERS_BY_TIER_SMALL: Dictionary = {
	ReputationTier.NOTORIOUS: 5,
	ReputationTier.UNREMARKABLE: 6,
	ReputationTier.REPUTABLE: 8,
	ReputationTier.LEGENDARY: 10,
}

const MAX_CUSTOMERS_BY_TIER_MEDIUM: Dictionary = {
	ReputationTier.NOTORIOUS: 8,
	ReputationTier.UNREMARKABLE: 10,
	ReputationTier.REPUTABLE: 12,
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
const DEFAULT_EVENT_STORE_ID: String = "default"

var _scores: Dictionary = {}
var _tiers: Dictionary = {}
var _tier_locks: Dictionary = {}
var _pending_buyer_exits: Dictionary = {}
var _price_ratios_by_item: Dictionary = {}
var _sale_reputation_applied_items: Dictionary = {}
var _owned_store_ids: Array[String] = []
## Set to false before add_child() in tests to prevent EventBus auto-connections.
var auto_connect_bus: bool = true


func _ready() -> void:
	if not auto_connect_bus:
		return
	_connect_bus_signals()


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
	_tier_locks.erase(sid)
	if not is_equal_approx(old_score, new_score):
		EventBus.reputation_changed.emit(sid, new_score)
	if new_tier != old_tier:
		_emit_tier_change_toast(sid, old_tier, new_tier)


## Applies an event magnitude to reputation using deferred downgrade semantics.
func add_reputation_event(
	_event_id: String, magnitude: float, store_id: String = ""
) -> void:
	var sid: String = _resolve_event_store_id(store_id)
	var old_score: float = _scores.get(sid, 0.0) as float
	var old_tier: ReputationTier = _tier_locks.get(
		sid, _score_to_tier(old_score)
	)
	var new_score: float = clampf(
		old_score + magnitude, MIN_REPUTATION, MAX_REPUTATION
	)
	_scores[sid] = new_score
	var score_tier: ReputationTier = _score_to_tier(new_score)
	if score_tier > old_tier:
		_tiers[sid] = score_tier
		_tier_locks[sid] = score_tier
		EventBus.reputation_tier_changed.emit(
			sid, int(old_tier), int(score_tier)
		)
	elif sid not in _tiers:
		_tiers[sid] = old_tier
	if not is_equal_approx(old_score, new_score):
		EventBus.reputation_changed.emit(sid, new_score)


func get_tier(store_id: String = "") -> ReputationTier:
	var score: float = get_reputation(store_id)
	var sid: String = _resolve_event_store_id(store_id)
	var score_tier: ReputationTier = _score_to_tier(score)
	if sid in _tier_locks:
		var locked_tier: ReputationTier = _tier_locks[sid] as ReputationTier
		if locked_tier > score_tier:
			return locked_tier
	return score_tier


func get_global_reputation() -> float:
	if _scores.is_empty():
		return DEFAULT_REPUTATION
	if not _owned_store_ids.is_empty():
		return _get_owned_store_average()
	if not GameManager.owned_stores.is_empty():
		var owned_store_ids: Array[String] = []
		for store_id: StringName in GameManager.owned_stores:
			owned_store_ids.append(String(store_id))
		return _get_store_average(owned_store_ids)
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


func get_global_customer_multiplier() -> float:
	var global_tier: ReputationTier = _score_to_tier(get_global_reputation())
	return CUSTOMER_MULTIPLIERS.get(global_tier, 1.0) as float


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
		"tiers": _tiers.duplicate(),
		"tier_locks": _tier_locks.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	_scores.clear()
	_tiers.clear()
	_tier_locks.clear()
	_pending_buyer_exits.clear()
	_price_ratios_by_item.clear()
	_sale_reputation_applied_items.clear()
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
	var tier_locks_data: Variant = data.get("tier_locks", {})
	if tier_locks_data is Dictionary:
		for key: Variant in tier_locks_data:
			var sid: String = str(key)
			if sid not in _scores:
				continue
			var score_tier: ReputationTier = _score_to_tier(
				_scores[sid] as float
			)
			var saved_tier: int = int(tier_locks_data[key])
			var score_tier_value: int = int(score_tier)
			_tier_locks[sid] = (
				saved_tier if saved_tier > score_tier_value
				else score_tier_value
			)


## Restores saved reputation data; alias for save/load API consistency.
func load_state(data: Dictionary) -> void:
	load_save_data(data)


func reset() -> void:
	_scores.clear()
	_tiers.clear()
	_tier_locks.clear()
	_pending_buyer_exits.clear()
	_price_ratios_by_item.clear()
	_sale_reputation_applied_items.clear()
	_owned_store_ids.clear()


func _connect_bus_signals() -> void:
	_connect_signal(EventBus.item_sold, _on_item_sold)
	_connect_signal(EventBus.item_price_set, _on_item_price_set)
	_connect_signal(EventBus.customer_purchased, _on_customer_purchased)
	_connect_signal(EventBus.customer_left, _on_customer_left)
	_connect_signal(EventBus.customer_left_mall, _on_customer_left_mall)
	_connect_signal(EventBus.day_ended, _on_day_ended)
	_connect_signal(EventBus.haggle_completed, _on_haggle_completed)
	_connect_signal(EventBus.haggle_failed, _on_haggle_failed)
	_connect_signal(EventBus.lease_completed, _on_lease_completed)
	_connect_signal(EventBus.owned_slots_restored, _on_owned_slots_restored)


func _connect_signal(signal_ref: Signal, callable: Callable) -> void:
	if not signal_ref.is_connected(callable):
		signal_ref.connect(callable)


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
	if not ContentRegistry.exists(store_id):
		return store_id
	var canonical: StringName = ContentRegistry.resolve(store_id)
	if canonical.is_empty():
		return store_id
	return ContentRegistry.get_display_name(canonical)


func _tier_to_name(tier: ReputationTier) -> String:
	match tier:
		ReputationTier.NOTORIOUS:
			return "Unknown"
		ReputationTier.UNREMARKABLE:
			return "Local Favorite"
		ReputationTier.REPUTABLE:
			return "Destination Shop"
		ReputationTier.LEGENDARY:
			return "Legendary"
	return "Unknown"


func _resolve_store_id(store_id: String) -> String:
	if not store_id.is_empty():
		if ContentRegistry.exists(store_id):
			var canonical: StringName = ContentRegistry.resolve(store_id)
			if not canonical.is_empty():
				return String(canonical)
		return store_id
	var active: StringName = GameManager.current_store_id
	if not active.is_empty():
		return String(active)
	return ""


func _resolve_event_store_id(store_id: String) -> String:
	var sid: String = _resolve_store_id(store_id)
	if sid.is_empty():
		return DEFAULT_EVENT_STORE_ID
	return sid


func _score_to_tier(score: float) -> ReputationTier:
	if score >= TIER_THRESHOLDS[ReputationTier.LEGENDARY]:
		return ReputationTier.LEGENDARY
	if score >= TIER_THRESHOLDS[ReputationTier.REPUTABLE]:
		return ReputationTier.REPUTABLE
	if score >= TIER_THRESHOLDS[ReputationTier.UNREMARKABLE]:
		return ReputationTier.UNREMARKABLE
	return ReputationTier.NOTORIOUS


func _get_owned_store_average() -> float:
	return _get_store_average(_owned_store_ids)


func _get_store_average(store_ids: Array[String]) -> float:
	var total: float = 0.0
	var count: int = 0
	for sid: String in store_ids:
		total += _scores.get(sid, DEFAULT_REPUTATION) as float
		count += 1
	if count == 0:
		return DEFAULT_REPUTATION
	return total / float(count)


func _remember_owned_store(store_id: String) -> void:
	var sid: String = _resolve_store_id(store_id)
	if sid.is_empty():
		return
	initialize_store(sid)
	if sid not in _owned_store_ids:
		_owned_store_ids.append(sid)


func _mark_purchase_for_exit(store_id: String) -> void:
	var count: int = _pending_buyer_exits.get(store_id, 0) as int
	_pending_buyer_exits[store_id] = count + 1


func _get_sale_reputation_delta(item_id: String) -> float:
	var ratio: float = _price_ratios_by_item.get(item_id, 0.0) as float
	if ratio <= 0.0:
		return REP_FAIR_SALE
	if ratio >= FAIR_MARKUP_MIN and ratio <= FAIR_MARKUP_MAX:
		return REP_FAIR_SALE
	if ratio > OVERPRICED_THRESHOLD:
		return REP_OVERPRICED_SALE
	return 0.0


func _apply_sale_reputation(
	store_id: String, item_id: String
) -> void:
	if item_id in _sale_reputation_applied_items:
		return
	_sale_reputation_applied_items[item_id] = true
	_mark_purchase_for_exit(store_id)
	var delta: float = _get_sale_reputation_delta(item_id)
	if is_zero_approx(delta):
		return
	add_reputation(store_id, delta)


func _on_item_price_set(
	store_id: StringName, item_id: StringName, _price: float, ratio: float
) -> void:
	if String(item_id).is_empty() or ratio <= 0.0:
		return
	_price_ratios_by_item[String(item_id)] = ratio
	if not String(store_id).is_empty():
		_remember_owned_store(String(store_id))


func _on_item_sold(
	_item_id: String, _price: float, _category: String
) -> void:
	var sid: String = _resolve_store_id("")
	if sid.is_empty():
		return
	_apply_sale_reputation(sid, _item_id)


func _on_customer_purchased(
	store_id: StringName, item_id: StringName,
	_price: float, _customer_id: StringName
) -> void:
	var sid: String = _resolve_store_id(String(store_id))
	if sid.is_empty():
		return
	_remember_owned_store(sid)
	_apply_sale_reputation(sid, String(item_id))


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
	_sale_reputation_applied_items.clear()


func _on_haggle_completed(
	store_id: StringName, _item_id: StringName,
	_final_price: float, _asking_price: float,
	accepted: bool, _offer_count: int
) -> void:
	var sid: String = _resolve_store_id(String(store_id))
	if sid.is_empty():
		return
	var delta: float = REP_HAGGLE_ACCEPTED if accepted else REP_HAGGLE_REJECTED
	add_reputation(sid, delta)


func _on_haggle_failed(
	_item_id: String, _customer_id: int
) -> void:
	var sid: String = _resolve_store_id("")
	if sid.is_empty():
		return
	add_reputation(sid, REP_HAGGLE_REJECTED)


func _on_lease_completed(
	store_id: StringName, success: bool, _message: String
) -> void:
	if not success:
		return
	_remember_owned_store(String(store_id))


func _on_owned_slots_restored(slots: Dictionary) -> void:
	_owned_store_ids.clear()
	for key: Variant in slots:
		_remember_owned_store(str(slots[key]))
