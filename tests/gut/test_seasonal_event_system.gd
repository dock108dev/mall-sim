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
	# System auto-connects in _ensure_day_started_connected(); do not
	# re-connect here, which would produce "already connected" errors.


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


# ── Event telegraph timing ──────────────────────────────────────────────


func _make_event_def(
	id: String,
	freq: int,
	offset: int,
	duration: int,
	telegraph: int,
	affected: Array,
	price_mult: float
) -> SeasonalEventDefinition:
	var def := SeasonalEventDefinition.new()
	def.id = id
	def.name = id
	def.display_name = id
	def.frequency_days = freq
	def.offset_days = offset
	def.duration_days = duration
	def.telegraph_days = telegraph
	def.affected_stores = PackedStringArray(affected)
	def.price_multiplier = price_mult
	def.customer_traffic_multiplier = 1.0
	def.spending_multiplier = 1.0
	return def


func test_event_telegraphed_fires_on_trigger_day() -> void:
	var def := _make_event_def("test_evt", 10, 0, 5, 3, ["sports"], 1.5)
	_sys._event_definitions = [def]
	watch_signals(EventBus)
	EventBus.day_started.emit(10)
	assert_signal_emitted(EventBus, "event_telegraphed")
	var params: Array = get_signal_parameters(EventBus, "event_telegraphed", 0)
	assert_eq(params[0], "test_evt")
	assert_eq(params[1], 3)


func test_event_started_fires_exactly_telegraph_days_after_telegraph() -> void:
	_sys._season_table = []
	var def := _make_event_def("test_evt", 10, 0, 5, 3, ["sports"], 1.5)
	_sys._event_definitions = [def]
	# Day 10: telegraph fires
	EventBus.day_started.emit(10)
	# Days 11 and 12: event not yet started
	watch_signals(EventBus)
	EventBus.day_started.emit(11)
	EventBus.day_started.emit(12)
	assert_signal_not_emitted(EventBus, "seasonal_event_started")
	# Day 13 = 10 + 3: event starts
	EventBus.day_started.emit(13)
	assert_signal_emitted_with_parameters(
		EventBus, "seasonal_event_started", ["test_evt"]
	)


func test_event_price_multiplier_active_for_affected_store() -> void:
	var def := _make_event_def("sports_kick", 10, 0, 5, 3, ["sports"], 1.5)
	_sys._event_definitions = [def]
	EventBus.day_started.emit(10)
	EventBus.day_started.emit(13)
	assert_almost_eq(
		_sys.get_event_price_multiplier_for_store("sports"), 1.5, 0.001
	)


func test_event_price_multiplier_neutral_for_unaffected_store() -> void:
	var def := _make_event_def("sports_kick", 10, 0, 5, 3, ["sports"], 1.5)
	_sys._event_definitions = [def]
	EventBus.day_started.emit(10)
	EventBus.day_started.emit(13)
	assert_almost_eq(
		_sys.get_event_price_multiplier_for_store("electronics"), 1.0, 0.001
	)


func test_event_ended_resets_price_multiplier_to_one() -> void:
	# duration=3 means active on days 13, 14, 15; expires at day 16
	var def := _make_event_def("slump", 10, 0, 3, 3, ["sports"], 0.7)
	_sys._event_definitions = [def]
	EventBus.day_started.emit(10)
	EventBus.day_started.emit(13)
	assert_almost_eq(
		_sys.get_event_price_multiplier_for_store("sports"), 0.7, 0.001
	)
	EventBus.day_started.emit(14)
	EventBus.day_started.emit(15)
	EventBus.day_started.emit(16)
	assert_almost_eq(
		_sys.get_event_price_multiplier_for_store("sports"), 1.0, 0.001
	)


func test_event_ended_signal_fires_on_expiry() -> void:
	var def := _make_event_def("short_evt", 10, 0, 3, 3, ["sports"], 1.2)
	_sys._event_definitions = [def]
	EventBus.day_started.emit(10)
	EventBus.day_started.emit(13)
	watch_signals(EventBus)
	EventBus.day_started.emit(14)
	EventBus.day_started.emit(15)
	assert_signal_not_emitted(EventBus, "seasonal_event_ended")
	EventBus.day_started.emit(16)
	assert_signal_emitted_with_parameters(
		EventBus, "seasonal_event_ended", ["short_evt"]
	)


func test_price_resolver_event_slot_visible_in_audit() -> void:
	var def := _make_event_def("big_sale", 10, 0, 5, 3, ["sports"], 1.5)
	_sys._event_definitions = [def]
	EventBus.day_started.emit(10)
	EventBus.day_started.emit(13)
	var event_mult: float = _sys.get_event_price_multiplier_for_store("sports")
	var multipliers: Array = [{
		"slot": "event",
		"label": "Event",
		"factor": event_mult,
		"detail": "Seasonal event boost",
	}]
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		&"test_item", 10.0, multipliers, false
	)
	assert_almost_eq(result.final_price, 15.0, 0.01)
	var found_event_slot: bool = false
	for step: Variant in result.steps:
		if step is PriceResolver.AuditStep:
			if (step as PriceResolver.AuditStep).label == "Event":
				found_event_slot = true
	assert_true(found_event_slot, "Event slot must appear in PriceResolver audit trace")


# ── Overlapping events on different stores do not interfere ────────────


func test_overlapping_events_different_stores_no_interference() -> void:
	var def_a := _make_event_def("evt_a", 100, 0, 10, 1, ["sports"], 1.5)
	var def_b := _make_event_def("evt_b", 100, 0, 10, 1, ["pocket_creatures"], 2.0)
	_sys._active_events.append({"definition": def_a, "start_day": 1})
	_sys._active_events.append({"definition": def_b, "start_day": 1})
	assert_almost_eq(
		_sys.get_event_price_multiplier_for_store("sports"), 1.5, 0.001
	)
	assert_almost_eq(
		_sys.get_event_price_multiplier_for_store("pocket_creatures"), 2.0, 0.001
	)
	assert_almost_eq(
		_sys.get_event_price_multiplier_for_store("retro_games"), 1.0, 0.001
	)


func test_overlapping_events_same_store_multiply_independently() -> void:
	var def_a := _make_event_def("evt_a", 100, 0, 10, 1, ["sports"], 1.5)
	var def_b := _make_event_def("evt_b", 100, 0, 10, 1, ["sports"], 1.2)
	_sys._active_events.append({"definition": def_a, "start_day": 1})
	_sys._active_events.append({"definition": def_b, "start_day": 1})
	assert_almost_eq(
		_sys.get_event_price_multiplier_for_store("sports"), 1.8, 0.001
	)
