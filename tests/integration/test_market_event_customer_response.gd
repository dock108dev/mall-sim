## Integration test: MarketEventSystem demand spike → CustomerSystem elevated
## purchase intent for spiked category.
extends GutTest

var _market_event: MarketEventSystem
var _customer_system: CustomerSystem
var _saved_day: int

const SPIKE_CATEGORY: StringName = &"sports_memorabilia"
const UNAFFECTED_CATEGORY: StringName = &"retro_games"
const SPIKE_MAGNITUDE: float = 1.5


func before_each() -> void:
	_saved_day = GameManager.current_day
	GameManager.current_day = 1
	_market_event = MarketEventSystem.new()
	add_child_autofree(_market_event)
	_customer_system = CustomerSystem.new()
	add_child_autofree(_customer_system)
	_customer_system.set_market_event_system(_market_event)


func after_each() -> void:
	GameManager.current_day = _saved_day


func _create_spike_def(overrides: Dictionary = {}) -> MarketEventDefinition:
	var def := MarketEventDefinition.new()
	def.id = overrides.get("id", "test_demand_spike")
		def.name = overrides.get("name", "Test Demand Spike")
	def.event_type = "spike"
	def.target_tags = overrides.get(
		"target_tags", PackedStringArray([])
	)
	def.target_categories = overrides.get(
		"target_categories",
		PackedStringArray([String(SPIKE_CATEGORY)])
	)
	def.magnitude = overrides.get("magnitude", SPIKE_MAGNITUDE)
	def.duration_days = overrides.get("duration_days", 5)
	def.announcement_days = overrides.get("announcement_days", 0)
	def.ramp_up_days = overrides.get("ramp_up_days", 0)
	def.ramp_down_days = overrides.get("ramp_down_days", 0)
	def.cooldown_days = overrides.get("cooldown_days", 10)
	def.weight = 1.0
	def.announcement_text = ""
	def.active_text = ""
	return def


func _create_collector_profile() -> CustomerTypeDefinition:
	var profile := CustomerTypeDefinition.new()
	profile.id = "collector"
	profile.customer_name = "Collector"
	profile.store_types = PackedStringArray(["sports_memorabilia"])
	profile.budget_range = [5.0, 100.0]
	profile.patience = 0.7
	profile.price_sensitivity = 0.4
	profile.preferred_categories = PackedStringArray(
		[String(SPIKE_CATEGORY)]
	)
	profile.preferred_tags = PackedStringArray([])
	profile.condition_preference = "near_mint"
	profile.browse_time_range = [30.0, 60.0]
	profile.purchase_probability_base = 0.6
	profile.impulse_buy_chance = 0.1
	profile.visit_frequency = "high"
	profile.max_price_to_market_ratio = 1.0
	return profile


# --- Scenario A: demand spike elevates customer purchase intent ---


func test_market_event_registers_active_spike() -> void:
	var spike_def: MarketEventDefinition = _create_spike_def()
	_market_event._activate_event(spike_def, 1)
	_market_event._advance_event_lifecycles(1)

	assert_eq(
		_market_event.get_active_effect_count(), 1,
		"MarketEventSystem should register one active spike"
	)
	var cat_mult: float = (
		_market_event.get_category_demand_multiplier(SPIKE_CATEGORY)
	)
	assert_almost_eq(
		cat_mult, SPIKE_MAGNITUDE, 0.01,
		"Category multiplier should equal spike magnitude during full effect"
	)


func test_purchase_intent_baseline_before_spike() -> void:
	var profile: CustomerTypeDefinition = _create_collector_profile()
	var baseline: float = (
		_customer_system.get_purchase_intent_for_category(
			profile, SPIKE_CATEGORY
		)
	)
	assert_almost_eq(
		baseline, profile.purchase_probability_base, 0.001,
		"Baseline intent should equal profile purchase_probability_base"
	)


func test_purchase_intent_elevated_after_spike() -> void:
	var profile: CustomerTypeDefinition = _create_collector_profile()
	var baseline: float = (
		_customer_system.get_purchase_intent_for_category(
			profile, SPIKE_CATEGORY
		)
	)

	var spike_def: MarketEventDefinition = _create_spike_def()
	_market_event._activate_event(spike_def, 1)
	_market_event._advance_event_lifecycles(1)

	var spiked_intent: float = (
		_customer_system.get_purchase_intent_for_category(
			profile, SPIKE_CATEGORY
		)
	)
	var min_expected: float = baseline * 1.2
	assert_gte(
		spiked_intent, min_expected,
		"Post-spike intent (%.3f) should be >= baseline × 1.2 (%.3f)"
		% [spiked_intent, min_expected]
	)


func test_intent_bonus_scales_with_event_magnitude() -> void:
	var profile: CustomerTypeDefinition = _create_collector_profile()
	var baseline: float = profile.purchase_probability_base
	var expected_bonus: float = (SPIKE_MAGNITUDE - 1.0) * baseline

	var spike_def: MarketEventDefinition = _create_spike_def()
	_market_event._activate_event(spike_def, 1)
	_market_event._advance_event_lifecycles(1)

	var spiked_intent: float = (
		_customer_system.get_purchase_intent_for_category(
			profile, SPIKE_CATEGORY
		)
	)
	assert_almost_eq(
		spiked_intent, baseline + expected_bonus, 0.01,
		"Intent bonus should scale with event magnitude"
	)


# --- Scenario B: category isolation ---


func test_unaffected_category_intent_unchanged() -> void:
	var profile: CustomerTypeDefinition = _create_collector_profile()
	var baseline: float = (
		_customer_system.get_purchase_intent_for_category(
			profile, UNAFFECTED_CATEGORY
		)
	)

	var spike_def: MarketEventDefinition = _create_spike_def()
	_market_event._activate_event(spike_def, 1)
	_market_event._advance_event_lifecycles(1)

	var post_spike: float = (
		_customer_system.get_purchase_intent_for_category(
			profile, UNAFFECTED_CATEGORY
		)
	)
	assert_almost_eq(
		post_spike, baseline, 0.001,
		"Intent for non-spiked category should remain at baseline"
	)


func test_category_multiplier_unaffected_for_other_category() -> void:
	var spike_def: MarketEventDefinition = _create_spike_def()
	_market_event._activate_event(spike_def, 1)
	_market_event._advance_event_lifecycles(1)

	var mult: float = (
		_market_event.get_category_demand_multiplier(UNAFFECTED_CATEGORY)
	)
	assert_almost_eq(
		mult, 1.0, 0.01,
		"Category multiplier for non-spiked category should be 1.0"
	)


# --- Scenario C: spike expiry resets customer intent bonus ---


func test_intent_returns_to_baseline_after_spike_expires() -> void:
	var profile: CustomerTypeDefinition = _create_collector_profile()
	var baseline: float = (
		_customer_system.get_purchase_intent_for_category(
			profile, SPIKE_CATEGORY
		)
	)

	var spike_def: MarketEventDefinition = _create_spike_def({
		"duration_days": 3,
	})
	_market_event._activate_event(spike_def, 1)
	_market_event._advance_event_lifecycles(1)

	var spiked: float = (
		_customer_system.get_purchase_intent_for_category(
			profile, SPIKE_CATEGORY
		)
	)
	assert_gt(
		spiked, baseline,
		"Intent should be elevated during active spike"
	)

	# end_day = announced_day(1) + announcement_days(0) + duration_days(3) = 4
	_market_event._advance_event_lifecycles(4)

	var post_expiry: float = (
		_customer_system.get_purchase_intent_for_category(
			profile, SPIKE_CATEGORY
		)
	)
	assert_almost_eq(
		post_expiry, baseline, 0.001,
		"Intent should return to baseline after spike expires"
	)


func test_active_effect_count_zero_after_expiry() -> void:
	var spike_def: MarketEventDefinition = _create_spike_def({
		"duration_days": 3,
	})
	_market_event._activate_event(spike_def, 1)
	_market_event._advance_event_lifecycles(1)
	assert_eq(
		_market_event.get_active_effect_count(), 1,
		"One active effect while spike is live"
	)

	_market_event._advance_event_lifecycles(4)
	assert_eq(
		_market_event.get_active_effect_count(), 0,
		"No active effects after spike expires"
	)
