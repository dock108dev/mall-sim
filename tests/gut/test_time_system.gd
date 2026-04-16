## Tests for TimeSystem day phases, speed controls, and auto-slowdown.
extends GutTest


var _ts: TimeSystem


func before_each() -> void:
	_ts = TimeSystem.new()
	add_child_autofree(_ts)
	_ts.initialize()


func test_initial_state() -> void:
	assert_eq(_ts.current_day, 1)
	assert_eq(_ts.current_phase, TimeSystem.DayPhase.PRE_OPEN)
	assert_eq(
		_ts.game_time_minutes, 420.0,
		"Day should start at 420 minutes (7:00)"
	)
	assert_eq(_ts.speed_multiplier, 1.0)


func test_constants() -> void:
	assert_eq(TimeSystem.GAME_MINUTES_PER_REAL_SECOND_NORMAL, 1.0)
	assert_eq(TimeSystem.MALL_OPEN_HOUR, 9)
	assert_eq(TimeSystem.MALL_CLOSE_HOUR, 21)


func test_speed_tiers() -> void:
	assert_eq(TimeSystem.SpeedTier.PAUSED, 0)
	assert_eq(TimeSystem.SpeedTier.NORMAL, 1)
	assert_eq(TimeSystem.SpeedTier.FAST, 3)
	assert_eq(TimeSystem.SpeedTier.ULTRA, 6)


func test_set_speed_normal() -> void:
	_ts.set_speed(TimeSystem.SpeedTier.NORMAL)
	assert_eq(_ts.speed_multiplier, 1.0)


func test_set_speed_fast() -> void:
	_ts.set_speed(TimeSystem.SpeedTier.FAST)
	assert_eq(_ts.speed_multiplier, 3.0)


func test_set_speed_ultra() -> void:
	_ts.set_speed(TimeSystem.SpeedTier.ULTRA)
	assert_eq(_ts.speed_multiplier, 6.0)


func test_set_speed_paused() -> void:
	_ts.set_speed(TimeSystem.SpeedTier.PAUSED)
	assert_eq(_ts.speed_multiplier, 0.0)
	assert_true(_ts.is_paused())


func test_toggle_pause() -> void:
	_ts.set_speed(TimeSystem.SpeedTier.FAST)
	_ts.toggle_pause()
	assert_true(_ts.is_paused())
	_ts.toggle_pause()
	assert_eq(_ts.speed_multiplier, 1.0)


func test_get_current_phase() -> void:
	assert_eq(_ts.get_current_phase(), TimeSystem.DayPhase.PRE_OPEN)


func test_day_phase_boundaries() -> void:
	_ts.game_time_minutes = 420.0
	_ts._check_phase_transition()
	assert_eq(_ts.current_phase, TimeSystem.DayPhase.PRE_OPEN)

	_ts.game_time_minutes = 540.0
	_ts._check_phase_transition()
	assert_eq(_ts.current_phase, TimeSystem.DayPhase.MORNING_RAMP)

	_ts.game_time_minutes = 690.0
	_ts._check_phase_transition()
	assert_eq(_ts.current_phase, TimeSystem.DayPhase.MIDDAY_RUSH)

	_ts.game_time_minutes = 840.0
	_ts._check_phase_transition()
	assert_eq(_ts.current_phase, TimeSystem.DayPhase.AFTERNOON)

	_ts.game_time_minutes = 1080.0
	_ts._check_phase_transition()
	assert_eq(_ts.current_phase, TimeSystem.DayPhase.EVENING)


func test_hour_changed_signal_emits_once() -> void:
	var hours_received: Array[int] = []
	EventBus.hour_changed.connect(
		func(h: int) -> void: hours_received.append(h)
	)
	_ts.game_time_minutes = 479.0
	_ts._last_emitted_hour = 7
	_ts._process(2.0)
	assert_eq(hours_received.size(), 1, "Should emit exactly once for hour 8")
	assert_eq(hours_received[0], 8)


func test_hour_changed_not_duplicated() -> void:
	var count: Array = [0]
	EventBus.hour_changed.connect(
		func(_h: int) -> void: count[0] += 1
	)
	_ts.game_time_minutes = 539.0
	_ts._last_emitted_hour = 8
	_ts._process(0.5)
	_ts._process(0.5)
	assert_eq(count[0], 1, "Hour 9 should only emit once across frames")


func test_day_started_emitted() -> void:
	var days: Array[int] = []
	EventBus.day_started.connect(
		func(d: int) -> void: days.append(d)
	)
	_ts.advance_to_next_day()
	assert_eq(days.size(), 1)
	assert_eq(days[0], 2)


func test_day_ended_emitted() -> void:
	var ended_days: Array[int] = []
	EventBus.day_ended.connect(
		func(d: int) -> void: ended_days.append(d)
	)
	_ts.game_time_minutes = 1259.0
	_ts._last_emitted_hour = 20
	_ts._process(2.0)
	assert_eq(ended_days.size(), 1)
	assert_eq(ended_days[0], 1)


func test_day_phase_changed_signal() -> void:
	var phases: Array[int] = []
	EventBus.day_phase_changed.connect(
		func(p: int) -> void: phases.append(p)
	)
	_ts.game_time_minutes = 539.0
	_ts._last_emitted_hour = 8
	_ts._process(2.0)
	assert_true(
		phases.has(TimeSystem.DayPhase.MORNING_RAMP),
		"Should emit MORNING_RAMP phase"
	)


func test_day_phase_changed_emits_each_crossed_boundary() -> void:
	var phases: Array[int] = []
	EventBus.day_phase_changed.connect(
		func(p: int) -> void: phases.append(p)
	)
	_ts.game_time_minutes = 539.0
	_ts._last_emitted_hour = 8
	_ts._process(600.0)
	assert_eq(
		phases,
		[
			TimeSystem.DayPhase.MORNING_RAMP,
			TimeSystem.DayPhase.MIDDAY_RUSH,
			TimeSystem.DayPhase.AFTERNOON,
			TimeSystem.DayPhase.EVENING,
		],
		"Large time jumps should emit every phase boundary in order"
	)


func test_auto_slow_forces_normal() -> void:
	_ts.set_speed(TimeSystem.SpeedTier.ULTRA)
	assert_eq(_ts.speed_multiplier, 6.0)
	_ts.push_auto_slow("customer_complaint")
	assert_eq(_ts.speed_multiplier, 1.0, "Auto-slow should force NORMAL")
	assert_true(_ts.is_auto_slowed())


func test_auto_slow_pop_restores_speed() -> void:
	_ts.set_speed(TimeSystem.SpeedTier.FAST)
	_ts.push_auto_slow("event_a")
	assert_eq(_ts.speed_multiplier, 1.0)
	_ts.pop_auto_slow("event_a")
	assert_eq(
		_ts.speed_multiplier, 3.0,
		"Should restore FAST after popping last reason"
	)
	assert_false(_ts.is_auto_slowed())


func test_auto_slow_stack_multiple() -> void:
	_ts.set_speed(TimeSystem.SpeedTier.ULTRA)
	_ts.push_auto_slow("reason_a")
	_ts.push_auto_slow("reason_b")
	assert_eq(_ts.speed_multiplier, 1.0)
	_ts.pop_auto_slow("reason_a")
	assert_eq(
		_ts.speed_multiplier, 1.0,
		"Still slowed with one reason remaining"
	)
	_ts.pop_auto_slow("reason_b")
	assert_eq(
		_ts.speed_multiplier, 6.0,
		"Restored to ULTRA after all reasons popped"
	)


func test_speed_reduced_by_event_signal() -> void:
	var reasons: Array[String] = []
	EventBus.speed_reduced_by_event.connect(
		func(r: String) -> void: reasons.append(r)
	)
	_ts.push_auto_slow("theft")
	assert_eq(reasons.size(), 1)
	assert_eq(reasons[0], "theft")


func test_time_advances_at_correct_rate() -> void:
	_ts.set_speed(TimeSystem.SpeedTier.FAST)
	var start: float = _ts.game_time_minutes
	_ts._process(1.0)
	var elapsed: float = _ts.game_time_minutes - start
	assert_almost_eq(elapsed, 3.0, 0.01, "FAST should advance 3 min/sec")


func test_time_advances_at_all_speed_tiers() -> void:
	_ts.set_speed(TimeSystem.SpeedTier.PAUSED)
	_ts.game_time_minutes = 420.0
	_ts._process(1.0)
	assert_almost_eq(_ts.game_time_minutes, 420.0, 0.01)

	_ts.set_speed(TimeSystem.SpeedTier.NORMAL)
	_ts.game_time_minutes = 420.0
	_ts._process(1.0)
	assert_almost_eq(_ts.game_time_minutes, 421.0, 0.01)

	_ts.set_speed(TimeSystem.SpeedTier.FAST)
	_ts.game_time_minutes = 420.0
	_ts._process(1.0)
	assert_almost_eq(_ts.game_time_minutes, 423.0, 0.01)

	_ts.set_speed(TimeSystem.SpeedTier.ULTRA)
	_ts.game_time_minutes = 420.0
	_ts._process(1.0)
	assert_almost_eq(_ts.game_time_minutes, 426.0, 0.01)


func test_paused_does_not_advance() -> void:
	_ts.set_speed(TimeSystem.SpeedTier.PAUSED)
	var start: float = _ts.game_time_minutes
	_ts._process(5.0)
	assert_eq(
		_ts.game_time_minutes, start,
		"Paused should not advance time"
	)


func test_save_load_round_trip() -> void:
	_ts.current_day = 3
	_ts.game_time_minutes = 750.0
	_ts.set_speed(TimeSystem.SpeedTier.FAST)
	_ts.push_auto_slow("test_reason")

	var data: Dictionary = _ts.get_save_data()

	var ts2: TimeSystem = TimeSystem.new()
	add_child_autofree(ts2)
	ts2.load_save_data(data)

	assert_eq(ts2.current_day, 3)
	assert_almost_eq(ts2.game_time_minutes, 750.0, 0.01)
	assert_true(ts2.is_auto_slowed())


func test_advance_to_next_day_resets_state() -> void:
	_ts.game_time_minutes = 1200.0
	_ts.current_phase = TimeSystem.DayPhase.EVENING
	_ts.push_auto_slow("some_reason")
	_ts.advance_to_next_day()

	assert_eq(_ts.current_day, 2)
	assert_eq(_ts.game_time_minutes, 420.0)
	assert_eq(_ts.current_phase, TimeSystem.DayPhase.PRE_OPEN)
	assert_false(_ts.is_auto_slowed())


func test_get_active_phases_excludes_late_evening_by_default() -> void:
	var phases: Array[TimeSystem.DayPhase] = _ts.get_active_phases()
	assert_eq(phases.size(), 5, "Should have 5 phases without extended hours")
	assert_false(
		phases.has(TimeSystem.DayPhase.LATE_EVENING),
		"LATE_EVENING should not be in active phases before unlock"
	)


func test_get_active_phases_includes_late_evening_when_enabled() -> void:
	_ts._late_evening_enabled = true
	var phases: Array[TimeSystem.DayPhase] = _ts.get_active_phases()
	assert_eq(phases.size(), 6, "Should have 6 phases with extended hours")
	assert_true(
		phases.has(TimeSystem.DayPhase.LATE_EVENING),
		"LATE_EVENING should be in active phases after unlock"
	)
	assert_eq(
		phases[-1], TimeSystem.DayPhase.LATE_EVENING,
		"LATE_EVENING should be the last phase"
	)


func test_unlock_granted_enables_late_evening() -> void:
	assert_false(_ts._late_evening_enabled)
	EventBus.unlock_granted.emit(&"extended_hours_unlock")
	assert_true(_ts._late_evening_enabled, "Should enable LATE_EVENING on unlock signal")


func test_unrelated_unlock_does_not_enable_late_evening() -> void:
	EventBus.unlock_granted.emit(&"some_other_unlock")
	assert_false(_ts._late_evening_enabled, "Unrelated unlock should not affect late evening")


func test_late_evening_phase_transition() -> void:
	_ts._late_evening_enabled = true
	_ts.game_time_minutes = 1259.0
	_ts._check_phase_transition()
	assert_eq(_ts.current_phase, TimeSystem.DayPhase.EVENING)

	_ts.game_time_minutes = 1260.0
	_ts._check_phase_transition()
	assert_eq(_ts.current_phase, TimeSystem.DayPhase.LATE_EVENING)


func test_day_ends_at_1440_when_late_evening_enabled() -> void:
	_ts._late_evening_enabled = true
	var ended_days: Array[int] = []
	EventBus.day_ended.connect(
		func(d: int) -> void: ended_days.append(d)
	)
	_ts.game_time_minutes = 1439.0
	_ts._last_emitted_hour = 23
	_ts._process(2.0)
	assert_eq(ended_days.size(), 1, "Day should end after LATE_EVENING completes")


func test_day_does_not_end_at_1260_when_late_evening_enabled() -> void:
	_ts._late_evening_enabled = true
	var ended_days: Array[int] = []
	EventBus.day_ended.connect(
		func(d: int) -> void: ended_days.append(d)
	)
	_ts.game_time_minutes = 1259.0
	_ts._last_emitted_hour = 20
	_ts._process(0.5)
	assert_eq(ended_days.size(), 0, "Day should not end at 1260 when late evening is active")
