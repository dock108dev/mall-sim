## GUT unit tests for SeasonalEventSystem — season detection, demand modifier
## activation, and EventBus signal contracts.
extends GutTest

const FLOAT_DELTA: float = 0.001

var _sys: SeasonalEventSystem


func _make_season_entry(
	id: String,
	start_day: int,
	end_day: int,
	category_multipliers: Dictionary
) -> Dictionary:
	return {
		"id": id,
		"start_day": start_day,
		"end_day": end_day,
		"category_multipliers": category_multipliers,
		"price_sensitivity_modifier": 1.0,
	}


func _make_recurring_def(
	id: String,
	frequency_days: int,
	offset_days: int,
	duration_days: int,
	traffic_multiplier: float
) -> SeasonalEventDefinition:
	var def: SeasonalEventDefinition = SeasonalEventDefinition.new()
	def.id = id
	def.item_name = id
	def.frequency_days = frequency_days
	def.offset_days = offset_days
	def.duration_days = duration_days
	def.customer_traffic_multiplier = traffic_multiplier
	def.spending_multiplier = 1.0
	def.customer_type_weights = {}
	def.target_categories = []
	def.announcement_text = ""
	def.active_text = ""
	return def


func before_each() -> void:
	_sys = SeasonalEventSystem.new()
	add_child_autofree(_sys)
	_sys._season_table = []
	_sys._season_cycle_length = 100
	_sys._seasonal_config = []
	_sys._event_definitions = []
	EventBus.day_started.connect(_sys._on_day_started)


func after_each() -> void:
	if EventBus.day_started.is_connected(_sys._on_day_started):
		EventBus.day_started.disconnect(_sys._on_day_started)


# ── season activation ──────────────────────────────────────────────────────────


func test_season_activates_on_start_day() -> void:
	_sys._season_table = [_make_season_entry("summer", 5, 15, {"electronics": 1.5})]
	_sys._season_cycle_length = 30
	var received_id: Array = [""]
	var cb: Callable = func(season_id: String) -> void:
		received_id[0] = season_id
	EventBus.seasonal_event_started.connect(cb)
	EventBus.day_started.emit(5)
	EventBus.seasonal_event_started.disconnect(cb)
	assert_eq(
		received_id[0], "summer",
		"seasonal_event_started should fire with the correct season id on start day"
	)


# ── demand modifier during active season ──────────────────────────────────────


func test_season_modifier_returned_during_active_season() -> void:
	_sys._season_table = [
		_make_season_entry("winter_sale", 1, 20, {"collectibles": 1.6, "electronics": 1.3})
	]
	_sys._season_cycle_length = 30
	EventBus.day_started.emit(10)
	assert_almost_eq(
		_sys.get_demand_multiplier(&"collectibles"), 1.6, FLOAT_DELTA,
		"collectibles multiplier should match the season definition"
	)
	assert_almost_eq(
		_sys.get_demand_multiplier(&"electronics"), 1.3, FLOAT_DELTA,
		"electronics multiplier should match the season definition"
	)


# ── season deactivation and signal emission ───────────────────────────────────


func test_season_deactivates_on_end_day() -> void:
	# Named seasons do not emit seasonal_event_ended; recurring
	# SeasonalEventDefinition events do via _expire_active_events.
	# frequency=4, offset=0: triggers on day 4.
	# Announced day 4, promoted on day 5 (start_day=5), expires day 7 (>=5+2).
	var def: SeasonalEventDefinition = _make_recurring_def("spring_boost", 4, 0, 2, 1.5)
	_sys._event_definitions = [def]
	var ended_id: Array = [""]
	var cb: Callable = func(event_id: String) -> void:
		ended_id[0] = event_id
	EventBus.seasonal_event_ended.connect(cb)
	EventBus.day_started.emit(4)
	EventBus.day_started.emit(5)
	EventBus.day_started.emit(7)
	EventBus.seasonal_event_ended.disconnect(cb)
	assert_eq(
		ended_id[0], "spring_boost",
		"seasonal_event_ended should fire with the correct event id on expiry day"
	)
	assert_almost_eq(
		_sys.get_traffic_multiplier(), 1.0, FLOAT_DELTA,
		"traffic multiplier should return to 1.0 after the event expires"
	)


# ── no modifier outside season ────────────────────────────────────────────────


func test_no_modifier_outside_season() -> void:
	_sys._season_table = []
	_sys._current_named_season = &""
	assert_almost_eq(
		_sys.get_demand_multiplier(&"electronics"), 1.0, FLOAT_DELTA,
		"get_demand_multiplier should return 1.0 when no season is active"
	)
	assert_almost_eq(
		_sys.get_demand_multiplier(&"collectibles"), 1.0, FLOAT_DELTA,
		"get_demand_multiplier should return 1.0 for any category when no season is active"
	)


# ── adjacent seasons do not overlap ───────────────────────────────────────────


func test_multiple_seasons_do_not_overlap() -> void:
	_sys._season_table = [
		_make_season_entry("first", 1, 10, {"electronics": 1.3}),
		_make_season_entry("second", 11, 20, {"electronics": 1.6}),
	]
	_sys._season_cycle_length = 30
	EventBus.day_started.emit(5)
	assert_eq(
		_sys.get_current_season(), &"first",
		"day 5 should be in the first season only"
	)
	assert_almost_eq(
		_sys.get_demand_multiplier(&"electronics"), 1.3, FLOAT_DELTA,
		"demand multiplier should reflect first season while it is active"
	)
	EventBus.day_started.emit(15)
	assert_eq(
		_sys.get_current_season(), &"second",
		"day 15 should be in the second season only"
	)
	assert_almost_eq(
		_sys.get_demand_multiplier(&"electronics"), 1.6, FLOAT_DELTA,
		"demand multiplier should reflect second season after transition"
	)


# ── uncovered category returns 1.0 ────────────────────────────────────────────


func test_season_for_uncovered_category_returns_1() -> void:
	_sys._season_table = [_make_season_entry("holiday", 1, 30, {"gifts": 1.8})]
	_sys._season_cycle_length = 40
	EventBus.day_started.emit(10)
	assert_eq(
		_sys.get_current_season(), &"holiday",
		"holiday season should be active on day 10"
	)
	assert_almost_eq(
		_sys.get_demand_multiplier(&"clothing"), 1.0, FLOAT_DELTA,
		"category not listed in the season definition should return 1.0"
	)
	assert_almost_eq(
		_sys.get_demand_multiplier(&"furniture"), 1.0, FLOAT_DELTA,
		"another unlisted category should also return 1.0"
	)
