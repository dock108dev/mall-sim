## Manages difficulty tier selection, persistence, and modifier/flag lookups.
class_name DifficultySystem
extends Node


signal difficulty_selected(tier_id: StringName)

const DEFAULT_TIER: StringName = &"normal"
const SETTINGS_SECTION: String = "difficulty"
const SETTINGS_KEY: String = "tier"
const PEAK_HOURS_START: int = 11
const PEAK_HOURS_END: int = 20

var _current_tier_id: StringName = DEFAULT_TIER
var _current_hour: int = 0
var _tiers: Dictionary = {}
var _tier_order: Array[StringName] = []
var _assisted: bool = false
var _initialized: bool = false
var used_difficulty_downgrade: bool = false


func _ready() -> void:
	_load_config()
	_restore_persisted_tier()
	EventBus.hour_changed.connect(_on_hour_changed)


func set_tier(tier_id: StringName) -> void:
	if not _tiers.has(tier_id):
		push_error("DifficultySystem: unknown tier '%s'" % tier_id)
		return
	if _initialized and _is_lower_tier(tier_id):
		var day: int = GameManager.current_day
		if day > 1:
			_assisted = true
	_current_tier_id = tier_id
	_persist_tier()
	_initialized = true
	difficulty_selected.emit(tier_id)


## Changes difficulty mid-game. Emits difficulty_changed signal.
## Does NOT retroactively adjust cash or inventory.
func apply_difficulty_change(new_tier_id: StringName) -> void:
	if not _tiers.has(new_tier_id):
		push_error(
			"DifficultySystem: unknown tier '%s'" % new_tier_id
		)
		return
	if new_tier_id == _current_tier_id:
		return
	var old_index: int = _get_tier_index(_current_tier_id)
	var new_index: int = _get_tier_index(new_tier_id)
	_current_tier_id = new_tier_id
	_persist_tier()
	difficulty_selected.emit(new_tier_id)
	EventBus.difficulty_changed.emit(old_index, new_index)


## Returns true if changing to the given tier is a downgrade.
func is_downgrade(new_tier_id: StringName) -> bool:
	return _is_lower_tier(new_tier_id)


## Returns the ordered list of all tier IDs.
func get_tier_ids() -> Array[StringName]:
	return _tier_order.duplicate()


## Returns the display name for a specific tier.
func get_display_name_for_tier(tier_id: StringName) -> String:
	var tier: Dictionary = _tiers.get(tier_id, {})
	return tier.get("display_name", "") as String


## Serializes difficulty state for saving.
func get_save_data() -> Dictionary:
	return {
		"current_tier": String(_current_tier_id),
		"used_difficulty_downgrade": used_difficulty_downgrade,
	}


## Restores difficulty state from saved data.
func load_save_data(data: Dictionary) -> void:
	var tier_str: String = data.get("current_tier", "")
	if not tier_str.is_empty() and _tiers.has(StringName(tier_str)):
		_current_tier_id = StringName(tier_str)
		_persist_tier()
	used_difficulty_downgrade = data.get(
		"used_difficulty_downgrade", false
	)


func _get_tier_index(tier_id: StringName) -> int:
	return _tier_order.find(tier_id)


func get_modifier(key: StringName) -> float:
	var tier: Dictionary = _tiers.get(_current_tier_id, {})
	var modifiers: Dictionary = tier.get("modifiers", {})
	if not modifiers.has(String(key)):
		push_error(
			"DifficultySystem: unknown modifier '%s' for tier '%s'"
			% [key, _current_tier_id]
		)
		return 1.0
	return float(modifiers[String(key)])


func get_flag(key: StringName) -> bool:
	var tier: Dictionary = _tiers.get(_current_tier_id, {})
	var flags: Dictionary = tier.get("flags", {})
	if not flags.has(String(key)):
		push_error(
			"DifficultySystem: unknown flag '%s' for tier '%s'"
			% [key, _current_tier_id]
		)
		return false
	return bool(flags[String(key)])


func get_current_tier_id() -> StringName:
	return _current_tier_id


func get_tier_display_name() -> String:
	var tier: Dictionary = _tiers.get(_current_tier_id, {})
	return tier.get("display_name", "") as String


func is_assisted() -> bool:
	return _assisted


## Returns true when the current in-game hour falls within peak-traffic hours.
func is_peak_hours() -> bool:
	return _current_hour >= PEAK_HOURS_START and _current_hour < PEAK_HOURS_END


func _on_hour_changed(hour: int) -> void:
	_current_hour = hour


func _load_config() -> void:
	var config: Dictionary = DataLoaderSingleton.get_difficulty_config()
	if config.is_empty():
		push_error("DifficultySystem: difficulty_config is empty")
		return
	_tiers.clear()
	_tier_order.clear()
	var tiers_array: Array = config.get("tiers", [])
	for tier_data: Variant in tiers_array:
		var tier_dict: Dictionary = tier_data as Dictionary
		var id: StringName = StringName(tier_dict.get("id", ""))
		if id.is_empty():
			continue
		_tiers[id] = tier_dict
		_tier_order.append(id)


func _restore_persisted_tier() -> void:
	var config := ConfigFile.new()
	if config.load(Settings.settings_path) != OK:
		_initialized = true
		return
	var saved_tier: String = config.get_value(
		SETTINGS_SECTION, SETTINGS_KEY, ""
	)
	if saved_tier.is_empty() or not _tiers.has(StringName(saved_tier)):
		_initialized = true
		return
	_current_tier_id = StringName(saved_tier)
	_initialized = true


func _persist_tier() -> void:
	var config := ConfigFile.new()
	config.load(Settings.settings_path)
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY, String(_current_tier_id))
	var err: Error = config.save(Settings.settings_path)
	if err != OK:
		push_warning(
			"DifficultySystem: failed to persist tier — %s"
			% error_string(err)
		)


func _is_lower_tier(new_tier_id: StringName) -> bool:
	var current_index: int = _tier_order.find(_current_tier_id)
	var new_index: int = _tier_order.find(new_tier_id)
	if current_index < 0 or new_index < 0:
		return false
	return new_index < current_index
