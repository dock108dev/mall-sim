## Integration test: SeasonalEventSystem → MarketValueSystem pricing chain — seasonal event
## activation → spending multiplier applied → calculate_item_value reflects seasonal boost.
extends GutTest

var _seasonal_event: SeasonalEventSystem
var _market_value: MarketValueSystem
var _saved_day: int
var _event_def: SeasonalEventDefinition

const BASE_PRICE: float = 20.0
const SPORTS_CATEGORY: String = "sports_memorabilia"
const OTHER_CATEGORY: String = "retro_games"
const FLOAT_EPSILON: float = 0.01
const EVENT_DURATION: int = 15
const ACTIVE_DAY: int = 5
const EXPIRE_DAY: int = ACTIVE_DAY + EVENT_DURATION


func before_each() -> void:
	_saved_day = GameManager.current_day
	GameManager.current_day = 1
	_event_def = _create_event_def()
	_seasonal_event = SeasonalEventSystem.new()
	add_child_autofree(_seasonal_event)
	_market_value = MarketValueSystem.new()
	add_child_autofree(_market_value)
	_market_value._seasonal_event_system = _seasonal_event
	EventBus.seasonal_multipliers_updated.connect(
		_market_value._on_seasonal_multipliers_updated
	)


func after_each() -> void:
	GameManager.current_day = _saved_day
	if EventBus.seasonal_multipliers_updated.is_connected(
		_market_value._on_seasonal_multipliers_updated
	):
		EventBus.seasonal_multipliers_updated.disconnect(
			_market_value._on_seasonal_multipliers_updated
		)


func _create_event_def() -> SeasonalEventDefinition:
	var def := SeasonalEventDefinition.new()
	def.id = "sports_season_kickoff"
	def.name = "Sports Season Kickoff"
	def.frequency_days = 90
	def.duration_days = EVENT_DURATION
	def.offset_days = 20
	def.customer_traffic_multiplier = 1.5
	def.spending_multiplier = 1.2
	def.customer_type_weights = {
		"serious_collector": 1.8,
		"casual_fan": 2.0,
	}
	def.target_categories = PackedStringArray([
		"sports_card", "autographed", "jersey", "memorabilia",
	])
	def.announcement_text = ""
	def.active_text = ""
	return def


func _create_item(
	category: String, store_type: String = ""
) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "test_%s_item" % category
	def.item_name = "Test Item"
	def.base_price = BASE_PRICE
	def.rarity = "common"
	def.condition_range = PackedStringArray(["good"])
	def.tags = PackedStringArray([])
	def.category = category
	def.store_type = store_type
	return ItemInstance.create_from_definition(def, "good")


func _activate_event() -> void:
	_seasonal_event._active_events.append({
		"definition": _event_def,
		"start_day": ACTIVE_DAY,
	})


# --- Scenario A: season start raises item prices ---


func test_seasonal_event_started_fires_on_promotion() -> void:
	var started_id: Array = [""]
	var cb: Callable = func(id: String) -> void:
		started_id[0] = id
	EventBus.seasonal_event_started.connect(cb)

	_seasonal_event._announced_events.append({
		"definition": _event_def,
		"announced_day": ACTIVE_DAY - SeasonalEventSystem.ANNOUNCEMENT_DAYS,
	})
	_seasonal_event._on_day_started(ACTIVE_DAY)

	assert_eq(
		started_id[0],
		_event_def.id,
		"seasonal_event_started should fire with correct event id"
	)
	EventBus.seasonal_event_started.disconnect(cb)


func test_price_elevated_during_active_season() -> void:
	var item: ItemInstance = _create_item(SPORTS_CATEGORY)
	var baseline: float = _market_value.calculate_item_value(item)
	assert_gt(baseline, 0.0, "Baseline price should be positive")

	_activate_event()
	_market_value.invalidate_cache()

	var elevated: float = _market_value.calculate_item_value(item)
	assert_gt(
		elevated,
		baseline,
		"Price should be elevated after seasonal event activates"
	)


func test_price_equals_baseline_times_spending_multiplier() -> void:
	var item: ItemInstance = _create_item(SPORTS_CATEGORY)
	var baseline: float = _market_value.calculate_item_value(item)

	_activate_event()
	_market_value.invalidate_cache()

	var elevated: float = _market_value.calculate_item_value(item)
	assert_almost_eq(
		elevated,
		baseline * _event_def.spending_multiplier,
		FLOAT_EPSILON,
		"Price should equal baseline × spending_multiplier from event def"
	)


func test_seasonal_multipliers_updated_fires_on_day_started() -> void:
	var fired: Array = [false]
	var cb: Callable = func(_m: Dictionary) -> void:
		fired[0] = true
	EventBus.seasonal_multipliers_updated.connect(cb)

	_seasonal_event._on_day_started(ACTIVE_DAY)

	assert_true(
		fired[0],
		"seasonal_multipliers_updated should fire on day_started"
	)
	EventBus.seasonal_multipliers_updated.disconnect(cb)


# --- Scenario B: season end restores baseline ---


func test_seasonal_event_ended_fires_after_duration() -> void:
	var ended_id: Array = [""]
	var cb: Callable = func(id: String) -> void:
		ended_id[0] = id
	EventBus.seasonal_event_ended.connect(cb)

	_activate_event()
	_seasonal_event._on_day_started(EXPIRE_DAY)

	assert_eq(
		ended_id[0],
		_event_def.id,
		"seasonal_event_ended should fire with correct event id"
	)
	EventBus.seasonal_event_ended.disconnect(cb)


func test_price_returns_to_baseline_after_season_ends() -> void:
	var item: ItemInstance = _create_item(SPORTS_CATEGORY)
	var baseline: float = _market_value.calculate_item_value(item)

	_activate_event()
	_market_value.invalidate_cache()
	assert_gt(
		_market_value.calculate_item_value(item),
		baseline,
		"Price should be elevated during active season"
	)

	_seasonal_event._on_day_started(EXPIRE_DAY)
	_market_value.invalidate_cache()

	var restored: float = _market_value.calculate_item_value(item)
	assert_almost_eq(
		restored,
		baseline,
		FLOAT_EPSILON,
		"Price should return to baseline after seasonal event ends"
	)


# --- Scenario C: item in non-seasonal category is unaffected ---


func test_non_seasonal_store_type_unaffected_by_calendar_multiplier() -> void:
	var sports_item: ItemInstance = _create_item(
		SPORTS_CATEGORY, "sports"
	)
	var retro_item: ItemInstance = _create_item(
		OTHER_CATEGORY, "retro_games"
	)
	var retro_baseline: float = _market_value.calculate_item_value(
		retro_item
	)

	_seasonal_event._seasonal_config = [
		{
			"index": 0,
			"store_multipliers": {"sports": 1.4},
		},
	]
	_seasonal_event._current_season = 0
	# Day 1 quarantine suppresses seasonal_multipliers_updated; use Day 2.
	_seasonal_event._on_day_started(2)
	_market_value.invalidate_cache()

	var sports_value: float = _market_value.calculate_item_value(
		sports_item
	)
	var retro_value: float = _market_value.calculate_item_value(
		retro_item
	)

	assert_gt(
		sports_value,
		retro_value,
		"Sports item with calendar seasonal multiplier should cost more"
	)
	assert_almost_eq(
		retro_value,
		retro_baseline,
		FLOAT_EPSILON,
		"Retro games item should equal baseline — no seasonal modifier"
	)
