## Manages product lifecycle phases and depreciation for consumer electronics.
class_name ElectronicsLifecycleManager
extends RefCounted


enum Phase { LAUNCH, PEAK, MATURE, CLEARANCE, OBSOLETE }

const PHASE_NAMES: Dictionary = {
	Phase.LAUNCH: "launch",
	Phase.PEAK: "peak",
	Phase.MATURE: "mature",
	Phase.CLEARANCE: "clearance",
	Phase.OBSOLETE: "obsolete",
}

const LAUNCH_END_DAY: int = 5
const PEAK_END_DAY: int = 15
const MATURE_END_DAY: int = 30

const LAUNCH_MULT_MAX: float = 1.5
const LAUNCH_MULT_MIN: float = 1.2
const PEAK_MULT: float = 1.0
const MATURE_MULT_MAX: float = 0.9
const MATURE_MULT_MIN: float = 0.7
const CLEARANCE_MULT_MAX: float = 0.5
const CLEARANCE_MULT_MIN: float = 0.3
const CLEARANCE_FADE_DAYS: int = 20
const OBSOLETE_MULT_MAX: float = 0.2
const OBSOLETE_MULT_MIN: float = 0.1

## product_line -> highest generation that has launched so far.
var _active_generations: Dictionary = {}

## product_line -> Array of {generation: int, launch_day: int} for future launches.
var _pending_launches: Array[Dictionary] = []

## product_line -> generation that was announced but not yet launched.
var _announced: Dictionary = {}

## Tracks which item_ids have had their phase-change signal emitted this day.
var _last_known_phases: Dictionary = {}


## Builds the launch schedule from all electronics ItemDefinitions.
func initialize(items: Array[ItemDefinition], current_day: int) -> void:
	_active_generations.clear()
	_pending_launches.clear()
	_announced.clear()

	for item: ItemDefinition in items:
		if item.store_type != "consumer_electronics":
			continue
		if item.product_line.is_empty():
			continue

		var effective_launch: int = item.launch_day
		if effective_launch <= 0:
			effective_launch = 1

		if effective_launch <= current_day:
			_register_launched(item.product_line, item.generation)
		else:
			_pending_launches.append({
				"product_line": item.product_line,
				"generation": item.generation,
				"launch_day": effective_launch,
			})

	_pending_launches.sort_custom(_sort_by_launch_day)
	_deduplicate_pending()


## Called at the start of each new day to process launches and announcements.
func process_day(current_day: int, items: Array[ItemDefinition]) -> void:
	_process_announcements(current_day)
	_process_launches(current_day, items)


## Returns the lifecycle Phase enum value for an item on the given day.
func get_phase(item: ItemDefinition, current_day: int) -> Phase:
	if item.product_line.is_empty():
		return Phase.PEAK

	var effective_launch: int = _get_effective_launch_day(item)
	if effective_launch > current_day:
		return Phase.PEAK

	var active_gen: int = _active_generations.get(
		item.product_line, item.generation
	)
	if item.generation < active_gen:
		return Phase.OBSOLETE

	var days_since: int = current_day - effective_launch
	if days_since < 0:
		days_since = 0

	if days_since <= LAUNCH_END_DAY:
		return Phase.LAUNCH
	if days_since <= PEAK_END_DAY:
		return Phase.PEAK
	if days_since <= MATURE_END_DAY:
		return Phase.MATURE
	return Phase.CLEARANCE


## Returns the human-readable phase name string.
func get_phase_name(item: ItemDefinition, current_day: int) -> String:
	return PHASE_NAMES[get_phase(item, current_day)]


## Returns the lifecycle price multiplier for an item on the given day.
func get_multiplier(item: ItemDefinition, current_day: int) -> float:
	var phase: Phase = get_phase(item, current_day)
	var effective_launch: int = _get_effective_launch_day(item)
	var days_since: int = maxi(0, current_day - effective_launch)

	match phase:
		Phase.LAUNCH:
			return _lerp_range(
				days_since, 1, LAUNCH_END_DAY,
				LAUNCH_MULT_MAX, LAUNCH_MULT_MIN
			)
		Phase.PEAK:
			return PEAK_MULT
		Phase.MATURE:
			return _lerp_range(
				days_since, PEAK_END_DAY + 1, MATURE_END_DAY,
				MATURE_MULT_MAX, MATURE_MULT_MIN
			)
		Phase.CLEARANCE:
			return _lerp_range(
				days_since, MATURE_END_DAY + 1,
				MATURE_END_DAY + CLEARANCE_FADE_DAYS,
				CLEARANCE_MULT_MAX, CLEARANCE_MULT_MIN
			)
		Phase.OBSOLETE:
			return _lerp_range(
				days_since, MATURE_END_DAY + 1,
				MATURE_END_DAY + CLEARANCE_FADE_DAYS,
				OBSOLETE_MULT_MAX, OBSOLETE_MULT_MIN
			)
	return PEAK_MULT


## Returns true if the item is available in the supplier catalog on this day.
func is_available_for_purchase(
	item: ItemDefinition, current_day: int
) -> bool:
	var effective_launch: int = _get_effective_launch_day(item)
	return current_day >= effective_launch


## Checks all tracked items and emits phase_changed signals where applicable.
func check_phase_transitions(
	items: Array[ItemDefinition], current_day: int
) -> void:
	for item: ItemDefinition in items:
		if item.store_type != "consumer_electronics":
			continue
		var current_phase_name: String = get_phase_name(item, current_day)
		var last_phase: String = _last_known_phases.get(item.id, "")
		if last_phase.is_empty():
			_last_known_phases[item.id] = current_phase_name
			continue
		if current_phase_name != last_phase:
			_last_known_phases[item.id] = current_phase_name
			EventBus.electronics_phase_changed.emit(
				item.id, last_phase, current_phase_name
			)


## Serializes lifecycle state for saving.
func get_save_data() -> Dictionary:
	var pending_copy: Array[Dictionary] = []
	for entry: Dictionary in _pending_launches:
		pending_copy.append(entry.duplicate())
	return {
		"active_generations": _active_generations.duplicate(),
		"pending_launches": pending_copy,
		"announced": _announced.duplicate(),
		"last_known_phases": _last_known_phases.duplicate(),
	}


## Restores lifecycle state from saved data.
func load_save_data(data: Dictionary) -> void:
	_active_generations.clear()
	_pending_launches.clear()
	_announced.clear()
	_last_known_phases.clear()

	var saved_gens: Variant = data.get("active_generations", {})
	if saved_gens is Dictionary:
		for key: String in saved_gens:
			_active_generations[key] = int(saved_gens[key])

	var saved_pending: Variant = data.get("pending_launches", [])
	if saved_pending is Array:
		for entry: Variant in saved_pending:
			if entry is Dictionary:
				_pending_launches.append(entry as Dictionary)

	var saved_announced: Variant = data.get("announced", {})
	if saved_announced is Dictionary:
		for key: String in saved_announced:
			_announced[key] = int(saved_announced[key])

	var saved_phases: Variant = data.get("last_known_phases", {})
	if saved_phases is Dictionary:
		for key: String in saved_phases:
			_last_known_phases[key] = str(saved_phases[key])


func _register_launched(product_line: String, generation: int) -> void:
	var current: int = _active_generations.get(product_line, 0)
	if generation > current:
		_active_generations[product_line] = generation


func _process_announcements(current_day: int) -> void:
	for entry: Dictionary in _pending_launches:
		var launch_day: int = entry.get("launch_day", 0) as int
		var line: String = entry.get("product_line", "") as String
		var gen: int = entry.get("generation", 0) as int
		var announce_day: int = launch_day - 3
		if current_day == announce_day and not _announced.has(line):
			_announced[line] = gen
			EventBus.electronics_product_announced.emit(
				line, gen, launch_day
			)


func _process_launches(
	current_day: int, items: Array[ItemDefinition]
) -> void:
	var launched_lines: Array[String] = []
	var i: int = 0
	while i < _pending_launches.size():
		var entry: Dictionary = _pending_launches[i]
		var launch_day: int = entry.get("launch_day", 0) as int
		if launch_day <= current_day:
			var line: String = entry.get("product_line", "") as String
			var gen: int = entry.get("generation", 0) as int
			_register_launched(line, gen)
			launched_lines.append(line)
			_announced.erase(line)
			EventBus.electronics_product_launched.emit(line, gen)
			_pending_launches.remove_at(i)
		else:
			i += 1

	if not launched_lines.is_empty():
		check_phase_transitions(items, current_day)


func _get_effective_launch_day(item: ItemDefinition) -> int:
	if item.launch_day > 0:
		return item.launch_day
	return 1


## Linearly interpolates a value within a day range, clamped.
func _lerp_range(
	day: int, day_start: int, day_end: int,
	value_start: float, value_end: float
) -> float:
	if day_end <= day_start:
		return value_end
	var t: float = clampf(
		float(day - day_start) / float(day_end - day_start), 0.0, 1.0
	)
	return lerpf(value_start, value_end, t)


static func _sort_by_launch_day(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("launch_day", 0)) < int(b.get("launch_day", 0))


## Removes duplicate product_line+generation entries from pending launches.
func _deduplicate_pending() -> void:
	var seen: Dictionary = {}
	var i: int = 0
	while i < _pending_launches.size():
		var entry: Dictionary = _pending_launches[i]
		var key: String = "%s_%d" % [
			entry.get("product_line", ""),
			entry.get("generation", 0),
		]
		if seen.has(key):
			_pending_launches.remove_at(i)
		else:
			seen[key] = true
			i += 1
