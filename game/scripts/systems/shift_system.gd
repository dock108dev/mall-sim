## ShiftSystem — owner of the player's clock-in / clock-out state.
##
## Tracks one shift per day. Resets on EventBus.day_started, exposes shift
## state through is_clocked_in / get_shift_summary, and arms a TimeSystem
## minute-watcher so the auto-clock-in fallback fires at 08:55 game time when
## the player has not yet manually clocked in.
##
## Phase contract:
##   * PRE_OPEN window is 07:00–09:00 (TimeSystem `_PHASE_BOUNDARIES_MINUTES`).
##   * AUTO_CLOCK_IN_MINUTE = 535 (08:55) sits inside that window — the natural
##     PRE_OPEN → MORNING_RAMP transition at 540 (09:00) is handled by
##     TimeSystem and is NOT delayed by this system. The auto-clock-in is a
##     side-effect that ensures the shift starts before the OPEN phase begins;
##     it never blocks the phase machine, so the OPEN phase always reaches
##     09:00 on schedule even when the player never touches a ClockIn node.
##
## Trust deltas (issue spec):
##   * Auto-clock-in (late) → −5 trust via EmploymentSystem
##   * Missing clock-out at day end → −2 trust via EmploymentSystem
##
## Registered as the `ShiftSystem` autoload in project.godot.
extends Node


const AUTO_CLOCK_IN_MINUTE: float = 535.0  # 08:55 — 5 minutes before MALL_OPEN
const _PRE_OPEN_PHASE: int = 0  # TimeSystem.DayPhase.PRE_OPEN ordinal

const TRUST_DELTA_LATE_CLOCK_IN: float = -5.0
const TRUST_DELTA_MISSING_CLOCK_OUT: float = -2.0
const REASON_LATE_CLOCK_IN: String = "late_clock_in"
const REASON_MISSING_CLOCK_OUT: String = "missing_clock_out"

const DAY_OBJECTIVE_BANNER_DURATION: float = 4.0
const DAY_OBJECTIVE_BANNER_CATEGORY: StringName = &"objective"


var is_clocked_in: bool = false
var shift_start_time: float = -1.0
var shift_end_time: float = -1.0
var was_late: bool = false

var _auto_clock_in_fired: bool = false
var _store_id: StringName = &""
var _watching_for_auto: bool = false


func _ready() -> void:
	_connect_event_bus()
	# Force per-frame polling for the auto-clock-in fallback. The check is
	# cheap (single min comparison + an early-out flag) so polling is safe.
	set_process(true)


func _process(_delta: float) -> void:
	if not _watching_for_auto:
		return
	if _auto_clock_in_fired or is_clocked_in:
		return
	var time_system: TimeSystem = GameManager.get_time_system()
	if time_system == null:
		return
	if time_system.game_time_minutes >= AUTO_CLOCK_IN_MINUTE:
		auto_clock_in()


# ── Public API ────────────────────────────────────────────────────────────────

## Player-driven clock-in. Records the current TimeSystem minute, emits
## shift_started(store_id, timestamp, late=false), shows the day-objective
## banner, and arms the morning-note signal so ISSUE-005 listeners can render
## the manager memo. Idempotent — calling twice in a single day is a no-op.
func clock_in() -> void:
	if is_clocked_in:
		return
	var minute: float = _current_minute()
	var late: bool = minute >= AUTO_CLOCK_IN_MINUTE
	_record_shift_start(minute, late)
	_emit_shift_started()
	_show_day_objective_banner()
	_request_morning_note()


## Auto-fallback clock-in. Fires at 08:55 when the player has not manually
## clocked in. Marks the shift as late (regardless of actual minute), applies
## the −5 trust penalty, queues the manager warning note, and emits
## shift_started(late=true). Idempotent.
func auto_clock_in() -> void:
	if is_clocked_in or _auto_clock_in_fired:
		return
	_auto_clock_in_fired = true
	var minute: float = _current_minute()
	_record_shift_start(minute, true)
	_apply_trust_delta(TRUST_DELTA_LATE_CLOCK_IN, REASON_LATE_CLOCK_IN)
	_emit_warning_note(REASON_LATE_CLOCK_IN)
	_emit_shift_started()
	_show_day_objective_banner()


## Player-driven clock-out. Records the current TimeSystem minute and emits
## shift_ended(store_id, hours_worked). Idempotent — calling without an active
## shift is a no-op.
func clock_out() -> void:
	if not is_clocked_in:
		return
	var minute: float = _current_minute()
	is_clocked_in = false
	shift_end_time = minute
	var hours: float = get_hours_worked()
	EventBus.shift_ended.emit(_store_id, hours)


## Returns a JSON-safe snapshot of the shift state for the day-close payload.
func get_shift_summary() -> Dictionary:
	return {
		"clocked_in": is_clocked_in,
		"shift_start_time": shift_start_time,
		"shift_end_time": shift_end_time,
		"hours_worked": get_hours_worked(),
		"was_late": was_late,
		"clocked_out": shift_end_time >= 0.0,
		"store_id": String(_store_id),
	}


## Returns the hours worked during the current (or completed) shift.
## Returns 0.0 when no shift was started; uses the current minute when the
## shift is still in progress.
func get_hours_worked() -> float:
	if shift_start_time < 0.0:
		return 0.0
	var end_minute: float = shift_end_time
	if end_minute < 0.0:
		end_minute = _current_minute()
	if end_minute < shift_start_time:
		return 0.0
	return (end_minute - shift_start_time) / 60.0


# ── Internals ─────────────────────────────────────────────────────────────────

func _connect_event_bus() -> void:
	_connect_signal(EventBus.day_started, _on_day_started)
	_connect_signal(EventBus.day_ended, _on_day_ended)
	_connect_signal(EventBus.active_store_changed, _on_active_store_changed)


func _connect_signal(signal_ref: Signal, callable: Callable) -> void:
	if not signal_ref.is_connected(callable):
		signal_ref.connect(callable)


func _on_day_started(_day: int) -> void:
	_reset_for_new_day()


func _on_day_ended(_day: int) -> void:
	_watching_for_auto = false
	if is_clocked_in:
		# Player started a shift but never clocked out. Apply the missing-
		# clock-out penalty and emit shift_ended so downstream readers see a
		# consistent terminal event.
		_apply_trust_delta(
			TRUST_DELTA_MISSING_CLOCK_OUT, REASON_MISSING_CLOCK_OUT
		)
		_emit_warning_note(REASON_MISSING_CLOCK_OUT)
		var minute: float = _current_minute()
		is_clocked_in = false
		shift_end_time = minute
		EventBus.shift_ended.emit(_store_id, get_hours_worked())


func _on_active_store_changed(store_id: StringName) -> void:
	_store_id = store_id


func _reset_for_new_day() -> void:
	is_clocked_in = false
	shift_start_time = -1.0
	shift_end_time = -1.0
	was_late = false
	_auto_clock_in_fired = false
	_watching_for_auto = true
	if _store_id == &"":
		_store_id = GameState.active_store_id


func _record_shift_start(minute: float, late: bool) -> void:
	is_clocked_in = true
	shift_start_time = minute
	shift_end_time = -1.0
	was_late = late


func _emit_shift_started() -> void:
	if _store_id == &"":
		_store_id = GameState.active_store_id
	EventBus.shift_started.emit(_store_id, shift_start_time, was_late)


func _show_day_objective_banner() -> void:
	var text: String = _resolve_day_objective_text()
	if text.is_empty():
		return
	EventBus.toast_requested.emit(
		text, DAY_OBJECTIVE_BANNER_CATEGORY, DAY_OBJECTIVE_BANNER_DURATION
	)


func _resolve_day_objective_text() -> String:
	# day_beats.json carries narrative beats per day; the loader keeps the raw
	# data in DataLoader's day-beats catalog. Fall back to a generic objective
	# string when the catalog is unavailable (test fixtures or a missing entry)
	# so the banner always has something to render after clock-in.
	var data_loader: DataLoader = GameManager.data_loader
	var time_system: TimeSystem = GameManager.get_time_system()
	var day: int = 1
	if time_system != null:
		day = time_system.current_day
	if data_loader != null and data_loader.has_method("get_day_beat"):
		var beat: Variant = data_loader.call("get_day_beat", day)
		if beat is Dictionary:
			var dict: Dictionary = beat as Dictionary
			var objective: String = str(dict.get("objective", ""))
			if not objective.is_empty():
				return objective
	return "Day %d: open the store and serve customers." % day


func _request_morning_note() -> void:
	# ISSUE-005 will own the manager note panel; until then this is a forward
	# signal so the panel can wire up at request time without a code change to
	# this system.
	EventBus.manager_warning_note_requested.emit("clock_in_morning")


func _emit_warning_note(reason: String) -> void:
	EventBus.manager_warning_note_requested.emit(reason)


func _apply_trust_delta(delta: float, reason: String) -> void:
	var employment: Node = get_node_or_null("/root/EmploymentSystem")
	# §F-121 — EmploymentSystem is an autoload (project.godot:54). A missing
	# node or wrong type is a configuration regression, not a runtime state;
	# escalate so the late-clock-in / missing-clock-out trust penalties
	# can't silently disappear in shipping.
	if employment == null:
		push_error(
			"ShiftSystem: EmploymentSystem autoload missing — trust delta '%s' dropped"
			% reason
		)
		return
	if not employment.has_method("apply_trust_delta"):
		push_error(
			"ShiftSystem: EmploymentSystem missing apply_trust_delta — trust delta '%s' dropped"
			% reason
		)
		return
	# Not-employed is a legit run-time state (player hasn't started the
	# season yet), so this branch stays silent.
	if not employment.call("is_employed"):
		return
	employment.call("apply_trust_delta", delta, reason)


func _current_minute() -> float:
	var time_system: TimeSystem = GameManager.get_time_system()
	if time_system == null:
		return AUTO_CLOCK_IN_MINUTE
	return time_system.game_time_minutes


# ── Test seam ────────────────────────────────────────────────────────────────

## Resets all in-memory state. Used by tests to run each case from a clean slate.
func _reset_for_testing() -> void:
	is_clocked_in = false
	shift_start_time = -1.0
	shift_end_time = -1.0
	was_late = false
	_auto_clock_in_fired = false
	_watching_for_auto = false
	_store_id = &""
