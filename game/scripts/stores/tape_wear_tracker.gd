## Tracks per-tape return counts within each condition tier for rental degradation.
class_name TapeWearTracker
extends RefCounted

const RENTALS_PER_CONDITION_DROP: int = 5
const POOREST_CONDITION: String = "poor"

var _play_counts: Dictionary = {}
var _conditions: Dictionary = {}
var _written_off: Dictionary = {}


## Synchronizes tracked tape state with the current store inventory.
func initialize(items: Array[ItemInstance] = []) -> void:
	var next_counts: Dictionary = {}
	var next_conditions: Dictionary = {}
	var next_written_off: Dictionary = {}

	for item: ItemInstance in items:
		if not item or String(item.instance_id).is_empty():
			continue
		var instance_id: String = String(item.instance_id)
		var count: int = clampi(
			int(_play_counts.get(instance_id, 0)),
			0,
			RENTALS_PER_CONDITION_DROP
		)
		var condition: String = _normalize_condition(item.condition)
		next_counts[instance_id] = count
		next_conditions[instance_id] = condition
		next_written_off[instance_id] = (
			condition == POOREST_CONDITION
			and count >= RENTALS_PER_CONDITION_DROP
		)

	_play_counts = next_counts
	_conditions = next_conditions
	_written_off = next_written_off


## Registers an item with its current condition if not already tracked.
func initialize_item(instance_id: String, condition: String) -> void:
	if instance_id.is_empty():
		return
	var normalized_condition: String = _normalize_condition(condition)
	var count: int = clampi(
		int(_play_counts.get(instance_id, 0)),
		0,
		RENTALS_PER_CONDITION_DROP
	)
	_play_counts[instance_id] = count
	_conditions[instance_id] = normalized_condition
	_written_off[instance_id] = (
		normalized_condition == POOREST_CONDITION
		and count >= RENTALS_PER_CONDITION_DROP
	)


## Updates the cached condition for an item without changing its play progress.
func sync_condition(instance_id: String, condition: String) -> void:
	if instance_id.is_empty():
		return
	if not _play_counts.has(instance_id):
		initialize_item(instance_id, condition)
		return
	var normalized_condition: String = _normalize_condition(condition)
	_conditions[instance_id] = normalized_condition
	_written_off[instance_id] = (
		normalized_condition == POOREST_CONDITION
		and int(_play_counts.get(instance_id, 0)) >= RENTALS_PER_CONDITION_DROP
	)


## Records a returned rental and reports whether its condition tier changed.
func record_return(instance_id: String) -> Dictionary:
	var result: Dictionary = {
		"condition_changed": false,
		"new_condition": _conditions.get(instance_id, "good"),
		"play_count": int(_play_counts.get(instance_id, 0)),
		"rentable": is_rentable(instance_id),
		"became_unrentable": false,
	}
	if instance_id.is_empty():
		return result
	if not _conditions.has(instance_id):
		initialize_item(instance_id, "good")
		result["new_condition"] = "good"
	if not is_rentable(instance_id):
		result["play_count"] = RENTALS_PER_CONDITION_DROP
		result["rentable"] = false
		return result

	var play_count: int = int(_play_counts.get(instance_id, 0)) + 1
	var current_condition: String = _conditions.get(instance_id, "good")
	if play_count < RENTALS_PER_CONDITION_DROP:
		_play_counts[instance_id] = play_count
		result["play_count"] = play_count
		return result

	if current_condition == POOREST_CONDITION:
		_play_counts[instance_id] = RENTALS_PER_CONDITION_DROP
		_written_off[instance_id] = true
		result["play_count"] = RENTALS_PER_CONDITION_DROP
		result["rentable"] = false
		result["became_unrentable"] = true
		return result

	var new_condition: String = _degrade_condition(current_condition)
	_play_counts[instance_id] = 0
	_conditions[instance_id] = new_condition
	_written_off[instance_id] = false
	result["condition_changed"] = true
	result["new_condition"] = new_condition
	result["play_count"] = 0
	return result


## Returns the current play count within the active condition tier.
func get_play_count(instance_id: String) -> int:
	return int(_play_counts.get(instance_id, 0))


## Returns the tracked condition for the tape.
func get_condition(instance_id: String) -> String:
	return str(_conditions.get(instance_id, "good"))


## Returns true when the tape can still be rented.
func is_rentable(instance_id: String) -> bool:
	if instance_id.is_empty() or not _conditions.has(instance_id):
		return false
	return not bool(_written_off.get(instance_id, false))


## Removes an item from wear tracking.
func erase_item(instance_id: String) -> void:
	_play_counts.erase(instance_id)
	_conditions.erase(instance_id)
	_written_off.erase(instance_id)


## Serializes per-item play counts for save/load.
func get_save_data() -> Dictionary:
	return _play_counts.duplicate()


## Restores saved play counts.
func load_save_data(data: Dictionary) -> void:
	_play_counts = {}
	_conditions = {}
	_written_off = {}
	for raw_key: Variant in data.keys():
		var instance_id: String = str(raw_key)
		_play_counts[instance_id] = clampi(
			int(data[raw_key]),
			0,
			RENTALS_PER_CONDITION_DROP
		)


func _degrade_condition(condition: String) -> String:
	var current_tier: int = ItemDefinition.condition_to_tier(
		_normalize_condition(condition)
	)
	return ItemDefinition.tier_to_condition(current_tier - 1)


func _normalize_condition(condition: String) -> String:
	if ItemDefinition.CONDITION_ORDER.has(condition):
		return condition
	return "good"
