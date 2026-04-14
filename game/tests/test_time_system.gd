## Unit tests for TimeSystem day/phase progression, speed control, and signal emission.
extends GutTest


var _time: TimeSystem


func before_each() -> void:
	_time = TimeSystem.new()
	add_child_autofree(_time)
	_time.set_process(false)


func test_advance_to_next_day_increments_day() -> void:
	assert_eq(_time.current_day, 1, "Should start at day 1")
	_time.advance_to_next_day()
	assert_eq(_time.current_day, 2, "Day should be 2 after advance")


func test_advance_to_next_day_resets_time_to_start() -> void:
	_time.game_time_minutes = 900.0
	_time.advance_to_next_day()
	assert_almost_eq(
		_time.game_time_minutes, 420.0, 0.01,
		"game_time_minutes should reset to DAY_START (420)"
	)
	assert_eq(
		_time.current_hour, 7,
		"current_hour should reset to 7 (420 / 60)"
	)


func test_hour_changed_signal_fires_on_hour_crossing() -> void:
	_time.game_time_minutes = 479.0
	_time._last_emitted_hour = 7
	_time.current_hour = 7

	var emitted_hours: Array[int] = []
	var cb: Callable = func(hour: int) -> void:
		emitted_hours.append(hour)
	EventBus.hour_changed.connect(cb)

	_time.game_time_minutes = 540.0
	_time._process(0.0)

	EventBus.hour_changed.disconnect(cb)
	assert_true(
		emitted_hours.has(8),
		"hour_changed should have emitted hour 8"
	)
	assert_true(
		emitted_hours.has(9),
		"hour_changed should have emitted hour 9"
	)


func test_hour_changed_does_not_fire_within_same_hour() -> void:
	_time.game_time_minutes = 420.0
	_time._last_emitted_hour = 7
	_time.current_hour = 7

	watch_signals(EventBus)
	_time.game_time_minutes = 450.0
	_time._process(0.0)

	assert_signal_not_emitted(
		EventBus, "hour_changed",
		"hour_changed should not fire when still within the same hour"
	)


func test_day_ended_signal_fires_at_end_of_day() -> void:
	_time.game_time_minutes = 1259.0
	_time._last_emitted_hour = 20
	_time.current_hour = 20
	_time.current_day = 3

	var ended_day: int = -1
	var cb: Callable = func(day: int) -> void:
		ended_day = day
	EventBus.day_ended.connect(cb)

	_time.game_time_minutes = 1261.0
	_time._process(0.0)

	EventBus.day_ended.disconnect(cb)
	assert_eq(ended_day, 3, "day_ended should fire with the current day number")


func test_day_started_signal_fires_on_advance_to_next_day() -> void:
	_time.current_day = 5

	var started_day: int = -1
	var cb: Callable = func(day: int) -> void:
		started_day = day
	EventBus.day_started.connect(cb)

	_time.advance_to_next_day()

	EventBus.day_started.disconnect(cb)
	assert_eq(
		started_day, 6,
		"day_started should fire with the new day number"
	)


func test_day_phase_changed_signal_fires_on_phase_boundary() -> void:
	_time.game_time_minutes = 530.0
	_time._last_emitted_hour = 8
	_time.current_hour = 8
	_time.current_phase = TimeSystem.DayPhase.PRE_OPEN

	var new_phase: int = -1
	var cb: Callable = func(phase: int) -> void:
		new_phase = phase
	EventBus.day_phase_changed.connect(cb)

	_time.game_time_minutes = 545.0
	_time._process(0.0)

	EventBus.day_phase_changed.disconnect(cb)
	assert_eq(
		new_phase, TimeSystem.DayPhase.MORNING_RAMP,
		"day_phase_changed should fire when crossing into MORNING_RAMP (540)"
	)


func test_day_phase_changed_does_not_fire_within_same_phase() -> void:
	_time.game_time_minutes = 550.0
	_time._last_emitted_hour = 9
	_time.current_hour = 9
	_time.current_phase = TimeSystem.DayPhase.MORNING_RAMP

	watch_signals(EventBus)
	_time.game_time_minutes = 600.0
	_time._process(0.0)

	assert_signal_not_emitted(
		EventBus, "day_phase_changed",
		"day_phase_changed should not fire when staying in same phase"
	)


func test_set_speed_changes_multiplier() -> void:
	_time.set_speed(TimeSystem.SpeedTier.FAST)
	assert_almost_eq(
		_time.speed_multiplier, 3.0, 0.01,
		"speed_multiplier should be 3.0 for FAST tier"
	)


func test_set_speed_emits_speed_changed_signal() -> void:
	_time.speed_multiplier = 1.0

	var emitted_speed: float = -1.0
	var cb: Callable = func(new_speed: float) -> void:
		emitted_speed = new_speed
	EventBus.speed_changed.connect(cb)

	_time.set_speed(TimeSystem.SpeedTier.ULTRA)

	EventBus.speed_changed.disconnect(cb)
	assert_almost_eq(
		emitted_speed, 6.0, 0.01,
		"speed_changed should emit with the new speed value (6.0 for ULTRA)"
	)


func test_set_speed_does_not_emit_when_unchanged() -> void:
	_time.set_speed(TimeSystem.SpeedTier.NORMAL)
	_time.speed_multiplier = 1.0

	watch_signals(EventBus)
	_time.set_speed(TimeSystem.SpeedTier.NORMAL)

	assert_signal_not_emitted(
		EventBus, "speed_changed",
		"speed_changed should not fire when speed is already the same"
	)


func test_paused_speed_prevents_time_advance() -> void:
	_time.game_time_minutes = 500.0
	_time._last_emitted_hour = 8
	_time.current_hour = 8
	_time.speed_multiplier = 0.0

	_time._process(10.0)

	assert_almost_eq(
		_time.game_time_minutes, 500.0, 0.01,
		"Time should not advance when speed_multiplier is 0"
	)


func test_set_speed_paused_sets_zero_multiplier() -> void:
	_time.set_speed(TimeSystem.SpeedTier.PAUSED)
	assert_almost_eq(
		_time.speed_multiplier, 0.0, 0.01,
		"PAUSED tier should set speed_multiplier to 0"
	)


func test_toggle_pause_from_normal() -> void:
	_time.set_speed(TimeSystem.SpeedTier.NORMAL)
	_time.toggle_pause()
	assert_true(_time.is_paused(), "Should be paused after toggle from NORMAL")


func test_toggle_pause_from_paused() -> void:
	_time.set_speed(TimeSystem.SpeedTier.PAUSED)
	_time.toggle_pause()
	assert_false(
		_time.is_paused(),
		"Should be unpaused after toggle from PAUSED"
	)


func test_phase_progression_through_all_phases() -> void:
	var phases_seen: Array[int] = []
	var cb: Callable = func(phase: int) -> void:
		phases_seen.append(phase)
	EventBus.day_phase_changed.connect(cb)

	_time.game_time_minutes = 419.0
	_time._last_emitted_hour = 6
	_time.current_hour = 6
	_time.current_phase = TimeSystem.DayPhase.PRE_OPEN

	var test_minutes: Array[float] = [545.0, 695.0, 845.0, 1085.0]
	for mins: float in test_minutes:
		_time.game_time_minutes = mins
		_time._process(0.0)

	EventBus.day_phase_changed.disconnect(cb)
	assert_eq(phases_seen.size(), 4, "Should have seen 4 phase transitions")
	assert_eq(
		phases_seen[0], TimeSystem.DayPhase.MORNING_RAMP,
		"First phase transition should be MORNING_RAMP"
	)
	assert_eq(
		phases_seen[1], TimeSystem.DayPhase.MIDDAY_RUSH,
		"Second phase transition should be MIDDAY_RUSH"
	)
	assert_eq(
		phases_seen[2], TimeSystem.DayPhase.AFTERNOON,
		"Third phase transition should be AFTERNOON"
	)
	assert_eq(
		phases_seen[3], TimeSystem.DayPhase.EVENING,
		"Fourth phase transition should be EVENING"
	)


func test_save_load_preserves_state() -> void:
	_time.current_day = 7
	_time.game_time_minutes = 800.0
	_time._last_emitted_hour = 13
	_time.current_hour = 13
	_time.set_speed(TimeSystem.SpeedTier.FAST)

	var save_data: Dictionary = _time.get_save_data()

	var fresh: TimeSystem = TimeSystem.new()
	add_child_autofree(fresh)
	fresh.load_save_data(save_data)

	assert_eq(fresh.current_day, 7, "Day should survive round-trip")
	assert_almost_eq(
		fresh.game_time_minutes, 800.0, 0.01,
		"game_time_minutes should survive round-trip"
	)
	assert_eq(
		fresh.current_hour, 13,
		"current_hour should survive round-trip"
	)
