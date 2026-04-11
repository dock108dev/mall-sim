## Tests for MarketEventSystem: lifecycle, multiplier calculation, save/load.
extends GutTest


var _system: MarketEventSystem
var _boom_def: MarketEventDefinition
var _bust_def: MarketEventDefinition
var _spike_def: MarketEventDefinition


func _create_event_def(overrides: Dictionary = {}) -> MarketEventDefinition:
	var def := MarketEventDefinition.new()
	def.id = overrides.get("id", "test_boom")
	def.name = overrides.get("name", "Test Boom")
	def.event_type = overrides.get("event_type", "boom")
	def.target_tags = overrides.get("target_tags", PackedStringArray(["rookie"]))
	def.target_categories = overrides.get(
		"target_categories", PackedStringArray(["trading_cards"])
	)
	def.magnitude = overrides.get("magnitude", 1.8)
	def.duration_days = overrides.get("duration_days", 8)
	def.announcement_days = overrides.get("announcement_days", 2)
	def.ramp_up_days = overrides.get("ramp_up_days", 2)
	def.ramp_down_days = overrides.get("ramp_down_days", 2)
	def.cooldown_days = overrides.get("cooldown_days", 20)
	def.weight = overrides.get("weight", 1.0)
	def.announcement_text = overrides.get("announcement_text", "Boom incoming")
	def.active_text = overrides.get("active_text", "Boom is active")
	return def


func _create_item(
	tags: PackedStringArray = PackedStringArray(["rookie"]),
	category: String = "trading_cards",
) -> ItemInstance:
	var item_def := ItemDefinition.new()
	item_def.id = "test_card"
	item_def.base_price = 10.0
	item_def.rarity = "common"
	item_def.tags = tags
	item_def.category = category
	return ItemInstance.create_from_definition(item_def, "good")


func before_each() -> void:
	_system = MarketEventSystem.new()
	add_child_autofree(_system)
	_boom_def = _create_event_def()
	_bust_def = _create_event_def({
		"id": "test_bust",
		"name": "Test Bust",
		"event_type": "bust",
		"magnitude": 0.5,
		"target_tags": PackedStringArray(["vintage"]),
	})
	_spike_def = _create_event_def({
		"id": "test_spike",
		"name": "Test Spike",
		"event_type": "spike",
		"magnitude": 2.5,
		"duration_days": 3,
		"announcement_days": 0,
		"ramp_up_days": 1,
		"ramp_down_days": 1,
	})


# --- get_trend_multiplier ---


func test_no_active_events_returns_one() -> void:
	var item: ItemInstance = _create_item()
	var mult: float = _system.get_trend_multiplier(item)
	assert_eq(mult, 1.0, "No events should return 1.0")


func test_null_item_returns_one() -> void:
	assert_eq(_system.get_trend_multiplier(null), 1.0)


func test_item_without_definition_returns_one() -> void:
	var item := ItemInstance.new()
	item.definition = null
	assert_eq(_system.get_trend_multiplier(item), 1.0)


func test_full_effect_boom_returns_magnitude() -> void:
	_system._active_events.append({
		"definition": _boom_def,
		"announced_day": 0,
		"phase": MarketEventSystem.Phase.FULL_EFFECT,
	})
	var item: ItemInstance = _create_item(
		PackedStringArray(["rookie"]), "trading_cards"
	)
	var mult: float = _system.get_trend_multiplier(item)
	assert_eq(mult, _boom_def.magnitude, "Full effect should return magnitude")


func test_announcement_phase_returns_one() -> void:
	_system._active_events.append({
		"definition": _boom_def,
		"announced_day": 0,
		"phase": MarketEventSystem.Phase.ANNOUNCEMENT,
	})
	var item: ItemInstance = _create_item()
	assert_eq(
		_system.get_trend_multiplier(item), 1.0,
		"Announcement phase should not affect price"
	)


func test_cooldown_phase_returns_one() -> void:
	_system._active_events.append({
		"definition": _boom_def,
		"announced_day": 0,
		"phase": MarketEventSystem.Phase.COOLDOWN,
	})
	var item: ItemInstance = _create_item()
	assert_eq(
		_system.get_trend_multiplier(item), 1.0,
		"Cooldown phase should not affect price"
	)


func test_non_matching_item_returns_one() -> void:
	_system._active_events.append({
		"definition": _boom_def,
		"announced_day": 0,
		"phase": MarketEventSystem.Phase.FULL_EFFECT,
	})
	var item: ItemInstance = _create_item(
		PackedStringArray(["vintage"]), "memorabilia"
	)
	assert_eq(
		_system.get_trend_multiplier(item), 1.0,
		"Non-matching item should return 1.0"
	)


func test_multiplier_clamped_to_max() -> void:
	var high_def: MarketEventDefinition = _create_event_def({
		"id": "extreme1", "magnitude": 2.0,
	})
	var high_def2: MarketEventDefinition = _create_event_def({
		"id": "extreme2", "magnitude": 2.0,
		"target_tags": PackedStringArray(["rookie"]),
	})
	_system._active_events.append({
		"definition": high_def,
		"announced_day": 0,
		"phase": MarketEventSystem.Phase.FULL_EFFECT,
	})
	_system._active_events.append({
		"definition": high_def2,
		"announced_day": 0,
		"phase": MarketEventSystem.Phase.FULL_EFFECT,
	})
	var item: ItemInstance = _create_item()
	var mult: float = _system.get_trend_multiplier(item)
	assert_true(
		mult <= MarketEventSystem.TREND_MULT_MAX,
		"Multiplier should be clamped to max (%s <= %s)"
		% [mult, MarketEventSystem.TREND_MULT_MAX]
	)


func test_multiplier_clamped_to_min() -> void:
	var low_def: MarketEventDefinition = _create_event_def({
		"id": "low1", "magnitude": 0.3,
		"target_tags": PackedStringArray(["rookie"]),
		"target_categories": PackedStringArray(["trading_cards"]),
	})
	_system._active_events.append({
		"definition": low_def,
		"announced_day": 0,
		"phase": MarketEventSystem.Phase.FULL_EFFECT,
	})
	var item: ItemInstance = _create_item()
	var mult: float = _system.get_trend_multiplier(item)
	assert_true(
		mult >= MarketEventSystem.TREND_MULT_MIN,
		"Multiplier should be clamped to min (%s >= %s)"
		% [mult, MarketEventSystem.TREND_MULT_MIN]
	)


# --- get_active_events ---


func test_get_active_events_returns_copies() -> void:
	_system._active_events.append({
		"definition": _boom_def,
		"announced_day": 1,
		"phase": MarketEventSystem.Phase.FULL_EFFECT,
	})
	var events: Array[Dictionary] = _system.get_active_events()
	assert_eq(events.size(), 1, "Should return 1 active event")
	events[0]["phase"] = -999
	assert_ne(
		_system._active_events[0].get("phase", 0), -999,
		"Returned events should be copies"
	)


# --- get_active_effect_count ---


func test_active_effect_count_excludes_announcement() -> void:
	_system._active_events.append({
		"definition": _boom_def,
		"announced_day": 1,
		"phase": MarketEventSystem.Phase.ANNOUNCEMENT,
	})
	_system._active_events.append({
		"definition": _bust_def,
		"announced_day": 1,
		"phase": MarketEventSystem.Phase.FULL_EFFECT,
	})
	assert_eq(
		_system.get_active_effect_count(), 1,
		"Announcement phase should not count as active effect"
	)


# --- save/load ---


func test_save_and_load_roundtrip() -> void:
	_system._days_since_last_event = 7
	_system._cooldowns["test_boom"] = 5
	_system._active_events.append({
		"definition": _boom_def,
		"announced_day": 3,
		"phase": MarketEventSystem.Phase.FULL_EFFECT,
	})
	var save_data: Dictionary = _system.get_save_data()
	assert_true(
		save_data.has("active_events"),
		"Save data should have active_events"
	)
	assert_true(
		save_data.has("cooldowns"),
		"Save data should have cooldowns"
	)
	assert_eq(
		save_data["days_since_last_event"], 7,
		"Days since last event should be preserved"
	)
	var saved_events: Array = save_data["active_events"]
	assert_eq(saved_events.size(), 1)
	assert_true(
		saved_events[0].has("definition_id"),
		"Serialized event should have definition_id"
	)
	assert_false(
		saved_events[0].has("definition"),
		"Serialized event should not have definition object"
	)


func test_load_restores_state() -> void:
	_system._event_definitions = [_boom_def, _bust_def]
	var save_data: Dictionary = {
		"days_since_last_event": 12,
		"cooldowns": {"test_bust": 3},
		"active_events": [
			{
				"definition_id": "test_boom",
				"announced_day": 5,
				"phase": MarketEventSystem.Phase.RAMP_UP,
			},
		],
	}
	_system.load_save_data(save_data)
	assert_eq(_system._days_since_last_event, 12)
	assert_eq(_system._cooldowns.size(), 1)
	assert_eq(_system._cooldowns.get("test_bust", 0), 3)
	assert_eq(_system._active_events.size(), 1)
	var restored: Dictionary = _system._active_events[0]
	assert_eq(restored.get("announced_day", -1), 5)
	assert_true(
		restored.has("definition"),
		"Loaded event should have definition object restored"
	)


func test_load_skips_unknown_definition() -> void:
	_system._event_definitions = [_boom_def]
	var save_data: Dictionary = {
		"days_since_last_event": 0,
		"cooldowns": {},
		"active_events": [
			{"definition_id": "nonexistent", "announced_day": 1, "phase": 0},
		],
	}
	_system.load_save_data(save_data)
	assert_eq(
		_system._active_events.size(), 0,
		"Unknown definition should be skipped"
	)


# --- _item_matches_event ---


func test_item_matches_by_category() -> void:
	var def: MarketEventDefinition = _create_event_def({
		"target_categories": PackedStringArray(["trading_cards"]),
		"target_tags": PackedStringArray([]),
	})
	var item_def := ItemDefinition.new()
	item_def.category = "trading_cards"
	item_def.tags = PackedStringArray([])
	assert_true(_system._item_matches_event(item_def, def))


func test_item_no_match_wrong_category() -> void:
	var def: MarketEventDefinition = _create_event_def({
		"target_categories": PackedStringArray(["trading_cards"]),
		"target_tags": PackedStringArray([]),
	})
	var item_def := ItemDefinition.new()
	item_def.category = "electronics"
	item_def.tags = PackedStringArray([])
	assert_false(_system._item_matches_event(item_def, def))


func test_item_matches_by_tag() -> void:
	var def: MarketEventDefinition = _create_event_def({
		"target_categories": PackedStringArray([]),
		"target_tags": PackedStringArray(["vintage", "classic"]),
	})
	var item_def := ItemDefinition.new()
	item_def.category = "trading_cards"
	item_def.tags = PackedStringArray(["classic"])
	assert_true(_system._item_matches_event(item_def, def))


func test_item_no_match_wrong_tag() -> void:
	var def: MarketEventDefinition = _create_event_def({
		"target_categories": PackedStringArray([]),
		"target_tags": PackedStringArray(["vintage"]),
	})
	var item_def := ItemDefinition.new()
	item_def.category = "trading_cards"
	item_def.tags = PackedStringArray(["modern"])
	assert_false(_system._item_matches_event(item_def, def))


func test_event_with_no_filters_matches_all() -> void:
	var def: MarketEventDefinition = _create_event_def({
		"target_categories": PackedStringArray([]),
		"target_tags": PackedStringArray([]),
	})
	var item_def := ItemDefinition.new()
	item_def.category = "anything"
	item_def.tags = PackedStringArray(["whatever"])
	assert_true(_system._item_matches_event(item_def, def))


# --- Constants match project brief ---


func test_base_event_chance_is_fifteen_percent() -> void:
	assert_eq(
		MarketEventSystem.BASE_EVENT_CHANCE, 0.15,
		"Base chance should be 15%"
	)


func test_max_concurrent_events_is_two() -> void:
	assert_eq(MarketEventSystem.MAX_CONCURRENT_EVENTS, 2)


func test_guaranteed_event_every_fifteen_days() -> void:
	assert_eq(MarketEventSystem.GUARANTEED_EVENT_DAYS, 15)
