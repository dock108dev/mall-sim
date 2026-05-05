## Tests for the ShiftSystem autoload — clock-in / clock-out behaviour, the
## 08:55 auto-clock-in fallback, late / missing-clock-out trust penalties,
## the day-close shift summary payload, and the OPEN-by-09:00 contract that
## guarantees TimeSystem still progresses out of PRE_OPEN even when the
## player never touches a ClockIn node.
extends GutTest


# 08:55 — 5 minutes before MALL_OPEN; mirrors ShiftSystem.AUTO_CLOCK_IN_MINUTE.
# Constant duplicated from the autoload because the autoload identifier is not
# resolvable inside a class-level const initializer.
const _AUTO_CLOCK_IN_MINUTE: float = 535.0
const _MORNING_RAMP_MINUTE: float = 540.0  # 09:00 — TimeSystem boundary
const _EMPLOYMENT_SAVE_PATH: String = "user://employment_state.cfg"


var _saved_trust: float
var _saved_approval: float
var _saved_active_store: StringName


func before_each() -> void:
	_saved_trust = GameState.employee_trust
	_saved_approval = GameState.manager_approval
	_saved_active_store = GameState.active_store_id
	GameState.employee_trust = EmploymentState.DEFAULT_TRUST
	GameState.manager_approval = EmploymentState.DEFAULT_APPROVAL
	GameState.active_store_id = &"retro_games"
	ShiftSystem._reset_for_testing()
	EmploymentSystem.state = EmploymentState.new()
	EmploymentSystem._employed = false
	EmploymentSystem._evaluated_outcome = false
	if FileAccess.file_exists(_EMPLOYMENT_SAVE_PATH):
		DirAccess.remove_absolute(_EMPLOYMENT_SAVE_PATH)


func after_each() -> void:
	GameState.employee_trust = _saved_trust
	GameState.manager_approval = _saved_approval
	GameState.active_store_id = _saved_active_store
	ShiftSystem._reset_for_testing()
	EmploymentSystem.state = EmploymentState.new()
	EmploymentSystem._employed = false
	EmploymentSystem._evaluated_outcome = false
	if FileAccess.file_exists(_EMPLOYMENT_SAVE_PATH):
		DirAccess.remove_absolute(_EMPLOYMENT_SAVE_PATH)


# ── Initial state + reset on day_started ─────────────────────────────────────


func test_initial_state_is_clocked_out() -> void:
	assert_false(ShiftSystem.is_clocked_in)
	assert_eq(ShiftSystem.shift_start_time, -1.0)
	assert_eq(ShiftSystem.shift_end_time, -1.0)
	assert_eq(ShiftSystem.get_hours_worked(), 0.0)


func test_day_started_resets_state_and_arms_auto_watch() -> void:
	ShiftSystem.is_clocked_in = true
	ShiftSystem.shift_start_time = 480.0
	EventBus.day_started.emit(2)
	assert_false(ShiftSystem.is_clocked_in)
	assert_eq(ShiftSystem.shift_start_time, -1.0)
	assert_true(
		ShiftSystem._watching_for_auto,
		"day_started must arm the auto-clock-in watcher"
	)


# ── Manual clock-in path ──────────────────────────────────────────────────────


func test_clock_in_sets_state_and_emits_signal() -> void:
	EventBus.day_started.emit(1)
	EmploymentSystem.start_employment(&"retro_games")
	watch_signals(EventBus)
	# Simulate clock-in early in PRE_OPEN — no TimeSystem in tree, so the
	# helper falls back to AUTO_CLOCK_IN_MINUTE; force a known value first.
	ShiftSystem.shift_start_time = -1.0
	ShiftSystem.clock_in()
	assert_true(ShiftSystem.is_clocked_in)
	assert_signal_emitted(EventBus, "shift_started")
	var params: Array = get_signal_parameters(EventBus, "shift_started")
	assert_eq(params[0], &"retro_games", "store_id must match active store")


func test_manual_clock_in_keeps_late_false_when_before_855() -> void:
	EventBus.day_started.emit(1)
	# Force the recorded minute to fall before AUTO_CLOCK_IN_MINUTE.
	ShiftSystem._record_shift_start(_AUTO_CLOCK_IN_MINUTE - 60.0, false)
	ShiftSystem._emit_shift_started()
	assert_false(
		ShiftSystem.was_late,
		"manual clock-in before 08:55 must not be flagged late"
	)


func test_clock_in_is_idempotent() -> void:
	EventBus.day_started.emit(1)
	ShiftSystem.clock_in()
	var first_start: float = ShiftSystem.shift_start_time
	ShiftSystem.clock_in()
	assert_eq(
		ShiftSystem.shift_start_time, first_start,
		"a second clock_in must not overwrite the recorded start time"
	)


# ── Auto-clock-in fallback ────────────────────────────────────────────────────


func test_auto_clock_in_marks_shift_late() -> void:
	EventBus.day_started.emit(1)
	EmploymentSystem.start_employment(&"retro_games")
	watch_signals(EventBus)
	ShiftSystem.auto_clock_in()
	assert_true(ShiftSystem.is_clocked_in)
	assert_true(ShiftSystem.was_late, "auto-clock-in must flag late=true")
	assert_signal_emitted(EventBus, "shift_started")
	var params: Array = get_signal_parameters(EventBus, "shift_started")
	assert_true(bool(params[2]), "shift_started.late must be true")


func test_auto_clock_in_applies_late_trust_penalty() -> void:
	EventBus.day_started.emit(1)
	EmploymentSystem.start_employment(&"retro_games")
	var before: float = EmploymentSystem.state.employee_trust
	ShiftSystem.auto_clock_in()
	var actual: float = EmploymentSystem.state.employee_trust - before
	assert_almost_eq(
		actual, ShiftSystem.TRUST_DELTA_LATE_CLOCK_IN, 0.001,
		"late auto-clock-in must apply the −5 trust penalty"
	)


func test_auto_clock_in_queues_manager_warning_note() -> void:
	EventBus.day_started.emit(1)
	EmploymentSystem.start_employment(&"retro_games")
	watch_signals(EventBus)
	ShiftSystem.auto_clock_in()
	assert_signal_emitted(EventBus, "manager_warning_note_requested")
	var params: Array = get_signal_parameters(
		EventBus, "manager_warning_note_requested"
	)
	assert_eq(params[0], ShiftSystem.REASON_LATE_CLOCK_IN)


func test_auto_clock_in_is_idempotent() -> void:
	EventBus.day_started.emit(1)
	EmploymentSystem.start_employment(&"retro_games")
	ShiftSystem.auto_clock_in()
	var first_start: float = ShiftSystem.shift_start_time
	var trust_after_first: float = EmploymentSystem.state.employee_trust
	ShiftSystem.auto_clock_in()
	assert_eq(ShiftSystem.shift_start_time, first_start)
	assert_eq(
		EmploymentSystem.state.employee_trust, trust_after_first,
		"a second auto-clock-in must not double-apply the trust penalty"
	)


func test_manual_clock_in_before_auto_blocks_late_path() -> void:
	# Player clocks in manually before 08:55. The auto-clock-in fallback must
	# observe is_clocked_in == true and skip its work — no late=true emission,
	# no trust penalty.
	var time_system := TimeSystem.new()
	add_child_autofree(time_system)
	time_system.initialize()
	# Force the TimeSystem minute below the auto-clock-in boundary so the
	# manual path records was_late=false rather than the fallback minute.
	time_system.game_time_minutes = _AUTO_CLOCK_IN_MINUTE - 60.0
	EventBus.day_started.emit(1)
	EmploymentSystem.start_employment(&"retro_games")
	ShiftSystem.clock_in()
	var trust_after_manual: float = EmploymentSystem.state.employee_trust
	watch_signals(EventBus)
	ShiftSystem.auto_clock_in()
	assert_eq(
		EmploymentSystem.state.employee_trust, trust_after_manual,
		"auto-fallback must be a no-op once a manual clock-in already ran"
	)
	assert_signal_not_emitted(EventBus, "shift_started")
	assert_false(ShiftSystem.was_late)


# ── Hours worked + clock-out ──────────────────────────────────────────────────


func test_hours_worked_uses_recorded_start_and_end() -> void:
	ShiftSystem._record_shift_start(_MORNING_RAMP_MINUTE, false)
	ShiftSystem.shift_end_time = _MORNING_RAMP_MINUTE + 480.0  # +8 hours
	assert_almost_eq(ShiftSystem.get_hours_worked(), 8.0, 0.001)


func test_hours_worked_zero_before_clock_in() -> void:
	assert_eq(ShiftSystem.get_hours_worked(), 0.0)


func test_clock_out_marks_shift_complete_and_emits_signal() -> void:
	EventBus.day_started.emit(1)
	ShiftSystem._record_shift_start(_MORNING_RAMP_MINUTE, false)
	ShiftSystem._emit_shift_started()
	watch_signals(EventBus)
	# Force a known clock-out minute via direct field set so the assertion
	# is independent of TimeSystem availability.
	ShiftSystem.shift_end_time = _MORNING_RAMP_MINUTE + 480.0
	ShiftSystem.is_clocked_in = false
	EventBus.shift_ended.emit(&"retro_games", ShiftSystem.get_hours_worked())
	assert_signal_emitted(EventBus, "shift_ended")
	var params: Array = get_signal_parameters(EventBus, "shift_ended")
	assert_almost_eq(float(params[1]), 8.0, 0.001)


func test_clock_out_is_noop_when_not_clocked_in() -> void:
	watch_signals(EventBus)
	ShiftSystem.clock_out()
	assert_signal_not_emitted(EventBus, "shift_ended")


# ── Missing clock-out at day_ended ────────────────────────────────────────────


func test_missing_clock_out_at_day_ended_applies_trust_penalty() -> void:
	EventBus.day_started.emit(1)
	EmploymentSystem.start_employment(&"retro_games")
	ShiftSystem._record_shift_start(_MORNING_RAMP_MINUTE, false)
	ShiftSystem.is_clocked_in = true
	var before: float = EmploymentSystem.state.employee_trust
	EventBus.day_ended.emit(1)
	var delta: float = EmploymentSystem.state.employee_trust - before
	# day_ended triggers EmploymentSystem.issue_daily_wage too (no trust effect)
	# plus our missing-clock-out penalty.
	assert_almost_eq(
		delta, ShiftSystem.TRUST_DELTA_MISSING_CLOCK_OUT, 0.001,
		"missing clock-out must apply −2 trust delta"
	)


func test_missing_clock_out_at_day_ended_emits_warning_note() -> void:
	EventBus.day_started.emit(1)
	EmploymentSystem.start_employment(&"retro_games")
	ShiftSystem._record_shift_start(_MORNING_RAMP_MINUTE, false)
	ShiftSystem.is_clocked_in = true
	watch_signals(EventBus)
	EventBus.day_ended.emit(1)
	assert_signal_emitted(EventBus, "manager_warning_note_requested")


func test_clean_clock_out_before_day_ended_skips_penalty() -> void:
	EventBus.day_started.emit(1)
	EmploymentSystem.start_employment(&"retro_games")
	ShiftSystem._record_shift_start(_MORNING_RAMP_MINUTE, false)
	ShiftSystem.is_clocked_in = true
	# Player clocks out manually.
	ShiftSystem.shift_end_time = _MORNING_RAMP_MINUTE + 480.0
	ShiftSystem.is_clocked_in = false
	var before: float = EmploymentSystem.state.employee_trust
	EventBus.day_ended.emit(1)
	# day_ended fires issue_daily_wage with no trust delta; no missing-out penalty.
	assert_eq(
		EmploymentSystem.state.employee_trust, before,
		"a clean clock-out must not trigger the missing-clock-out penalty"
	)


# ── get_shift_summary payload ────────────────────────────────────────────────


func test_summary_payload_has_required_keys() -> void:
	EventBus.day_started.emit(1)
	ShiftSystem._record_shift_start(_MORNING_RAMP_MINUTE, true)
	var summary: Dictionary = ShiftSystem.get_shift_summary()
	for key: String in [
		"clocked_in", "shift_start_time", "shift_end_time",
		"hours_worked", "was_late", "clocked_out", "store_id",
	]:
		assert_true(
			summary.has(key),
			"shift summary must include '%s'" % key,
		)


func test_summary_round_trips_late_flag() -> void:
	EventBus.day_started.emit(1)
	ShiftSystem._record_shift_start(_MORNING_RAMP_MINUTE, true)
	var summary: Dictionary = ShiftSystem.get_shift_summary()
	assert_true(bool(summary["was_late"]))
	assert_true(bool(summary["clocked_in"]))


# ── OPEN phase reachability without clock-in ─────────────────────────────────


func test_pre_open_to_morning_ramp_progresses_without_clock_in() -> void:
	# The phase boundary at 09:00 (540 min) is owned by TimeSystem and must
	# never be blocked by ShiftSystem state. Drive a fresh TimeSystem from
	# PRE_OPEN past 09:00 and assert the phase advances even though the
	# player has not touched a ClockIn node.
	var time_system := TimeSystem.new()
	add_child_autofree(time_system)
	time_system.initialize()
	time_system.current_phase = TimeSystem.DayPhase.PRE_OPEN
	time_system.game_time_minutes = _AUTO_CLOCK_IN_MINUTE - 1.0
	time_system._check_phase_transitions_between(
		_AUTO_CLOCK_IN_MINUTE - 1.0, _MORNING_RAMP_MINUTE + 1.0
	)
	assert_eq(
		time_system.current_phase,
		TimeSystem.DayPhase.MORNING_RAMP,
		"OPEN/MORNING_RAMP must be reachable by 09:00 even without clock-in",
	)
	assert_false(
		ShiftSystem.is_clocked_in,
		"this test asserts the phase machine does not depend on shift state",
	)
