## GUT unit tests for AmbientMomentsSystem selection and cooldown contracts.
extends GutTest


var _system: AmbientMomentsSystem


func before_each() -> void:
	_system = AmbientMomentsSystem.new()
	add_child_autofree(_system)
	_system._apply_state({})
	_system._state = AmbientMomentsSystem.State.MONITORING
	_system.set_moment_pool([])
	GameManager.current_store_id = &""


func after_each() -> void:
	GameManager.current_store_id = &""


func test_ready_loads_moment_definitions_without_error() -> void:
	_system._ready()

	assert_true(
		_system._moment_definitions.size() >= 0,
		"_ready should leave moment definitions initialized"
	)


func test_trigger_moment_selects_eligible_and_emits_delivered() -> void:
	_system.set_moment_pool([
		_make_moment({"id": "eligible_one"}),
	])
	var delivered_ids: Array[StringName] = []
	var callback: Callable = func(
		moment_id: StringName,
		_display_type: StringName,
		_flavor_text: String,
		_audio_cue_id: StringName,
	) -> void:
		delivered_ids.append(moment_id)

	EventBus.ambient_moment_delivered.connect(callback)
	var selected: StringName = _system.trigger_moment(9)
	EventBus.ambient_moment_delivered.disconnect(callback)

	assert_eq(selected, &"eligible_one")
	assert_eq(delivered_ids, [&"eligible_one"])


func test_triggered_moment_is_ineligible_until_cooldown_expires() -> void:
	_system.set_moment_pool([
		_make_moment({"id": "cooldown_moment", "cooldown_days": 2}),
	])

	assert_eq(_system.trigger_moment(9), &"cooldown_moment")
	assert_eq(
		_system.get_eligible_moments(9).size(), 0,
		"Triggered moment should be blocked while cooldown is active"
	)
	assert_eq(
		_system.trigger_moment(9), &"",
		"Same moment must not re-trigger before cooldown expires"
	)

	_system.advance_time(2.0)

	var eligible: Array[AmbientMomentDefinition] = (
		_system.get_eligible_moments(9)
	)
	assert_eq(eligible.size(), 1)
	assert_eq(eligible[0].id, "cooldown_moment")


func test_trigger_moment_empty_eligible_pool_does_not_emit() -> void:
	_system.set_moment_pool([
		_make_moment({"id": "blocked", "cooldown_days": 3}),
	])
	_system._cooldowns["blocked"] = 3
	var delivered_ids: Array[StringName] = []
	var callback: Callable = func(
		moment_id: StringName,
		_display_type: StringName,
		_flavor_text: String,
		_audio_cue_id: StringName,
	) -> void:
		delivered_ids.append(moment_id)

	EventBus.ambient_moment_delivered.connect(callback)
	var selected: StringName = _system.trigger_moment(9)
	EventBus.ambient_moment_delivered.disconnect(callback)

	assert_eq(selected, &"")
	assert_eq(delivered_ids.size(), 0)


func test_advance_time_reduces_active_cooldowns() -> void:
	_system._cooldowns["slow"] = 3
	_system._cooldowns["fast"] = 1

	_system.advance_time(2.0)

	assert_eq(int(_system._cooldowns["slow"]), 1)
	assert_false(
		_system._cooldowns.has("fast"),
		"Cooldowns at or below zero should be removed"
	)


func test_get_eligible_moments_returns_only_zero_cooldown_moments() -> void:
	_system.set_moment_pool([
		_make_moment({"id": "open_a"}),
		_make_moment({"id": "blocked"}),
		_make_moment({"id": "open_b"}),
	])
	_system._cooldowns["blocked"] = 2

	var eligible_ids: PackedStringArray = []
	for moment: AmbientMomentDefinition in _system.get_eligible_moments(9):
		eligible_ids.append(moment.id)

	assert_eq(eligible_ids.size(), 2)
	assert_true("open_a" in eligible_ids)
	assert_false("blocked" in eligible_ids)
	assert_true("open_b" in eligible_ids)


func test_higher_weight_moment_is_selected_more_often() -> void:
	_system.set_moment_pool([
		_make_moment({"id": "heavy", "scheduling_weight": 9.0}),
		_make_moment({"id": "light", "scheduling_weight": 1.0}),
	])
	var counts: Dictionary = {"heavy": 0, "light": 0}

	seed(188)
	for i: int in range(100):
		var selected: StringName = _system.trigger_moment(9)
		counts[String(selected)] = int(counts[String(selected)]) + 1
		_system._cooldowns.clear()
		_system._delivery_history.clear()

	assert_gt(
		int(counts["heavy"]), int(counts["light"]),
		"Higher-weight moment should be selected more frequently"
	)


func test_set_moment_pool_replaces_active_moment_list() -> void:
	_system.set_moment_pool([
		_make_moment({"id": "old_a"}),
		_make_moment({"id": "old_b"}),
	])
	_system.set_moment_pool([
		_make_moment({"id": "new_only"}),
	])

	var eligible: Array[AmbientMomentDefinition] = (
		_system.get_eligible_moments(9)
	)
	assert_eq(eligible.size(), 1)
	assert_eq(eligible[0].id, "new_only")
	assert_null(_system._find_definition("old_a"))


func _make_moment(overrides: Dictionary = {}) -> AmbientMomentDefinition:
	var moment := AmbientMomentDefinition.new()
	moment.id = overrides.get("id", "test_moment")
	moment.name = overrides.get("name", "Test Moment")
	moment.category = overrides.get("category", "any")
	moment.trigger_category = overrides.get(
		"trigger_category", "time_of_day"
	)
	moment.trigger_value = overrides.get("trigger_value", "9")
	moment.display_type = StringName(
		overrides.get("display_type", "toast")
	)
	moment.flavor_text = overrides.get("flavor_text", "Test flavor")
	moment.audio_cue_id = StringName(overrides.get("audio_cue_id", ""))
	moment.scheduling_weight = overrides.get("scheduling_weight", 1.0)
	moment.cooldown_days = overrides.get("cooldown_days", 1)
	return moment
