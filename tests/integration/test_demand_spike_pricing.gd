## Integration test: demand spike pricing chain — MarketEventSystem spike → multiplier
## applied → MarketValueSystem price updated.
extends GutTest

var _market_event: MarketEventSystem
var _market_value: MarketValueSystem
var _saved_day: int

const SPIKE_MAGNITUDE: float = 2.5
const BASE_PRICE: float = 10.0
const SPIKE_CATEGORY: String = "trading_cards"
const SPIKE_TAG: String = "rookie"


func before_each() -> void:
	_saved_day = GameManager.current_day
	GameManager.current_day = 1
	_market_event = MarketEventSystem.new()
	add_child_autofree(_market_event)
	_market_value = MarketValueSystem.new()
	add_child_autofree(_market_value)
	# Wire the event system directly; inventory/trend/seasonal not needed for price chain.
	_market_value._market_event_system = _market_event


func after_each() -> void:
	GameManager.current_day = _saved_day


func _create_spike_def(overrides: Dictionary = {}) -> MarketEventDefinition:
	var def := MarketEventDefinition.new()
	def.id = overrides.get("id", "test_spike")
		def.name = overrides.get("name", "Test Demand Spike")
	def.event_type = "spike"
	def.target_tags = overrides.get(
		"target_tags", PackedStringArray([SPIKE_TAG])
	)
	def.target_categories = overrides.get(
		"target_categories", PackedStringArray([SPIKE_CATEGORY])
	)
	def.magnitude = overrides.get("magnitude", SPIKE_MAGNITUDE)
	def.duration_days = overrides.get("duration_days", 3)
	def.announcement_days = overrides.get("announcement_days", 0)
	def.ramp_up_days = overrides.get("ramp_up_days", 0)
	def.ramp_down_days = overrides.get("ramp_down_days", 0)
	def.cooldown_days = overrides.get("cooldown_days", 5)
	def.weight = 1.0
	def.announcement_text = ""
	def.active_text = ""
	return def


func _create_item(
	tags: PackedStringArray = PackedStringArray([SPIKE_TAG]),
	category: String = SPIKE_CATEGORY,
) -> ItemInstance:
	var item_def := ItemDefinition.new()
	item_def.id = "test_card"
	item_def.item_name = "Test Card"
	item_def.base_price = BASE_PRICE
	item_def.rarity = "common"
	item_def.condition_range = PackedStringArray(["good"])
	item_def.tags = tags
	item_def.category = category
	item_def.store_type = "sports_memorabilia"
	return ItemInstance.create_from_definition(item_def, "good")


# --- Scenario: demand spike raises item price ---


func test_spike_activates_and_market_event_started_fires() -> void:
	var started_fired: Array = [false]
	var got_id: Array = [""]
	var cb: Callable = func(id: String) -> void:
		started_fired[0] = true
		got_id[0] = id
	EventBus.market_event_started.connect(cb)

	var spike_def: MarketEventDefinition = _create_spike_def()
	_market_event._activate_event(spike_def, 1)

	assert_true(
		started_fired[0],
		"market_event_started should fire when no-announcement spike activates"
	)
	assert_eq(got_id[0], "test_spike", "Fired event id matches spike definition id")
	EventBus.market_event_started.disconnect(cb)


func test_market_event_system_records_active_spike_for_category() -> void:
	var spike_def: MarketEventDefinition = _create_spike_def()
	_market_event._activate_event(spike_def, 1)
	_market_event._advance_event_lifecycles(1)

	assert_eq(
		_market_event.get_active_effect_count(), 1,
		"MarketEventSystem should record one active spike"
	)
	var item: ItemInstance = _create_item()
	var mult: float = _market_event.get_trend_multiplier(item)
	assert_almost_eq(
		mult, SPIKE_MAGNITUDE, 0.01,
		"Multiplier should equal spike magnitude during full effect"
	)


func test_spike_raises_item_price_above_baseline() -> void:
	var item: ItemInstance = _create_item()
	var baseline: float = _market_value.calculate_item_value(item)
	assert_gt(baseline, 0.0, "Baseline price should be positive")

	var spike_def: MarketEventDefinition = _create_spike_def()
	_market_event._activate_event(spike_def, 1)
	_market_event._advance_event_lifecycles(1)
	_market_value.invalidate_cache()

	var spiked_price: float = _market_value.calculate_item_value(item)
	assert_gt(spiked_price, baseline, "Spike should raise item price above baseline")


func test_spike_price_matches_expected_multiplier() -> void:
	var item: ItemInstance = _create_item()
	var baseline: float = _market_value.calculate_item_value(item)

	var spike_def: MarketEventDefinition = _create_spike_def()
	_market_event._activate_event(spike_def, 1)
	_market_event._advance_event_lifecycles(1)
	_market_value.invalidate_cache()

	var spiked_price: float = _market_value.calculate_item_value(item)
	assert_almost_eq(
		spiked_price,
		baseline * SPIKE_MAGNITUDE,
		0.01,
		"Spiked price should equal baseline times spike magnitude"
	)


# --- Scenario: spike expires and price returns to baseline ---


func test_market_event_ended_fires_when_spike_expires() -> void:
	var ended_fired: Array = [false]
	var ended_id: Array = [""]
	var cb: Callable = func(id: String) -> void:
		ended_fired[0] = true
		ended_id[0] = id
	EventBus.market_event_ended.connect(cb)

	var spike_def: MarketEventDefinition = _create_spike_def({
		"duration_days": 3,
	})
	_market_event._activate_event(spike_def, 1)
	# end_day = announced_day(1) + announcement_days(0) + duration_days(3) = 4
	_market_event._advance_event_lifecycles(3)
	assert_false(ended_fired[0], "Should not expire before end_day")
	_market_event._advance_event_lifecycles(4)
	assert_true(ended_fired[0], "market_event_ended should fire when day >= end_day")
	assert_eq(ended_id[0], "test_spike", "Ended event id matches spike definition id")
	EventBus.market_event_ended.disconnect(cb)


func test_spike_expiry_removes_active_effect() -> void:
	var spike_def: MarketEventDefinition = _create_spike_def({
		"duration_days": 3,
	})
	_market_event._activate_event(spike_def, 1)
	_market_event._advance_event_lifecycles(1)
	assert_eq(
		_market_event.get_active_effect_count(), 1,
		"One active effect while spike is live"
	)
	# end_day = 1 + 0 + 3 = 4
	_market_event._advance_event_lifecycles(4)
	assert_eq(
		_market_event.get_active_effect_count(), 0,
		"No active effects after spike expires"
	)


func test_price_returns_to_baseline_after_spike_expires() -> void:
	var item: ItemInstance = _create_item()
	var baseline: float = _market_value.calculate_item_value(item)

	var spike_def: MarketEventDefinition = _create_spike_def({
		"duration_days": 3,
	})
	_market_event._activate_event(spike_def, 1)
	_market_event._advance_event_lifecycles(1)
	_market_value.invalidate_cache()
	var spiked_price: float = _market_value.calculate_item_value(item)
	assert_gt(spiked_price, baseline, "Price should be elevated during spike")

	# end_day = 1 + 0 + 3 = 4
	_market_event._advance_event_lifecycles(4)
	_market_value.invalidate_cache()

	var returned_price: float = _market_value.calculate_item_value(item)
	assert_almost_eq(
		returned_price, baseline, 0.01,
		"Price should return to baseline after spike expires"
	)


# --- Scenario: unaffected items are not repriced ---


func test_unaffected_category_price_unchanged_during_spike() -> void:
	var unaffected_item: ItemInstance = _create_item(
		PackedStringArray(["vintage"]), "electronics"
	)
	var baseline_unaffected: float = _market_value.calculate_item_value(
		unaffected_item
	)

	var spike_def: MarketEventDefinition = _create_spike_def()
	_market_event._activate_event(spike_def, 1)
	_market_event._advance_event_lifecycles(1)
	_market_value.invalidate_cache()

	var after_spike: float = _market_value.calculate_item_value(
		unaffected_item
	)
	assert_almost_eq(
		after_spike, baseline_unaffected, 0.01,
		"Unaffected item price should not change when spike targets other category"
	)


# --- Scenario: multiple simultaneous spikes stack multipliers ---


func test_two_simultaneous_spikes_stack_multipliers() -> void:
	var item: ItemInstance = _create_item(
		PackedStringArray([]), SPIKE_CATEGORY
	)
	var baseline: float = _market_value.calculate_item_value(item)

	var spike_a: MarketEventDefinition = _create_spike_def({
		"id": "spike_a",
		"magnitude": 1.5,
		"target_tags": PackedStringArray([]),
		"target_categories": PackedStringArray([SPIKE_CATEGORY]),
	})
	var spike_b: MarketEventDefinition = _create_spike_def({
		"id": "spike_b",
		"magnitude": 1.4,
		"target_tags": PackedStringArray([]),
		"target_categories": PackedStringArray([SPIKE_CATEGORY]),
	})

	_market_event._activate_event(spike_a, 1)
	_market_event._activate_event(spike_b, 1)
	_market_event._advance_event_lifecycles(1)
	_market_value.invalidate_cache()

	var stacked_price: float = _market_value.calculate_item_value(item)
	assert_almost_eq(
		stacked_price,
		baseline * 1.5 * 1.4,
		0.01,
		"Simultaneous spikes should multiply their magnitudes together"
	)
