## Tracks player progression — evaluates milestone conditions and grants rewards.
class_name ProgressionSystem
extends Node


const MILESTONES_PATH := "res://game/content/milestones/milestone_definitions.json"

const CONDITION_REVENUE := "cumulative_revenue"
const CONDITION_REPUTATION := "max_reputation_score"
const CONDITION_DAYS := "current_day"
const CONDITION_ITEMS_SOLD := "customer_purchased_count"

const REWARD_CASH_BONUS := "cash"
const REWARD_STORE_SLOT := "store_slot"
const REWARD_FIXTURE_UNLOCK := "fixture_unlock"
const REWARD_SUPPLIER_TIER := "supplier_tier"

const STORE_UNLOCK_THRESHOLDS: Array[Dictionary] = [
	{},
	{"reputation": 25, "cash": 2000},
	{"reputation": 40, "cash": 6000},
	{"reputation": 55, "cash": 15000},
	{"reputation": 70, "cash": 35000},
]

var _milestones: Array[Dictionary] = []
var _completed_ids: Dictionary = {}
var _total_revenue: float = 0.0
var _total_items_sold: int = 0
var _current_day: int = 0
var _current_reputation: float = 0.0
var _economy_system: EconomySystem
var _reputation_system: ReputationSystem
var _unlocked_fixtures: PackedStringArray = []
var _unlocked_store_slots: int = 1
var _unlocked_supplier_tier: int = 0
var _cumulative_cash_earned: float = 0.0
var _mall_reputation: float = 0.0
var _unlocked_slot_indices: Dictionary = {}


func initialize(
	economy: EconomySystem,
	reputation: ReputationSystem
) -> void:
	_economy_system = economy
	_reputation_system = reputation
	_load_milestone_definitions()
	_apply_state({})
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.day_started.connect(_on_day_started)


## Re-evaluates milestones after the day summary is acknowledged.
## Called by DayCycleController to ensure milestone checks run
## after all day-end processing is complete.
func evaluate_day_end() -> void:
	_recalculate_mall_reputation()
	if _reputation_system:
		_current_reputation = _reputation_system.get_reputation()
	_check_store_unlock_thresholds()
	_evaluate_milestones()


func get_milestones() -> Array[Dictionary]:
	return _milestones


func get_completed_ids() -> Dictionary:
	return _completed_ids


func is_milestone_completed(milestone_id: String) -> bool:
	return _completed_ids.has(milestone_id)


func get_total_revenue() -> float:
	return _total_revenue


func get_total_items_sold() -> int:
	return _total_items_sold


func get_unlocked_store_slots() -> int:
	return _unlocked_store_slots


func get_unlocked_supplier_tier() -> int:
	return _unlocked_supplier_tier


func is_fixture_unlocked(fixture_id: String) -> bool:
	return fixture_id in _unlocked_fixtures


func get_cumulative_cash_earned() -> float:
	return _cumulative_cash_earned


func get_mall_reputation() -> float:
	return _mall_reputation


func is_slot_unlocked(slot_index: int) -> bool:
	if slot_index == 0:
		return true
	return _unlocked_slot_indices.has(slot_index)


## Increments the running total for the given milestone's condition type.
func increment_progress(milestone_id: String, amount: float) -> void:
	var milestone: Dictionary = _find_milestone(milestone_id)
	if milestone.is_empty():
		push_error(
			"ProgressionSystem: unknown milestone_id '%s'" % milestone_id
		)
		return

	var condition: String = str(
		milestone.get("trigger_stat_key", milestone.get("condition_type", ""))
	)
	match condition:
		CONDITION_REVENUE:
			_total_revenue += amount
			_cumulative_cash_earned += amount
		CONDITION_ITEMS_SOLD:
			_total_items_sold += int(amount)
		CONDITION_DAYS:
			_current_day += int(amount)
		CONDITION_REPUTATION:
			_current_reputation += amount
	_evaluate_milestones()


## Returns the raw running total for a milestone's condition type.
func get_progress(milestone_id: String) -> float:
	var milestone: Dictionary = _find_milestone(milestone_id)
	if milestone.is_empty():
		push_error(
			"ProgressionSystem: unknown milestone_id '%s'" % milestone_id
		)
		return 0.0

	var condition: String = str(
		milestone.get("trigger_stat_key", milestone.get("condition_type", ""))
	)
	return _get_current_value_for(condition)


## Returns progress toward a milestone as a float from 0.0 to 1.0.
func get_milestone_progress(milestone: Dictionary) -> float:
	var condition: String = milestone.get(
		"trigger_stat_key", ""
	)
	var threshold: float = float(
		milestone.get("trigger_threshold", 1)
	)
	if threshold <= 0.0:
		return 1.0

	var current: float = _get_current_value_for(condition)
	return clampf(current / threshold, 0.0, 1.0)


func get_save_data() -> Dictionary:
	var completed_list: Array[String] = []
	for key: String in _completed_ids:
		completed_list.append(key)

	var unlocked_slots_list: Array[int] = []
	for key: Variant in _unlocked_slot_indices:
		unlocked_slots_list.append(int(key))

	return {
		"completed_ids": completed_list,
		"total_revenue": _total_revenue,
		"total_items_sold": _total_items_sold,
		"unlocked_fixtures": Array(_unlocked_fixtures),
		"unlocked_store_slots": _unlocked_store_slots,
		"unlocked_supplier_tier": _unlocked_supplier_tier,
		"current_day": _current_day,
		"current_reputation": _current_reputation,
		"cumulative_cash_earned": _cumulative_cash_earned,
		"mall_reputation": _mall_reputation,
		"unlocked_slot_indices": unlocked_slots_list,
	}


func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_completed_ids = {}
	var saved_ids: Variant = data.get("completed_ids", [])
	if saved_ids is Array:
		for entry: Variant in saved_ids:
			_completed_ids[str(entry)] = true

	_total_revenue = float(data.get("total_revenue", 0.0))
	_total_items_sold = int(data.get("total_items_sold", 0))
	_unlocked_store_slots = int(
		data.get("unlocked_store_slots", 1)
	)
	_unlocked_supplier_tier = int(
		data.get("unlocked_supplier_tier", 0)
	)
	_current_day = int(data.get("current_day", 0))
	_current_reputation = float(
		data.get("current_reputation", 0.0)
	)
	_cumulative_cash_earned = float(
		data.get("cumulative_cash_earned", 0.0)
	)
	_mall_reputation = float(
		data.get("mall_reputation", 0.0)
	)

	_unlocked_fixtures = PackedStringArray()
	var saved_fixtures: Variant = data.get("unlocked_fixtures", [])
	if saved_fixtures is Array:
		for entry: Variant in saved_fixtures:
			_unlocked_fixtures.append(str(entry))

	_unlocked_slot_indices = {}
	var saved_slots: Variant = data.get("unlocked_slot_indices", [])
	if saved_slots is Array:
		for entry: Variant in saved_slots:
			_unlocked_slot_indices[int(entry)] = true


func _load_milestone_definitions() -> void:
	if not FileAccess.file_exists(MILESTONES_PATH):
		push_warning(
			"ProgressionSystem: milestone file not found at %s"
			% MILESTONES_PATH
		)
		return

	var file: FileAccess = FileAccess.open(
		MILESTONES_PATH, FileAccess.READ
	)
	if not file:
		push_warning(
			"ProgressionSystem: failed to open %s" % MILESTONES_PATH
		)
		return

	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_warning(
			"ProgressionSystem: JSON parse error — %s"
			% json.get_error_message()
		)
		return

	var root: Variant = json.data
	if root is not Dictionary:
		push_warning(
			"ProgressionSystem: root is not a Dictionary"
		)
		return

	var entries: Variant = (root as Dictionary).get("milestones", [])
	if entries is not Array:
		return

	_milestones = []
	for entry: Variant in entries:
		if entry is Dictionary:
			_milestones.append(entry as Dictionary)


func _find_milestone(milestone_id: String) -> Dictionary:
	for milestone: Dictionary in _milestones:
		if milestone.get("id", "") == milestone_id:
			return milestone
	return {}


func _get_current_value_for(condition_type: String) -> float:
	match condition_type:
		CONDITION_REVENUE:
			return _total_revenue
		CONDITION_REPUTATION:
			return _current_reputation
		CONDITION_DAYS:
			return float(_current_day)
		CONDITION_ITEMS_SOLD:
			return float(_total_items_sold)
	return 0.0


func _evaluate_milestones() -> void:
	for milestone: Dictionary in _milestones:
		var mid: String = milestone.get("id", "")
		if mid.is_empty() or _completed_ids.has(mid):
			continue

		var condition: String = milestone.get(
			"trigger_stat_key", ""
		)
		var threshold: float = float(
			milestone.get("trigger_threshold", 0)
		)
		var current: float = _get_current_value_for(condition)

		if current >= threshold:
			_complete_milestone(milestone)


func _complete_milestone(milestone: Dictionary) -> void:
	var mid: String = milestone.get("id", "")
	_completed_ids[mid] = true

	_grant_reward(milestone)

	var mname: String = milestone.get(
		"display_name", mid
	)
	var mdesc: String = str(milestone.get("description", ""))
	EventBus.milestone_completed.emit(mid, mname, mdesc)


func _grant_reward(milestone: Dictionary) -> void:
	var reward_type: String = milestone.get("reward_type", "")
	var reward_value: Variant = milestone.get("reward_value", 0)

	match reward_type:
		REWARD_CASH_BONUS:
			_grant_cash_bonus(float(reward_value))
		REWARD_STORE_SLOT:
			_grant_store_slot(int(reward_value))
		REWARD_FIXTURE_UNLOCK:
			_grant_fixture_unlock(str(reward_value))
		REWARD_SUPPLIER_TIER:
			_grant_supplier_tier(int(reward_value))


func _grant_cash_bonus(amount: float) -> void:
	if _economy_system:
		_economy_system.add_cash(amount, "Milestone bonus")


func _grant_store_slot(slot_count: int) -> void:
	_unlocked_store_slots = maxi(_unlocked_store_slots, slot_count)


func _grant_fixture_unlock(fixture_id: String) -> void:
	if fixture_id not in _unlocked_fixtures:
		_unlocked_fixtures.append(fixture_id)


func _grant_supplier_tier(tier: int) -> void:
	_unlocked_supplier_tier = maxi(_unlocked_supplier_tier, tier)


func _recalculate_mall_reputation() -> void:
	if not _reputation_system:
		_mall_reputation = 0.0
		return
	_mall_reputation = _reputation_system.get_global_reputation()


func _check_store_unlock_thresholds() -> void:
	for slot_index: int in range(1, STORE_UNLOCK_THRESHOLDS.size()):
		if _unlocked_slot_indices.has(slot_index):
			continue

		var req: Dictionary = STORE_UNLOCK_THRESHOLDS[slot_index]
		var req_rep: float = float(req.get("reputation", 0))
		var req_cash: float = float(req.get("cash", 0))

		if _mall_reputation >= req_rep and _cumulative_cash_earned >= req_cash:
			_unlocked_slot_indices[slot_index] = true
			_unlocked_store_slots = maxi(
				_unlocked_store_slots, slot_index + 1
			)
			EventBus.store_slot_unlocked.emit(slot_index)


func _on_day_ended(day: int) -> void:
	_current_day = day
	_recalculate_mall_reputation()
	if _reputation_system:
		_current_reputation = _reputation_system.get_reputation()
	_check_store_unlock_thresholds()
	_evaluate_milestones()


func _on_day_started(day: int) -> void:
	_current_day = day


func _on_item_sold(
	_item_id: String, price: float, _category: String
) -> void:
	_total_items_sold += 1
	_total_revenue += price
	_cumulative_cash_earned += price
	_evaluate_milestones()


func _on_reputation_changed(
	_store_id: String, new_value: float
) -> void:
	_current_reputation = new_value
	_evaluate_milestones()
