## Integration test: TrendSystem → MarketValueSystem pricing chain — trend spawned →
## qualifying items receive demand multiplier → calculated price reflects new value.
extends GutTest

var _trend_system: TrendSystem
var _market_value: MarketValueSystem
var _saved_day: int

const TREND_CATEGORY: String = "electronics"
const OTHER_CATEGORY: String = "sports_memorabilia"
const BASE_PRICE: float = 20.0
const TREND_MULTIPLIER: float = 1.5
const ACTIVE_DAY: int = 1
const END_DAY: int = 4
const FADE_END_DAY: int = 6
const FLOAT_EPSILON: float = 0.01


func before_each() -> void:
	_saved_day = GameManager.current_day
	GameManager.current_day = ACTIVE_DAY
	_trend_system = TrendSystem.new()
	add_child_autofree(_trend_system)
	# Prevent auto-generation from firing during day-advance loops.
	_trend_system._days_until_next_shift = 100
	_market_value = MarketValueSystem.new()
	add_child_autofree(_market_value)
	_market_value._trend_system = _trend_system


func after_each() -> void:
	GameManager.current_day = _saved_day


func _create_item(category: String) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "test_item_%s" % category
	def.item_name = "Test Item"
	def.base_price = BASE_PRICE
	def.rarity = "common"
	def.condition_range = PackedStringArray(["good"])
	def.tags = PackedStringArray([])
	def.category = category
	def.store_type = ""
	return ItemInstance.create_from_definition(def, "good")


func _inject_trend(
	category: String,
	multiplier: float,
	active_day: int,
	end_day: int,
	fade_end_day: int,
) -> void:
	var trend: Dictionary = {
		"target_type": "category",
		"target": category,
		"trend_type": TrendSystem.TrendType.HOT,
		"multiplier": multiplier,
		"announced_day": active_day,
		"active_day": active_day,
		"end_day": end_day,
		"fade_end_day": fade_end_day,
	}
	_trend_system._active_trends.append(trend)
	_trend_system._emit_trend_changed()


# --- Scenario A: active trend raises prices ---


func test_trend_changed_fires_when_trend_injected() -> void:
	var fired: bool = false
	var cb: Callable = func(_hot: Array, _cold: Array) -> void:
		fired = true
	EventBus.trend_changed.connect(cb)

	_inject_trend(TREND_CATEGORY, TREND_MULTIPLIER, ACTIVE_DAY, END_DAY, FADE_END_DAY)

	assert_true(fired, "trend_changed should fire when a trend is injected")
	EventBus.trend_changed.disconnect(cb)


func test_trending_item_price_above_baseline() -> void:
	var item: ItemInstance = _create_item(TREND_CATEGORY)
	var baseline: float = _market_value.calculate_item_value(item)
	assert_gt(baseline, 0.0, "Baseline price should be positive")

	_inject_trend(TREND_CATEGORY, TREND_MULTIPLIER, ACTIVE_DAY, END_DAY, FADE_END_DAY)
	_market_value.invalidate_cache()

	var elevated: float = _market_value.calculate_item_value(item)
	assert_gt(elevated, baseline, "Price should be elevated after trend activates")


func test_trending_item_price_equals_baseline_times_multiplier() -> void:
	var item: ItemInstance = _create_item(TREND_CATEGORY)
	var baseline: float = _market_value.calculate_item_value(item)

	_inject_trend(TREND_CATEGORY, TREND_MULTIPLIER, ACTIVE_DAY, END_DAY, FADE_END_DAY)
	_market_value.invalidate_cache()

	var elevated: float = _market_value.calculate_item_value(item)
	assert_almost_eq(
		elevated,
		baseline * TREND_MULTIPLIER,
		FLOAT_EPSILON,
		"Elevated price should equal baseline × trend multiplier"
	)


# --- Scenario B: trend expiry restores baseline ---


func test_no_active_trends_remain_after_expiry() -> void:
	_inject_trend(TREND_CATEGORY, TREND_MULTIPLIER, ACTIVE_DAY, END_DAY, FADE_END_DAY)
	assert_eq(_trend_system._active_trends.size(), 1, "One trend active before expiry")

	# Advance through all days up to and including fade_end_day.
	for day: int in range(ACTIVE_DAY + 1, FADE_END_DAY + 1):
		GameManager.current_day = day
		_trend_system._on_day_started(day)

	assert_eq(_trend_system._active_trends.size(), 0, "No active trends remain after expiry")


func test_price_returns_to_baseline_after_trend_expires() -> void:
	var item: ItemInstance = _create_item(TREND_CATEGORY)
	var baseline: float = _market_value.calculate_item_value(item)

	_inject_trend(TREND_CATEGORY, TREND_MULTIPLIER, ACTIVE_DAY, END_DAY, FADE_END_DAY)
	_market_value.invalidate_cache()
	assert_gt(
		_market_value.calculate_item_value(item),
		baseline,
		"Price should be elevated with active trend"
	)

	# Advance through all days up to and including fade_end_day.
	for day: int in range(ACTIVE_DAY + 1, FADE_END_DAY + 1):
		GameManager.current_day = day
		_trend_system._on_day_started(day)
	_market_value.invalidate_cache()

	var restored: float = _market_value.calculate_item_value(item)
	assert_almost_eq(
		restored,
		baseline,
		FLOAT_EPSILON,
		"Price should return to original baseline after trend expires"
	)


# --- Scenario C: non-trending category is unaffected ---


func test_non_trending_category_price_unchanged() -> void:
	var unaffected: ItemInstance = _create_item(OTHER_CATEGORY)
	var baseline: float = _market_value.calculate_item_value(unaffected)

	_inject_trend(TREND_CATEGORY, TREND_MULTIPLIER, ACTIVE_DAY, END_DAY, FADE_END_DAY)
	_market_value.invalidate_cache()

	var after_trend: float = _market_value.calculate_item_value(unaffected)
	assert_almost_eq(
		after_trend,
		baseline,
		FLOAT_EPSILON,
		"Non-trending category item should not be affected by electronics trend"
	)
