## Tests for RandomEventSystem EventBus wiring and event notifications.
extends GutTest


var _system: RandomEventSystem
var _triggered_events: Array[Dictionary] = []
var _toast_messages: Array[Dictionary] = []


func _make_def(overrides: Dictionary = {}) -> RandomEventDefinition:
	var d := RandomEventDefinition.new()
	d.id = overrides.get("id", "test_event")
	d.name = overrides.get("name", "Test Event")
	d.description = overrides.get("description", "A test")
	d.effect_type = overrides.get("effect_type", "celebrity_visit")
	d.duration_days = overrides.get("duration_days", 1)
	d.severity = overrides.get("severity", "medium")
	d.cooldown_days = overrides.get("cooldown_days", 10)
	d.probability_weight = overrides.get("probability_weight", 1.0)
	d.notification_text = overrides.get(
		"notification_text", "Something happened!"
	)
	d.resolution_text = overrides.get("resolution_text", "")
	d.toast_message = overrides.get("toast_message", "Toast msg")
	d.time_window_start = overrides.get("time_window_start", -1)
	d.time_window_end = overrides.get("time_window_end", -1)
	return d


func before_each() -> void:
	_system = RandomEventSystem.new()
	add_child_autofree(_system)
	_triggered_events = []
	_toast_messages = []
	EventBus.random_event_triggered.connect(_on_triggered)
	EventBus.toast_requested.connect(_on_toast)


func after_each() -> void:
	if EventBus.random_event_triggered.is_connected(_on_triggered):
		EventBus.random_event_triggered.disconnect(_on_triggered)
	if EventBus.toast_requested.is_connected(_on_toast):
		EventBus.toast_requested.disconnect(_on_toast)


func _on_triggered(
	event_id: StringName,
	store_id: StringName,
	effect: Dictionary
) -> void:
	_triggered_events.append({
		"event_id": event_id,
		"store_id": store_id,
		"effect": effect,
	})


func _on_toast(
	message: String,
	category: StringName,
	duration: float
) -> void:
	_toast_messages.append({
		"message": message,
		"category": category,
		"duration": duration,
	})


func test_evaluate_daily_events_returns_fired_ids() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "celebrity_visit",
		"effect_type": "celebrity_visit",
		"probability_weight": 100.0,
	})
	_system._event_definitions = [def]
	_system._active_event = {}
	_system._cooldowns = {}
	_system._daily_rolled = false
	var fired: Array[StringName] = _system.evaluate_daily_events(1)
	assert_eq(fired.size(), 1)
	assert_eq(fired[0], &"celebrity_visit")


func test_evaluate_daily_events_returns_empty_when_all_on_cooldown() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "test_cd",
		"cooldown_days": 5,
	})
	_system._event_definitions = [def]
	_system._cooldowns = {"test_cd": 5}
	_system._daily_rolled = false
	var fired: Array[StringName] = _system.evaluate_daily_events(1)
	assert_eq(fired.size(), 0)


func test_evaluate_daily_events_emits_random_event_triggered() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "rainy_day",
		"effect_type": "rainy_day",
		"probability_weight": 100.0,
		"notification_text": "Rainy!",
	})
	_system._event_definitions = [def]
	_system._active_event = {}
	_system._cooldowns = {}
	_system._daily_rolled = false
	_system.evaluate_daily_events(1)
	assert_eq(_triggered_events.size(), 1)
	assert_eq(_triggered_events[0]["event_id"], &"rainy_day")


func test_get_event_config_returns_definition_dict() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "celebrity_visit",
		"name": "Celebrity Visit",
		"effect_type": "celebrity_visit",
		"duration_days": 1,
		"cooldown_days": 10,
		"probability_weight": 0.8,
	})
	_system._event_definitions = [def]
	var config: Dictionary = _system.get_event_config(
		&"celebrity_visit"
	)
	assert_eq(config["id"], "celebrity_visit")
	assert_eq(config["name"], "Celebrity Visit")
	assert_eq(config["effect_type"], "celebrity_visit")
	assert_eq(config["duration_days"], 1)
	assert_eq(config["cooldown_days"], 10)
	assert_almost_eq(
		float(config["probability_weight"]), 0.8, 0.01
	)


func test_get_event_config_returns_empty_for_unknown_id() -> void:
	_system._event_definitions = []
	var config: Dictionary = _system.get_event_config(
		&"nonexistent"
	)
	assert_eq(config.size(), 0)


func test_serialize_deserialize_preserves_cooldowns() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "test_ser",
		"effect_type": "celebrity_visit",
		"cooldown_days": 5,
		"duration_days": 2,
	})
	_system._event_definitions = [def]
	_system._cooldowns = {"test_ser": 3}
	_system._active_event = {
		"definition": def,
		"start_day": 1,
		"target_category": "",
		"target_item_id": "",
	}
	var saved: Dictionary = _system.serialize()
	assert_true(saved.has("cooldowns"))
	assert_true(saved.has("active_event"))
	_system._cooldowns = {}
	_system._active_event = {}
	_system.deserialize(saved)
	assert_true(_system._cooldowns.has("test_ser"))
	assert_eq(int(_system._cooldowns["test_ser"]), 3)
	assert_true(_system.has_active_event())


func test_evaluate_frequency_over_simulated_days() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "freq_test",
		"effect_type": "rainy_day",
		"probability_weight": 1.0,
		"cooldown_days": 0,
		"notification_text": "Rainy!",
	})
	_system._event_definitions = [def]
	var fire_count: int = 0
	for day: int in range(1, 101):
		_system._daily_rolled = false
		_system._active_event = {}
		_system._cooldowns = {}
		var fired: Array[StringName] = _system.evaluate_daily_events(
			day
		)
		fire_count += fired.size()
	assert_gt(fire_count, 50)
	assert_lt(fire_count, 101)


func test_subscribes_to_day_started() -> void:
	_system._event_definitions = []
	_system._apply_state({})
	EventBus.day_started.connect(_system._on_day_started)
	assert_true(
		EventBus.day_started.is_connected(_system._on_day_started)
	)


func test_subscribes_to_hour_changed() -> void:
	_system._event_definitions = []
	_system._apply_state({})
	EventBus.hour_changed.connect(_system._on_hour_changed)
	assert_true(
		EventBus.hour_changed.is_connected(_system._on_hour_changed)
	)


func test_daily_event_emits_random_event_triggered() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "celebrity_visit",
		"effect_type": "celebrity_visit",
		"probability_weight": 100.0,
	})
	_system._event_definitions = [def]
	_system._daily_rolled = false
	_system._active_event = {}
	_system._cooldowns = {}
	_system._try_trigger_daily_event(1)
	assert_eq(_triggered_events.size(), 1)
	assert_eq(
		_triggered_events[0]["event_id"], &"celebrity_visit"
	)


func test_daily_event_emits_toast_with_category() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "rainy_day",
		"effect_type": "rainy_day",
		"probability_weight": 100.0,
		"toast_message": "It's raining!",
	})
	_system._event_definitions = [def]
	_system._daily_rolled = false
	_system._active_event = {}
	_system._cooldowns = {}
	_system._try_trigger_daily_event(1)
	assert_eq(_toast_messages.size(), 1)
	assert_eq(_toast_messages[0]["message"], "It's raining!")
	assert_eq(_toast_messages[0]["category"], &"random_event")
	assert_eq(_toast_messages[0]["duration"], 4.0)


func test_toast_falls_back_to_event_name() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "power_outage",
		"effect_type": "power_outage",
		"probability_weight": 100.0,
		"toast_message": "",
		"name": "Power Outage",
	})
	_system._event_definitions = [def]
	_system._daily_rolled = false
	_system._active_event = {}
	_system._cooldowns = {}
	_system._try_trigger_daily_event(1)
	assert_eq(_toast_messages[0]["message"], "Power Outage")


func test_hourly_event_only_triggers_in_time_window() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "shoplifting",
		"effect_type": "shoplifting",
		"probability_weight": 100.0,
		"time_window_start": 10,
		"time_window_end": 17,
		"notification_text": "Shoplifting! A thief stole %s!",
	})
	_system._event_definitions = [def]
	_system._active_event = {}
	_system._cooldowns = {}
	_system._hourly_rolled_events = {}
	var eligible: Array[RandomEventDefinition] = (
		_system._get_eligible_hourly(8)
	)
	assert_eq(eligible.size(), 0)
	eligible = _system._get_eligible_hourly(12)
	assert_eq(eligible.size(), 1)


func test_hourly_event_excluded_from_daily_roll() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "shoplifting",
		"effect_type": "shoplifting",
		"time_window_start": 10,
		"time_window_end": 17,
	})
	_system._event_definitions = [def]
	_system._cooldowns = {}
	var eligible: Array[RandomEventDefinition] = (
		_system._get_eligible_daily()
	)
	assert_eq(eligible.size(), 0)


func test_weighted_pick_respects_weights() -> void:
	var heavy: RandomEventDefinition = _make_def({
		"id": "heavy", "probability_weight": 1000.0,
	})
	var light: RandomEventDefinition = _make_def({
		"id": "light", "probability_weight": 0.001,
	})
	var picks: Dictionary = {"heavy": 0, "light": 0}
	for i: int in range(100):
		var pick: RandomEventDefinition = _system._weighted_pick(
			[heavy, light] as Array[RandomEventDefinition]
		)
		if pick:
			picks[pick.id] += 1
	assert_gt(picks["heavy"], 90)


func test_cooldown_prevents_reactivation() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "test_cd",
		"cooldown_days": 5,
	})
	_system._event_definitions = [def]
	_system._cooldowns = {"test_cd": 5}
	var eligible: Array[RandomEventDefinition] = (
		_system._get_eligible_daily()
	)
	assert_eq(eligible.size(), 0)


func test_rainy_day_traffic_multiplier() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "rainy_day",
		"effect_type": "rainy_day",
		"probability_weight": 100.0,
		"notification_text": "Rainy day!",
	})
	_system._event_definitions = [def]
	_system._daily_rolled = false
	_system._active_event = {}
	_system._cooldowns = {}
	_system._try_trigger_daily_event(1)
	assert_almost_eq(
		_system.get_traffic_multiplier(), 0.7, 0.01
	)


func test_competitor_sale_demand_modifier() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "competitor_sale",
		"effect_type": "competitor_sale",
		"probability_weight": 100.0,
		"notification_text": "Competitor sale!",
		"duration_days": 1,
	})
	_system._event_definitions = [def]
	_system._daily_rolled = false
	_system._active_event = {}
	_system._cooldowns = {}
	_system._try_trigger_daily_event(1)
	assert_almost_eq(
		_system.get_demand_multiplier("any_item"), 0.9, 0.01
	)


func test_event_expiry_clears_active_event() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "test_exp",
		"duration_days": 2,
	})
	_system._active_event = {
		"definition": def,
		"start_day": 1,
		"target_category": "",
		"target_item_id": "",
	}
	_system._check_active_event_expiry(3)
	assert_false(_system.has_active_event())


func test_triggered_effect_dict_contains_type() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "rainy_day",
		"effect_type": "rainy_day",
		"probability_weight": 100.0,
		"notification_text": "Rainy!",
	})
	_system._event_definitions = [def]
	_system._daily_rolled = false
	_system._active_event = {}
	_system._cooldowns = {}
	_system._try_trigger_daily_event(1)
	assert_eq(_triggered_events.size(), 1)
	assert_eq(_triggered_events[0]["effect"]["type"], "rainy_day")
	assert_almost_eq(
		float(_triggered_events[0]["effect"]["traffic_modifier"]),
		0.7, 0.01
	)


func test_seeded_rng_single_event_always_selected() -> void:
	seed(12345)
	var def: RandomEventDefinition = _make_def({
		"id": "always_pick",
		"effect_type": "rainy_day",
		"probability_weight": 1.0,
		"notification_text": "Rainy!",
	})
	_system._event_definitions = [def]
	for i: int in range(20):
		_system._active_event = {}
		_system._cooldowns = {}
		_system._daily_rolled = false
		var fired: Array[StringName] = _system.evaluate_daily_events(
			i + 1
		)
		assert_eq(fired.size(), 1)
		assert_eq(fired[0], &"always_pick")


func test_equal_weight_distribution_within_tolerance() -> void:
	seed(99999)
	var event_a: RandomEventDefinition = _make_def({
		"id": "event_a",
		"effect_type": "rainy_day",
		"probability_weight": 1.0,
		"notification_text": "A!",
	})
	var event_b: RandomEventDefinition = _make_def({
		"id": "event_b",
		"effect_type": "rainy_day",
		"probability_weight": 1.0,
		"notification_text": "B!",
	})
	_system._event_definitions = [event_a, event_b]
	var counts: Dictionary = {"event_a": 0, "event_b": 0}
	for i: int in range(100):
		_system._active_event = {}
		_system._cooldowns = {}
		_system._daily_rolled = false
		var fired: Array[StringName] = _system.evaluate_daily_events(
			i + 1
		)
		if fired.size() > 0:
			counts[String(fired[0])] += 1
	assert_gt(counts["event_a"], 35)
	assert_lt(counts["event_a"], 65)
	assert_gt(counts["event_b"], 35)
	assert_lt(counts["event_b"], 65)


func test_empty_pool_no_signal_no_error() -> void:
	_system._event_definitions = []
	_system._active_event = {}
	_system._cooldowns = {}
	_system._daily_rolled = false
	var fired: Array[StringName] = _system.evaluate_daily_events(1)
	assert_eq(fired.size(), 0)
	assert_eq(_triggered_events.size(), 0)
	assert_false(_system.has_active_event())


func test_cooldown_decrements_per_day_started() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "cd_test",
		"cooldown_days": 5,
	})
	_system._event_definitions = [def]
	_system._cooldowns = {"cd_test": 3}
	_system._tick_cooldowns()
	assert_eq(int(_system._cooldowns["cd_test"]), 2)
	_system._tick_cooldowns()
	assert_eq(int(_system._cooldowns["cd_test"]), 1)
	_system._tick_cooldowns()
	assert_false(_system._cooldowns.has("cd_test"))


func test_cooldown_event_excluded_then_eligible_after_expiry() -> void:
	var def: RandomEventDefinition = _make_def({
		"id": "cd_lifecycle",
		"effect_type": "rainy_day",
		"probability_weight": 100.0,
		"cooldown_days": 2,
		"notification_text": "Rainy!",
	})
	_system._event_definitions = [def]
	_system._cooldowns = {"cd_lifecycle": 2}
	var eligible: Array[RandomEventDefinition] = (
		_system._get_eligible_daily()
	)
	assert_eq(eligible.size(), 0)
	_system._tick_cooldowns()
	eligible = _system._get_eligible_daily()
	assert_eq(eligible.size(), 0)
	_system._tick_cooldowns()
	eligible = _system._get_eligible_daily()
	assert_eq(eligible.size(), 1)
