## Tracks cumulative tape wear per rental item and maps wear to condition.
class_name TapeWearTracker
extends RefCounted

const VHS_DEGRADATION_RATE: float = 0.08
const DVD_DEGRADATION_RATE: float = 0.04

const CONDITION_TO_WEAR: Dictionary = {
	"mint": 0.0,
	"near_mint": 0.2,
	"good": 0.4,
	"fair": 0.6,
	"poor": 0.8,
}

var _wear: Dictionary = {}


## Initializes wear for an item based on its current condition.
func initialize_item(instance_id: String, condition: String) -> void:
	if not _wear.has(instance_id):
		_wear[instance_id] = CONDITION_TO_WEAR.get(condition, 0.4)


## Applies one rental's worth of degradation and returns the new condition.
func apply_degradation(instance_id: String, category: String) -> String:
	var rate: float = VHS_DEGRADATION_RATE
	if category == "dvd_titles" or category.begins_with("dvd_"):
		rate = DVD_DEGRADATION_RATE
	var current: float = _wear.get(instance_id, 0.0)
	current += rate
	_wear[instance_id] = current
	return wear_to_condition(current)


## Returns the current wear value for an item.
func get_wear(instance_id: String) -> float:
	return _wear.get(instance_id, 0.0)


## Removes an item from wear tracking.
func erase_item(instance_id: String) -> void:
	_wear.erase(instance_id)


## Serializes all wear data.
func get_save_data() -> Dictionary:
	return _wear.duplicate()


## Restores wear data from a saved dictionary.
func load_save_data(data: Dictionary) -> void:
	_wear = {}
	for key: String in data:
		_wear[key] = float(data[key])


## Converts a numeric wear value to a condition string.
static func wear_to_condition(wear: float) -> String:
	if wear < 0.2:
		return "mint"
	if wear < 0.4:
		return "near_mint"
	if wear < 0.6:
		return "good"
	if wear < 0.8 - 0.001:
		return "fair"
	return "poor"
