## Manages PocketCreatures competitive meta shifts that periodically alter card values.
class_name MetaShiftSystem
extends Node


const STORE_TYPE: String = "pocket_creatures"
const CARD_CATEGORY: String = "card_singles"

const MIN_SHIFT_INTERVAL: int = 7
const MAX_SHIFT_INTERVAL: int = 10
const ANNOUNCEMENT_LEAD_DAYS: int = 2

const MIN_CARDS_PER_DIRECTION: int = 2
const MAX_CARDS_PER_DIRECTION: int = 3

const SPIKE_MULT_MIN: float = 2.0
const SPIKE_MULT_MAX: float = 3.0
const DROP_MULT: float = 0.5

const SET_TAGS: Array[String] = [
	"base_set", "jungle", "fossil",
	"neo_genesis", "gym_heroes", "crystal_storm",
]

## Cards currently spiking. Each: {item_id, multiplier, set_tag, name}
var _rising_cards: Array[Dictionary] = []

## Cards currently dropping. Each: {item_id, multiplier, set_tag, name}
var _falling_cards: Array[Dictionary] = []

## Day the current shift takes effect (0 = no pending/active shift).
var _active_day: int = 0

## Day the current shift was announced (0 = none).
var _announced_day: int = 0

## Days until the next shift is announced.
var _days_until_next_announcement: int = 0

## Whether the current shift has been activated (past announcement period).
var _shift_active: bool = false

var _data_loader: DataLoader = null
var _manual_shift_days_remaining: int = 0


func initialize(data_loader: DataLoader) -> void:
	_data_loader = data_loader
	_apply_state({})
	EventBus.day_started.connect(_on_day_started)


## Returns the meta shift multiplier for an item. 1.0 if unaffected.
func get_meta_shift_multiplier(item: ItemInstance) -> float:
	if not item or not item.definition:
		return 1.0
	if item.definition.store_type != STORE_TYPE:
		return 1.0
	if item.definition.category != CARD_CATEGORY:
		return 1.0
	if not _shift_active:
		return 1.0
	for entry: Dictionary in _rising_cards:
		if entry.get("item_id", "") == item.definition.id:
			return entry.get("multiplier", 1.0) as float
	for entry: Dictionary in _falling_cards:
		if entry.get("item_id", "") == item.definition.id:
			return DROP_MULT
	return 1.0


## Returns the list of currently rising cards (deep copies).
func get_rising_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _rising_cards:
		result.append(entry.duplicate())
	return result


## Returns the list of currently falling cards (deep copies).
func get_falling_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _falling_cards:
		result.append(entry.duplicate())
	return result


## Returns true if a meta shift is currently active.
func is_shift_active() -> bool:
	return _shift_active


## Triggers an immediate single-card meta shift for the given duration.
func trigger_shift(card_id: StringName, duration_days: int) -> void:
	if card_id == StringName():
		push_warning("MetaShiftSystem: trigger_shift requires a card_id")
		return
	if duration_days <= 0:
		push_warning("MetaShiftSystem: trigger_shift duration must be positive")
		return

	_end_current_shift()

	var multiplier: float = SPIKE_MULT_MIN
	_rising_cards = [{
		"item_id": String(card_id),
		"name": String(card_id).capitalize(),
		"multiplier": multiplier,
		"set_tag": "manual",
	}]
	_falling_cards = []
	_active_day = 1
	_announced_day = 1
	_days_until_next_announcement = maxi(duration_days + 1, MIN_SHIFT_INTERVAL)
	_shift_active = true
	_manual_shift_days_remaining = duration_days

	EventBus.meta_shift_started.emit(card_id, multiplier, duration_days)
	EventBus.meta_shift_activated.emit(
		_extract_names(_rising_cards), _extract_names(_falling_cards)
	)


## Returns the demand modifier for the supplied card ID.
func get_demand_modifier(card_id: StringName) -> float:
	if not _shift_active or card_id == StringName():
		return 1.0
	for entry: Dictionary in _rising_cards:
		if StringName(entry.get("item_id", "")) == card_id:
			return float(entry.get("multiplier", 1.0))
	return 1.0


## Returns true if a shift has been announced but not yet active.
func is_shift_announced() -> bool:
	return _announced_day > 0 and not _shift_active


## Returns the day the next shift activates, or 0 if none pending.
func get_active_day() -> int:
	return _active_day


## Returns days remaining until the next announcement.
func get_days_until_next_announcement() -> int:
	return _days_until_next_announcement


## Serializes meta shift state for saving.
func get_save_data() -> Dictionary:
	var rising_copy: Array[Dictionary] = []
	for entry: Dictionary in _rising_cards:
		rising_copy.append(entry.duplicate())
	var falling_copy: Array[Dictionary] = []
	for entry: Dictionary in _falling_cards:
		falling_copy.append(entry.duplicate())
	return {
		"rising_cards": rising_copy,
		"falling_cards": falling_copy,
		"active_day": _active_day,
		"announced_day": _announced_day,
		"days_until_next_announcement": _days_until_next_announcement,
		"shift_active": _shift_active,
	}


## Restores meta shift state from saved data.
func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_rising_cards = []
	var saved_rising: Array = data.get("rising_cards", [])
	for entry: Variant in saved_rising:
		if entry is Dictionary:
			_rising_cards.append((entry as Dictionary).duplicate())

	_falling_cards = []
	var saved_falling: Array = data.get("falling_cards", [])
	for entry: Variant in saved_falling:
		if entry is Dictionary:
			_falling_cards.append((entry as Dictionary).duplicate())

	_active_day = int(data.get("active_day", 0))
	_announced_day = int(data.get("announced_day", 0))
	_days_until_next_announcement = int(
		data.get("days_until_next_announcement", randi_range(
			MIN_SHIFT_INTERVAL, MAX_SHIFT_INTERVAL
		))
	)
	_shift_active = bool(data.get("shift_active", false))
	_manual_shift_days_remaining = 0


func _on_day_started(day: int) -> void:
	if _shift_active and _manual_shift_days_remaining > 0:
		_manual_shift_days_remaining -= 1
		if _manual_shift_days_remaining <= 0:
			_end_current_shift()
			return

	if _announced_day > 0 and day >= _active_day and not _shift_active:
		_activate_shift()

	_days_until_next_announcement -= 1
	if _days_until_next_announcement <= 0:
		_announce_new_shift(day)


## Announces a new meta shift, ending any previous one.
func _announce_new_shift(day: int) -> void:
	_end_current_shift()

	var rising: Array[Dictionary] = _select_cards(
		randi_range(MIN_CARDS_PER_DIRECTION, MAX_CARDS_PER_DIRECTION),
		true
	)
	var falling: Array[Dictionary] = _select_cards(
		randi_range(MIN_CARDS_PER_DIRECTION, MAX_CARDS_PER_DIRECTION),
		false,
		_used_sets(rising)
	)

	if rising.is_empty() and falling.is_empty():
		_days_until_next_announcement = randi_range(
			MIN_SHIFT_INTERVAL, MAX_SHIFT_INTERVAL
		)
		return

	_rising_cards = rising
	_falling_cards = falling
	_announced_day = day
	_active_day = day + ANNOUNCEMENT_LEAD_DAYS
	_shift_active = false
	_days_until_next_announcement = randi_range(
		MIN_SHIFT_INTERVAL, MAX_SHIFT_INTERVAL
	)

	var rising_names: Array[String] = _extract_names(_rising_cards)
	var falling_names: Array[String] = _extract_names(_falling_cards)

	EventBus.meta_shift_announced.emit(rising_names, falling_names)
	_send_announcement_notification(rising_names, falling_names)


## Activates the pending shift.
func _activate_shift() -> void:
	_shift_active = true
	var rising_names: Array[String] = _extract_names(_rising_cards)
	var falling_names: Array[String] = _extract_names(_falling_cards)
	EventBus.meta_shift_activated.emit(rising_names, falling_names)
	EventBus.notification_requested.emit(
		"Meta shift active! Check card prices."
	)


## Ends the current shift if one is active.
func _end_current_shift() -> void:
	if _rising_cards.is_empty() and _falling_cards.is_empty():
		return
	var ended_card_id: StringName = _get_primary_card_id()
	_rising_cards = []
	_falling_cards = []
	_active_day = 0
	_announced_day = 0
	_shift_active = false
	_manual_shift_days_remaining = 0
	EventBus.meta_shift_ended.emit(ended_card_id)


## Selects cards from different sets for a meta shift direction.
func _select_cards(
	count: int,
	is_rising: bool,
	exclude_sets: Dictionary = {},
) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	if not _data_loader:
		return selected

	var candidates: Array[ItemDefinition] = _get_eligible_cards()
	if candidates.is_empty():
		return selected

	var used_sets: Dictionary = exclude_sets.duplicate()

	for _i: int in range(count):
		var filtered: Array[ItemDefinition] = _filter_by_unused_sets(
			candidates, used_sets
		)
		if filtered.is_empty():
			break
		var idx: int = randi() % filtered.size()
		var chosen: ItemDefinition = filtered[idx]
		var set_tag: String = _get_set_tag(chosen)
		used_sets[set_tag] = true

		var multiplier: float = 1.0
		if is_rising:
			multiplier = randf_range(SPIKE_MULT_MIN, SPIKE_MULT_MAX)
		else:
			multiplier = DROP_MULT

		selected.append({
			"item_id": chosen.id,
			"name": chosen.name,
			"multiplier": multiplier,
			"set_tag": set_tag,
		})

		candidates = candidates.filter(
			func(c: ItemDefinition) -> bool: return c.id != chosen.id
		)
	return selected


## Returns all eligible card singles for meta shift selection.
func _get_eligible_cards() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	var all_items: Array[ItemDefinition] = (
		_data_loader.get_items_by_store(STORE_TYPE)
	)
	for item: ItemDefinition in all_items:
		if item.category == CARD_CATEGORY:
			result.append(item)
	return result


## Filters candidates to only those from sets not yet used.
func _filter_by_unused_sets(
	candidates: Array[ItemDefinition],
	used_sets: Dictionary,
) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item: ItemDefinition in candidates:
		var set_tag: String = _get_set_tag(item)
		if not used_sets.has(set_tag):
			result.append(item)
	return result


## Extracts the set tag from an item definition's tags.
func _get_set_tag(item: ItemDefinition) -> String:
	for tag: String in item.tags:
		if tag in SET_TAGS:
			return tag
	return "unknown"


## Returns a dictionary of sets used by the given card entries.
func _used_sets(cards: Array[Dictionary]) -> Dictionary:
	var sets: Dictionary = {}
	for entry: Dictionary in cards:
		var set_tag: String = entry.get("set_tag", "") as String
		if not set_tag.is_empty():
			sets[set_tag] = true
	return sets


## Extracts card names from shift entries.
func _extract_names(cards: Array[Dictionary]) -> Array[String]:
	var names: Array[String] = []
	for entry: Dictionary in cards:
		names.append(entry.get("name", "Unknown") as String)
	return names


func _get_primary_card_id() -> StringName:
	if _rising_cards.is_empty():
		return &""
	return StringName(_rising_cards[0].get("item_id", ""))


## Sends HUD notification about the upcoming meta shift.
func _send_announcement_notification(
	rising: Array[String], falling: Array[String]
) -> void:
	if not rising.is_empty():
		var joined: String = ", ".join(PackedStringArray(rising))
		EventBus.notification_requested.emit(
			"Meta shift in %d days — Rising: %s"
			% [ANNOUNCEMENT_LEAD_DAYS, joined]
		)
	if not falling.is_empty():
		var joined: String = ", ".join(PackedStringArray(falling))
		EventBus.notification_requested.emit(
			"Meta shift in %d days — Falling: %s"
			% [ANNOUNCEMENT_LEAD_DAYS, joined]
		)
