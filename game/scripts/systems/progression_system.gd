## Tracks player progression — evaluates milestone conditions and grants rewards.
class_name ProgressionSystem
extends Node


const MILESTONES_PATH := "res://game/content/milestones/milestone_definitions.json"

const CONDITION_REVENUE := "revenue"
const CONDITION_REPUTATION := "reputation"
const CONDITION_DAYS := "days"
const CONDITION_ITEMS_SOLD := "items_sold"

const REWARD_CASH_BONUS := "cash_bonus"
const REWARD_STORE_SLOT := "store_slot"
const REWARD_FIXTURE_UNLOCK := "fixture_unlock"
const REWARD_SUPPLIER_TIER := "supplier_tier"

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


func initialize(
	economy: EconomySystem,
	reputation: ReputationSystem
) -> void:
	_economy_system = economy
	_reputation_system = reputation
	_load_milestone_definitions()
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.day_started.connect(_on_day_started)


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


## Returns progress toward a milestone as a float from 0.0 to 1.0.
func get_milestone_progress(milestone: Dictionary) -> float:
	var condition: String = milestone.get("condition_type", "")
	var threshold: float = float(milestone.get("threshold", 1))
	if threshold <= 0.0:
		return 1.0

	var current: float = _get_current_value_for(condition)
	return clampf(current / threshold, 0.0, 1.0)


func get_save_data() -> Dictionary:
	var completed_list: Array[String] = []
	for key: String in _completed_ids:
		completed_list.append(key)

	return {
		"completed_ids": completed_list,
		"total_revenue": _total_revenue,
		"total_items_sold": _total_items_sold,
		"unlocked_fixtures": Array(_unlocked_fixtures),
		"unlocked_store_slots": _unlocked_store_slots,
		"unlocked_supplier_tier": _unlocked_supplier_tier,
	}


func load_save_data(data: Dictionary) -> void:
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

	_unlocked_fixtures = PackedStringArray()
	var saved_fixtures: Variant = data.get("unlocked_fixtures", [])
	if saved_fixtures is Array:
		for entry: Variant in saved_fixtures:
			_unlocked_fixtures.append(str(entry))


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

		var condition: String = milestone.get("condition_type", "")
		var threshold: float = float(milestone.get("threshold", 0))
		var current: float = _get_current_value_for(condition)

		if current >= threshold:
			_complete_milestone(milestone)


func _complete_milestone(milestone: Dictionary) -> void:
	var mid: String = milestone.get("id", "")
	_completed_ids[mid] = true

	_grant_reward(milestone)

	var mname: String = milestone.get("name", mid)
	var reward_desc: String = milestone.get(
		"reward_description", ""
	)
	EventBus.milestone_completed.emit(mid, mname, reward_desc)


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


func _on_day_ended(day: int) -> void:
	_current_day = day
	if _reputation_system:
		_current_reputation = _reputation_system.get_reputation()
	_evaluate_milestones()


func _on_day_started(day: int) -> void:
	_current_day = day


func _on_item_sold(
	_item_id: String, price: float, _category: String
) -> void:
	_total_items_sold += 1
	_total_revenue += price
	_evaluate_milestones()


func _on_reputation_changed(
	_old_value: float, new_value: float
) -> void:
	_current_reputation = new_value
	_evaluate_milestones()
