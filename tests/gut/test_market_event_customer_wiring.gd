## Tests that MarketEventSystem demand spikes wire into CustomerSystem spawn and intent modifiers.
extends GutTest


var _customer_system: CustomerSystem
var _market_event_system: MarketEventSystem


func _create_event_def(overrides: Dictionary = {}) -> MarketEventDefinition:
	var def := MarketEventDefinition.new()
	def.id = overrides.get("id", "test_boom")
	def.item_name = overrides.get("name", "Test Boom")
	def.event_type = overrides.get("event_type", "boom")
	def.target_tags = overrides.get("target_tags", PackedStringArray([]))
	def.target_categories = overrides.get(
		"target_categories", PackedStringArray(["trading_cards"])
	)
	def.magnitude = overrides.get("magnitude", 1.5)
	def.duration_days = overrides.get("duration_days", 5)
	def.announcement_days = overrides.get("announcement_days", 2)
	def.ramp_up_days = overrides.get("ramp_up_days", 1)
	def.ramp_down_days = overrides.get("ramp_down_days", 1)
	def.cooldown_days = overrides.get("cooldown_days", 10)
	def.weight = overrides.get("weight", 1.0)
	return def


func before_each() -> void:
	_customer_system = CustomerSystem.new()
	add_child_autofree(_customer_system)
	_customer_system.max_customers_in_mall = 30
	_customer_system._connect_signals()

	_market_event_system = MarketEventSystem.new()
	add_child_autofree(_market_event_system)


# --- Default state ---


func test_default_spawn_modifier_is_one() -> void:
	assert_eq(
		_customer_system._active_event_spawn_modifier, 1.0,
		"Default spawn modifier should be 1.0"
	)


func test_default_intent_modifier_is_one() -> void:
	assert_eq(
		_customer_system._active_event_intent_modifier, 1.0,
		"Default intent modifier should be 1.0"
	)


# --- market_event_active signal ---


func test_market_event_active_sets_spawn_modifier() -> void:
	EventBus.market_event_active.emit(
		&"test_boom",
		{"spawn_rate_multiplier": 2.0, "purchase_intent_multiplier": 1.5}
	)
	assert_eq(
		_customer_system._active_event_spawn_modifier, 2.0,
		"Spawn modifier should reflect emitted value"
	)


func test_market_event_active_sets_intent_modifier() -> void:
	EventBus.market_event_active.emit(
		&"test_boom",
		{"spawn_rate_multiplier": 1.0, "purchase_intent_multiplier": 1.8}
	)
	assert_eq(
		_customer_system._active_event_intent_modifier, 1.8,
		"Intent modifier should reflect emitted value"
	)


func test_market_event_active_defaults_missing_spawn_key() -> void:
	EventBus.market_event_active.emit(
		&"partial_event", {"purchase_intent_multiplier": 1.2}
	)
	assert_eq(
		_customer_system._active_event_spawn_modifier, 1.0,
		"Missing spawn_rate_multiplier key should default to 1.0"
	)


func test_market_event_active_defaults_missing_intent_key() -> void:
	EventBus.market_event_active.emit(
		&"partial_event", {"spawn_rate_multiplier": 1.4}
	)
	assert_eq(
		_customer_system._active_event_intent_modifier, 1.0,
		"Missing purchase_intent_multiplier key should default to 1.0"
	)


# --- market_event_expired signal ---


func test_market_event_expired_resets_spawn_modifier() -> void:
	EventBus.market_event_active.emit(
		&"test_boom",
		{"spawn_rate_multiplier": 2.0, "purchase_intent_multiplier": 1.5}
	)
	EventBus.market_event_expired.emit(&"test_boom")
	assert_eq(
		_customer_system._active_event_spawn_modifier, 1.0,
		"Spawn modifier should reset to 1.0 on expiry"
	)


func test_market_event_expired_resets_intent_modifier() -> void:
	EventBus.market_event_active.emit(
		&"test_boom",
		{"spawn_rate_multiplier": 2.0, "purchase_intent_multiplier": 1.5}
	)
	EventBus.market_event_expired.emit(&"test_boom")
	assert_eq(
		_customer_system._active_event_intent_modifier, 1.0,
		"Intent modifier should reset to 1.0 on expiry"
	)


func test_expired_unknown_event_does_not_crash() -> void:
	EventBus.market_event_expired.emit(&"never_activated")
	assert_eq(
		_customer_system._active_event_spawn_modifier, 1.0,
		"Expiring unknown event should leave modifier at 1.0"
	)


# --- Multiple concurrent events compose multiplicatively ---


func test_two_active_events_compose_spawn_modifier() -> void:
	EventBus.market_event_active.emit(
		&"event_a", {"spawn_rate_multiplier": 2.0, "purchase_intent_multiplier": 1.0}
	)
	EventBus.market_event_active.emit(
		&"event_b", {"spawn_rate_multiplier": 1.5, "purchase_intent_multiplier": 1.0}
	)
	assert_almost_eq(
		_customer_system._active_event_spawn_modifier, 3.0, 0.001,
		"Two active events should multiply spawn modifiers (2.0 * 1.5 = 3.0)"
	)


func test_two_active_events_compose_intent_modifier() -> void:
	EventBus.market_event_active.emit(
		&"event_a", {"spawn_rate_multiplier": 1.0, "purchase_intent_multiplier": 1.4}
	)
	EventBus.market_event_active.emit(
		&"event_b", {"spawn_rate_multiplier": 1.0, "purchase_intent_multiplier": 1.2}
	)
	assert_almost_eq(
		_customer_system._active_event_intent_modifier, 1.68, 0.001,
		"Two active events should multiply intent modifiers (1.4 * 1.2 = 1.68)"
	)


func test_expiring_one_of_two_events_leaves_remaining_modifier() -> void:
	EventBus.market_event_active.emit(
		&"event_a", {"spawn_rate_multiplier": 2.0, "purchase_intent_multiplier": 1.0}
	)
	EventBus.market_event_active.emit(
		&"event_b", {"spawn_rate_multiplier": 1.5, "purchase_intent_multiplier": 1.0}
	)
	EventBus.market_event_expired.emit(&"event_a")
	assert_almost_eq(
		_customer_system._active_event_spawn_modifier, 1.5, 0.001,
		"After expiring event_a, only event_b modifier (1.5) should remain"
	)


# --- get_spawn_target applies spawn modifier ---


func test_spawn_target_increases_with_active_event() -> void:
	_customer_system._current_hour = 12
	_customer_system._hour_elapsed = 0.0
	_customer_system._current_day_of_week = 0
	var base_target: int = _customer_system.get_spawn_target()

	EventBus.market_event_active.emit(
		&"boom_event", {"spawn_rate_multiplier": 2.0, "purchase_intent_multiplier": 1.0}
	)
	var boosted_target: int = _customer_system.get_spawn_target()
	assert_true(
		boosted_target > base_target,
		"Active event with spawn_rate_multiplier > 1.0 should increase spawn target"
	)


func test_spawn_target_decreases_with_bust_event() -> void:
	_customer_system._current_hour = 12
	_customer_system._hour_elapsed = 0.0
	_customer_system._current_day_of_week = 0
	var base_target: int = _customer_system.get_spawn_target()

	EventBus.market_event_active.emit(
		&"bust_event", {"spawn_rate_multiplier": 0.5, "purchase_intent_multiplier": 1.0}
	)
	var reduced_target: int = _customer_system.get_spawn_target()
	assert_true(
		reduced_target < base_target,
		"Active event with spawn_rate_multiplier < 1.0 should reduce spawn target"
	)


func test_spawn_target_capped_at_max() -> void:
	_customer_system._current_hour = 12
	_customer_system._hour_elapsed = 0.0
	_customer_system._current_day_of_week = 0
	EventBus.market_event_active.emit(
		&"extreme_event", {"spawn_rate_multiplier": 100.0, "purchase_intent_multiplier": 1.0}
	)
	var target: int = _customer_system.get_spawn_target()
	assert_true(
		target <= _customer_system.max_customers_in_mall,
		"Spawn target must never exceed max_customers_in_mall"
	)


# --- MarketEventSystem emits market_event_active with correct dict ---


func test_market_event_system_builds_modifier_dict() -> void:
	var def: MarketEventDefinition = _create_event_def({"magnitude": 1.8})
	var modifier: Dictionary = _market_event_system._build_event_modifier(def)
	assert_true(
		modifier.has("spawn_rate_multiplier"),
		"Modifier dict must have spawn_rate_multiplier"
	)
	assert_true(
		modifier.has("purchase_intent_multiplier"),
		"Modifier dict must have purchase_intent_multiplier"
	)
	assert_eq(
		modifier["spawn_rate_multiplier"], 1.8,
		"spawn_rate_multiplier should equal event magnitude"
	)
	assert_eq(
		modifier["purchase_intent_multiplier"], 1.8,
		"purchase_intent_multiplier should equal event magnitude"
	)


func test_market_event_system_emits_active_on_immediate_start() -> void:
	var def: MarketEventDefinition = _create_event_def({
		"id": "instant_event",
		"announcement_days": 0,
		"magnitude": 1.6,
	})
	_market_event_system._event_definitions = [def]

	var received_id: Array = [&""]
	var received_modifier: Dictionary = {}
	EventBus.market_event_active.connect(
		func(eid: StringName, mod: Dictionary) -> void:
			received_id[0] = eid
			received_modifier = mod
	)

	_market_event_system._activate_event(def, 1)

	assert_eq(received_id[0], &"instant_event", "market_event_active should fire event_id")
	assert_true(
		received_modifier.has("spawn_rate_multiplier"),
		"Emitted modifier must include spawn_rate_multiplier"
	)


func test_market_event_system_emits_expired_when_event_ends() -> void:
	var def: MarketEventDefinition = _create_event_def({
		"id": "ending_event",
		"announcement_days": 0,
		"duration_days": 3,
		"ramp_up_days": 0,
		"ramp_down_days": 0,
	})
	_market_event_system._event_definitions = [def]
	_market_event_system._activate_event(def, 1)

	var expired_id: Array = [&""]
	EventBus.market_event_expired.connect(
		func(eid: StringName) -> void:
			expired_id[0] = eid
	)

	# Advance past end_day = 1 + 0 + 3 = 4, so day 5 triggers removal
	_market_event_system._advance_event_lifecycles(5)

	assert_eq(expired_id[0], &"ending_event", "market_event_expired should fire when event ends")
