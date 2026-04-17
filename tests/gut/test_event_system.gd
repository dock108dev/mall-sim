## GUT coverage for seasonal day windows and random event lifecycle weighting.
extends GutTest


var _seasonal_system: SeasonalEventSystem
var _random_system: RandomEventSystem


func before_each() -> void:
	_seasonal_system = SeasonalEventSystem.new()
	add_child_autofree(_seasonal_system)

	_random_system = RandomEventSystem.new()
	add_child_autofree(_random_system)


func _make_seasonal_event_definition(
	overrides: Dictionary = {}
) -> SeasonalEventDefinition:
	var definition: SeasonalEventDefinition = (
		SeasonalEventDefinition.new()
	)
	definition.id = str(overrides.get("id", "holiday_rush"))
	definition.name = str(
		overrides.get("name", "Holiday Rush")
	)
	definition.description = str(
		overrides.get("description", "Increased shopping traffic.")
	)
	definition.frequency_days = int(
		overrides.get("frequency_days", 5)
	)
	definition.duration_days = int(
		overrides.get("duration_days", 2)
	)
	definition.offset_days = int(overrides.get("offset_days", 0))
	definition.customer_traffic_multiplier = float(
		overrides.get("customer_traffic_multiplier", 1.6)
	)
	definition.spending_multiplier = float(
		overrides.get("spending_multiplier", 1.25)
	)
	definition.customer_type_weights = (
		overrides.get("customer_type_weights", {}) as Dictionary
	)
	definition.target_categories = PackedStringArray(
		overrides.get("target_categories", PackedStringArray())
	)
	definition.announcement_text = str(
		overrides.get("announcement_text", "Holiday rush incoming.")
	)
	definition.active_text = str(
		overrides.get("active_text", "Holiday rush is live.")
	)
	return definition


func _make_random_event_definition(
	overrides: Dictionary = {}
) -> RandomEventDefinition:
	var definition: RandomEventDefinition = (
		RandomEventDefinition.new()
	)
	definition.id = str(overrides.get("id", "celebrity_visit"))
	definition.name = str(
		overrides.get("name", "Celebrity Visit")
	)
	definition.description = str(
		overrides.get("description", "A celebrity draws a crowd.")
	)
	definition.effect_type = str(
		overrides.get("effect_type", "celebrity_visit")
	)
	definition.duration_days = int(
		overrides.get("duration_days", 2)
	)
	definition.severity = str(overrides.get("severity", "medium"))
	definition.cooldown_days = int(
		overrides.get("cooldown_days", 4)
	)
	definition.probability_weight = float(
		overrides.get("probability_weight", 1.0)
	)
	definition.target_category = str(
		overrides.get("target_category", "")
	)
	definition.target_item_id = str(
		overrides.get("target_item_id", "")
	)
	definition.notification_text = str(
		overrides.get("notification_text", "Celebrity sighting!")
	)
	definition.resolution_text = str(
		overrides.get("resolution_text", "The crowd has dispersed.")
	)
	definition.toast_message = str(
		overrides.get("toast_message", "Celebrity Visit")
	)
	definition.time_window_start = int(
		overrides.get("time_window_start", -1)
	)
	definition.time_window_end = int(
		overrides.get("time_window_end", -1)
	)
	return definition


func test_seasonal_event_activates_within_configured_day_range() -> void:
	_seasonal_system._season_table = [
		{
			"id": "holiday_rush",
			"start_day": 20,
			"end_day": 30,
			"category_multipliers": {"electronics": 1.6},
			"price_sensitivity_modifier": 0.85,
		},
	]
	_seasonal_system._season_cycle_length = 40

	_seasonal_system._on_day_started(25)

	assert_eq(_seasonal_system.get_current_season(), &"holiday_rush")
	assert_almost_eq(
		_seasonal_system.get_demand_multiplier(&"electronics"),
		1.6,
		0.001
	)
	assert_almost_eq(
		_seasonal_system.get_price_sensitivity_modifier(),
		0.85,
		0.001
	)


func test_seasonal_event_does_not_activate_outside_configured_day_range() -> void:
	_seasonal_system._season_table = [
		{
			"id": "holiday_rush",
			"start_day": 20,
			"end_day": 30,
			"category_multipliers": {"electronics": 1.6},
			"price_sensitivity_modifier": 0.85,
		},
	]
	_seasonal_system._season_cycle_length = 40

	_seasonal_system._on_day_started(31)

	assert_eq(_seasonal_system.get_current_season(), &"")
	assert_almost_eq(
		_seasonal_system.get_demand_multiplier(&"electronics"),
		1.0,
		0.001
	)
	assert_almost_eq(
		_seasonal_system.get_price_sensitivity_modifier(),
		1.0,
		0.001
	)


func test_random_event_probability_weighting_favors_higher_weight_over_1000_rolls() -> void:
	seed(424242)
	var heavy_event: RandomEventDefinition = (
		_make_random_event_definition({
			"id": "heavy_event",
			"probability_weight": 9.0,
		})
	)
	var light_event: RandomEventDefinition = (
		_make_random_event_definition({
			"id": "light_event",
			"probability_weight": 1.0,
		})
	)
	var candidates: Array[RandomEventDefinition] = [
		heavy_event,
		light_event,
	]
	var heavy_count: int = 0
	var light_count: int = 0

	for _roll_index: int in range(1000):
		var chosen: RandomEventDefinition = (
			_random_system._weighted_pick(candidates)
		)
		if chosen.id == "heavy_event":
			heavy_count += 1
		elif chosen.id == "light_event":
			light_count += 1

	assert_gt(
		heavy_count,
		light_count,
		"Higher-weight events should be selected more often."
	)
	assert_gt(
		heavy_count,
		800,
		"Heavier event should dominate the 1000 weighted picks."
	)


func test_seasonal_event_effects_apply_on_start_and_expire_on_end() -> void:
	var definition: SeasonalEventDefinition = (
		_make_seasonal_event_definition({
			"frequency_days": 5,
			"duration_days": 2,
			"customer_traffic_multiplier": 1.75,
			"spending_multiplier": 0.8,
		})
	)
	var event_definitions: Array[SeasonalEventDefinition] = [
		definition,
	]
	_seasonal_system._event_definitions = event_definitions

	_seasonal_system._on_day_started(5)
	_seasonal_system._on_day_started(6)

	assert_eq(_seasonal_system.get_active_events().size(), 1)
	assert_almost_eq(
		_seasonal_system.get_traffic_multiplier(),
		1.75,
		0.001
	)
	assert_almost_eq(
		_seasonal_system.get_spending_multiplier(),
		0.8,
		0.001
	)

	_seasonal_system._on_day_started(8)

	assert_eq(_seasonal_system.get_active_events().size(), 0)
	assert_almost_eq(
		_seasonal_system.get_traffic_multiplier(),
		1.0,
		0.001
	)
	assert_almost_eq(
		_seasonal_system.get_spending_multiplier(),
		1.0,
		0.001
	)


func test_random_event_effects_apply_on_start_and_clear_on_end() -> void:
	var definition: RandomEventDefinition = (
		_make_random_event_definition({
			"effect_type": "celebrity_visit",
			"duration_days": 2,
			"cooldown_days": 5,
		})
	)

	_random_system._activate_event(definition, 10)

	assert_true(_random_system.has_active_event())
	assert_almost_eq(
		_random_system.get_traffic_multiplier(),
		RandomEventSystem.CELEBRITY_TRAFFIC_MULTIPLIER,
		0.001
	)

	_random_system._check_active_event_expiry(12)

	assert_false(_random_system.has_active_event())
	assert_almost_eq(
		_random_system.get_traffic_multiplier(),
		1.0,
		0.001
	)
	assert_eq(_random_system._cooldowns.get(definition.id, 0), 5)
