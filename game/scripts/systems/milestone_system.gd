## EventBus-driven milestone state and unlock evaluation system.
class_name MilestoneSystem
extends Node


const PRICING_STREAK_MIN_RATIO := 1.2
const PRICING_STREAK_MAX_RATIO := 1.5

var _milestones: Array[MilestoneDefinition] = []
var _completed: Dictionary = {}
var _counters: Dictionary = {}
var _unique_stores_seen: Dictionary = {}


func initialize() -> void:
	_init_counters()
	_load_milestones()
	_connect_signals()


func is_complete(milestone_id: StringName) -> bool:
	return _completed.has(milestone_id)


func get_completed_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key: StringName in _completed:
		result.append(key)
	return result


func get_completion_percent() -> float:
	if _milestones.is_empty():
		return 0.0
	var visible_total: int = 0
	var visible_completed: int = 0
	for m: MilestoneDefinition in _milestones:
		if not m.is_visible:
			continue
		visible_total += 1
		if _completed.has(StringName(m.id)):
			visible_completed += 1
	if visible_total == 0:
		return 0.0
	return float(visible_completed) / float(visible_total)


func get_save_data() -> Dictionary:
	var completed_list: Array[String] = []
	for key: StringName in _completed:
		completed_list.append(String(key))
	var stores_list: Array[String] = []
	for key: StringName in _unique_stores_seen:
		stores_list.append(String(key))
	return {
		"completed": completed_list,
		"counters": _counters.duplicate(),
		"unique_stores_seen": stores_list,
	}


func load_state(data: Dictionary) -> void:
	_init_counters()
	_completed = {}
	var saved_completed: Variant = data.get("completed", [])
	if saved_completed is Array:
		for entry: Variant in saved_completed:
			_completed[StringName(str(entry))] = true

	var saved_counters: Variant = data.get("counters", {})
	if saved_counters is Dictionary:
		for key: String in saved_counters:
			if _counters.has(key):
				_counters[key] = saved_counters[key]

	_unique_stores_seen = {}
	var saved_stores: Variant = data.get("unique_stores_seen", [])
	if saved_stores is Array:
		for entry: Variant in saved_stores:
			_unique_stores_seen[StringName(str(entry))] = true
	_counters["unique_store_types_entered"] = _unique_stores_seen.size()


func _init_counters() -> void:
	_counters = {
		"cumulative_revenue": 0.0,
		"customer_purchased_count": 0,
		"satisfied_customer_count": 0,
		"owned_store_count": 0,
		"unique_store_types_entered": 0,
		"max_reputation_tier_seen": 0,
		"single_day_revenue": 0.0,
		"haggle_max_price_ratio": 0.0,
		"rare_items_sold": 0,
		"pricing_streak_in_range": 0,
		"market_crash_survived": 0,
		"current_day": 0,
		"max_reputation_score": 0.0,
	}
	_unique_stores_seen = {}


func _load_milestones() -> void:
	var all_defs: Array[MilestoneDefinition] = (
		GameManager.data_loader.get_all_milestones()
	)
	_milestones = all_defs


func _connect_signals() -> void:
	EventBus.transaction_completed.connect(
		_on_transaction_completed
	)
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.customer_left.connect(_on_customer_left)
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.store_leased.connect(_on_store_leased)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.haggle_completed.connect(_on_haggle_completed)
	EventBus.item_price_set.connect(_on_item_price_set)
	EventBus.random_event_resolved.connect(
		_on_random_event_resolved
	)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.milestone_unlocked.connect(_on_milestone_unlocked)


func _on_milestone_unlocked(
	milestone_id: StringName, _reward: Dictionary
) -> void:
	var display_name: String = ContentRegistry.get_display_name(
		milestone_id
	)
	EventBus.toast_requested.emit(
		"Milestone reached: %s" % display_name, &"milestone", 4.0
	)


func _on_transaction_completed(
	amount: float, success: bool, _message: String
) -> void:
	if not success or amount <= 0.0:
		return
	_counters["cumulative_revenue"] = (
		float(_counters["cumulative_revenue"]) + amount
	)
	_counters["single_day_revenue"] = (
		float(_counters["single_day_revenue"]) + amount
	)
	_evaluate_by_condition("cumulative_revenue")
	_evaluate_by_condition("single_day_revenue")
	_evaluate_by_condition("revenue")


func _on_customer_purchased(
	_store_id: StringName, _item_id: StringName,
	_price: float, _customer_id: StringName
) -> void:
	_counters["customer_purchased_count"] = (
		int(_counters["customer_purchased_count"]) + 1
	)
	_evaluate_by_condition("customer_purchased_count")
	_evaluate_by_condition("items_sold")


func _on_customer_left(customer_data: Dictionary) -> void:
	var satisfied: bool = customer_data.get("satisfied", false)
	if satisfied:
		_counters["satisfied_customer_count"] = (
			int(_counters["satisfied_customer_count"]) + 1
		)
		_evaluate_by_condition("satisfied_customer_count")


func _on_day_started(_day: int) -> void:
	_counters["single_day_revenue"] = 0.0


func _on_day_ended(day: int) -> void:
	_counters["current_day"] = day
	_evaluate_by_condition("days")
	_evaluate_by_condition("single_day_revenue")


func _on_store_leased(
	_slot_index: int, _store_type: String
) -> void:
	_counters["owned_store_count"] = (
		int(_counters["owned_store_count"]) + 1
	)
	_evaluate_by_condition("owned_store_count")


func _on_reputation_changed(
	_store_id: String, _old_score: float, new_score: float
) -> void:
	var tier: int = _score_to_tier(new_score)
	if tier > int(_counters["max_reputation_tier_seen"]):
		_counters["max_reputation_tier_seen"] = tier
	if new_score > float(_counters["max_reputation_score"]):
		_counters["max_reputation_score"] = new_score
	_evaluate_by_condition("max_reputation_tier_seen")
	_evaluate_by_condition("reputation")


func _on_store_entered(store_id: StringName) -> void:
	if not _unique_stores_seen.has(store_id):
		_unique_stores_seen[store_id] = true
		_counters["unique_store_types_entered"] = (
			_unique_stores_seen.size()
		)
		_evaluate_by_condition("unique_store_types_entered")


func _on_haggle_completed(
	_store_id: StringName, _item_id: StringName,
	final_price: float, asking_price: float,
	accepted: bool, _offer_count: int
) -> void:
	if not accepted or asking_price <= 0.0:
		return
	var ratio: float = final_price / asking_price
	if ratio > float(_counters["haggle_max_price_ratio"]):
		_counters["haggle_max_price_ratio"] = ratio
		_evaluate_by_condition("haggle_max_price_ratio")


func _on_item_price_set(
	_store_id: StringName, _item_id: StringName,
	_price: float, ratio: float
) -> void:
	if ratio >= PRICING_STREAK_MIN_RATIO and (
		ratio <= PRICING_STREAK_MAX_RATIO
	):
		_counters["pricing_streak_in_range"] = (
			int(_counters["pricing_streak_in_range"]) + 1
		)
	else:
		_counters["pricing_streak_in_range"] = 0
	_evaluate_by_condition("pricing_streak_in_range")


func _on_random_event_resolved(
	event_id: StringName, outcome: StringName
) -> void:
	if "crash" in String(event_id) and outcome == &"survived":
		_counters["market_crash_survived"] = 1
		_evaluate_by_condition("market_crash_survived")


func _on_item_sold(
	item_id: String, _price: float, _category: String
) -> void:
	var entry: Dictionary = ContentRegistry.get_entry(
		StringName(item_id)
	)
	var rarity: String = str(entry.get("rarity", "common"))
	if rarity == "rare" or rarity == "legendary":
		_counters["rare_items_sold"] = (
			int(_counters["rare_items_sold"]) + 1
		)
		_evaluate_by_condition("rare_items_sold")


func _evaluate_by_condition(condition_type: String) -> void:
	for m: MilestoneDefinition in _milestones:
		var mid: StringName = StringName(m.id)
		if _completed.has(mid):
			continue
		var stat_key: String = m.trigger_stat_key
		if stat_key.is_empty():
			stat_key = m.trigger_type
		if stat_key != condition_type:
			if not _is_alias_match(stat_key, condition_type):
				continue
		var current: float = _get_counter_value(stat_key)
		if current >= m.trigger_threshold:
			_complete_milestone(m)


func _is_alias_match(
	stat_key: String, condition_type: String
) -> bool:
	match condition_type:
		"revenue":
			return stat_key == "cumulative_revenue"
		"items_sold":
			return stat_key == "customer_purchased_count"
		"days":
			return stat_key == "current_day"
		"reputation":
			return (
				stat_key == "max_reputation_tier_seen"
				or stat_key == "max_reputation_score"
			)
	return false


func _get_counter_value(stat_key: String) -> float:
	if _counters.has(stat_key):
		return float(_counters[stat_key])
	match stat_key:
		"revenue":
			return float(_counters["cumulative_revenue"])
		"items_sold":
			return float(
				_counters["customer_purchased_count"]
			)
		"days":
			return float(_counters["current_day"])
		"reputation":
			return float(
				_counters["max_reputation_score"]
			)
	return 0.0


func _complete_milestone(milestone: MilestoneDefinition) -> void:
	var mid: StringName = StringName(milestone.id)
	_completed[mid] = true
	_apply_reward(milestone)
	var reward: Dictionary = {
		"reward_type": milestone.reward_type,
		"reward_value": milestone.reward_value,
		"unlock_id": milestone.unlock_id,
	}
	EventBus.milestone_unlocked.emit(mid, reward)
	EventBus.milestone_completed.emit(
		milestone.id, milestone.display_name,
		_build_reward_description(milestone)
	)


func _apply_reward(milestone: MilestoneDefinition) -> void:
	match milestone.reward_type:
		"cash", "cash_bonus":
			pass  # EconomySystem credits cash via milestone_unlocked listener.
		"reputation":
			EventBus.milestone_reputation_reward.emit(
				StringName(milestone.id),
				int(milestone.reward_value)
			)
		"unlock", "fixture_unlock":
			if not milestone.unlock_id.is_empty():
				EventBus.milestone_unlock_granted.emit(
					StringName(milestone.unlock_id)
				)
		"store_slot":
			EventBus.store_slot_unlocked.emit(
				int(milestone.reward_value)
			)
		"supplier_tier":
			EventBus.supplier_tier_changed.emit(
				-1, int(milestone.reward_value)
			)


func _build_reward_description(
	milestone: MilestoneDefinition,
) -> String:
	match milestone.reward_type:
		"cash":
			return "Bonus: $%d cash" % int(milestone.reward_value)
		"reputation":
			return "+%d reputation" % int(milestone.reward_value)
		"unlock":
			return "Unlocked: %s" % milestone.unlock_id
	return ""


func _score_to_tier(score: float) -> int:
	if score >= 80.0:
		return 4
	if score >= 50.0:
		return 3
	if score >= 25.0:
		return 2
	if score >= 10.0:
		return 1
	return 0
