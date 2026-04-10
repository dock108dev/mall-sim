## Monitors frame performance and manages caching for market value calculations.
class_name PerformanceManager
extends Node


## Emitted when performance drops below target for sustained period.
signal performance_warning(avg_fps: float, worst_frame_ms: float)

const TARGET_FPS: float = 60.0
const FRAME_BUDGET_MS: float = 16.67
const WARNING_THRESHOLD_FPS: float = 55.0
const SAMPLE_WINDOW: int = 120
const WARNING_COOLDOWN: float = 10.0

## Market value cache: item_instance_id -> {value, day, minute}
var _market_value_cache: Dictionary = {}
const CACHE_TTL_MINUTES: int = 5

var _frame_times: PackedFloat64Array = PackedFloat64Array()
var _frame_index: int = 0
var _warning_timer: float = 0.0
var _economy_system: EconomySystem = null
var _current_day: int = 0
var _current_minute: int = 0


func initialize(economy_system: EconomySystem = null) -> void:
	_economy_system = economy_system
	_frame_times.resize(SAMPLE_WINDOW)
	_frame_times.fill(FRAME_BUDGET_MS)
	_frame_index = 0
	EventBus.day_started.connect(_on_day_started)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.inventory_changed.connect(_on_inventory_changed)


func set_economy_system(system: EconomySystem) -> void:
	_economy_system = system


func _process(delta: float) -> void:
	var frame_ms: float = delta * 1000.0
	_frame_times[_frame_index] = frame_ms
	_frame_index = (_frame_index + 1) % SAMPLE_WINDOW

	if _warning_timer > 0.0:
		_warning_timer -= delta
		return

	if _frame_index == 0:
		_check_performance()


## Returns a cached market value for an item, recalculating only when stale.
func get_cached_market_value(item: ItemInstance) -> float:
	if not item or not _economy_system:
		return 0.0
	var cache_key: String = item.instance_id
	if _market_value_cache.has(cache_key):
		var entry: Dictionary = _market_value_cache[cache_key]
		var cached_day: int = entry.get("day", -1) as int
		var cached_minute: int = entry.get("minute", -1) as int
		if cached_day == _current_day:
			if (_current_minute - cached_minute) < CACHE_TTL_MINUTES:
				return entry.get("value", 0.0) as float
	var value: float = _economy_system.calculate_market_value(item)
	_market_value_cache[cache_key] = {
		"value": value,
		"day": _current_day,
		"minute": _current_minute,
	}
	return value


## Invalidates cache for a specific item.
func invalidate_item_cache(item_id: String) -> void:
	_market_value_cache.erase(item_id)


## Clears the entire market value cache.
func clear_market_value_cache() -> void:
	_market_value_cache.clear()


## Returns the average FPS over the sample window.
func get_average_fps() -> float:
	var total_ms: float = 0.0
	for i: int in range(SAMPLE_WINDOW):
		total_ms += _frame_times[i]
	var avg_ms: float = total_ms / float(SAMPLE_WINDOW)
	if avg_ms <= 0.0:
		return TARGET_FPS
	return 1000.0 / avg_ms


## Returns the worst frame time in ms over the sample window.
func get_worst_frame_ms() -> float:
	var worst: float = 0.0
	for i: int in range(SAMPLE_WINDOW):
		if _frame_times[i] > worst:
			worst = _frame_times[i]
	return worst


## Returns performance statistics as a dictionary.
func get_performance_stats() -> Dictionary:
	return {
		"average_fps": get_average_fps(),
		"worst_frame_ms": get_worst_frame_ms(),
		"cache_entries": _market_value_cache.size(),
		"target_fps": TARGET_FPS,
	}


func _check_performance() -> void:
	var avg_fps: float = get_average_fps()
	if avg_fps < WARNING_THRESHOLD_FPS:
		_warning_timer = WARNING_COOLDOWN
		var worst_ms: float = get_worst_frame_ms()
		push_warning(
			"PerformanceManager: avg FPS %.1f (worst frame %.1fms)"
			% [avg_fps, worst_ms]
		)
		performance_warning.emit(avg_fps, worst_ms)


func _on_day_started(day: int) -> void:
	_current_day = day
	_current_minute = 0
	clear_market_value_cache()


func _on_hour_changed(hour: int) -> void:
	_current_minute = hour * Constants.MINUTES_PER_HOUR


func _on_item_sold(item_id: String, _price: float, _cat: String) -> void:
	invalidate_item_cache(item_id)


func _on_inventory_changed() -> void:
	clear_market_value_cache()
