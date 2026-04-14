## Unit tests for MarketTrendSystem: volatility clamping, signal threshold, category modifiers,
## day counter, reproducibility, daily shift behavior, and modifier accessor.
extends GutTest


var _system: MarketTrendSystem
var _emitted_categories: Array[StringName] = []
var _emitted_levels: Array[float] = []


func before_each() -> void:
	_emitted_categories = []
	_emitted_levels = []
	_system = MarketTrendSystem.new()
	add_child_autofree(_system)
	EventBus.trend_shifted.connect(_on_trend_shifted)


func after_each() -> void:
	if EventBus.trend_shifted.is_connected(_on_trend_shifted):
		EventBus.trend_shifted.disconnect(_on_trend_shifted)


func _on_trend_shifted(category_id: StringName, new_level: float) -> void:
	_emitted_categories.append(category_id)
	_emitted_levels.append(new_level)


# --- Volatility clamping ---

func test_volatility_clamp_lower() -> void:
	var clamped: float = MarketTrendSystemSingleton._clamp_volatility(-0.5)
	assert_almost_eq(
		clamped, 0.0, 0.001,
		"raw_volatility of -0.5 must clamp to 0.0"
	)


func test_volatility_clamp_upper() -> void:
	var clamped: float = MarketTrendSystemSingleton._clamp_volatility(2.5)
	assert_almost_eq(
		clamped, 2.0, 0.001,
		"raw_volatility of 2.5 must clamp to 2.0"
	)


# --- trend_shifted signal threshold ---

func test_trend_shifted_emitted() -> void:
	# delta 0.10 >= SHIFT_THRESHOLD (0.05) → signal fires
	_system._maybe_emit_trend_shifted(&"fashion", 1.0, 1.10)
	assert_eq(
		_emitted_categories.size(), 1,
		"trend_shifted must fire when |delta| is 0.10 (>= SHIFT_THRESHOLD 0.05)"
	)

	_emitted_categories.clear()
	_emitted_levels.clear()

	# delta 0.03 < SHIFT_THRESHOLD (0.05) → signal NOT fired
	_system._maybe_emit_trend_shifted(&"fashion", 1.0, 1.03)
	assert_eq(
		_emitted_categories.size(), 0,
		"trend_shifted must NOT fire when |delta| is 0.03 (< SHIFT_THRESHOLD 0.05)"
	)


# --- Category modifier ---

func test_category_modifier_additive() -> void:
	var effective: float = _system.apply_category_modifier(1.0, 0.3)
	assert_almost_eq(
		effective, 1.3, 0.001,
		"base_trend 1.0 + modifier 0.3 must yield effective_trend 1.3"
	)


# --- Day counter ---

func test_daily_update_increments_day() -> void:
	var initial: int = _system._current_day
	_system._on_day_ended(1)
	assert_eq(
		_system._current_day, initial + 1,
		"_on_day_ended must increment _current_day by 1"
	)


# --- Reproducibility ---

func test_reproducibility() -> void:
	seed(42)
	var sequence_a: Array[Dictionary] = []
	for i: int in range(30):
		_system._on_day_ended(i + 1)
		sequence_a.append(_system.get_all_trend_levels())

	var system_b: MarketTrendSystem = MarketTrendSystem.new()
	add_child_autofree(system_b)
	seed(42)
	var sequence_b: Array[Dictionary] = []
	for i: int in range(30):
		system_b._on_day_ended(i + 1)
		sequence_b.append(system_b.get_all_trend_levels())

	for i: int in range(30):
		for key: Variant in sequence_a[i]:
			var sid: StringName = key as StringName
			assert_almost_eq(
				float(sequence_a[i][sid]),
				float(sequence_b[i][sid]),
				0.001,
				"Seed 42 must produce identical trend for '%s' at day %d" % [sid, i + 1]
			)


# --- Daily shift behavior ---

func test_daily_shift_changes_at_least_one_level_over_ten_iterations() -> void:
	var initial_levels: Dictionary = _system.get_all_trend_levels()
	for i: int in range(10):
		_system._on_day_ended(i + 1)
	var final_levels: Dictionary = _system.get_all_trend_levels()
	var any_changed: bool = false
	for key: Variant in initial_levels:
		if not is_equal_approx(float(initial_levels[key]), float(final_levels[key])):
			any_changed = true
			break
	assert_true(any_changed, "At least one level must shift over 10 _on_day_ended calls")


func test_daily_shift_delta_does_not_exceed_category_volatility() -> void:
	var before: Dictionary = _system.get_all_trend_levels()
	_system._on_day_ended(1)
	var after: Dictionary = _system.get_all_trend_levels()
	for key: Variant in _system._category_configs:
		var sid: StringName = key as StringName
		var config: Dictionary = _system._category_configs[sid]
		var volatility: float = float(config.get("volatility", 0.1))
		var delta: float = absf(float(after[sid]) - float(before[sid]))
		assert_true(
			delta <= volatility + 0.0001,
			"Delta for '%s' (%f) must not exceed volatility (%f)" % [sid, delta, volatility]
		)


# --- Level clamping ---

func test_clamp_floor_prevents_level_below_min() -> void:
	for key: Variant in _system._trend_levels:
		_system._trend_levels[key] = 0.0
	_system._on_day_ended(1)
	for key: Variant in _system.get_all_trend_levels():
		var level: float = _system.get_trend_modifier(key as StringName)
		assert_true(
			level >= MarketTrendSystemSingleton.MIN_LEVEL,
			"Level for '%s' must be >= MIN_LEVEL (0.2) after shift from 0.0" % key
		)


func test_clamp_ceiling_prevents_level_above_max() -> void:
	for key: Variant in _system._trend_levels:
		_system._trend_levels[key] = 3.0
	_system._on_day_ended(1)
	for key: Variant in _system.get_all_trend_levels():
		var level: float = _system.get_trend_modifier(key as StringName)
		assert_true(
			level <= MarketTrendSystemSingleton.MAX_LEVEL,
			"Level for '%s' must be <= MAX_LEVEL (2.0) after shift from 3.0" % key
		)


# --- trend_shifted signal gate ---

func test_trend_shifted_not_emitted_when_max_delta_below_threshold() -> void:
	# volatility 0.04 guarantees |delta| <= 0.04, which is strictly below SHIFT_THRESHOLD (0.05)
	for key: Variant in _system._category_configs:
		_system._category_configs[key]["volatility"] = 0.04
	_system._on_day_ended(1)
	assert_eq(
		_emitted_categories.size(), 0,
		"trend_shifted must not fire when max |delta| (0.04) is below SHIFT_THRESHOLD (0.05)"
	)


func test_trend_shifted_emitted_with_correct_params_when_delta_exceeds_threshold() -> void:
	# Default volatilities for tech (0.25), sports (0.20), fashion (0.15) all exceed SHIFT_THRESHOLD.
	# Over 10 iterations, at least one shift will meet or exceed the threshold with near-certainty.
	for i: int in range(10):
		_system._on_day_ended(i + 1)
		if not _emitted_categories.is_empty():
			break
	assert_true(
		not _emitted_categories.is_empty(),
		"trend_shifted must fire at least once when volatility exceeds SHIFT_THRESHOLD (0.05)"
	)
	var emitted_id: StringName = _emitted_categories[0]
	var emitted_level: float = _emitted_levels[0]
	assert_true(
		_system.get_all_trend_levels().has(emitted_id),
		"trend_shifted category_id must be a recognized category"
	)
	assert_almost_eq(
		emitted_level, _system.get_trend_modifier(emitted_id), 0.001,
		"trend_shifted new_level must match the category's actual current level"
	)


# --- Modifier accessor ---

func test_get_trend_modifier_returns_float_in_valid_range() -> void:
	var mod: float = _system.get_trend_modifier(&"fashion")
	assert_true(
		mod >= MarketTrendSystemSingleton.MIN_LEVEL and mod <= MarketTrendSystemSingleton.MAX_LEVEL,
		"Modifier for 'fashion' must be in [MIN_LEVEL (0.2), MAX_LEVEL (2.0)]"
	)


func test_get_trend_modifier_unknown_id_returns_neutral_fallback() -> void:
	var mod: float = _system.get_trend_modifier(&"unknown_id")
	assert_almost_eq(
		mod, 1.0, 0.001,
		"Unknown category ID must return 1.0 neutral fallback"
	)
