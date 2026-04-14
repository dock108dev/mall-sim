## Tests for named season detection and demand multipliers (ISSUE-152).
extends GutTest


var _seasonal: SeasonalEventSystem
var _started_signals: Array[String] = []


func before_each() -> void:
	_started_signals.clear()
	_seasonal = SeasonalEventSystem.new()
	add_child_autofree(_seasonal)
	_seasonal._season_table = _build_test_seasons()
	_seasonal._season_cycle_length = 70
	_seasonal._apply_state({})
	EventBus.day_started.connect(_seasonal._on_day_started)
	EventBus.seasonal_event_started.connect(_record_started)


func after_each() -> void:
	if EventBus.day_started.is_connected(_seasonal._on_day_started):
		EventBus.day_started.disconnect(_seasonal._on_day_started)
	if EventBus.seasonal_event_started.is_connected(
		_record_started
	):
		EventBus.seasonal_event_started.disconnect(
			_record_started
		)


func _record_started(event_id: String) -> void:
	_started_signals.append(event_id)


func _build_test_seasons() -> Array[Dictionary]:
	return [
		{
			"id": "back_to_school", "start_day": 1,
			"end_day": 7,
			"category_multipliers": {
				"electronics": 1.4, "handheld": 1.3,
			},
			"price_sensitivity_modifier": 1.0,
		},
		{
			"id": "fall_sports", "start_day": 8,
			"end_day": 21,
			"category_multipliers": {
				"sports_cards": 1.5, "autographs": 1.4,
			},
			"price_sensitivity_modifier": 1.0,
		},
		{
			"id": "pre_holiday", "start_day": 22,
			"end_day": 35,
			"category_multipliers": {
				"electronics": 1.3, "trading_cards": 1.3,
			},
			"price_sensitivity_modifier": 0.8,
		},
		{
			"id": "post_holiday", "start_day": 36,
			"end_day": 42,
			"category_multipliers": {
				"electronics": 0.7,
			},
			"price_sensitivity_modifier": 1.3,
		},
		{
			"id": "spring_gaming", "start_day": 43,
			"end_day": 56,
			"category_multipliers": {
				"cartridge": 1.4, "console": 1.3,
			},
			"price_sensitivity_modifier": 1.0,
		},
		{
			"id": "summer_lull", "start_day": 57,
			"end_day": 70,
			"category_multipliers": {},
			"price_sensitivity_modifier": 1.0,
		},
	]


# ── get_current_season ──────────────────────────────────────────────


func test_day_1_is_back_to_school() -> void:
	EventBus.day_started.emit(1)
	assert_eq(
		_seasonal.get_current_season(), &"back_to_school"
	)


func test_day_7_is_back_to_school() -> void:
	EventBus.day_started.emit(7)
	assert_eq(
		_seasonal.get_current_season(), &"back_to_school"
	)


func test_day_8_is_fall_sports() -> void:
	EventBus.day_started.emit(8)
	assert_eq(
		_seasonal.get_current_season(), &"fall_sports"
	)


func test_day_22_is_pre_holiday() -> void:
	EventBus.day_started.emit(22)
	assert_eq(
		_seasonal.get_current_season(), &"pre_holiday"
	)


func test_day_36_is_post_holiday() -> void:
	EventBus.day_started.emit(36)
	assert_eq(
		_seasonal.get_current_season(), &"post_holiday"
	)


func test_day_43_is_spring_gaming() -> void:
	EventBus.day_started.emit(43)
	assert_eq(
		_seasonal.get_current_season(), &"spring_gaming"
	)


func test_day_57_is_summer_lull() -> void:
	EventBus.day_started.emit(57)
	assert_eq(
		_seasonal.get_current_season(), &"summer_lull"
	)


func test_day_70_is_summer_lull() -> void:
	EventBus.day_started.emit(70)
	assert_eq(
		_seasonal.get_current_season(), &"summer_lull"
	)


# ── Cycle wrapping ──────────────────────────────────────────────────


func test_day_71_wraps_to_back_to_school() -> void:
	EventBus.day_started.emit(71)
	assert_eq(
		_seasonal.get_current_season(), &"back_to_school"
	)


func test_day_141_wraps_to_back_to_school() -> void:
	EventBus.day_started.emit(141)
	assert_eq(
		_seasonal.get_current_season(), &"back_to_school"
	)


func test_day_78_wraps_to_fall_sports() -> void:
	EventBus.day_started.emit(78)
	assert_eq(
		_seasonal.get_current_season(), &"fall_sports"
	)


# ── get_demand_multiplier ───────────────────────────────────────────


func test_demand_multiplier_listed_category() -> void:
	EventBus.day_started.emit(1)
	assert_almost_eq(
		_seasonal.get_demand_multiplier(&"electronics"),
		1.4, 0.001
	)


func test_demand_multiplier_unlisted_category_returns_one() -> void:
	EventBus.day_started.emit(1)
	assert_almost_eq(
		_seasonal.get_demand_multiplier(&"vhs"),
		1.0, 0.001
	)


func test_demand_multiplier_summer_lull_returns_one() -> void:
	EventBus.day_started.emit(57)
	assert_almost_eq(
		_seasonal.get_demand_multiplier(&"electronics"),
		1.0, 0.001
	)


func test_demand_multiplier_post_holiday_below_one() -> void:
	EventBus.day_started.emit(36)
	assert_almost_eq(
		_seasonal.get_demand_multiplier(&"electronics"),
		0.7, 0.001
	)


# ── get_price_sensitivity_modifier ──────────────────────────────────


func test_price_sensitivity_pre_holiday() -> void:
	EventBus.day_started.emit(22)
	assert_almost_eq(
		_seasonal.get_price_sensitivity_modifier(),
		0.8, 0.001
	)


func test_price_sensitivity_post_holiday() -> void:
	EventBus.day_started.emit(36)
	assert_almost_eq(
		_seasonal.get_price_sensitivity_modifier(),
		1.3, 0.001
	)


func test_price_sensitivity_baseline() -> void:
	EventBus.day_started.emit(1)
	assert_almost_eq(
		_seasonal.get_price_sensitivity_modifier(),
		1.0, 0.001
	)


# ── seasonal_event_started signal ───────────────────────────────────


func test_signal_fires_on_season_transition() -> void:
	EventBus.day_started.emit(1)
	_started_signals.clear()
	EventBus.day_started.emit(8)
	assert_eq(_started_signals.size(), 1)
	assert_eq(_started_signals[0], "fall_sports")


func test_signal_not_fired_within_same_season() -> void:
	EventBus.day_started.emit(1)
	_started_signals.clear()
	EventBus.day_started.emit(2)
	assert_eq(_started_signals.size(), 0)


func test_signal_fires_on_cycle_wrap() -> void:
	EventBus.day_started.emit(70)
	_started_signals.clear()
	EventBus.day_started.emit(71)
	assert_eq(_started_signals.size(), 1)
	assert_eq(_started_signals[0], "back_to_school")


# ── Deterministic from day alone ────────────────────────────────────


func test_season_deterministic_from_day() -> void:
	EventBus.day_started.emit(22)
	var first: StringName = _seasonal.get_current_season()
	var fresh: SeasonalEventSystem = SeasonalEventSystem.new()
	add_child_autofree(fresh)
	fresh._season_table = _build_test_seasons()
	fresh._season_cycle_length = 70
	fresh._apply_state({"current_day": 22})
	assert_eq(fresh.get_current_season(), first)


# ── Empty season table ──────────────────────────────────────────────


func test_empty_season_table_returns_empty() -> void:
	var empty_sys: SeasonalEventSystem = SeasonalEventSystem.new()
	add_child_autofree(empty_sys)
	empty_sys._season_table = []
	empty_sys._apply_state({})
	assert_eq(empty_sys.get_current_season(), &"")
	assert_almost_eq(
		empty_sys.get_demand_multiplier(&"electronics"),
		1.0, 0.001
	)
	assert_almost_eq(
		empty_sys.get_price_sensitivity_modifier(),
		1.0, 0.001
	)
