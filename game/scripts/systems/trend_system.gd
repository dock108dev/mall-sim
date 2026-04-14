## Manages periodic hot/cold demand trends that shift item category and tag values.
class_name TrendSystem
extends Node


enum TrendType {
	HOT,
	COLD,
}

const MIN_SHIFT_INTERVAL: int = 7
const MAX_SHIFT_INTERVAL: int = 10
const MIN_TREND_DURATION: int = 5
const MAX_TREND_DURATION: int = 8
const FADE_DAYS: int = 2
const ANNOUNCEMENT_DAYS: int = 1
const HOT_MULT_MIN: float = 1.5
const HOT_MULT_MAX: float = 2.0
const COLD_MULT_MIN: float = 0.5
const COLD_MULT_MAX: float = 0.7
const MIN_TRENDS_PER_SHIFT: int = 2
const MAX_TRENDS_PER_SHIFT: int = 3
## Weight boost per sale in a category toward trending probability.
const SALES_INFLUENCE_WEIGHT: float = 0.1
const TREND_MULT_MIN: float = 0.4
const TREND_MULT_MAX: float = 3.0

## Active trend entries. Each is a Dictionary with keys:
## target_type ("category" or "tag"), target (String), trend_type (TrendType),
## multiplier (float), announced_day (int), active_day (int),
## end_day (int), fade_end_day (int).
var _active_trends: Array[Dictionary] = []

## Days remaining until the next trend shift is scheduled.
var _days_until_next_shift: int = 0

## Cumulative sales per category since last shift (influences selection).
var _sales_since_shift: Dictionary = {}

## Reference to DataLoader for querying available categories and tags.
var _data_loader: DataLoader = null

## All category StringNames that have ever had an active trend — used to
## broadcast reset (1.0) when a trend expires.
var _tracked_categories: Dictionary = {}


func initialize(data_loader: DataLoader = null) -> void:
	_data_loader = data_loader
	_apply_state({})
	EventBus.day_started.connect(_on_day_started)
	EventBus.item_sold.connect(_on_item_sold)


## Returns the combined trend multiplier for an item from active trends.
func get_trend_multiplier(item: ItemInstance) -> float:
	return get_trend_multiplier_scaled(item, 1.0)


## Returns the combined trend multiplier with trend durations scaled by duration_scale.
## duration_scale > 1.0 extends trend longevity; < 1.0 shortens it.
func get_trend_multiplier_scaled(
	item: ItemInstance, duration_scale: float
) -> float:
	if not item or not item.definition:
		return 1.0
	var combined: float = 1.0
	var current_day: int = GameManager.current_day
	for trend: Dictionary in _active_trends:
		if not _item_matches_trend(item.definition, trend):
			continue
		var mult: float = _calc_trend_multiplier_scaled(
			trend, current_day, duration_scale
		)
		combined *= mult
	return clampf(combined, TREND_MULT_MIN, TREND_MULT_MAX)


## Returns all active trends for UI display (deep copies).
func get_active_trends() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for trend: Dictionary in _active_trends:
		var copy: Dictionary = trend.duplicate()
		copy["trend_type_name"] = _trend_type_name(
			copy.get("trend_type", TrendType.HOT) as int
		)
		result.append(copy)
	return result


## Returns only trends that are currently in effect (past announcement).
func get_effective_trends() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var current_day: int = GameManager.current_day
	for trend: Dictionary in _active_trends:
		var active_day: int = trend.get("active_day", 0) as int
		if current_day >= active_day:
			var copy: Dictionary = trend.duplicate()
			copy["trend_type_name"] = _trend_type_name(
				copy.get("trend_type", TrendType.HOT) as int
			)
			result.append(copy)
	return result


## Returns the combined effective multiplier for a category from active trends.
## Returns 1.0 if the category has no active trend.
func get_category_multiplier(category: StringName) -> float:
	var combined: float = 1.0
	var current_day: int = GameManager.current_day
	for trend: Dictionary in _active_trends:
		if trend.get("target_type", "") != "category":
			continue
		if StringName(trend.get("target", "")) != category:
			continue
		combined *= _calc_trend_multiplier(trend, current_day)
	return clampf(combined, TREND_MULT_MIN, TREND_MULT_MAX)


## Serializes trend state for saving.
func get_save_data() -> Dictionary:
	var serialized: Array[Dictionary] = []
	for trend: Dictionary in _active_trends:
		serialized.append(trend.duplicate())
	return {
		"active_trends": serialized,
		"days_until_next_shift": _days_until_next_shift,
		"sales_since_shift": _sales_since_shift.duplicate(),
	}


## Restores trend state from saved data.
func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_days_until_next_shift = int(
		data.get("days_until_next_shift", randi_range(
			MIN_SHIFT_INTERVAL, MAX_SHIFT_INTERVAL
		))
	)
	_active_trends = []
	var saved_trends: Array = data.get("active_trends", [])
	for entry: Variant in saved_trends:
		if entry is Dictionary:
			_active_trends.append(
				(entry as Dictionary).duplicate()
			)
	_sales_since_shift = {}
	var saved_sales: Variant = data.get("sales_since_shift", {})
	if saved_sales is Dictionary:
		_sales_since_shift = (saved_sales as Dictionary).duplicate()
	_rebuild_tracked_categories()


func _on_day_started(_day: int) -> void:
	_remove_expired_trends(_day)
	_days_until_next_shift -= 1
	if _days_until_next_shift <= 0:
		_generate_new_trends(_day)
		_days_until_next_shift = randi_range(
			MIN_SHIFT_INTERVAL, MAX_SHIFT_INTERVAL
		)
		_sales_since_shift = {}
	_activate_announced_trends(_day)
	_broadcast_trend_updates()


func _on_item_sold(
	_item_id: String, _price: float, category: String
) -> void:
	if category.is_empty():
		return
	var current: float = _sales_since_shift.get(category, 0.0) as float
	_sales_since_shift[category] = current + 1.0


## Removes trends whose fade period has ended.
func _remove_expired_trends(day: int) -> void:
	var remaining: Array[Dictionary] = []
	for trend: Dictionary in _active_trends:
		var fade_end: int = trend.get("fade_end_day", 0) as int
		if day < fade_end:
			remaining.append(trend)
	_active_trends = remaining


## Sends notifications for trends entering their active phase today.
func _activate_announced_trends(day: int) -> void:
	for trend: Dictionary in _active_trends:
		var active_day: int = trend.get("active_day", 0) as int
		if active_day == day:
			var target: String = trend.get("target", "")
			var type_int: int = trend.get(
				"trend_type", TrendType.HOT
			) as int
			var label: String = _trend_type_name(type_int)
			EventBus.notification_requested.emit(
				"Trend now active: %s is %s!" % [target, label]
			)


## Generates a new set of hot and cold trends.
func _generate_new_trends(day: int) -> void:
	var categories: Array[String] = _get_available_categories()
	var tags: Array[String] = _get_available_tags()
	var pool: Array[Dictionary] = _build_target_pool(categories, tags)
	if pool.is_empty():
		return

	var hot_count: int = randi_range(
		MIN_TRENDS_PER_SHIFT, MAX_TRENDS_PER_SHIFT
	)
	var cold_count: int = randi_range(
		MIN_TRENDS_PER_SHIFT, MAX_TRENDS_PER_SHIFT
	)

	var used_targets: Dictionary = {}
	var hot_trends: Array[Dictionary] = _select_trends(
		pool, hot_count, TrendType.HOT, day, used_targets
	)
	var cold_trends: Array[Dictionary] = _select_trends(
		pool, cold_count, TrendType.COLD, day, used_targets
	)

	for trend: Dictionary in hot_trends:
		_active_trends.append(trend)
		if trend.get("target_type", "") == "category":
			_tracked_categories[StringName(trend.get("target", ""))] = true
	for trend: Dictionary in cold_trends:
		_active_trends.append(trend)
		if trend.get("target_type", "") == "category":
			_tracked_categories[StringName(trend.get("target", ""))] = true

	_emit_trend_changed()
	_announce_new_trends(hot_trends, cold_trends)


## Selects a number of trends from the pool using weighted random selection.
func _select_trends(
	pool: Array[Dictionary],
	count: int,
	trend_type: int,
	day: int,
	used_targets: Dictionary,
) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	var available: Array[Dictionary] = pool.duplicate()

	for _i: int in range(count):
		if available.is_empty():
			break
		var weights: Array[float] = _calc_weights(
			available, trend_type, used_targets
		)
		var idx: int = _weighted_random_index(weights)
		if idx < 0:
			break

		var entry: Dictionary = available[idx]
		var target: String = entry.get("target", "")
		used_targets[target] = true
		available.remove_at(idx)

		var duration: int = randi_range(
			MIN_TREND_DURATION, MAX_TREND_DURATION
		)
		var multiplier: float = _random_multiplier(trend_type)
		var trend: Dictionary = {
			"target_type": entry.get("target_type", "category"),
			"target": target,
			"trend_type": trend_type,
			"multiplier": multiplier,
			"announced_day": day,
			"active_day": day + ANNOUNCEMENT_DAYS,
			"end_day": day + ANNOUNCEMENT_DAYS + duration,
			"fade_end_day": day + ANNOUNCEMENT_DAYS + duration + FADE_DAYS,
		}
		selected.append(trend)
	return selected


## Calculates selection weights for targets, boosted by player sales.
func _calc_weights(
	pool: Array[Dictionary],
	trend_type: int,
	used_targets: Dictionary,
) -> Array[float]:
	var weights: Array[float] = []
	for entry: Dictionary in pool:
		var target: String = entry.get("target", "")
		if used_targets.has(target):
			weights.append(0.0)
			continue
		var base_weight: float = 1.0
		if trend_type == TrendType.HOT:
			var sales: float = _sales_since_shift.get(
				target, 0.0
			) as float
			base_weight += sales * SALES_INFLUENCE_WEIGHT
		weights.append(base_weight)
	return weights


## Returns a random index based on weights.
func _weighted_random_index(weights: Array[float]) -> int:
	var total: float = 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		return -1
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for i: int in range(weights.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return i
	return weights.size() - 1


## Returns a random multiplier for a given trend type.
func _random_multiplier(trend_type: int) -> float:
	if trend_type == TrendType.HOT:
		return randf_range(HOT_MULT_MIN, HOT_MULT_MAX)
	return randf_range(COLD_MULT_MIN, COLD_MULT_MAX)


## Calculates the effective multiplier for a trend on a given day.
func _calc_trend_multiplier(trend: Dictionary, day: int) -> float:
	return _calc_trend_multiplier_scaled(trend, day, 1.0)


## Calculates the effective multiplier with the active duration scaled by duration_scale.
func _calc_trend_multiplier_scaled(
	trend: Dictionary, day: int, duration_scale: float
) -> float:
	var active_day: int = trend.get("active_day", 0) as int
	var orig_end_day: int = trend.get("end_day", 0) as int
	var orig_fade_end: int = trend.get("fade_end_day", 0) as int
	var multiplier: float = trend.get("multiplier", 1.0) as float
	var duration: int = orig_end_day - active_day
	var fade_days: int = orig_fade_end - orig_end_day
	var effective_end: int = active_day + maxi(
		1, int(round(float(duration) * duration_scale))
	)
	var effective_fade: int = effective_end + fade_days

	if day < active_day:
		return 1.0
	if day >= active_day and day < effective_end:
		return multiplier
	if day >= effective_end and day < effective_fade:
		var fade_progress: float = (
			float(day - effective_end)
			/ float(maxi(effective_fade - effective_end, 1))
		)
		return lerpf(multiplier, 1.0, clampf(fade_progress, 0.0, 1.0))
	return 1.0


## Checks whether an item definition matches a trend's target.
func _item_matches_trend(
	item_def: ItemDefinition, trend: Dictionary
) -> bool:
	var target_type: String = trend.get("target_type", "") as String
	var target: String = trend.get("target", "") as String
	if target_type == "category":
		return item_def.category == target
	if target_type == "tag":
		return target in item_def.tags
	return false


## Builds a pool of targetable categories and tags from the DataLoader.
func _build_target_pool(
	categories: Array[String], tags: Array[String]
) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for cat: String in categories:
		pool.append({"target_type": "category", "target": cat})
	for tag: String in tags:
		pool.append({"target_type": "tag", "target": tag})
	return pool


## Returns unique categories from all item definitions.
func _get_available_categories() -> Array[String]:
	var result: Array[String] = []
	if not _data_loader:
		return result
	var seen: Dictionary = {}
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	for item: ItemDefinition in items:
		if not item.category.is_empty() and not seen.has(item.category):
			seen[item.category] = true
			result.append(item.category)
	return result


## Returns unique tags from all item definitions.
func _get_available_tags() -> Array[String]:
	var result: Array[String] = []
	if not _data_loader:
		return result
	var seen: Dictionary = {}
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	for item: ItemDefinition in items:
		for tag: String in item.tags:
			if not seen.has(tag):
				seen[tag] = true
				result.append(tag)
	return result


## Emits the trend_changed signal with current hot and cold lists.
func _emit_trend_changed() -> void:
	var hot: Array = []
	var cold: Array = []
	for trend: Dictionary in _active_trends:
		var type_int: int = trend.get(
			"trend_type", TrendType.HOT
		) as int
		var target: String = trend.get("target", "")
		if type_int == TrendType.HOT:
			hot.append(target)
		else:
			cold.append(target)
	EventBus.trend_changed.emit(hot, cold)


## Sends announcement notifications for newly generated trends.
func _announce_new_trends(
	hot_trends: Array[Dictionary],
	cold_trends: Array[Dictionary],
) -> void:
	var hot_names: PackedStringArray = []
	for trend: Dictionary in hot_trends:
		hot_names.append(trend.get("target", "unknown"))
	var cold_names: PackedStringArray = []
	for trend: Dictionary in cold_trends:
		cold_names.append(trend.get("target", "unknown"))

	if not hot_names.is_empty():
		EventBus.notification_requested.emit(
			"Trending tomorrow: %s" % ", ".join(hot_names)
		)
	if not cold_names.is_empty():
		EventBus.notification_requested.emit(
			"Cooling off tomorrow: %s" % ", ".join(cold_names)
		)


func _trend_type_name(trend_type: int) -> String:
	if trend_type == TrendType.HOT:
		return "trending"
	return "cold"


## Emits trend_updated for every tracked category so listeners can refresh caches.
## Categories with no active trend emit with multiplier 1.0 (no effect).
func _broadcast_trend_updates() -> void:
	for cat: Variant in _tracked_categories:
		var mult: float = get_category_multiplier(cat as StringName)
		EventBus.trend_updated.emit(cat as StringName, mult)


## Rebuilds _tracked_categories from the current active trend list (called on load).
func _rebuild_tracked_categories() -> void:
	for trend: Dictionary in _active_trends:
		if trend.get("target_type", "") == "category":
			_tracked_categories[StringName(trend.get("target", ""))] = true
