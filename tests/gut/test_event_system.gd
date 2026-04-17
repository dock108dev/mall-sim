## Tests for SeasonalEventSystem and RandomEventSystem lifecycle and effects.
extends GutTest

var _seasonal: SeasonalEventSystem
var _random: RandomEventSystem

func _seasonal_def(o: Dictionary = {}) -> SeasonalEventDefinition:
	var d := SeasonalEventDefinition.new()
	d.id = o.get("id", "test_seasonal")
	d.name = o.get("name", "Test Seasonal")
	d.description = o.get("description", "A test event")
	d.frequency_days = o.get("frequency_days", 30)
	d.duration_days = o.get("duration_days", 3)
	d.offset_days = o.get("offset_days", 0)
	d.customer_traffic_multiplier = o.get("traffic", 1.5)
	d.spending_multiplier = o.get("spending", 1.2)
	d.customer_type_weights = o.get("weights", {})
	d.target_categories = o.get("cats", PackedStringArray([]))
	d.announcement_text = o.get("announce", "Incoming!")
	d.active_text = o.get("active", "It's here!")
	return d

func _random_def(o: Dictionary = {}) -> RandomEventDefinition:
	var d := RandomEventDefinition.new()
	d.id = o.get("id", "test_random")
	d.name = o.get("name", "Test Random")
	d.description = o.get("description", "A test event")
	d.effect_type = o.get("effect_type", "celebrity_visit")
	d.duration_days = o.get("duration_days", 2)
	d.severity = o.get("severity", "medium")
	d.cooldown_days = o.get("cooldown_days", 10)
	d.probability_weight = o.get("probability_weight", 1.0)
	d.target_category = o.get("target_category", "")
	d.target_item_id = o.get("target_item_id", "")
	d.notification_text = o.get("notif", "Something happened!")
	d.resolution_text = o.get("resolve", "All clear.")
	return d

func before_each() -> void:
	_seasonal = SeasonalEventSystem.new()
	add_child_autofree(_seasonal)
	_random = RandomEventSystem.new()
	add_child_autofree(_random)


func _set_seasonal_definitions(def: SeasonalEventDefinition) -> void:
	var arr: Array[SeasonalEventDefinition] = []
	arr.append(def)
	_seasonal._event_definitions = arr


func _clear_seasonal_definitions() -> void:
	var empty: Array[SeasonalEventDefinition] = []
	_seasonal._event_definitions = empty


func _set_seasonal_definitions_on(
	sys: SeasonalEventSystem, def: SeasonalEventDefinition
) -> void:
	var arr: Array[SeasonalEventDefinition] = []
	arr.append(def)
	sys._event_definitions = arr


func _set_random_definitions(def: RandomEventDefinition) -> void:
	var arr: Array[RandomEventDefinition] = []
	arr.append(def)
	_random._event_definitions = arr


func _set_random_definitions_three(
	a: RandomEventDefinition,
	b: RandomEventDefinition,
	c: RandomEventDefinition,
) -> void:
	var arr: Array[RandomEventDefinition] = []
	arr.append(a)
	arr.append(b)
	arr.append(c)
	_random._event_definitions = arr


func _clear_random_definitions() -> void:
	var empty: Array[RandomEventDefinition] = []
	_random._event_definitions = empty


func _set_random_definitions_on(
	sys: RandomEventSystem, def: RandomEventDefinition
) -> void:
	var arr: Array[RandomEventDefinition] = []
	arr.append(def)
	sys._event_definitions = arr


# --- Seasonal: triggering within configured day range ---

func test_seasonal_triggers_on_correct_day() -> void:
	var def: SeasonalEventDefinition = _seasonal_def({
		"frequency_days": 10, "offset_days": 0,
	})
	_set_seasonal_definitions(def)
	assert_true(_seasonal._should_trigger(10, def))

func test_seasonal_triggers_on_frequency_multiple() -> void:
	var def: SeasonalEventDefinition = _seasonal_def({
		"frequency_days": 7, "offset_days": 0,
	})
	assert_true(_seasonal._should_trigger(21, def))

func test_seasonal_not_trigger_off_cycle() -> void:
	var def: SeasonalEventDefinition = _seasonal_def({
		"frequency_days": 10, "offset_days": 0,
	})
	assert_false(_seasonal._should_trigger(5, def))

func test_seasonal_offset_shifts_trigger() -> void:
	var def: SeasonalEventDefinition = _seasonal_def({
		"frequency_days": 10, "offset_days": 3,
	})
	assert_true(_seasonal._should_trigger(13, def))
	assert_false(_seasonal._should_trigger(10, def))

func test_seasonal_not_trigger_before_offset() -> void:
	var def: SeasonalEventDefinition = _seasonal_def({
		"frequency_days": 10, "offset_days": 5,
	})
	assert_false(_seasonal._should_trigger(3, def))

func test_seasonal_not_trigger_day_zero() -> void:
	var def: SeasonalEventDefinition = _seasonal_def({
		"frequency_days": 10, "offset_days": 0,
	})
	assert_false(_seasonal._should_trigger(0, def))

# --- Seasonal: announcement and activation lifecycle ---

func test_seasonal_announced_on_trigger_day() -> void:
	var def: SeasonalEventDefinition = _seasonal_def({
		"frequency_days": 10, "offset_days": 0,
	})
	_set_seasonal_definitions(def)
	var fired: Array = [false]
	var got_id: Array = [""]
	var cb: Callable = func(id: String) -> void:
		fired[0] = true
		got_id[0] = id
	EventBus.seasonal_event_announced.connect(cb)
	_seasonal._on_day_started(10)
	assert_true(fired[0], "Announced signal should fire")
	assert_eq(got_id[0], "test_seasonal")
	assert_eq(_seasonal._announced_events.size(), 1)
	assert_eq(_seasonal._active_events.size(), 0)
	EventBus.seasonal_event_announced.disconnect(cb)

func test_seasonal_activates_after_announcement() -> void:
	var def: SeasonalEventDefinition = _seasonal_def({
		"frequency_days": 10, "offset_days": 0, "duration_days": 5,
	})
	_set_seasonal_definitions(def)
	var got_id: Array = [""]
	var cb: Callable = func(id: String) -> void:
		got_id[0] = id
	EventBus.seasonal_event_started.connect(cb)
	_seasonal._on_day_started(10)
	_seasonal._on_day_started(10 + SeasonalEventSystem.ANNOUNCEMENT_DAYS)
	assert_eq(got_id[0], "test_seasonal")
	assert_eq(_seasonal._active_events.size(), 1)
	assert_eq(_seasonal._announced_events.size(), 0)
	EventBus.seasonal_event_started.disconnect(cb)

func test_seasonal_expires_after_duration() -> void:
	var def: SeasonalEventDefinition = _seasonal_def({"duration_days": 3})
	_seasonal._active_events.append({"definition": def, "start_day": 10})
	var got_id: Array = [""]
	var cb: Callable = func(id: String) -> void:
		got_id[0] = id
	EventBus.seasonal_event_ended.connect(cb)
	_seasonal._on_day_started(12)
	assert_eq(_seasonal._active_events.size(), 1, "Still active day 12")
	_seasonal._on_day_started(13)
	assert_eq(_seasonal._active_events.size(), 0, "Expired day 13")
	assert_eq(got_id[0], "test_seasonal")
	EventBus.seasonal_event_ended.disconnect(cb)

func test_seasonal_no_duplicate_activation() -> void:
	var def: SeasonalEventDefinition = _seasonal_def({
		"frequency_days": 10, "offset_days": 0, "duration_days": 10,
	})
	_set_seasonal_definitions(def)
	_seasonal._active_events.append({"definition": def, "start_day": 9})
	_seasonal._on_day_started(10)
	assert_eq(_seasonal._announced_events.size(), 0)

# --- Seasonal: multiplier effects ---

func test_seasonal_traffic_no_events() -> void:
	assert_eq(_seasonal.get_traffic_multiplier(), 1.0)

func test_seasonal_traffic_single() -> void:
	var def: SeasonalEventDefinition = _seasonal_def({"traffic": 1.75})
	_seasonal._active_events.append({"definition": def, "start_day": 1})
	assert_eq(_seasonal.get_traffic_multiplier(), 1.75)

func test_seasonal_traffic_stacks() -> void:
	var a: SeasonalEventDefinition = _seasonal_def({"id": "a", "traffic": 1.5})
	var b: SeasonalEventDefinition = _seasonal_def({"id": "b", "traffic": 1.2})
	_seasonal._active_events.append({"definition": a, "start_day": 1})
	_seasonal._active_events.append({"definition": b, "start_day": 1})
	assert_almost_eq(_seasonal.get_traffic_multiplier(), 1.8, 0.001)

func test_seasonal_spending() -> void:
	var def: SeasonalEventDefinition = _seasonal_def({"spending": 1.3})
	_seasonal._active_events.append({"definition": def, "start_day": 1})
	assert_eq(_seasonal.get_spending_multiplier(), 1.3)

func test_seasonal_weights_merged() -> void:
	var a: SeasonalEventDefinition = _seasonal_def({
		"id": "a", "weights": {"bargain": 2.0},
	})
	var b: SeasonalEventDefinition = _seasonal_def({
		"id": "b", "weights": {"bargain": 1.5, "collector": 3.0},
	})
	_seasonal._active_events.append({"definition": a, "start_day": 1})
	_seasonal._active_events.append({"definition": b, "start_day": 1})
	var w: Dictionary = _seasonal.get_customer_type_weights()
	assert_almost_eq(w.get("bargain", 0.0) as float, 3.0, 0.001)
	assert_eq(w.get("collector", 0.0), 3.0)

# --- Seasonal: effects applied on start, removed on end ---

func test_seasonal_effects_during_active() -> void:
	var def: SeasonalEventDefinition = _seasonal_def({
		"frequency_days": 5, "offset_days": 0, "duration_days": 3,
		"traffic": 1.75, "spending": 0.8,
	})
	_set_seasonal_definitions(def)
	_seasonal._on_day_started(5)
	_seasonal._on_day_started(5 + SeasonalEventSystem.ANNOUNCEMENT_DAYS)
	assert_eq(_seasonal.get_traffic_multiplier(), 1.75)
	assert_eq(_seasonal.get_spending_multiplier(), 0.8)

func test_seasonal_effects_removed_after_expiry() -> void:
	var def: SeasonalEventDefinition = _seasonal_def({
		"frequency_days": 5, "offset_days": 0, "duration_days": 2,
		"traffic": 1.75, "spending": 0.8,
	})
	_set_seasonal_definitions(def)
	_seasonal._on_day_started(5)
	var act: int = 5 + SeasonalEventSystem.ANNOUNCEMENT_DAYS
	_seasonal._on_day_started(act)
	_seasonal._on_day_started(act + def.duration_days)
	assert_eq(_seasonal._active_events.size(), 0)
	assert_eq(_seasonal.get_traffic_multiplier(), 1.0)
	assert_eq(_seasonal.get_spending_multiplier(), 1.0)

# --- Seasonal: save/load ---

func test_seasonal_save_load_roundtrip() -> void:
	var def: SeasonalEventDefinition = _seasonal_def({"id": "holiday"})
	_set_seasonal_definitions(def)
	_seasonal._active_events.append({"definition": def, "start_day": 15})
	_seasonal._announced_events.append({
		"definition": def, "announced_day": 20,
	})
	var save: Dictionary = _seasonal.get_save_data()
	var rest: SeasonalEventSystem = SeasonalEventSystem.new()
	add_child_autofree(rest)
	_set_seasonal_definitions_on(rest, def)
	rest.load_save_data(save)
	assert_eq(rest._active_events.size(), 1)
	assert_eq(rest._announced_events.size(), 1)
	assert_eq(rest._active_events[0].get("start_day", -1), 15)
	var rd: SeasonalEventDefinition = rest._active_events[0].get(
		"definition", null
	) as SeasonalEventDefinition
	assert_eq(rd.id, "holiday")

func test_seasonal_load_skips_unknown() -> void:
	_clear_seasonal_definitions()
	_seasonal.load_save_data({
		"active_events": [
			{"definition_id": "nonexistent", "start_day": 1},
		],
		"announced_events": [],
	})
	assert_eq(_seasonal._active_events.size(), 0)

# --- Random: traffic multiplier by effect type ---

func test_random_no_event_traffic() -> void:
	assert_eq(_random.get_traffic_multiplier(), 1.0)

func test_random_celebrity_traffic() -> void:
	var def: RandomEventDefinition = _random_def({
		"effect_type": "celebrity_visit",
	})
	_random._active_event = {
		"definition": def, "start_day": 1,
		"target_category": "", "target_item_id": "",
	}
	assert_eq(
		_random.get_traffic_multiplier(),
		RandomEventSystem.CELEBRITY_TRAFFIC_MULTIPLIER
	)

func test_random_power_outage_traffic() -> void:
	var def: RandomEventDefinition = _random_def({
		"effect_type": "power_outage",
	})
	_random._active_event = {
		"definition": def, "start_day": 1,
		"target_category": "", "target_item_id": "",
	}
	assert_eq(
		_random.get_traffic_multiplier(),
		RandomEventSystem.POWER_OUTAGE_TRAFFIC_MULTIPLIER
	)

func test_random_collector_convention_traffic() -> void:
	var def: RandomEventDefinition = _random_def({
		"effect_type": "collector_convention",
	})
	_random._active_event = {
		"definition": def, "start_day": 1,
		"target_category": "", "target_item_id": "",
	}
	assert_eq(
		_random.get_traffic_multiplier(),
		RandomEventSystem.COLLECTOR_CONVENTION_TRAFFIC_MULTIPLIER
	)

func test_random_supply_shortage_no_traffic() -> void:
	var def: RandomEventDefinition = _random_def({
		"effect_type": "supply_shortage",
	})
	_random._active_event = {
		"definition": def, "start_day": 1,
		"target_category": "electronics", "target_item_id": "",
	}
	assert_eq(_random.get_traffic_multiplier(), 1.0)

# --- Random: demand multiplier (viral trend) ---

func test_random_viral_trend_target() -> void:
	var def: RandomEventDefinition = _random_def({
		"effect_type": "viral_trend",
	})
	_random._active_event = {
		"definition": def, "start_day": 1,
		"target_category": "", "target_item_id": "hot_42",
	}
	assert_eq(
		_random.get_demand_multiplier("hot_42"),
		RandomEventSystem.VIRAL_TREND_DEMAND_MULTIPLIER
	)

func test_random_viral_trend_non_target() -> void:
	var def: RandomEventDefinition = _random_def({
		"effect_type": "viral_trend",
	})
	_random._active_event = {
		"definition": def, "start_day": 1,
		"target_category": "", "target_item_id": "hot_42",
	}
	assert_eq(_random.get_demand_multiplier("other"), 1.0)

func test_random_no_event_demand() -> void:
	assert_eq(_random.get_demand_multiplier("any"), 1.0)

# --- Random: blocked category ---

func test_random_shortage_blocks_category() -> void:
	var def: RandomEventDefinition = _random_def({
		"effect_type": "supply_shortage",
	})
	_random._active_event = {
		"definition": def, "start_day": 1,
		"target_category": "electronics", "target_item_id": "",
	}
	assert_eq(_random.get_blocked_category(), "electronics")

func test_random_no_blocked_without_event() -> void:
	assert_eq(_random.get_blocked_category(), "")

# --- Random: expiry and effects removal ---

func test_random_expires_after_duration() -> void:
	var def: RandomEventDefinition = _random_def({
		"effect_type": "celebrity_visit", "duration_days": 2,
	})
	_random._active_event = {
		"definition": def, "start_day": 10,
		"target_category": "", "target_item_id": "",
	}
	var got_id: Array = [""]
	var cb: Callable = func(id: String) -> void:
		got_id[0] = id
	EventBus.random_event_ended.connect(cb)
	_random._check_active_event_expiry(11)
	assert_true(_random.has_active_event(), "Still active day 11")
	_random._check_active_event_expiry(12)
	assert_false(_random.has_active_event(), "Expired day 12")
	assert_eq(got_id[0], "test_random")
	EventBus.random_event_ended.disconnect(cb)

func test_random_effects_cleared_on_expiry() -> void:
	var def: RandomEventDefinition = _random_def({
		"effect_type": "celebrity_visit", "duration_days": 1,
	})
	_random._active_event = {
		"definition": def, "start_day": 5,
		"target_category": "", "target_item_id": "",
	}
	_random._disabled_fixture_id = "some_fixture"
	_random._check_active_event_expiry(6)
	assert_false(_random.has_active_event())
	assert_eq(_random._disabled_fixture_id, "")
	assert_eq(_random.get_traffic_multiplier(), 1.0)

func test_random_cooldown_set_after_expiry() -> void:
	var def: RandomEventDefinition = _random_def({
		"cooldown_days": 10, "duration_days": 1,
	})
	_random._active_event = {
		"definition": def, "start_day": 5,
		"target_category": "", "target_item_id": "",
	}
	_random._check_active_event_expiry(6)
	assert_eq(_random._cooldowns.get("test_random", 0), 10)

func test_random_cooldown_prevents_reactivation() -> void:
	var def: RandomEventDefinition = _random_def({"cooldown_days": 5})
	_set_random_definitions(def)
	_random._cooldowns["test_random"] = 3
	assert_eq(_random._get_eligible_daily().size(), 0)

func test_random_cooldown_ticks_down() -> void:
	_random._cooldowns["evt_a"] = 3
	_random._cooldowns["evt_b"] = 1
	_random._tick_cooldowns()
	assert_eq(_random._cooldowns.get("evt_a", -1), 2)
	assert_false(_random._cooldowns.has("evt_b"))

# --- Random: probability weighting ---

func test_random_eligible_filters_cooldowns() -> void:
	var a: RandomEventDefinition = _random_def({"id": "a"})
	var b: RandomEventDefinition = _random_def({"id": "b"})
	var c: RandomEventDefinition = _random_def({"id": "c"})
	_set_random_definitions_three(a, b, c)
	_random._cooldowns["b"] = 5
	var eligible: Array[RandomEventDefinition] = _random._get_eligible_daily()
	assert_eq(eligible.size(), 2)
	var ids: PackedStringArray = []
	for d: RandomEventDefinition in eligible:
		ids.append(d.id)
	assert_true("a" in ids and "c" in ids)
	assert_false("b" in ids)


func test_random_weighted_selection_favors_higher_weight() -> void:
	seed(424242)
	var heavy: RandomEventDefinition = _random_def({
		"id": "heavy", "probability_weight": 9.0,
	})
	var light: RandomEventDefinition = _random_def({
		"id": "light", "probability_weight": 1.0,
	})
	var counts: Dictionary = {"heavy": 0, "light": 0}
	var candidates: Array[RandomEventDefinition] = [heavy, light]
	for _i: int in range(1000):
		var chosen: RandomEventDefinition = _random._weighted_pick(
			candidates
		)
		counts[chosen.id] = int(counts[chosen.id]) + 1
	assert_gt(
		int(counts["heavy"]),
		int(counts["light"]),
		"Higher-weight events should be selected more often"
	)
	assert_gt(
		int(counts["heavy"]), 850,
		"Heavy event should dominate over 1000 weighted picks"
	)


func test_random_uniform_selection_over_eligible() -> void:
	var a: RandomEventDefinition = _random_def({"id": "a"})
	var b: RandomEventDefinition = _random_def({"id": "b"})
	var c: RandomEventDefinition = _random_def({"id": "c"})
	var defs: Array[RandomEventDefinition] = []
	defs.append(a)
	defs.append(b)
	defs.append(c)
	var counts: Dictionary = {"a": 0, "b": 0, "c": 0}
	for i: int in range(3000):
		var chosen: RandomEventDefinition = defs[randi() % defs.size()]
		counts[chosen.id] = int(counts[chosen.id]) + 1
	var expected: float = 1000.0
	for id: String in counts:
		var ratio: float = float(counts[id] as int) / expected
		assert_gt(ratio, 0.7, "%s ratio %.2f too low" % [id, ratio])
		assert_true(ratio < 1.3, "%s ratio %.2f too high" % [id, ratio])

# --- Random: save/load ---

func test_random_save_load_roundtrip() -> void:
	var def: RandomEventDefinition = _random_def({
		"id": "supply_evt", "effect_type": "supply_shortage",
	})
	_set_random_definitions(def)
	_random._active_event = {
		"definition": def, "start_day": 8,
		"target_category": "electronics", "target_item_id": "",
	}
	_random._cooldowns["old_evt"] = 3
	var save: Dictionary = _random.get_save_data()
	var rest: RandomEventSystem = RandomEventSystem.new()
	add_child_autofree(rest)
	_set_random_definitions_on(rest, def)
	rest.load_save_data(save)
	assert_true(rest.has_active_event())
	var active: Dictionary = rest.get_active_event()
	var rd: RandomEventDefinition = active.get(
		"definition", null
	) as RandomEventDefinition
	assert_eq(rd.id, "supply_evt")
	assert_eq(rest._cooldowns.get("old_evt", 0), 3)

func test_random_load_skips_unknown() -> void:
	_clear_random_definitions()
	_random.load_save_data({
		"active_event": {"definition_id": "x", "start_day": 1},
		"cooldowns": {},
	})
	assert_false(_random.has_active_event())

func test_random_load_empty_data() -> void:
	_random.load_save_data({})
	assert_false(_random.has_active_event())
	assert_eq(_random._cooldowns.size(), 0)
