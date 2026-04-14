## Integration test: market trend daily pipeline — day_ended → MarketTrendSystem shift →
## trend_shifted emitted → MarketValueSystem price cache invalidated.
extends GutTest

var _trend_system: MarketTrendSystem
var _market_value: MarketValueSystem
var _shifted_categories: Array[StringName] = []
var _shifted_levels: Array[float] = []

# Volatility high enough that every single randf_range call produces a delta > SHIFT_THRESHOLD.
const HIGH_VOLATILITY: float = 1.8
# Volatility low enough that every single randf_range call stays below SHIFT_THRESHOLD (0.1).
const LOW_VOLATILITY: float = 0.001
const FLOAT_EPSILON: float = 0.001
const TEST_CATEGORY: StringName = &"tech"
# Seed that produces large deltas across all categories with HIGH_VOLATILITY.
const SEED_LARGE_SHIFT: int = 12345
# Seed used when small shifts are required.
const SEED_SMALL_SHIFT: int = 99


func before_each() -> void:
	_shifted_categories = []
	_shifted_levels = []
	_trend_system = MarketTrendSystem.new()
	add_child_autofree(_trend_system)
	_market_value = MarketValueSystem.new()
	add_child_autofree(_market_value)
	_market_value.initialize(null, null, null)
	EventBus.trend_shifted.connect(_capture_trend_shifted)


func after_each() -> void:
	if EventBus.trend_shifted.is_connected(_capture_trend_shifted):
		EventBus.trend_shifted.disconnect(_capture_trend_shifted)


func _capture_trend_shifted(category_id: StringName, new_level: float) -> void:
	_shifted_categories.append(category_id)
	_shifted_levels.append(new_level)


# --- Scenario A: day_ended drives a shift across all tracked categories ---


func test_day_ended_triggers_trend_update() -> void:
	for key: Variant in _trend_system.get_all_trend_levels():
		_trend_system._trend_levels[key] = 1.0
		_trend_system._category_configs[key]["volatility"] = HIGH_VOLATILITY
	var before: Dictionary = _trend_system.get_all_trend_levels()
	var day_before: int = _trend_system._current_day
	seed(SEED_LARGE_SHIFT)
	EventBus.day_ended.emit(1)
	assert_eq(
		_trend_system._current_day,
		day_before + 1,
		"MarketTrendSystem._current_day must increment after day_ended"
	)
	var after: Dictionary = _trend_system.get_all_trend_levels()
	var changed_count: int = 0
	for key: Variant in before:
		if not is_equal_approx(float(before[key]), float(after[key])):
			changed_count += 1
	assert_eq(
		changed_count,
		before.size(),
		"day_ended must trigger a level shift for all %d tracked categories" % before.size()
	)


# --- Scenario B: a shift >= 0.1 fires trend_shifted with correct args ---


func test_significant_shift_emits_trend_shifted() -> void:
	for key: Variant in _trend_system.get_all_trend_levels():
		_trend_system._trend_levels[key] = 1.0
		_trend_system._category_configs[key]["volatility"] = HIGH_VOLATILITY
	seed(SEED_LARGE_SHIFT)
	_trend_system._shift_trends()
	assert_true(
		_shifted_categories.size() > 0,
		"At least one trend_shifted must fire when volatility is %.1f" % HIGH_VOLATILITY
	)
	for i: int in range(_shifted_categories.size()):
		var cat: StringName = _shifted_categories[i]
		var reported_level: float = _shifted_levels[i]
		var actual_level: float = _trend_system.get_trend_modifier(cat)
		assert_almost_eq(
			reported_level,
			actual_level,
			FLOAT_EPSILON,
			"trend_shifted new_level arg must match stored level for %s" % cat
		)


# --- Scenario C: a shift < 0.1 must NOT fire trend_shifted ---


func test_sub_threshold_shift_suppressed() -> void:
	for key: Variant in _trend_system.get_all_trend_levels():
		_trend_system._category_configs[key]["volatility"] = LOW_VOLATILITY
	_market_value._cache[&"cached_item"] = 42.0
	seed(SEED_SMALL_SHIFT)
	EventBus.day_ended.emit(1)
	assert_eq(
		_shifted_categories.size(),
		0,
		"trend_shifted must not fire when all shifts are below SHIFT_THRESHOLD"
	)
	assert_true(
		_market_value._cache.has(&"cached_item"),
		"Cache must remain valid when no trend_shifted fires"
	)


# --- Scenario D: trend_shifted clears the MarketValueSystem price cache ---


func test_trend_shifted_invalidates_price_cache() -> void:
	_market_value._cache[&"stale_item"] = 50.0
	assert_false(
		_market_value._cache.is_empty(),
		"Cache must be non-empty before trend_shifted fires"
	)
	EventBus.trend_shifted.emit(TEST_CATEGORY, 1.3)
	assert_true(
		_market_value._cache.is_empty(),
		"Cache must be cleared (equivalent invalidation) after trend_shifted fires"
	)


func test_stale_price_not_returned_after_shift() -> void:
	const STALE_ITEM_ID: StringName = &"stale_item"
	const STALE_VALUE: float = 99.99
	_market_value._cache[STALE_ITEM_ID] = STALE_VALUE
	assert_true(
		_market_value._cache.has(STALE_ITEM_ID),
		"Stale cache entry must be present before the shift"
	)
	EventBus.trend_shifted.emit(TEST_CATEGORY, 1.5)
	assert_false(
		_market_value._cache.has(STALE_ITEM_ID),
		"Stale cache entry must not survive after trend_shifted invalidates the cache"
	)


# --- Scenario E: full chain — day_ended → shift → trend_shifted → cache invalidated ---


func test_full_chain_day_ended_to_cache_invalidation() -> void:
	for key: Variant in _trend_system.get_all_trend_levels():
		_trend_system._trend_levels[key] = 1.0
		_trend_system._category_configs[key]["volatility"] = HIGH_VOLATILITY
	_market_value._cache[&"chain_item"] = 77.0
	var day_before: int = _trend_system._current_day
	seed(SEED_LARGE_SHIFT)
	EventBus.day_ended.emit(1)
	assert_eq(
		_trend_system._current_day,
		day_before + 1,
		"Chain link 1: _current_day must advance"
	)
	assert_true(
		_shifted_categories.size() > 0,
		"Chain link 2: trend_shifted must fire for high-volatility categories"
	)
	assert_true(
		_market_value._cache.is_empty(),
		"Chain link 3: price cache must be cleared after trend_shifted propagation"
	)


# --- Scenario F: clamping ensures levels stay within [MIN_LEVEL, MAX_LEVEL] ---


func test_clamping_respected() -> void:
	for key: Variant in _trend_system.get_all_trend_levels():
		_trend_system._trend_levels[key] = 0.05
		_trend_system._category_configs[key]["volatility"] = HIGH_VOLATILITY
	for _i: int in range(10):
		_trend_system._shift_trends()
	for key: Variant in _trend_system.get_all_trend_levels():
		var level: float = _trend_system.get_trend_modifier(key as StringName)
		assert_true(
			level >= MarketTrendSystem.MIN_LEVEL,
			"Level for %s must be >= MIN_LEVEL (%.1f)" % [key, MarketTrendSystem.MIN_LEVEL]
		)
		assert_true(
			level <= MarketTrendSystem.MAX_LEVEL,
			"Level for %s must be <= MAX_LEVEL (%.1f)" % [key, MarketTrendSystem.MAX_LEVEL]
		)
