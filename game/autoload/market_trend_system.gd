## Tracks per-category market trend levels and shifts them daily.
class_name MarketTrendSystem
extends Node


const CATALOG_PATH: String = "res://game/content/market_trends_catalog.json"
const MIN_LEVEL: float = 0.2
const MAX_LEVEL: float = 2.0
const SHIFT_THRESHOLD: float = 0.05
const VOLATILITY_MIN: float = 0.0
const VOLATILITY_MAX: float = 2.0

## Bidirectional propagation rules: when a source category shifts, a weighted
## fraction of its deviation from 1.0 is applied to each target category.
## vintage ↔ sports: retro-games vintage shelf and sports-cards share demand.
const CROSS_PROPAGATION_RULES: Dictionary = {
	"vintage": {"sports": 0.4},
	"sports": {"vintage": 0.4},
}

var _trend_levels: Dictionary = {}
var _category_configs: Dictionary = {}
var _initialized: bool = false


func _ready() -> void:
	_load_catalog()
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.tournament_completed.connect(_on_tournament_completed)
	_initialized = true


## Returns base_trend + modifier (additive combination, applied before volatility scaling).
func apply_category_modifier(base_trend: float, modifier: float) -> float:
	return base_trend + modifier


## Clamps raw_volatility to the valid range [VOLATILITY_MIN, VOLATILITY_MAX].
static func _clamp_volatility(raw_volatility: float) -> float:
	return clampf(raw_volatility, VOLATILITY_MIN, VOLATILITY_MAX)


func get_trend_modifier(category_id: StringName) -> float:
	if not _trend_levels.has(category_id):
		push_warning(
			"MarketTrendSystem: unknown category '%s'" % category_id
		)
		return 1.0
	return _trend_levels[category_id] as float


func get_all_trend_levels() -> Dictionary:
	return _trend_levels.duplicate()


## Resets all trend levels to their configured defaults. For test isolation.
func reset() -> void:
	for id: StringName in _category_configs:
		var cfg: Dictionary = _category_configs[id]
		_trend_levels[id] = float(cfg.get("default_level", 1.0))


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
	var entries: Array = DataLoader.load_catalog_entries(CATALOG_PATH)
	if entries.is_empty():
		push_error(
			"MarketTrendSystem: no entries loaded from catalog '%s'"
			% CATALOG_PATH
		)
		return

	for entry: Variant in entries:
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
	_shift_trends()
	_apply_cross_propagations()


## Propagates weighted trend deviations between linked categories (e.g.,
## vintage ↔ sports) so that a shift in one store's shelf affects the other
## within the same day tick.
func _apply_cross_propagations() -> void:
	for source_key: Variant in CROSS_PROPAGATION_RULES:
		var source_id: StringName = StringName(str(source_key))
		if not _trend_levels.has(source_id):
			continue
		var source_delta: float = (_trend_levels[source_id] as float) - 1.0
		if absf(source_delta) < SHIFT_THRESHOLD:
			continue
		var rules: Dictionary = CROSS_PROPAGATION_RULES[source_key] as Dictionary
		for target_key: Variant in rules:
			var target_id: StringName = StringName(str(target_key))
			if not _trend_levels.has(target_id):
				continue
			var weight: float = float(rules[target_key])
			var old_level: float = _trend_levels[target_id] as float
			var nudge: float = source_delta * weight * 0.5
			var new_level: float = clampf(old_level + nudge, MIN_LEVEL, MAX_LEVEL)
			_trend_levels[target_id] = new_level
			_maybe_emit_trend_shifted(target_id, old_level, new_level)


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


## Applies a multiplicative spike to a trend category, clamped to MAX_LEVEL.
## Used by tournament completion to drive post-event demand surges.
func apply_spike(category_id: StringName, factor: float) -> void:
	if not _trend_levels.has(category_id):
		return
	var old_level: float = _trend_levels[category_id] as float
	var new_level: float = clampf(old_level * factor, MIN_LEVEL, MAX_LEVEL)
	_trend_levels[category_id] = new_level
	_maybe_emit_trend_shifted(category_id, old_level, new_level)


## Emits trend_shifted when the level change meets or exceeds SHIFT_THRESHOLD.
func _maybe_emit_trend_shifted(
	category_id: StringName, old_level: float, new_level: float
) -> void:
	if absf(new_level - old_level) >= SHIFT_THRESHOLD:
		EventBus.trend_shifted.emit(category_id, new_level)


func _on_tournament_completed(_participant_count: int, _revenue: float) -> void:
	apply_spike(&"singles", 1.3)
