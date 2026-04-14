## GUT tests for SeasonalEventSystem named-season demand multipliers.
extends GutTest


var _sys: SeasonalEventSystem


func _build_season_table() -> Array[Dictionary]:
	return [
		{
			"id": "alpha",
			"start_day": 1,
			"end_day": 10,
			"category_multipliers": {
				"electronics": 1.4,
				"sports_cards": 1.2,
			},
			"price_sensitivity_modifier": 0.8,
		},
		{
			"id": "beta",
			"start_day": 11,
			"end_day": 20,
			"category_multipliers": {
				"cartridge": 1.5,
			},
			"price_sensitivity_modifier": 1.3,
		},
	]


func _build_overlapping_table() -> Array[Dictionary]:
	return [
		{
			"id": "first",
			"start_day": 1,
			"end_day": 15,
			"category_multipliers": {"electronics": 1.3},
			"price_sensitivity_modifier": 1.0,
		},
		{
			"id": "second",
			"start_day": 10,
			"end_day": 20,
			"category_multipliers": {"electronics": 1.6},
			"price_sensitivity_modifier": 0.9,
		},
	]


func before_each() -> void:
	_sys = SeasonalEventSystem.new()
	add_child_autofree(_sys)
	_sys._season_table = _build_season_table()
	_sys._season_cycle_length = 20
	_sys._seasonal_config = []
	EventBus.day_started.connect(_sys._on_day_started)


func after_each() -> void:
	if EventBus.day_started.is_connected(_sys._on_day_started):
		EventBus.day_started.disconnect(_sys._on_day_started)


# ── get_demand_multiplier returns configured value during active season ──


func test_demand_multiplier_returns_configured_value() -> void:
	EventBus.day_started.emit(5)
	assert_almost_eq(
		_sys.get_demand_multiplier(&"electronics"), 1.4, 0.001
	)
	assert_almost_eq(
		_sys.get_demand_multiplier(&"sports_cards"), 1.2, 0.001
	)


func test_demand_multiplier_second_season() -> void:
	EventBus.day_started.emit(15)
	assert_almost_eq(
		_sys.get_demand_multiplier(&"cartridge"), 1.5, 0.001
	)


# ── get_demand_multiplier returns 1.0 when no season is active ──────────


func test_demand_multiplier_no_season_returns_one() -> void:
	_sys._season_table = []
	_sys._current_named_season = &""
	assert_almost_eq(
		_sys.get_demand_multiplier(&"electronics"), 1.0, 0.001
	)


func test_demand_multiplier_unconfigured_category_returns_one() -> void:
	EventBus.day_started.emit(5)
	assert_almost_eq(
		_sys.get_demand_multiplier(&"nonexistent"), 1.0, 0.001
	)


# ── day_started within season range activates that season ───────────────


func test_day_started_activates_season_alpha() -> void:
	EventBus.day_started.emit(1)
	assert_eq(_sys.get_current_season(), &"alpha")


func test_day_started_activates_season_at_end_boundary() -> void:
	EventBus.day_started.emit(10)
	assert_eq(_sys.get_current_season(), &"alpha")


func test_day_started_activates_season_beta() -> void:
	EventBus.day_started.emit(11)
	assert_eq(_sys.get_current_season(), &"beta")


func test_day_started_activates_season_beta_end() -> void:
	EventBus.day_started.emit(20)
	assert_eq(_sys.get_current_season(), &"beta")


# ── day_started outside all season ranges deactivates current season ────


func test_day_outside_all_ranges_clears_season() -> void:
	_sys._season_table = [
		{
			"id": "only",
			"start_day": 5,
			"end_day": 10,
			"category_multipliers": {"electronics": 1.5},
			"price_sensitivity_modifier": 1.0,
		},
	]
	_sys._season_cycle_length = 20
	EventBus.day_started.emit(5)
	assert_eq(_sys.get_current_season(), &"only")
	EventBus.day_started.emit(11)
	assert_eq(_sys.get_current_season(), &"")


func test_deactivated_season_returns_one_multiplier() -> void:
	_sys._season_table = [
		{
			"id": "only",
			"start_day": 5,
			"end_day": 10,
			"category_multipliers": {"electronics": 1.5},
			"price_sensitivity_modifier": 1.0,
		},
	]
	_sys._season_cycle_length = 20
	EventBus.day_started.emit(5)
	assert_almost_eq(
		_sys.get_demand_multiplier(&"electronics"), 1.5, 0.001
	)
	EventBus.day_started.emit(11)
	assert_almost_eq(
		_sys.get_demand_multiplier(&"electronics"), 1.0, 0.001
	)


# ── active_season property reflects correct StringName ──────────────────


func test_active_season_reflects_alpha() -> void:
	EventBus.day_started.emit(3)
	assert_eq(_sys.get_current_season(), &"alpha")


func test_active_season_reflects_beta() -> void:
	EventBus.day_started.emit(15)
	assert_eq(_sys.get_current_season(), &"beta")


func test_active_season_empty_when_no_table() -> void:
	_sys._season_table = []
	EventBus.day_started.emit(5)
	assert_eq(_sys.get_current_season(), &"")


func test_active_season_updates_on_transition() -> void:
	EventBus.day_started.emit(10)
	assert_eq(_sys.get_current_season(), &"alpha")
	EventBus.day_started.emit(11)
	assert_eq(_sys.get_current_season(), &"beta")


# ── Cycle wrapping ──────────────────────────────────────────────────────


func test_season_wraps_after_cycle_length() -> void:
	EventBus.day_started.emit(21)
	assert_eq(
		_sys.get_current_season(), &"alpha",
		"Day 21 wraps to cycle day 1 → alpha"
	)


func test_demand_multiplier_after_wrap() -> void:
	EventBus.day_started.emit(25)
	assert_almost_eq(
		_sys.get_demand_multiplier(&"electronics"), 1.4, 0.001
	)


# ── Overlapping seasons handled without crash ───────────────────────────


func test_overlapping_seasons_no_crash() -> void:
	_sys._season_table = _build_overlapping_table()
	_sys._season_cycle_length = 20
	EventBus.day_started.emit(12)
	var season: StringName = _sys.get_current_season()
	assert_eq(
		season, &"first",
		"First matching season wins (first-writer-wins)"
	)


func test_overlapping_seasons_multiplier_from_winner() -> void:
	_sys._season_table = _build_overlapping_table()
	_sys._season_cycle_length = 20
	EventBus.day_started.emit(12)
	assert_almost_eq(
		_sys.get_demand_multiplier(&"electronics"), 1.3, 0.001
	)


func test_overlapping_seasons_second_takes_over() -> void:
	_sys._season_table = _build_overlapping_table()
	_sys._season_cycle_length = 20
	EventBus.day_started.emit(16)
	assert_eq(_sys.get_current_season(), &"second")
	assert_almost_eq(
		_sys.get_demand_multiplier(&"electronics"), 1.6, 0.001
	)


# ── price_sensitivity_modifier ──────────────────────────────────────────


func test_price_sensitivity_during_season() -> void:
	EventBus.day_started.emit(5)
	assert_almost_eq(
		_sys.get_price_sensitivity_modifier(), 0.8, 0.001
	)


func test_price_sensitivity_different_season() -> void:
	EventBus.day_started.emit(15)
	assert_almost_eq(
		_sys.get_price_sensitivity_modifier(), 1.3, 0.001
	)


func test_price_sensitivity_no_season() -> void:
	_sys._season_table = []
	_sys._current_named_season = &""
	assert_almost_eq(
		_sys.get_price_sensitivity_modifier(), 1.0, 0.001
	)
