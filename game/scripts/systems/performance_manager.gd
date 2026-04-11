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

var _market_value_cache: Dictionary = {}
const CACHE_TTL_MINUTES: int = 5
var _cache_hits: int = 0
var _cache_misses: int = 0
var _last_store_switch_ms: float = 0.0
var _store_switch_start_usec: int = 0

## NPC profiling: rolling window of per-frame NPC subsystem costs in ms.
const NPC_SAMPLE_WINDOW: int = 60
var _npc_script_times: PackedFloat64Array = PackedFloat64Array()
var _npc_navigation_times: PackedFloat64Array = PackedFloat64Array()
var _npc_animation_times: PackedFloat64Array = PackedFloat64Array()
var _npc_sample_index: int = 0
var _npc_count_samples: PackedInt32Array = PackedInt32Array()

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
	_npc_script_times.resize(NPC_SAMPLE_WINDOW)
	_npc_script_times.fill(0.0)
	_npc_navigation_times.resize(NPC_SAMPLE_WINDOW)
	_npc_navigation_times.fill(0.0)
	_npc_animation_times.resize(NPC_SAMPLE_WINDOW)
	_npc_animation_times.fill(0.0)
	_npc_count_samples.resize(NPC_SAMPLE_WINDOW)
	_npc_count_samples.fill(0)
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
				_cache_hits += 1
				return entry.get("value", 0.0) as float
	_cache_misses += 1
	var value: float = _economy_system.calculate_market_value(item)
	_market_value_cache[cache_key] = {
		"value": value,
		"day": _current_day,
		"minute": _current_minute,
	}
	return value


## Returns the cache hit rate as a percentage (0.0 to 100.0).
func get_cache_hit_rate() -> float:
	var total: int = _cache_hits + _cache_misses
	if total == 0:
		return 0.0
	return (float(_cache_hits) / float(total)) * 100.0


## Returns raw cache hit and miss counts.
func get_cache_stats() -> Dictionary:
	return {
		"hits": _cache_hits,
		"misses": _cache_misses,
		"hit_rate": get_cache_hit_rate(),
		"entries": _market_value_cache.size(),
	}


## Resets cache hit/miss counters.
func reset_cache_counters() -> void:
	_cache_hits = 0
	_cache_misses = 0


## Invalidates cache for a specific item.
func invalidate_item_cache(item_id: String) -> void:
	_market_value_cache.erase(item_id)


## Clears the entire market value cache.
func clear_market_value_cache() -> void:
	_market_value_cache.clear()


## Call when store switch begins to start the timer.
func begin_store_switch() -> void:
	_store_switch_start_usec = Time.get_ticks_usec()


## Call when store switch completes to record duration.
func end_store_switch() -> void:
	if _store_switch_start_usec > 0:
		var elapsed_usec: int = (
			Time.get_ticks_usec() - _store_switch_start_usec
		)
		_last_store_switch_ms = float(elapsed_usec) / 1000.0
		_store_switch_start_usec = 0
		if _last_store_switch_ms > 500.0:
			push_warning(
				"PerformanceManager: store switch took %.1fms "
				% _last_store_switch_ms
				+ "(target: <500ms)"
			)


## Returns the last store switch duration in milliseconds.
func get_last_store_switch_ms() -> float:
	return _last_store_switch_ms


## Estimates memory footprint for a list of UI panel nodes in bytes.
static func estimate_panel_memory(panels: Array[Node]) -> Dictionary:
	var total_bytes: int = 0
	var panel_details: Array[Dictionary] = []
	for panel: Node in panels:
		var size: int = _estimate_node_tree_size(panel)
		total_bytes += size
		panel_details.append({
			"name": panel.name,
			"bytes": size,
			"children": panel.get_child_count(),
		})
	return {
		"total_bytes": total_bytes,
		"total_kb": float(total_bytes) / 1024.0,
		"panel_count": panels.size(),
		"panels": panel_details,
	}


## Recursively estimates memory for a node tree.
static func _estimate_node_tree_size(node: Node) -> int:
	## Base overhead per node: name string + transform + metadata (~256 bytes).
	var size: int = 256
	if node is Control:
		## Controls carry layout, theme, and style data (~512 bytes extra).
		size += 512
	for child: Node in node.get_children():
		size += _estimate_node_tree_size(child)
	return size


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


## Records NPC subsystem timing for a single frame.
func record_npc_frame(
	script_ms: float,
	navigation_ms: float,
	animation_ms: float,
	npc_count: int
) -> void:
	_npc_script_times[_npc_sample_index] = script_ms
	_npc_navigation_times[_npc_sample_index] = navigation_ms
	_npc_animation_times[_npc_sample_index] = animation_ms
	_npc_count_samples[_npc_sample_index] = npc_count
	_npc_sample_index = (_npc_sample_index + 1) % NPC_SAMPLE_WINDOW


## Returns average NPC subsystem costs over the sample window.
func get_npc_performance_stats() -> Dictionary:
	var total_script: float = 0.0
	var total_nav: float = 0.0
	var total_anim: float = 0.0
	var peak_total: float = 0.0
	var valid_samples: int = 0
	for i: int in range(NPC_SAMPLE_WINDOW):
		var frame_total: float = (
			_npc_script_times[i]
			+ _npc_navigation_times[i]
			+ _npc_animation_times[i]
		)
		if _npc_count_samples[i] > 0:
			valid_samples += 1
		total_script += _npc_script_times[i]
		total_nav += _npc_navigation_times[i]
		total_anim += _npc_animation_times[i]
		if frame_total > peak_total:
			peak_total = frame_total
	var divisor: float = maxf(float(NPC_SAMPLE_WINDOW), 1.0)
	return {
		"avg_script_ms": total_script / divisor,
		"avg_navigation_ms": total_nav / divisor,
		"avg_animation_ms": total_anim / divisor,
		"avg_total_ms": (total_script + total_nav + total_anim) / divisor,
		"peak_total_ms": peak_total,
		"sample_count": valid_samples,
	}


## Returns performance statistics as a dictionary.
func get_performance_stats() -> Dictionary:
	var npc_stats: Dictionary = get_npc_performance_stats()
	var cache_stats: Dictionary = get_cache_stats()
	return {
		"average_fps": get_average_fps(),
		"worst_frame_ms": get_worst_frame_ms(),
		"cache_entries": cache_stats.get("entries", 0),
		"cache_hit_rate": cache_stats.get("hit_rate", 0.0),
		"cache_hits": cache_stats.get("hits", 0),
		"cache_misses": cache_stats.get("misses", 0),
		"target_fps": TARGET_FPS,
		"last_store_switch_ms": _last_store_switch_ms,
		"npc_avg_total_ms": npc_stats.get("avg_total_ms", 0.0),
		"npc_peak_total_ms": npc_stats.get("peak_total_ms", 0.0),
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
