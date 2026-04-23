## Tracks per-tape return counts within each condition tier for rental degradation.
class_name TapeWearTracker
extends RefCounted

const RENTALS_PER_CONDITION_DROP: int = 5
const POOREST_CONDITION: String = "poor"
const VHS_DEGRADATION_RATE: float = 0.08
const DVD_DEGRADATION_RATE: float = 0.04
const MEDIA_TYPE_VHS: String = "vhs"
const MEDIA_TYPE_DVD: String = "dvd"
const WEAR_EPSILON: float = 0.00001
const CONDITION_TO_WEAR: Dictionary = {
	"mint": 0.0,
	"near_mint": 0.2,
	"good": 0.4,
	"fair": 0.6,
	"poor": 0.8,
}
const CONDITION_WEAR_ORDER: PackedStringArray = [
	"mint", "near_mint", "good", "fair", "poor",
]

var _play_counts: Dictionary = {}
var _conditions: Dictionary = {}
var _written_off: Dictionary = {}
var _wear: Dictionary = {}
var _media_types: Dictionary = {}


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
func initialize_item(instance_id: String, condition_or_media_type: String) -> void:
	if instance_id.is_empty():
		return
	var normalized_input: String = str(condition_or_media_type).strip_edges().to_lower()
	if _is_media_type(normalized_input):
		_play_counts[instance_id] = clampi(
			int(_play_counts.get(instance_id, 0)),
			0,
			RENTALS_PER_CONDITION_DROP
		)
		_media_types[instance_id] = normalized_input
		_wear[instance_id] = float(_wear.get(instance_id, 0.0))
		var wear_condition: String = get_condition_for_wear(
			float(_wear[instance_id])
		)
		_conditions[instance_id] = wear_condition
		_written_off[instance_id] = (
			wear_condition == POOREST_CONDITION
			and float(_wear[instance_id]) >= float(CONDITION_TO_WEAR[POOREST_CONDITION])
		)
		return

	var normalized_condition: String = _normalize_condition(normalized_input)
	var count: int = clampi(
		int(_play_counts.get(instance_id, 0)),
		0,
		RENTALS_PER_CONDITION_DROP
	)
	_play_counts[instance_id] = count
	_conditions[instance_id] = normalized_condition
	_wear[instance_id] = float(
		_wear.get(
			instance_id,
			float(CONDITION_TO_WEAR.get(normalized_condition, 0.0))
		)
	)
	_written_off[instance_id] = (
		normalized_condition == POOREST_CONDITION
		and count >= RENTALS_PER_CONDITION_DROP
	)


## Applies media-specific wear degradation and returns the new wear value.
func apply_degradation(instance_id: String) -> float:
	if instance_id.is_empty() or not _media_types.has(instance_id):
		return 0.0

	var rate: float = VHS_DEGRADATION_RATE
	if str(_media_types.get(instance_id, MEDIA_TYPE_VHS)) == MEDIA_TYPE_DVD:
		rate = DVD_DEGRADATION_RATE
	var updated_wear: float = minf(float(_wear.get(instance_id, 0.0)) + rate, 1.0)
	_wear[instance_id] = updated_wear
	var condition: String = get_condition_for_wear(updated_wear)
	_conditions[instance_id] = condition
	_written_off[instance_id] = (
		condition == POOREST_CONDITION
		and updated_wear >= float(CONDITION_TO_WEAR[POOREST_CONDITION])
	)
	return updated_wear


## Updates the cached condition for an item without changing its play progress.
func sync_condition(instance_id: String, condition: String) -> void:
	if instance_id.is_empty():
		return
	if not _play_counts.has(instance_id):
		initialize_item(instance_id, condition)
		return
	var normalized_condition: String = _normalize_condition(condition)
	_conditions[instance_id] = normalized_condition
	_wear[instance_id] = float(
		_wear.get(
			instance_id,
			float(CONDITION_TO_WEAR.get(normalized_condition, 0.0))
		)
	)
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
	_wear[instance_id] = float(CONDITION_TO_WEAR.get(new_condition, 0.0))
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


## Returns the accumulated wear for a tracked item.
func get_wear(instance_id: String) -> float:
	return float(_wear.get(instance_id, 0.0))


## Returns the condition tier associated with a wear amount.
func get_condition_for_wear(wear_amount: float) -> String:
	var normalized_wear: float = clampf(wear_amount, 0.0, 1.0)
	var resolved_condition: String = "mint"
	for condition: String in CONDITION_WEAR_ORDER:
		if normalized_wear + WEAR_EPSILON >= float(CONDITION_TO_WEAR.get(condition, 0.0)):
			resolved_condition = condition
	return resolved_condition


## Returns the number of unique tracked items.
func get_tracked_item_count() -> int:
	return maxi(_conditions.size(), _wear.size())


## Maps a wear value in [0, 1] to a customer appeal factor in [0.5, 1.0].
## Low wear (≤0.2) keeps full appeal; wear beyond that linearly erodes appeal
## down to 0.5 at maximum wear. Used by the rental customer appeal formula.
static func compute_appeal_factor(wear_amount: float) -> float:
	var w: float = clampf(wear_amount, 0.0, 1.0)
	if w <= 0.2:
		return 1.0
	var erosion: float = (w - 0.2) / 0.8
	return clampf(1.0 - 0.5 * erosion, 0.5, 1.0)


## Categorizes a wear value for UI display: "pristine", "light", "moderate",
## "heavy", or "worn_out".
static func classify_wear(wear_amount: float) -> String:
	var w: float = clampf(wear_amount, 0.0, 1.0)
	if w <= 0.2:
		return "pristine"
	if w <= 0.4:
		return "light"
	if w <= 0.6:
		return "moderate"
	if w + WEAR_EPSILON < float(CONDITION_TO_WEAR[POOREST_CONDITION]):
		return "heavy"
	return "worn_out"


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
	_wear.erase(instance_id)
	_media_types.erase(instance_id)


## Serializes per-item wear state for save/load.
## Format: {version: 2, items: {instance_id: {play_count, wear, condition, media_type}}}.
## Version 1 (flat play_counts only) still loads for backward compat.
func get_save_data() -> Dictionary:
	var items: Dictionary = {}
	var ids: Dictionary = {}
	for id_key: Variant in _play_counts.keys():
		ids[str(id_key)] = true
	for id_key: Variant in _wear.keys():
		ids[str(id_key)] = true
	for id_key: Variant in _conditions.keys():
		ids[str(id_key)] = true
	for id_str: String in ids.keys():
		items[id_str] = {
			"play_count": int(_play_counts.get(id_str, 0)),
			"wear": float(_wear.get(id_str, 0.0)),
			"condition": str(_conditions.get(id_str, "good")),
			"media_type": str(_media_types.get(id_str, "")),
			"written_off": bool(_written_off.get(id_str, false)),
		}
	return {"version": 2, "items": items}


## Restores saved wear state. Accepts v2 nested format or v1 flat play-count map.
func load_save_data(data: Dictionary) -> void:
	_play_counts = {}
	_conditions = {}
	_written_off = {}
	_wear = {}
	_media_types = {}
	var items_data: Variant = data.get("items", null)
	if items_data is Dictionary:
		for raw_key: Variant in (items_data as Dictionary).keys():
			var instance_id: String = str(raw_key)
			var entry: Variant = (items_data as Dictionary)[raw_key]
			if not (entry is Dictionary):
				continue
			var row: Dictionary = entry as Dictionary
			_play_counts[instance_id] = clampi(
				int(row.get("play_count", 0)),
				0,
				RENTALS_PER_CONDITION_DROP,
			)
			_wear[instance_id] = clampf(
				float(row.get("wear", 0.0)), 0.0, 1.0
			)
			_conditions[instance_id] = _normalize_condition(
				str(row.get("condition", "good"))
			)
			var mt: String = str(row.get("media_type", ""))
			if _is_media_type(mt):
				_media_types[instance_id] = mt
			_written_off[instance_id] = bool(row.get("written_off", false))
		return
	# Backward compat: legacy flat {instance_id: play_count}.
	for raw_key: Variant in data.keys():
		if raw_key == "version" or raw_key == "items":
			continue
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


func _is_media_type(value: String) -> bool:
	return value == MEDIA_TYPE_VHS or value == MEDIA_TYPE_DVD
