## Tracks per-category market trend levels and shifts them daily.
class_name MarketTrendSystem
extends Node


const CATALOG_PATH: String = "res://game/content/market_trends_catalog.json"
const MIN_LEVEL: float = 0.2
const MAX_LEVEL: float = 2.0
const SHIFT_THRESHOLD: float = 0.05
const VOLATILITY_MIN: float = 0.0
const VOLATILITY_MAX: float = 2.0

var _trend_levels: Dictionary = {}
var _category_configs: Dictionary = {}
var _initialized: bool = false
var _current_day: int = 0


func _ready() -> void:
	_load_catalog()
	EventBus.day_ended.connect(_on_day_ended)
	_initialized = true


## Returns base_trend + modifier (additive combination, applied before volatility scaling).
func apply_category_modifier(base_trend: float, modifier: float) -> float:
	return base_trend + modifier


## Clamps raw_volatility to the valid range [VOLATILITY_MIN, VOLATILITY_MAX].
static func _clamp_volatility(raw_volatility: float) -> float:
	return clampf(raw_volatility, VOLATILITY_MIN, VOLATILITY_MAX)


func get_trend_modifier(category_id: StringName) -> float:
	if not _trend_levels.has(category_id):
		push_error(
			"MarketTrendSystem: unknown category '%s'" % category_id
		)
		return 1.0
	return _trend_levels[category_id] as float


func get_all_trend_levels() -> Dictionary:
	return _trend_levels.duplicate()


func get_save_data() -> Dictionary:
	return {"trend_levels": _trend_levels.duplicate()}


func load_save_data(data: Dictionary) -> void:
	var saved: Variant = data.get("trend_levels", {})
	if saved is Dictionary:
		for key: Variant in (saved as Dictionary):
			var sid: StringName = StringName(str(key))
			if _category_configs.has(sid):
				_trend_levels[sid] = clampf(
					float((saved as Dictionary)[key]),
					MIN_LEVEL, MAX_LEVEL
				)


func _load_catalog() -> void:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if not file:
		push_error(
			"MarketTrendSystem: failed to open %s — %s"
			% [CATALOG_PATH, error_string(FileAccess.get_open_error())]
		)
		return

	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	if err != OK:
		push_error(
			"MarketTrendSystem: JSON parse error in %s — %s"
			% [CATALOG_PATH, json.get_error_message()]
		)
		return

	var entries: Variant = json.data
	if not entries is Array:
		push_error("MarketTrendSystem: catalog root must be an Array")
		return

	for entry: Variant in entries as Array:
		if not entry is Dictionary:
			continue
		var dict: Dictionary = entry as Dictionary
		var id: StringName = StringName(dict.get("id", "") as String)
		if id.is_empty():
			continue
		var volatility: float = _clamp_volatility(float(dict.get("volatility", 0.1)))
		var default_level: float = float(dict.get("default_level", 1.0))
		_category_configs[id] = {
			"id": id,
			"display_name": dict.get("display_name", "") as String,
			"volatility": volatility,
			"default_level": default_level,
		}
		_trend_levels[id] = default_level


func _on_day_ended(_day: int) -> void:
	_current_day += 1
	_shift_trends()


func _shift_trends() -> void:
	for category_id: Variant in _category_configs:
		var sid: StringName = category_id as StringName
		var config: Dictionary = _category_configs[sid] as Dictionary
		var volatility: float = config.get("volatility", 0.1) as float
		var old_level: float = _trend_levels[sid] as float
		var delta: float = randf_range(-volatility, volatility)
		var new_level: float = clampf(
			old_level + delta, MIN_LEVEL, MAX_LEVEL
		)
		_trend_levels[sid] = new_level
		_maybe_emit_trend_shifted(sid, old_level, new_level)


## Emits trend_shifted when the level change meets or exceeds SHIFT_THRESHOLD.
func _maybe_emit_trend_shifted(
	category_id: StringName, old_level: float, new_level: float
) -> void:
	if absf(new_level - old_level) >= SHIFT_THRESHOLD:
		EventBus.trend_shifted.emit(category_id, new_level)
