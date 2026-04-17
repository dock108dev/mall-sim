## Tracks 22 game statistics and evaluates ending eligibility via priority-ordered scan.
class_name EndingEvaluatorSystem
extends Node


const CONFIG_PATH := "res://game/content/endings/ending_config.json"
const FALLBACK_ENDING_ID: StringName = &"broke_even"
const ENDING_CONTENT_TYPE := "ending"
const NEAR_BANKRUPTCY_THRESHOLD := 100.0

var _ending_definitions: Array[Dictionary] = []
var _stats: Dictionary = {}
var _ending_triggered: bool = false
var _resolved_ending_id: StringName = &""
var _owned_store_ids: Dictionary = {}
var _initialized: bool = false


func _ready() -> void:
	initialize()


## Loads ending definitions and begins tracking EventBus-driven stats.
func initialize() -> void:
	if _initialized:
		return
	_load_config()
	_reset_stats()
	_connect_signals()
	_initialized = true


## Returns the highest-priority ending that matches the current tracked stats.
func evaluate() -> StringName:
	_update_computed_stats()
	for ending: Dictionary in _ending_definitions:
		if _matches_criteria(ending):
			return StringName(str(ending.get("id", "")))
	return FALLBACK_ENDING_ID


## Returns a tracked stat as a float for test-friendly assertions.
func get_tracked_stat(stat_key: StringName) -> float:
	return float(_stats.get(stat_key, 0.0))


## Returns a snapshot of all tracked stats with derived values refreshed.
func get_all_tracked_stats() -> Dictionary:
	_update_computed_stats()
	return _stats.duplicate()


## Returns the ending ID resolved for the current run, if any.
func get_resolved_ending_id() -> StringName:
	return _resolved_ending_id


## Forces a specific ending to emit once with the current stats snapshot.
func force_ending(ending_id: StringName) -> void:
	if _ending_triggered:
		return
	_emit_resolved_ending(ending_id)


## Returns whether this run has already emitted an ending.
func has_ending_been_shown() -> bool:
	return _ending_triggered


## Returns the loaded ending definition for a given ID.
func get_ending_data(ending_id: StringName) -> Dictionary:
	for ending: Dictionary in _ending_definitions:
		if StringName(str(ending.get("id", ""))) == ending_id:
			return ending
	return {}


## Returns the persisted evaluator state, including tracked stats.
func get_save_data() -> Dictionary:
	return {
		"stats": _stats.duplicate(),
		"ending_triggered": _ending_triggered,
		"resolved_ending_id": String(_resolved_ending_id),
		"owned_store_ids": _owned_store_ids.duplicate(),
	}


## Restores tracked stats and ending state without emitting runtime signals.
func load_state(data: Dictionary) -> void:
	_reset_stats()
	var saved_stats: Variant = data.get("stats", {})
	if saved_stats is Dictionary:
		var restored_stats: Dictionary = (saved_stats as Dictionary).duplicate()
		for stat_key: Variant in restored_stats.keys():
			_stats[str(stat_key)] = restored_stats[stat_key]
	_ending_triggered = bool(data.get("ending_triggered", false))
	var saved_id: String = str(data.get("resolved_ending_id", ""))
	_resolved_ending_id = StringName(saved_id) if not saved_id.is_empty() else &""
	var saved_stores: Variant = data.get("owned_store_ids", {})
	if saved_stores is Dictionary:
		_owned_store_ids = (saved_stores as Dictionary).duplicate()
	_update_computed_stats()


func _reset_stats() -> void:
	_ending_triggered = false
	_resolved_ending_id = &""
	_owned_store_ids.clear()
	_stats = {
		"cumulative_revenue": 0.0,
		"cumulative_expenses": 0.0,
		"peak_cash": 0.0,
		"final_cash": 0.0,
		"days_survived": 0.0,
		"owned_store_count_peak": 0.0,
		"owned_store_count_final": 0.0,
		"total_sales_count": 0.0,
		"satisfied_customer_count": 0.0,
		"unsatisfied_customer_count": 0.0,
		"satisfaction_ratio": 0.0,
		"max_reputation_tier": 0.0,
		"final_reputation_tier": 0.0,
		"secret_threads_completed": 0.0,
		"haggle_attempts": 0.0,
		"haggle_never_used": 1.0,
		"days_near_bankruptcy": 0.0,
		"rare_items_sold": 0.0,
		"market_events_survived": 0.0,
		"unique_store_types_owned": 0.0,
		"trigger_type_bankruptcy": 0.0,
		"ghost_tenant_thread_completed": 0.0,
	}


func _connect_signals() -> void:
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.customer_left.connect(_on_customer_left)
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.store_leased.connect(_on_store_leased)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.haggle_completed.connect(_on_haggle_completed)
	EventBus.secret_thread_completed.connect(
		_on_secret_thread_completed
	)
	EventBus.random_event_resolved.connect(
		_on_random_event_resolved
	)
	EventBus.ending_requested.connect(_on_ending_requested)
	EventBus.bankruptcy_declared.connect(_on_bankruptcy_declared)
	EventBus.player_quit_to_end.connect(_on_player_quit_to_end)
	EventBus.completion_reached.connect(_on_completion_reached)


func _on_customer_purchased(
	_store_id: StringName, _item_id: StringName,
	price: float, _customer_id: StringName
) -> void:
	_stats["total_sales_count"] = (
		float(_stats.get("total_sales_count", 0.0)) + 1.0
	)
	_stats["cumulative_revenue"] = (
		float(_stats.get("cumulative_revenue", 0.0)) + price
	)
	if _is_rare_item(_item_id):
		_stats["rare_items_sold"] = (
			float(_stats.get("rare_items_sold", 0.0)) + 1.0
		)


func _on_customer_left(customer_data: Dictionary) -> void:
	var satisfied: bool = bool(
		customer_data.get("satisfied", false)
	)
	if satisfied:
		_stats["satisfied_customer_count"] = (
			float(_stats.get("satisfied_customer_count", 0.0)) + 1.0
		)
	else:
		_stats["unsatisfied_customer_count"] = (
			float(_stats.get("unsatisfied_customer_count", 0.0))
			+ 1.0
		)


func _on_day_started(_day: int) -> void:
	_stats["days_survived"] = (
		float(_stats.get("days_survived", 0.0)) + 1.0
	)


func _on_day_ended(_day: int) -> void:
	var current_cash: float = float(
		_stats.get("final_cash", 0.0)
	)
	if current_cash < NEAR_BANKRUPTCY_THRESHOLD:
		_stats["days_near_bankruptcy"] = (
			float(_stats.get("days_near_bankruptcy", 0.0)) + 1.0
		)


func _on_store_leased(
	_slot_index: int, store_type: String
) -> void:
	_owned_store_ids[store_type] = true
	var owned_count: float = float(_owned_store_ids.size())
	_stats["owned_store_count_final"] = owned_count
	_stats["unique_store_types_owned"] = owned_count
	var peak: float = float(
		_stats.get("owned_store_count_peak", 0.0)
	)
	if owned_count > peak:
		_stats["owned_store_count_peak"] = owned_count


func _on_money_changed(
	old_amount: float, new_amount: float
) -> void:
	_stats["final_cash"] = new_amount
	var peak: float = float(_stats.get("peak_cash", 0.0))
	if new_amount > peak:
		_stats["peak_cash"] = new_amount
	if new_amount < old_amount:
		var loss: float = old_amount - new_amount
		_stats["cumulative_expenses"] = (
			float(_stats.get("cumulative_expenses", 0.0)) + loss
		)


func _on_reputation_changed(
	_store_id: String, new_value: float
) -> void:
	var tier: float = _reputation_to_tier(new_value)
	_stats["final_reputation_tier"] = tier
	var max_tier: float = float(
		_stats.get("max_reputation_tier", 0.0)
	)
	if tier > max_tier:
		_stats["max_reputation_tier"] = tier


func _on_haggle_completed(
	_store_id: StringName, _item_id: StringName,
	_final_price: float, _asking_price: float,
	_accepted: bool, _offer_count: int
) -> void:
	_stats["haggle_attempts"] = (
		float(_stats.get("haggle_attempts", 0.0)) + 1.0
	)
	_stats["haggle_never_used"] = 0.0


func _on_secret_thread_completed(
	thread_id: StringName, _reward_data: Dictionary
) -> void:
	_stats["secret_threads_completed"] = (
		float(_stats.get("secret_threads_completed", 0.0)) + 1.0
	)
	if thread_id == &"the_ghost_tenant":
		_stats["ghost_tenant_thread_completed"] = 1.0


func _on_random_event_resolved(
	_event_id: StringName, outcome: StringName
) -> void:
	if outcome != &"survived":
		return
	_stats["market_events_survived"] = (
		float(_stats.get("market_events_survived", 0.0)) + 1.0
	)


func _on_bankruptcy_declared() -> void:
	_on_ending_requested("bankruptcy")


func _on_player_quit_to_end() -> void:
	_on_ending_requested("player_quit")


func _on_completion_reached(reason: String) -> void:
	_on_ending_requested(reason)


func _on_ending_requested(trigger_type: String) -> void:
	if _ending_triggered:
		return
	if trigger_type == "bankruptcy":
		_stats["trigger_type_bankruptcy"] = 1.0
	else:
		_stats["trigger_type_bankruptcy"] = 0.0
	_emit_resolved_ending(evaluate())


func _emit_resolved_ending(ending_id: StringName) -> void:
	_resolved_ending_id = ending_id
	_ending_triggered = true
	var all_stats: Dictionary = _build_stats_snapshot()
	EventBus.ending_stats_snapshot_ready.emit(all_stats)
	EventBus.ending_triggered.emit(ending_id, all_stats)


func _build_stats_snapshot() -> Dictionary:
	_update_computed_stats()
	var all_stats: Dictionary = _stats.duplicate()
	all_stats["used_difficulty_downgrade"] = (
		DifficultySystemSingleton.used_difficulty_downgrade
	)
	return all_stats


func _update_computed_stats() -> void:
	var satisfied: float = float(
		_stats.get("satisfied_customer_count", 0.0)
	)
	var unsatisfied: float = float(
		_stats.get("unsatisfied_customer_count", 0.0)
	)
	var total: float = satisfied + unsatisfied
	if total > 0.0:
		_stats["satisfaction_ratio"] = satisfied / total
	else:
		_stats["satisfaction_ratio"] = 0.0


func _matches_criteria(ending: Dictionary) -> bool:
	var required_all: Variant = ending.get("required_all", [])
	if required_all is Array:
		for criterion: Variant in required_all:
			if criterion is Dictionary:
				if not _eval_criterion(criterion as Dictionary):
					return false

	var required_any: Variant = ending.get("required_any", [])
	if required_any is Array:
		var any_list: Array = required_any as Array
		if not any_list.is_empty():
			var any_passed: bool = false
			for criterion: Variant in any_list:
				if criterion is Dictionary:
					if _eval_criterion(criterion as Dictionary):
						any_passed = true
						break
			if not any_passed:
				return false

	var forbidden_all: Variant = ending.get("forbidden_all", [])
	if forbidden_all is Array:
		for criterion: Variant in forbidden_all:
			if criterion is Dictionary:
				if _eval_criterion(criterion as Dictionary):
					return false

	return true


func _eval_criterion(criterion: Dictionary) -> bool:
	var stat_key: String = str(criterion.get("stat_key", ""))
	var op: String = str(criterion.get("operator", ""))
	var target: float = float(criterion.get("value", 0.0))
	var val: float = float(_stats.get(stat_key, 0.0))

	match op:
		"gte":
			return val >= target
		"lte":
			return val <= target
		"gt":
			return val > target
		"lt":
			return val < target
		"eq":
			return is_equal_approx(val, target)
		_:
			push_error(
				"EndingEvaluatorSystem: unknown operator '%s'"
				% op
			)
			return false


func _reputation_to_tier(reputation_value: float) -> float:
	if reputation_value >= 80.0:
		return 4.0
	if reputation_value >= 60.0:
		return 3.0
	if reputation_value >= 40.0:
		return 2.0
	if reputation_value >= 20.0:
		return 1.0
	return 0.0


func _load_config() -> void:
	var ending_ids: Array[StringName] = ContentRegistry.get_all_ids(
		ENDING_CONTENT_TYPE
	)
	if ending_ids.is_empty():
		_register_endings_in_content_registry()
		ending_ids = ContentRegistry.get_all_ids(ENDING_CONTENT_TYPE)
	if ending_ids.is_empty():
		push_error(
			"EndingEvaluatorSystem: no ending definitions registered in ContentRegistry"
		)
		_ending_definitions = []
		return
	_ending_definitions.clear()
	for ending_id: StringName in ending_ids:
		var entry: Dictionary = ContentRegistry.get_entry(ending_id)
		if entry.is_empty():
			push_error(
				"EndingEvaluatorSystem: missing ContentRegistry entry for '%s'"
				% ending_id
			)
			continue
		_ending_definitions.append(entry.duplicate())
	_ending_definitions.sort_custom(_sort_by_priority)
	if _ending_definitions.size() != 13:
		push_error(
			"EndingEvaluatorSystem: expected 13 ending definitions, found %d"
			% _ending_definitions.size()
		)


func _register_endings_in_content_registry() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error(
			"EndingEvaluatorSystem: config not found at %s"
			% CONFIG_PATH
		)
		return
	var file: FileAccess = FileAccess.open(
		CONFIG_PATH, FileAccess.READ
	)
	if not file:
		push_error(
			"EndingEvaluatorSystem: failed to open %s"
			% CONFIG_PATH
		)
		return
	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error(
			"EndingEvaluatorSystem: JSON parse error — %s"
			% json.get_error_message()
		)
		return
	var root: Variant = json.data
	if root is not Dictionary:
		push_error(
			"EndingEvaluatorSystem: config root must be a Dictionary"
		)
		return
	var endings_raw: Variant = (root as Dictionary).get("endings", [])
	if endings_raw is not Array:
		push_error(
			"EndingEvaluatorSystem: config 'endings' must be an Array"
		)
		return
	for entry: Variant in endings_raw:
		if entry is Dictionary:
			ContentRegistry.register_entry(
				(entry as Dictionary).duplicate(),
				ENDING_CONTENT_TYPE
			)


func _is_rare_item(item_id: StringName) -> bool:
	var entry: Dictionary = ContentRegistry.get_entry(item_id)
	if entry.is_empty():
		return false
	var rarity: String = str(entry.get("rarity", "common"))
	return rarity in ["rare", "very_rare", "legendary"]


func _sort_by_priority(a: Dictionary, b: Dictionary) -> bool:
	var pa: int = int(a.get("priority", 99))
	var pb: int = int(b.get("priority", 99))
	return pa < pb
