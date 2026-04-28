## Manages market event selection, lifecycle, and trend multiplier calculation.
class_name MarketEventSystem
extends Node


enum Phase {
	NONE,
	ANNOUNCEMENT,
	RAMP_UP,
	FULL_EFFECT,
	RAMP_DOWN,
	COOLDOWN,
}

const MAX_CONCURRENT_EVENTS: int = 2
const BASE_EVENT_CHANCE: float = 0.15
const BONUS_CHANCE_PER_DAY: float = 0.05
const BONUS_THRESHOLD_DAYS: int = 5
const GUARANTEED_EVENT_DAYS: int = 15
const TREND_MULT_MIN: float = 0.4
const TREND_MULT_MAX: float = 3.0

## All event definitions loaded from JSON, keyed by id.
var _event_definitions: Array[MarketEventDefinition] = []

## Currently active event instances (announced, ramping, or in effect).
var _active_events: Array[Dictionary] = []

## Cooldown tracker: event_id -> days remaining.
var _cooldowns: Dictionary = {}

## Days since the last event was activated (not announced).
var _days_since_last_event: int = 0


func initialize() -> void:
	_event_definitions = []
	if GameManager.data_loader:
		_event_definitions = GameManager.data_loader.get_all_market_events()
	_apply_state({})
	EventBus.day_started.connect(_on_day_started)


## Returns the combined trend multiplier for an item based on active events.
func get_trend_multiplier(item: ItemInstance) -> float:
	if not item or not item.definition:
		return 1.0
	var combined: float = 1.0
	for event_data: Dictionary in _active_events:
		var phase: int = event_data.get("phase", Phase.NONE) as int
		if phase == Phase.ANNOUNCEMENT or phase == Phase.COOLDOWN:
			continue
		var def: MarketEventDefinition = event_data.get(
			"definition", null
		) as MarketEventDefinition
		if not def:
			continue
		if not _item_matches_event(item.definition, def):
			continue
		var mult: float = _calc_phase_multiplier(event_data)
		combined *= mult
	return clampf(combined, TREND_MULT_MIN, TREND_MULT_MAX)


## Returns all currently active event instances (for UI display).
func get_active_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for evt: Dictionary in _active_events:
		result.append(evt.duplicate())
	return result


## Returns the combined demand multiplier for a category from active events.
func get_category_demand_multiplier(category: StringName) -> float:
	if category.is_empty():
		return 1.0
	var combined: float = 1.0
	for event_data: Dictionary in _active_events:
		var phase: int = event_data.get("phase", Phase.NONE) as int
		if phase == Phase.ANNOUNCEMENT or phase == Phase.COOLDOWN:
			continue
		var def: MarketEventDefinition = event_data.get(
			"definition", null
		) as MarketEventDefinition
		if not def:
			continue
		if not _category_matches_event(category, def):
			continue
		var mult: float = _calc_phase_multiplier(event_data)
		combined *= mult
	return clampf(combined, TREND_MULT_MIN, TREND_MULT_MAX)


## Returns the number of events that are past announcement phase.
func get_active_effect_count() -> int:
	var count: int = 0
	for evt: Dictionary in _active_events:
		var phase: int = evt.get("phase", Phase.NONE) as int
		if phase != Phase.ANNOUNCEMENT and phase != Phase.COOLDOWN:
			count += 1
	return count


## Serializes state for saving.
func get_save_data() -> Dictionary:
	var serialized_events: Array[Dictionary] = []
	for evt: Dictionary in _active_events:
		var save_evt: Dictionary = evt.duplicate()
		var def: MarketEventDefinition = evt.get(
			"definition", null
		) as MarketEventDefinition
		if def:
			save_evt["definition_id"] = def.id
			save_evt.erase("definition")
		serialized_events.append(save_evt)
	return {
		"active_events": serialized_events,
		"cooldowns": _cooldowns.duplicate(),
		"days_since_last_event": _days_since_last_event,
	}


## Restores state from saved data.
func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_days_since_last_event = int(
		data.get("days_since_last_event", 0)
	)
	_cooldowns = {}
	var saved_cooldowns: Variant = data.get("cooldowns", {})
	if saved_cooldowns is Dictionary:
		_cooldowns = (saved_cooldowns as Dictionary).duplicate()
	_active_events = []
	var saved_events: Array = data.get("active_events", [])
	for entry: Variant in saved_events:
		if not entry is Dictionary:
			continue
		var evt: Dictionary = entry as Dictionary
		var def_id: String = evt.get("definition_id", "")
		if def_id.is_empty():
			continue
		var def: MarketEventDefinition = _find_definition(def_id)
		if not def:
			push_warning(
				"MarketEventSystem: saved event def '%s' not found"
				% def_id
			)
			continue
		evt["definition"] = def
		evt.erase("definition_id")
		_active_events.append(evt)


func _on_day_started(day: int) -> void:
	# Day 1 quarantine: no market events should announce, start, or end on Day 1.
	# The system has no active events at session start, so skipping the lifecycle
	# advance is safe; the cooldown/selection skip prevents new events from firing.
	if day <= 1:
		return
	_advance_event_lifecycles(day)
	_tick_cooldowns()
	_days_since_last_event += 1
	_try_select_new_event(day)


func _advance_event_lifecycles(day: int) -> void:
	var to_remove: Array[int] = []
	for i: int in range(_active_events.size()):
		var evt: Dictionary = _active_events[i]
		var def: MarketEventDefinition = evt.get(
			"definition", null
		) as MarketEventDefinition
		if not def:
			to_remove.append(i)
			continue
		var announced_day: int = evt.get("announced_day", day) as int
		var old_phase: int = evt.get("phase", Phase.NONE) as int
		var new_phase: int = _determine_phase(day, announced_day, def)
		evt["phase"] = new_phase
		if old_phase != new_phase:
			_handle_phase_transition(evt, old_phase, new_phase, def)
		var end_day: int = announced_day + def.announcement_days + def.duration_days
		if day >= end_day:
			to_remove.append(i)
			_cooldowns[def.id] = def.cooldown_days
			EventBus.market_event_ended.emit(def.id)
			EventBus.market_event_expired.emit(StringName(def.id))
	for i: int in range(to_remove.size() - 1, -1, -1):
		_active_events.remove_at(to_remove[i])


func _determine_phase(
	current_day: int,
	announced_day: int,
	def: MarketEventDefinition,
) -> int:
	var start_day: int = announced_day + def.announcement_days
	if current_day < start_day:
		return Phase.ANNOUNCEMENT
	var days_active: int = current_day - start_day
	if days_active < def.ramp_up_days:
		return Phase.RAMP_UP
	var ramp_down_start: int = def.duration_days - def.ramp_down_days
	if days_active >= ramp_down_start:
		return Phase.RAMP_DOWN
	return Phase.FULL_EFFECT


func _handle_phase_transition(
	_evt: Dictionary,
	old_phase: int,
	new_phase: int,
	def: MarketEventDefinition,
) -> void:
	if new_phase == Phase.RAMP_UP and old_phase == Phase.ANNOUNCEMENT:
		EventBus.market_event_started.emit(def.id)
		_days_since_last_event = 0
		if not def.active_text.is_empty():
			EventBus.notification_requested.emit(def.active_text)
		EventBus.market_event_active.emit(
			StringName(def.id), _build_event_modifier(def)
		)


# gdlint:disable=max-returns
func _calc_phase_multiplier(event_data: Dictionary) -> float:
	var def: MarketEventDefinition = event_data.get(
		"definition", null
	) as MarketEventDefinition
	if not def:
		return 1.0
	var phase: int = event_data.get("phase", Phase.NONE) as int
	var announced_day: int = event_data.get("announced_day", 0) as int
	var start_day: int = announced_day + def.announcement_days
	var days_active: int = GameManager.current_day - start_day
	match phase:
		Phase.RAMP_UP:
			if def.ramp_up_days <= 0:
				return def.magnitude
			var t: float = float(days_active) / float(def.ramp_up_days)
			return lerpf(1.0, def.magnitude, clampf(t, 0.0, 1.0))
		Phase.FULL_EFFECT:
			return def.magnitude
		Phase.RAMP_DOWN:
			if def.ramp_down_days <= 0:
				return def.magnitude
			var rd_start: int = def.duration_days - def.ramp_down_days
			var t: float = (
				float(days_active - rd_start) / float(def.ramp_down_days)
			)
			return lerpf(def.magnitude, 1.0, clampf(t, 0.0, 1.0))
		_:
			return 1.0


## Ticks down all cooldown counters by one day.
# gdlint:enable=max-returns
func _tick_cooldowns() -> void:
	var expired: Array[String] = []
	for event_id: String in _cooldowns:
		var remaining: int = (_cooldowns[event_id] as int) - 1
		if remaining <= 0:
			expired.append(event_id)
		else:
			_cooldowns[event_id] = remaining
	for event_id: String in expired:
		_cooldowns.erase(event_id)


## Rolls for a new event and selects one if the roll succeeds.
func _try_select_new_event(day: int) -> void:
	if get_active_effect_count() >= MAX_CONCURRENT_EVENTS:
		return
	var chance: float = BASE_EVENT_CHANCE
	if _days_since_last_event >= BONUS_THRESHOLD_DAYS:
		chance += (
			float(_days_since_last_event - BONUS_THRESHOLD_DAYS + 1)
			* BONUS_CHANCE_PER_DAY
		)
	var forced: bool = _days_since_last_event >= GUARANTEED_EVENT_DAYS
	if not forced and randf() > chance:
		return
	var candidates: Array[MarketEventDefinition] = _get_candidates()
	if candidates.is_empty():
		return
	var selected: MarketEventDefinition = _weighted_select(candidates)
	if not selected:
		return
	_activate_event(selected, day)


## Returns event definitions eligible for activation right now.
func _get_candidates() -> Array[MarketEventDefinition]:
	var result: Array[MarketEventDefinition] = []
	var active_ids: Dictionary = {}
	for evt: Dictionary in _active_events:
		var def: MarketEventDefinition = evt.get(
			"definition", null
		) as MarketEventDefinition
		if def:
			active_ids[def.id] = true
	for def: MarketEventDefinition in _event_definitions:
		if active_ids.has(def.id):
			continue
		if _cooldowns.has(def.id):
			continue
		if _has_tag_overlap_with_active(def):
			continue
		result.append(def)
	return result


## Checks if a candidate event has overlapping tags with any active event.
func _has_tag_overlap_with_active(
	candidate: MarketEventDefinition,
) -> bool:
	if candidate.target_tags.is_empty():
		return false
	for evt: Dictionary in _active_events:
		var active_def: MarketEventDefinition = evt.get(
			"definition", null
		) as MarketEventDefinition
		if not active_def:
			continue
		for tag: String in candidate.target_tags:
			if tag in active_def.target_tags:
				return true
	return false


## Selects an event from candidates using weighted random selection.
func _weighted_select(
	candidates: Array[MarketEventDefinition],
) -> MarketEventDefinition:
	var total_weight: float = 0.0
	for def: MarketEventDefinition in candidates:
		total_weight += def.weight
	if total_weight <= 0.0:
		return null
	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for def: MarketEventDefinition in candidates:
		cumulative += def.weight
		if roll <= cumulative:
			return def
	return candidates[candidates.size() - 1]


## Creates an active event instance from a definition.
func _activate_event(
	def: MarketEventDefinition, day: int
) -> void:
	var evt: Dictionary = {
		"definition": def,
		"announced_day": day,
		"phase": Phase.ANNOUNCEMENT if def.announcement_days > 0
			else Phase.RAMP_UP,
	}
	_active_events.append(evt)
	if def.announcement_days > 0:
		EventBus.market_event_announced.emit(def.id)
		if not def.announcement_text.is_empty():
			EventBus.notification_requested.emit(def.announcement_text)
	# If no announcement phase, fire started immediately
	if def.announcement_days <= 0:
		EventBus.market_event_started.emit(def.id)
		_days_since_last_event = 0
		if not def.active_text.is_empty():
			EventBus.notification_requested.emit(def.active_text)
		EventBus.market_event_active.emit(
			StringName(def.id), _build_event_modifier(def)
		)


## Checks whether an item definition matches an event's targeting filters.
func _item_matches_event(
	item_def: ItemDefinition,
	event_def: MarketEventDefinition,
) -> bool:
	# Check category filter
	if not event_def.target_categories.is_empty():
		if not item_def.category in event_def.target_categories:
			return false
	# Check tag filter — if event has no tags, it affects all matching items
	if not event_def.target_tags.is_empty():
		var has_match: bool = false
		for tag: String in event_def.target_tags:
			if tag in item_def.tags:
				has_match = true
				break
		if not has_match:
			return false
	return true


## Checks whether a category matches an event's targeting filters.
func _category_matches_event(
	category: StringName,
	event_def: MarketEventDefinition,
) -> bool:
	if event_def.target_categories.is_empty():
		return true
	return String(category) in event_def.target_categories


func _find_definition(id: String) -> MarketEventDefinition:
	for def: MarketEventDefinition in _event_definitions:
		if def.id == id:
			return def
	return null


## Builds the modifier dictionary emitted with market_event_active.
func _build_event_modifier(def: MarketEventDefinition) -> Dictionary:
	return {
		"spawn_rate_multiplier": def.magnitude,
		"purchase_intent_multiplier": def.magnitude,
	}
