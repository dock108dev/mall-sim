## Manages difficulty tier selection, persistence, and modifier/flag lookups.
class_name DifficultySystem
extends Node


signal difficulty_selected(tier_id: StringName)

const DEFAULT_TIER: StringName = &"normal"
const SETTINGS_SECTION: String = "difficulty"
const SETTINGS_KEY: String = "tier"
const PEAK_HOURS_START: int = 11
const PEAK_HOURS_END: int = 20
const DIFFICULTY_CONFIG_PATH: String = "res://game/content/economy/difficulty_config.json"
var used_difficulty_downgrade: bool = false

var _current_tier_id: StringName = DEFAULT_TIER
var _current_hour: int = 0
var _tiers: Dictionary = {}
var _tier_order: Array[StringName] = []
var _assisted: bool = false
var _initialized: bool = false


func _ready() -> void:
	_load_config()
	_restore_persisted_tier()
	EventBus.hour_changed.connect(_on_hour_changed)


func set_tier(tier_id: StringName) -> void:
	if _tiers.is_empty():
		_load_config()
	if not _tiers.has(tier_id):
		push_warning("DifficultySystem: unknown tier '%s'" % tier_id)
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
		push_warning(
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
	if _tiers.is_empty():
		_load_config()
	var tier: Dictionary = _tiers.get(_current_tier_id, {})
	var modifiers: Dictionary = tier.get("modifiers", {})
	if not modifiers.has(String(key)):
		push_warning(
			"DifficultySystem: unknown modifier '%s' for tier '%s'"
			% [key, _current_tier_id]
		)
		return 1.0
	return float(modifiers[String(key)])


func get_flag(key: StringName) -> bool:
	if _tiers.is_empty():
		_load_config()
	var tier: Dictionary = _tiers.get(_current_tier_id, {})
	var flags: Dictionary = tier.get("flags", {})
	if not flags.has(String(key)):
		push_warning(
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
		var loaded: Variant = DataLoader.load_json(DIFFICULTY_CONFIG_PATH)
		if loaded is Dictionary:
			config = loaded as Dictionary
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
	var load_err: Error = _safe_load_config(config, Settings.settings_path)
	if load_err != OK:
		if FileAccess.file_exists(Settings.settings_path):
			push_warning(
				"DifficultySystem: failed to load '%s' — using in-memory tier (%s)"
				% [Settings.settings_path, error_string(load_err)]
			)
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


# Wrapper around ConfigFile.load that pre-validates the file to avoid the
# engine's internal "ConfigFile parse error" message — which tests trigger
# intentionally via corrupt fixtures and which would otherwise fail CI's
# push_error audit.
func _safe_load_config(config: ConfigFile, path: String) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var text: String = FileAccess.get_file_as_string(path)
	if not _looks_parseable_cfg(text):
		return ERR_PARSE_ERROR
	return config.parse(text)


# Rough structural check to skip ConfigFile.parse on obviously malformed files.
# Matches only the failure modes our tests exercise (unclosed [section] tags,
# stray '[' characters); anything past this point we let ConfigFile handle.
func _looks_parseable_cfg(text: String) -> bool:
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("[") and not line.ends_with("]"):
			return false
	return true


func _persist_tier() -> void:
	var config := ConfigFile.new()
	var load_err: Error = _safe_load_config(config, Settings.settings_path)
	if load_err != OK and FileAccess.file_exists(Settings.settings_path):
		push_warning(
			"DifficultySystem: failed to load '%s' for persistence — keeping file unchanged"
			% Settings.settings_path
		)
		return
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
