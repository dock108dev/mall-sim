## Unit tests for MetaShiftSystem shift detection, demand modifiers, expiration, and signals.
extends GutTest


var _system: MetaShiftSystem


func before_each() -> void:
	_system = MetaShiftSystem.new()
	add_child_autofree(_system)


func _trigger_active_shift(
	card_id: StringName = &"hot_card", duration_days: int = 3
) -> void:
	_system.trigger_shift(card_id, duration_days)


func test_no_active_shift_on_init() -> void:
	assert_false(
		_system.is_shift_active(),
		"Fresh instance should have no active shift"
	)


func test_trigger_shift_marks_active() -> void:
	_trigger_active_shift()
	assert_true(
		_system.is_shift_active(),
		"Shift should be active after trigger_shift"
	)


func test_active_shift_returns_modifier() -> void:
	_trigger_active_shift()
	var result: float = _system.get_demand_modifier(&"hot_card")
	assert_gt(
		result, 1.0,
		"Shifted card should get a demand modifier above 1.0"
	)


func test_non_shifted_card_returns_base_modifier() -> void:
	_trigger_active_shift()
	var result: float = _system.get_demand_modifier(&"unrelated_card")
	assert_almost_eq(
		result, 1.0, 0.01,
		"Non-shifted card should return base modifier of 1.0"
	)


func test_shift_expires_after_duration() -> void:
	# Day 1 quarantine: _on_day_started returns early on day <= 1, so progress
	# the shift via days 2 and 3 instead.
	_trigger_active_shift(&"hot_card", 2)
	assert_true(
		_system.is_shift_active(),
		"Shift should be active before expiration"
	)
	_system._on_day_started(2)
	assert_true(
		_system.is_shift_active(),
		"Shift should still be active before its duration elapses"
	)
	_system._on_day_started(3)
	assert_false(
		_system.is_shift_active(),
		"Shift should expire after its duration elapses"
	)


func test_meta_shift_started_signal() -> void:
	watch_signals(EventBus)
	_system.trigger_shift(&"hot_card", 4)
	assert_signal_emitted(
		EventBus, "meta_shift_started",
		"meta_shift_started should fire when shift starts"
	)
	var params: Array = get_signal_parameters(
		EventBus, "meta_shift_started"
	)
	assert_eq(
		params[0], &"hot_card",
		"Signal should include the shifted card ID"
	)
	assert_gt(
		params[1], 1.0,
		"Signal should include a demand modifier above 1.0"
	)
	assert_eq(
		params[2], 4,
		"Signal should include the shift duration"
	)


func test_meta_shift_ended_signal() -> void:
	# Day 1 quarantine: _on_day_started returns early on day <= 1, so use day 2
	# to expire a 1-day shift.
	_trigger_active_shift(&"hot_card", 1)
	watch_signals(EventBus)
	_system._on_day_started(2)
	assert_signal_emitted(
		EventBus, "meta_shift_ended",
		"meta_shift_ended should fire when shift expires"
	)
	var params: Array = get_signal_parameters(EventBus, "meta_shift_ended")
	assert_eq(
		params[0], &"hot_card",
		"Signal should include the expired card ID"
	)
