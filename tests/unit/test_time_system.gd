## Unit tests for TimeSystem day advancement, phase transitions, pause, and signals.
extends GutTest


var _ts: TimeSystem


func before_each() -> void:
	_ts = TimeSystem.new()
	add_child_autofree(_ts)
	_ts.initialize()


func test_initial_state_after_initialize() -> void:
	assert_eq(_ts.current_day, 1, "Day should start at 1")
	assert_eq(_ts.current_hour, 7, "Hour should start at 7 (420min / 60)")
	assert_false(_ts.is_paused(), "Should not be paused after initialize")


func test_hour_advancement_via_process() -> void:
	watch_signals(EventBus)
	_ts.game_time_minutes = 479.0
	_ts._last_emitted_hour = 7
	_ts._process(2.0)
	assert_signal_emitted(EventBus, "hour_changed")
	var params: Array = get_signal_parameters(EventBus, "hour_changed")
	assert_eq(params[0] as int, 8, "hour_changed should emit hour 8")
	assert_eq(_ts.current_hour, 8, "current_hour should update to 8")


func test_hour_advancement_emits_each_hour() -> void:
	var hours_received: Array[int] = []
	EventBus.hour_changed.connect(
		func(h: int) -> void: hours_received.append(h)
	)
	_ts.game_time_minutes = 479.0
	_ts._last_emitted_hour = 7
	_ts._process(121.0)
	assert_gt(
		hours_received.size(), 1,
		"Multiple hours should emit when time jumps ahead"
	)
	for i: int in range(1, hours_received.size()):
		assert_eq(
			hours_received[i], hours_received[i - 1] + 1,
			"Hours should emit in consecutive order"
		)


func test_day_boundary_emits_day_ended() -> void:
	watch_signals(EventBus)
	_ts.game_time_minutes = 1259.0
	_ts._last_emitted_hour = 20
	_ts._process(2.0)
	assert_signal_emitted(EventBus, "day_ended")
	var params: Array = get_signal_parameters(EventBus, "day_ended")
	assert_eq(params[0] as int, 1, "day_ended should carry current day")


func test_advance_day_increments_and_emits_day_started() -> void:
	watch_signals(EventBus)
	_ts.advance_to_next_day()
	assert_eq(_ts.current_day, 2, "Day should increment to 2")
	assert_signal_emitted(EventBus, "day_started")
	var params: Array = get_signal_parameters(EventBus, "day_started")
	assert_eq(params[0] as int, 2, "day_started should carry new day number")


func test_advance_day_resets_time_and_phase() -> void:
	_ts.game_time_minutes = 1200.0
	_ts.current_phase = TimeSystem.DayPhase.EVENING
	_ts.advance_to_next_day()
	assert_almost_eq(
		_ts.game_time_minutes, 420.0, 0.01,
		"Time should reset to day start"
	)
	assert_eq(
		_ts.current_phase, TimeSystem.DayPhase.PRE_OPEN,
		"Phase should reset to PRE_OPEN"
	)
	assert_eq(_ts.current_hour, 7, "Hour should reset to 7")


func test_pause_stops_time_advancement() -> void:
	_ts.set_speed(TimeSystem.SpeedTier.PAUSED)
	assert_true(_ts.is_paused(), "is_paused should return true")
	var start: float = _ts.game_time_minutes
	_ts._process(10.0)
	assert_eq(
		_ts.game_time_minutes, start,
		"Time should not advance while paused"
	)


func test_resume_after_pause() -> void:
	_ts.set_speed(TimeSystem.SpeedTier.PAUSED)
	assert_true(_ts.is_paused())
	_ts.set_speed(TimeSystem.SpeedTier.NORMAL)
	assert_false(_ts.is_paused(), "is_paused should return false after resume")
	var start: float = _ts.game_time_minutes
	_ts._process(1.0)
	assert_gt(
		_ts.game_time_minutes, start,
		"Time should advance after resume"
	)


func test_pause_blocks_hour_signal() -> void:
	_ts.set_speed(TimeSystem.SpeedTier.PAUSED)
	_ts.game_time_minutes = 479.0
	_ts._last_emitted_hour = 7
	watch_signals(EventBus)
	_ts._process(5.0)
	assert_signal_not_emitted(
		EventBus, "hour_changed",
		"hour_changed should not emit while paused"
	)


func test_no_double_day_ended_emit() -> void:
	var ended_count: Array = [0]
	EventBus.day_ended.connect(
		func(_d: int) -> void: ended_count[0] += 1
	)
	_ts.game_time_minutes = 1259.0
	_ts._last_emitted_hour = 20
	_ts._process(2.0)
	_ts._process(2.0)
	assert_eq(
		ended_count[0], 1,
		"day_ended should emit once even with multiple process calls"
	)


func test_save_load_round_trip_preserves_day_and_hour() -> void:
	_ts.current_day = 5
	_ts.game_time_minutes = 900.0
	_ts._last_emitted_hour = 15
	_ts.current_hour = 15
	_ts.set_speed(TimeSystem.SpeedTier.FAST)

	var data: Dictionary = _ts.get_save_data()

	var ts2: TimeSystem = TimeSystem.new()
	add_child_autofree(ts2)
	ts2.load_save_data(data)

	assert_eq(ts2.current_day, 5, "Day should survive round-trip")
	assert_eq(ts2.current_hour, 15, "Hour should survive round-trip")
	assert_almost_eq(
		ts2.game_time_minutes, 900.0, 0.01,
		"game_time_minutes should survive round-trip"
	)


func test_save_load_round_trip_preserves_auto_slow() -> void:
	_ts.push_auto_slow("test_reason")
	var data: Dictionary = _ts.get_save_data()

	var ts2: TimeSystem = TimeSystem.new()
	add_child_autofree(ts2)
	ts2.load_save_data(data)

	assert_true(
		ts2.is_auto_slowed(),
		"Auto-slow state should survive round-trip"
	)


func test_phase_pre_open() -> void:
	_ts.game_time_minutes = 420.0
	_ts._check_phase_transition()
	assert_eq(
		_ts.get_current_phase(), TimeSystem.DayPhase.PRE_OPEN,
		"420min should be PRE_OPEN"
	)


func test_phase_morning_ramp() -> void:
	_ts.game_time_minutes = 540.0
	_ts._check_phase_transition()
	assert_eq(
		_ts.get_current_phase(), TimeSystem.DayPhase.MORNING_RAMP,
		"540min should be MORNING_RAMP"
	)


func test_phase_midday_rush() -> void:
	_ts.game_time_minutes = 690.0
	_ts._check_phase_transition()
	assert_eq(
		_ts.get_current_phase(), TimeSystem.DayPhase.MIDDAY_RUSH,
		"690min should be MIDDAY_RUSH"
	)


func test_phase_afternoon() -> void:
	_ts.game_time_minutes = 840.0
	_ts._check_phase_transition()
	assert_eq(
		_ts.get_current_phase(), TimeSystem.DayPhase.AFTERNOON,
		"840min should be AFTERNOON"
	)


func test_phase_evening() -> void:
	_ts.game_time_minutes = 1080.0
	_ts._check_phase_transition()
	assert_eq(
		_ts.get_current_phase(), TimeSystem.DayPhase.EVENING,
		"1080min should be EVENING"
	)


func test_phase_transition_emits_signal() -> void:
	watch_signals(EventBus)
	_ts.game_time_minutes = 539.0
	_ts._last_emitted_hour = 8
	_ts._process(2.0)
	assert_signal_emitted(
		EventBus, "day_phase_changed",
		"Phase change should emit day_phase_changed"
	)
	var params: Array = get_signal_parameters(
		EventBus, "day_phase_changed"
	)
	assert_eq(
		params[0] as int,
		TimeSystem.DayPhase.MORNING_RAMP as int,
		"Should transition to MORNING_RAMP"
	)


func test_phase_mid_range_values() -> void:
	_ts.game_time_minutes = 600.0
	_ts._check_phase_transition()
	assert_eq(
		_ts.get_current_phase(), TimeSystem.DayPhase.MORNING_RAMP,
		"600min (between 540 and 690) should be MORNING_RAMP"
	)

	_ts.game_time_minutes = 750.0
	_ts._check_phase_transition()
	assert_eq(
		_ts.get_current_phase(), TimeSystem.DayPhase.MIDDAY_RUSH,
		"750min (between 690 and 840) should be MIDDAY_RUSH"
	)

	_ts.game_time_minutes = 1000.0
	_ts._check_phase_transition()
	assert_eq(
		_ts.get_current_phase(), TimeSystem.DayPhase.AFTERNOON,
		"1000min (between 840 and 1080) should be AFTERNOON"
	)

	_ts.game_time_minutes = 1200.0
	_ts._check_phase_transition()
	assert_eq(
		_ts.get_current_phase(), TimeSystem.DayPhase.EVENING,
		"1200min (above 1080) should be EVENING"
	)
