## Integration test: MarketEventSystem demand spike activates CustomerSystem spawn
## rate and purchase intent modifiers via EventBus signals.
extends GutTest

const FLOAT_TOLERANCE: float = 0.001
## Base purchase probability used by the test profile.
const BASE_INTENT: float = 0.9

var _system: CustomerSystem
var _profile: CustomerTypeDefinition


func before_each() -> void:
	_system = CustomerSystem.new()
	add_child_autofree(_system)
	EventBus.market_event_active.connect(_system._on_market_event_active)
	EventBus.market_event_expired.connect(_system._on_market_event_expired)
	_profile = _make_profile()


func after_each() -> void:
	if EventBus.market_event_active.is_connected(_system._on_market_event_active):
		EventBus.market_event_active.disconnect(_system._on_market_event_active)
	if EventBus.market_event_expired.is_connected(_system._on_market_event_expired):
		EventBus.market_event_expired.disconnect(_system._on_market_event_expired)
	_system._active_event_modifiers.clear()
	_system._recalculate_event_modifiers()


# ── Baseline: no active event ─────────────────────────────────────────────────


func test_baseline_spawn_modifier_is_one() -> void:
	assert_almost_eq(
		_system._active_event_spawn_modifier,
		1.0,
		FLOAT_TOLERANCE,
		"Baseline spawn modifier must be 1.0"
	)


func test_baseline_intent_modifier_is_one() -> void:
	assert_almost_eq(
		_system._active_event_intent_modifier,
		1.0,
		FLOAT_TOLERANCE,
		"Baseline intent modifier must be 1.0"
	)


func test_baseline_purchase_intent_equals_base_intent() -> void:
	var intent: float = _system.get_purchase_intent_for_category(
		_profile, &"collectibles"
	)
	assert_almost_eq(
		intent,
		BASE_INTENT,
		FLOAT_TOLERANCE,
		"Baseline purchase intent should equal purchase_probability_base"
	)


# ── Spawn modifier after market_event_active ──────────────────────────────────


func test_spawn_modifier_doubles_when_spawn_rate_multiplier_is_two() -> void:
	EventBus.market_event_active.emit(
		&"sports_championship",
		{"spawn_rate_multiplier": 2.0}
	)
	assert_almost_eq(
		_system._active_event_spawn_modifier,
		2.0,
		FLOAT_TOLERANCE,
		"Spawn modifier should be 2.0 after event with spawn_rate_multiplier=2.0"
	)


# ── Purchase intent modifier after market_event_active ────────────────────────


func test_intent_modifier_set_when_purchase_intent_multiplier_is_1_5() -> void:
	EventBus.market_event_active.emit(
		&"sports_championship",
		{"purchase_intent_multiplier": 1.5}
	)
	assert_almost_eq(
		_system._active_event_intent_modifier,
		1.5,
		FLOAT_TOLERANCE,
		"Intent modifier should be 1.5 after event with purchase_intent_multiplier=1.5"
	)


func test_purchase_intent_clamped_to_one_when_multiplied_above_one() -> void:
	EventBus.market_event_active.emit(
		&"sports_championship",
		{"purchase_intent_multiplier": 1.5}
	)
	var intent: float = _system.get_purchase_intent_for_category(
		_profile, &"collectibles"
	)
	var expected: float = minf(BASE_INTENT * 1.5, 1.0)
	assert_almost_eq(
		intent,
		expected,
		FLOAT_TOLERANCE,
		"Purchase intent must equal min(BASE × 1.5, 1.0)"
	)


# ── Event expired: both modifiers reset to 1.0 ───────────────────────────────


func test_spawn_modifier_resets_to_one_on_expired() -> void:
	EventBus.market_event_active.emit(
		&"sports_championship",
		{"spawn_rate_multiplier": 2.0}
	)
	EventBus.market_event_expired.emit(&"sports_championship")
	assert_almost_eq(
		_system._active_event_spawn_modifier,
		1.0,
		FLOAT_TOLERANCE,
		"Spawn modifier must reset to 1.0 after event expires"
	)


func test_intent_modifier_resets_to_one_on_expired() -> void:
	EventBus.market_event_active.emit(
		&"sports_championship",
		{"purchase_intent_multiplier": 1.5}
	)
	EventBus.market_event_expired.emit(&"sports_championship")
	assert_almost_eq(
		_system._active_event_intent_modifier,
		1.0,
		FLOAT_TOLERANCE,
		"Intent modifier must reset to 1.0 after event expires"
	)


# ── Modifier composition: two simultaneous active events ─────────────────────


func test_two_simultaneous_events_compose_spawn_modifiers_multiplicatively() -> void:
	EventBus.market_event_active.emit(
		&"sports_championship",
		{"spawn_rate_multiplier": 2.0}
	)
	EventBus.market_event_active.emit(
		&"holiday_rush",
		{"spawn_rate_multiplier": 1.5}
	)
	assert_almost_eq(
		_system._active_event_spawn_modifier,
		3.0,
		FLOAT_TOLERANCE,
		"Two events with spawn_rate_multiplier 2.0 × 1.5 must compose to 3.0"
	)


func test_two_simultaneous_events_compose_intent_modifiers_multiplicatively() -> void:
	EventBus.market_event_active.emit(
		&"sports_championship",
		{"purchase_intent_multiplier": 2.0}
	)
	EventBus.market_event_active.emit(
		&"holiday_rush",
		{"purchase_intent_multiplier": 1.5}
	)
	assert_almost_eq(
		_system._active_event_intent_modifier,
		3.0,
		FLOAT_TOLERANCE,
		"Two events with purchase_intent_multiplier 2.0 × 1.5 must compose to 3.0"
	)


# ── Unknown event_id: no crash and modifiers stay clean ──────────────────────


func test_expired_unknown_event_id_does_not_crash() -> void:
	EventBus.market_event_expired.emit(&"nonexistent_event_xyz")
	assert_almost_eq(
		_system._active_event_spawn_modifier,
		1.0,
		FLOAT_TOLERANCE,
		"Spawn modifier must remain 1.0 after expiring an unknown event"
	)
	assert_almost_eq(
		_system._active_event_intent_modifier,
		1.0,
		FLOAT_TOLERANCE,
		"Intent modifier must remain 1.0 after expiring an unknown event"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _make_profile() -> CustomerTypeDefinition:
	var p := CustomerTypeDefinition.new()
	p.id = "test_customer"
	p.customer_name = "Test Customer"
	p.budget_range = [10.0, 200.0]
	p.patience = 0.5
	p.price_sensitivity = 0.5
	p.preferred_categories = PackedStringArray([])
	p.preferred_tags = PackedStringArray([])
	p.condition_preference = "good"
	p.browse_time_range = [1.0, 2.0]
	p.purchase_probability_base = BASE_INTENT
	p.impulse_buy_chance = 0.1
	p.mood_tags = PackedStringArray([])
	return p
