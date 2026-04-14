## Tests for MarketTrendSystem: initialization, modifiers, clamping, signals.
extends GutTest


var _system: MarketTrendSystem
var _shifted_categories: Array[StringName] = []
var _shifted_levels: Array[float] = []


func before_each() -> void:
	_shifted_categories = []
	_shifted_levels = []
	_system = MarketTrendSystem.new()
	add_child_autofree(_system)
	EventBus.trend_shifted.connect(_on_trend_shifted)


func after_each() -> void:
	if EventBus.trend_shifted.is_connected(_on_trend_shifted):
		EventBus.trend_shifted.disconnect(_on_trend_shifted)


func _on_trend_shifted(
	category_id: StringName, new_level: float
) -> void:
	_shifted_categories.append(category_id)
	_shifted_levels.append(new_level)


# --- Initialization ---

func test_loads_all_five_categories() -> void:
	var levels: Dictionary = _system.get_all_trend_levels()
	assert_eq(levels.size(), 5, "Should load 5 categories")
	assert_true(levels.has(&"fashion"), "Should have fashion")
	assert_true(levels.has(&"sports"), "Should have sports")
	assert_true(levels.has(&"entertainment"), "Should have entertainment")
	assert_true(levels.has(&"tech"), "Should have tech")
	assert_true(levels.has(&"food"), "Should have food")


func test_default_levels_are_one() -> void:
	var levels: Dictionary = _system.get_all_trend_levels()
	for key: Variant in levels:
		assert_almost_eq(
			float(levels[key]), 1.0, 0.001,
			"Default level for %s should be 1.0" % key
		)


# --- get_trend_modifier ---

func test_get_trend_modifier_returns_default() -> void:
	var mod: float = _system.get_trend_modifier(&"fashion")
	assert_almost_eq(mod, 1.0, 0.001, "Default modifier should be 1.0")


func test_get_trend_modifier_unknown_category() -> void:
	var mod: float = _system.get_trend_modifier(&"nonexistent")
	assert_almost_eq(
		mod, 1.0, 0.001,
		"Unknown category should return 1.0"
	)


# --- Daily shift ---

func test_day_ended_shifts_levels() -> void:
	var before: Dictionary = _system.get_all_trend_levels()
	seed(12345)
	EventBus.day_ended.emit(1)
	var after: Dictionary = _system.get_all_trend_levels()
	var any_changed: bool = false
	for key: Variant in before:
		if not is_equal_approx(
			float(before[key]), float(after[key])
		):
			any_changed = true
			break
	assert_true(any_changed, "At least one level should shift after day_ended")


func test_levels_clamped_to_min() -> void:
	for key: Variant in _system.get_all_trend_levels():
		_system._trend_levels[key] = 0.1
	_system._shift_trends()
	for key: Variant in _system.get_all_trend_levels():
		var level: float = _system.get_trend_modifier(key as StringName)
		assert_true(
			level >= MarketTrendSystemSingleton.MIN_LEVEL,
			"Level for %s should be >= %f" % [key, MarketTrendSystemSingleton.MIN_LEVEL]
		)


func test_levels_clamped_to_max() -> void:
	for key: Variant in _system.get_all_trend_levels():
		_system._trend_levels[key] = 2.0
	_system._shift_trends()
	for key: Variant in _system.get_all_trend_levels():
		var level: float = _system.get_trend_modifier(key as StringName)
		assert_true(
			level <= MarketTrendSystemSingleton.MAX_LEVEL,
			"Level for %s should be <= %f" % [key, MarketTrendSystemSingleton.MAX_LEVEL]
		)


# --- trend_shifted signal ---

func test_trend_shifted_fires_on_large_change() -> void:
	_system._trend_levels[&"tech"] = 1.0
	_system._category_configs[&"tech"]["volatility"] = 1.0
	seed(42)
	_system._shift_trends()
	var tech_shifted: bool = _shifted_categories.has(&"tech")
	if absf(_system.get_trend_modifier(&"tech") - 1.0) > 0.1:
		assert_true(
			tech_shifted,
			"trend_shifted should fire when change > 0.1"
		)


func test_trend_shifted_skips_small_change() -> void:
	for key: Variant in _system.get_all_trend_levels():
		_system._category_configs[key]["volatility"] = 0.001
	_shifted_categories = []
	seed(99)
	_system._shift_trends()
	assert_eq(
		_shifted_categories.size(), 0,
		"trend_shifted should not fire for tiny changes"
	)


# --- Save / Load ---

func test_save_load_roundtrip() -> void:
	seed(777)
	EventBus.day_ended.emit(1)
	EventBus.day_ended.emit(2)
	var before: Dictionary = _system.get_all_trend_levels()
	var save_data: Dictionary = _system.get_save_data()

	var fresh := MarketTrendSystem.new()
	add_child_autofree(fresh)
	fresh.load_save_data(save_data)

	var after: Dictionary = fresh.get_all_trend_levels()
	for key: Variant in before:
		assert_almost_eq(
			float(after[key]), float(before[key]), 0.001,
			"Loaded level for %s should match saved" % key
		)


func test_load_ignores_unknown_categories() -> void:
	var save_data: Dictionary = {
		"trend_levels": {&"fake_category": 1.5}
	}
	_system.load_save_data(save_data)
	assert_false(
		_system.get_all_trend_levels().has(&"fake_category"),
		"Unknown categories should not be loaded"
	)


func test_load_clamps_values() -> void:
	var save_data: Dictionary = {
		"trend_levels": {&"fashion": 5.0, &"food": -1.0}
	}
	_system.load_save_data(save_data)
	assert_true(
		_system.get_trend_modifier(&"fashion") <= MarketTrendSystemSingleton.MAX_LEVEL,
		"Loaded value should be clamped to max"
	)
	assert_true(
		_system.get_trend_modifier(&"food") >= MarketTrendSystemSingleton.MIN_LEVEL,
		"Loaded value should be clamped to min"
	)
