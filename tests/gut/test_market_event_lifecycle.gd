## Tests for MarketEventSystem demand spike lifecycle and EventBus signal contracts.
extends GutTest


var _system: MarketEventSystem
var _saved_day: int


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
	def.duration_days = overrides.get("duration_days", 5)
	def.announcement_days = overrides.get("announcement_days", 0)
	def.ramp_up_days = overrides.get("ramp_up_days", 0)
	def.ramp_down_days = overrides.get("ramp_down_days", 0)
	def.cooldown_days = overrides.get("cooldown_days", 10)
	def.weight = overrides.get("weight", 1.0)
	def.announcement_text = overrides.get("announcement_text", "")
	def.active_text = overrides.get("active_text", "")
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
	_saved_day = GameManager.current_day


func after_each() -> void:
	GameManager.current_day = _saved_day


# --- Event activation emits market_event_started ---


func test_activate_no_announcement_emits_started() -> void:
	var def: MarketEventDefinition = _create_event_def({
		"announcement_days": 0,
	})
	var fired: bool = false
	var got_id: String = ""
	var cb: Callable = func(id: String) -> void:
		fired = true
		got_id = id
	EventBus.market_event_started.connect(cb)
	_system._activate_event(def, 1)
	assert_true(fired, "market_event_started should fire for no-announcement event")
	assert_eq(got_id, "test_boom")
	assert_eq(_system._active_events.size(), 1)
	var evt: Dictionary = _system._active_events[0]
	assert_eq(
		evt.get("phase", -1), MarketEventSystem.Phase.RAMP_UP,
		"Phase should be RAMP_UP when no announcement"
	)
	EventBus.market_event_started.disconnect(cb)


func test_activate_with_announcement_emits_announced_then_started() -> void:
	var def: MarketEventDefinition = _create_event_def({
		"announcement_days": 2,
		"ramp_up_days": 1,
	})
	var announced: bool = false
	var started: bool = false
	var announced_cb: Callable = func(id: String) -> void:
		announced = true
	var started_cb: Callable = func(id: String) -> void:
		started = true
	EventBus.market_event_announced.connect(announced_cb)
	EventBus.market_event_started.connect(started_cb)
	_system._activate_event(def, 1)
	assert_true(announced, "market_event_announced should fire")
	assert_false(started, "market_event_started should not fire yet")
	assert_eq(
		_system._active_events[0].get("phase", -1),
		MarketEventSystem.Phase.ANNOUNCEMENT,
	)
	_system._advance_event_lifecycles(3)
	assert_true(started, "market_event_started should fire after announcement ends")
	EventBus.market_event_announced.disconnect(announced_cb)
	EventBus.market_event_started.disconnect(started_cb)


# --- Demand multiplier during active phase ---


func test_multiplier_above_one_during_active_boom() -> void:
	var def: MarketEventDefinition = _create_event_def({
		"magnitude": 1.8,
		"announcement_days": 0,
		"ramp_up_days": 0,
		"ramp_down_days": 0,
		"duration_days": 5,
	})
	GameManager.current_day = 1
	_system._activate_event(def, 1)
	_system._advance_event_lifecycles(1)
	var item: ItemInstance = _create_item()
	var mult: float = _system.get_trend_multiplier(item)
	assert_gt(mult, 1.0, "Multiplier should be > 1.0 during active boom")
	assert_almost_eq(mult, 1.8, 0.001, "Should equal magnitude during full effect")


func test_unaffected_category_returns_one_during_active() -> void:
	var def: MarketEventDefinition = _create_event_def({
		"target_categories": PackedStringArray(["trading_cards"]),
		"magnitude": 2.0,
		"announcement_days": 0,
	})
	GameManager.current_day = 1
	_system._activate_event(def, 1)
	_system._advance_event_lifecycles(1)
	var item: ItemInstance = _create_item(
		PackedStringArray(["rookie"]), "electronics"
	)
	var mult: float = _system.get_trend_multiplier(item)
	assert_eq(mult, 1.0, "Unaffected category should return 1.0")


# --- Event expiry ---


func test_advancing_past_duration_emits_ended() -> void:
	var def: MarketEventDefinition = _create_event_def({
		"duration_days": 3,
		"announcement_days": 0,
		"ramp_up_days": 0,
		"ramp_down_days": 0,
	})
	_system._activate_event(def, 1)
	var ended: bool = false
	var ended_id: String = ""
	var cb: Callable = func(id: String) -> void:
		ended = true
		ended_id = id
	EventBus.market_event_ended.connect(cb)
	_system._advance_event_lifecycles(3)
	assert_false(ended, "Should not expire on day 3 (end_day = 1+0+3 = 4)")
	assert_eq(_system._active_events.size(), 1)
	_system._advance_event_lifecycles(4)
	assert_true(ended, "market_event_ended should fire when day >= end_day")
	assert_eq(ended_id, "test_boom")
	assert_eq(_system._active_events.size(), 0, "Event should be removed")
	EventBus.market_event_ended.disconnect(cb)


func test_multiplier_returns_to_one_after_expiry() -> void:
	var def: MarketEventDefinition = _create_event_def({
		"magnitude": 2.0,
		"duration_days": 3,
		"announcement_days": 0,
		"ramp_up_days": 0,
		"ramp_down_days": 0,
	})
	GameManager.current_day = 1
	_system._activate_event(def, 1)
	_system._advance_event_lifecycles(1)
	var item: ItemInstance = _create_item()
	var mult_active: float = _system.get_trend_multiplier(item)
	assert_eq(mult_active, 2.0, "Should be 2.0 while active")
	GameManager.current_day = 4
	_system._advance_event_lifecycles(4)
	var mult_expired: float = _system.get_trend_multiplier(item)
	assert_eq(mult_expired, 1.0, "Should return to 1.0 after expiry")


func test_cooldown_set_after_expiry() -> void:
	var def: MarketEventDefinition = _create_event_def({
		"duration_days": 2,
		"announcement_days": 0,
		"cooldown_days": 15,
	})
	_system._activate_event(def, 1)
	_system._advance_event_lifecycles(3)
	assert_eq(
		_system._cooldowns.get("test_boom", 0), 15,
		"Cooldown should be set after expiry"
	)


# --- No stacking of same event ---


func test_same_event_active_does_not_stack() -> void:
	var def: MarketEventDefinition = _create_event_def({
		"magnitude": 2.0,
		"announcement_days": 0,
		"ramp_up_days": 0,
		"ramp_down_days": 0,
		"duration_days": 10,
	})
	_system._event_definitions = [def]
	GameManager.current_day = 1
	_system._activate_event(def, 1)
	_system._advance_event_lifecycles(1)
	var candidates: Array[MarketEventDefinition] = _system._get_candidates()
	assert_false(
		candidates.has(def),
		"Active event should be excluded from candidates"
	)
	var item: ItemInstance = _create_item()
	var mult: float = _system.get_trend_multiplier(item)
	assert_almost_eq(
		mult, 2.0, 0.001,
		"Multiplier should not double from duplicate activation"
	)


# --- Multiple simultaneous events apply independently ---


func test_multiple_events_independent_multipliers() -> void:
	var boom_def: MarketEventDefinition = _create_event_def({
		"id": "cards_boom",
		"magnitude": 1.5,
		"target_categories": PackedStringArray(["trading_cards"]),
		"target_tags": PackedStringArray([]),
		"announcement_days": 0,
		"ramp_up_days": 0,
		"ramp_down_days": 0,
		"duration_days": 5,
	})
	var elec_def: MarketEventDefinition = _create_event_def({
		"id": "elec_boom",
		"magnitude": 2.0,
		"target_categories": PackedStringArray(["electronics"]),
		"target_tags": PackedStringArray([]),
		"announcement_days": 0,
		"ramp_up_days": 0,
		"ramp_down_days": 0,
		"duration_days": 5,
	})
	GameManager.current_day = 1
	_system._activate_event(boom_def, 1)
	_system._activate_event(elec_def, 1)
	_system._advance_event_lifecycles(1)
	assert_eq(_system._active_events.size(), 2, "Both events should be active")
	var card_item: ItemInstance = _create_item(
		PackedStringArray([]), "trading_cards"
	)
	var elec_item: ItemInstance = _create_item(
		PackedStringArray([]), "electronics"
	)
	var unrelated_item: ItemInstance = _create_item(
		PackedStringArray([]), "clothing"
	)
	var card_mult: float = _system.get_trend_multiplier(card_item)
	var elec_mult: float = _system.get_trend_multiplier(elec_item)
	var unrelated_mult: float = _system.get_trend_multiplier(unrelated_item)
	assert_almost_eq(
		card_mult, 1.5, 0.001,
		"Card item should get cards_boom multiplier only"
	)
	assert_almost_eq(
		elec_mult, 2.0, 0.001,
		"Electronics item should get elec_boom multiplier only"
	)
	assert_eq(
		unrelated_mult, 1.0,
		"Unrelated item should not be affected by either event"
	)


func test_overlapping_events_multiply_together() -> void:
	var def_a: MarketEventDefinition = _create_event_def({
		"id": "boom_a",
		"magnitude": 1.5,
		"target_categories": PackedStringArray(["trading_cards"]),
		"target_tags": PackedStringArray([]),
		"announcement_days": 0,
		"ramp_up_days": 0,
		"ramp_down_days": 0,
	})
	var def_b: MarketEventDefinition = _create_event_def({
		"id": "boom_b",
		"magnitude": 1.4,
		"target_categories": PackedStringArray(["trading_cards"]),
		"target_tags": PackedStringArray([]),
		"announcement_days": 0,
		"ramp_up_days": 0,
		"ramp_down_days": 0,
	})
	GameManager.current_day = 1
	_system._activate_event(def_a, 1)
	_system._activate_event(def_b, 1)
	_system._advance_event_lifecycles(1)
	var item: ItemInstance = _create_item(PackedStringArray([]), "trading_cards")
	var mult: float = _system.get_trend_multiplier(item)
	assert_almost_eq(
		mult, 1.5 * 1.4, 0.001,
		"Overlapping events should multiply their magnitudes"
	)


# --- Full lifecycle via _on_day_started ---


func test_full_lifecycle_via_day_started() -> void:
	var def: MarketEventDefinition = _create_event_def({
		"announcement_days": 1,
		"ramp_up_days": 1,
		"ramp_down_days": 0,
		"duration_days": 3,
		"cooldown_days": 5,
	})
	_system._activate_event(def, 1)
	var started: bool = false
	var ended: bool = false
	var start_cb: Callable = func(id: String) -> void:
		started = true
	var end_cb: Callable = func(id: String) -> void:
		ended = true
	EventBus.market_event_started.connect(start_cb)
	EventBus.market_event_ended.connect(end_cb)
	assert_eq(
		_system._active_events[0].get("phase", -1),
		MarketEventSystem.Phase.ANNOUNCEMENT,
	)
	GameManager.current_day = 2
	_system._on_day_started(2)
	assert_true(started, "Should transition to RAMP_UP on day 2")
	assert_false(ended, "Should not end on day 2")
	GameManager.current_day = 4
	_system._on_day_started(4)
	assert_false(ended, "Should not end on day 4 (end_day = 1+1+3 = 5)")
	GameManager.current_day = 5
	_system._on_day_started(5)
	assert_true(ended, "Should expire on day 5 (end_day = 5)")
	assert_eq(_system._active_events.size(), 0, "Event should be removed")
	assert_true(
		_system._cooldowns.has("test_boom"),
		"Cooldown should be set after expiry"
	)
	EventBus.market_event_started.disconnect(start_cb)
	EventBus.market_event_ended.disconnect(end_cb)
