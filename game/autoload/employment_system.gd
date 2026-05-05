## EmploymentSystem — owner of the seasonal-employee state.
##
## Single source of truth for the player's employment relationship. Issues
## daily wages at shift end, accumulates trust deltas via EventBus listeners,
## and evaluates firing/retention at season end.
##
## Responsibilities:
##   - Hold the EmploymentState resource for the active run.
##   - Mirror trust / approval into GameState so HUD and ProgressionSystem can
##     read through the existing GameState contract.
##   - Issue wages at EventBus.day_ended via EconomySystem.credit_wage.
##   - Persist trust / approval / status / hours_worked_total to user://
##     across sessions (loaded at EventBus.day_started).
##   - Evaluate firing/retention at SEASON_LENGTH_DAYS or when trust drops
##     below the firing floor.
extends Node


const SAVE_PATH: String = "user://employment_state.cfg"
const SAVE_SECTION: String = "employment"
# §F-127 — size cap on the persisted ConfigFile. The file is hand-editable
# (it lives under user://); without a cap a malicious or corrupted multi-MB
# file would be loaded into memory and parsed at every day_started. The 64 KiB
# ceiling is well above the actual payload (≈10 string/float keys) and matches
# the same defense-in-depth posture as `Settings.MAX_SETTINGS_FILE_BYTES`.
const MAX_EMPLOYMENT_FILE_BYTES: int = 65536

const SEASON_LENGTH_DAYS: int = 30
const FIRING_FLOOR: float = 15.0
const RETENTION_THRESHOLD: float = 60.0

## Per-event trust deltas (issue spec):
##   +1.5 / satisfied customer
##   −2.0 / complaint
##   +3.0 / task completed
##   −5.0 / manager confrontation
const TRUST_DELTA_SATISFIED_CUSTOMER: float = 1.5
const TRUST_DELTA_COMPLAINT: float = -2.0
const TRUST_DELTA_TASK_COMPLETED: float = 3.0
const TRUST_DELTA_MANAGER_CONFRONTATION: float = -5.0

const REASON_SATISFIED_CUSTOMER: String = "satisfied_customer"
const REASON_COMPLAINT: String = "complaint"
const REASON_TASK_COMPLETED: String = "task_completed"
const REASON_MANAGER_CONFRONTATION: String = "manager_confrontation"
const REASON_DAILY_WAGE: String = "Daily wage"

const HOURS_PER_SHIFT: float = 8.0


var state: EmploymentState
var _employed: bool = false
var _evaluated_outcome: bool = false


func _ready() -> void:
	state = EmploymentState.new()
	_connect_event_bus()


## Begins a new employment relationship. Resets state to documented Day-1
## defaults (trust=50.0, approval=0.5, status=active), seeds GameState mirrors,
## and emits employment_started. Idempotent — calling twice without an
## intervening end_employment is a no-op.
func start_employment(
	store_id: StringName = &"",
	hourly_wage: float = EmploymentState.DEFAULT_HOURLY_WAGE,
) -> void:
	if _employed:
		return
	state.reset_to_defaults(store_id)
	state.hourly_wage = max(hourly_wage, 0.0)
	_employed = true
	_evaluated_outcome = false
	_mirror_to_game_state()
	EventBus.employment_started.emit(store_id, state.season_number)


## Ends the current employment relationship with the given outcome status.
## Emits employment_ended(outcome) so UI and ProgressionSystem can reach a
## terminal screen. Safe to call when no employment is active.
func end_employment(outcome: StringName = EmploymentState.STATUS_FIRED) -> void:
	if not _employed and state.employment_status == outcome:
		return
	state.employment_status = outcome
	_employed = false
	EventBus.employment_ended.emit(outcome)


## Public mutator for trust deltas. Use for cases that don't have a dedicated
## EventBus listener (e.g. complaint and manager-confrontation events whose
## upstream signals are not yet wired). Clamps to [0,100] and emits
## EventBus.trust_changed only when the post-clamp value moved.
func apply_trust_delta(delta: float, reason: String) -> void:
	if is_zero_approx(delta):
		return
	var before: float = state.employee_trust
	state.employee_trust = before + delta
	var actual_delta: float = state.employee_trust - before
	if is_zero_approx(actual_delta):
		return
	GameState.employee_trust = state.employee_trust
	EventBus.trust_changed.emit(actual_delta, reason)


## Public mutator for manager_approval deltas. Same clamp / no-op-on-saturation
## contract as apply_trust_delta.
func apply_manager_approval_delta(delta: float, reason: String) -> void:
	if is_zero_approx(delta):
		return
	var before: float = state.manager_approval
	state.manager_approval = before + delta
	var actual_delta: float = state.manager_approval - before
	if is_zero_approx(actual_delta):
		return
	GameState.manager_approval = state.manager_approval
	EventBus.manager_approval_changed.emit(actual_delta, reason)


## Returns the active EmploymentState for read-only access. Callers must not
## mutate fields directly; use apply_trust_delta / apply_manager_approval_delta.
func get_state() -> EmploymentState:
	return state


func is_employed() -> bool:
	return _employed


## Records that the employer has assigned a new task to the player. Emits
## EventBus.task_assigned so UI / objective rail can render the task; the
## resolution side fires task_completed (which feeds the +3.0 trust delta).
func assign_task(task_id: StringName) -> void:
	if task_id == &"":
		return
	EventBus.task_assigned.emit(task_id)


## Records that the player completed an assigned task. Emits
## EventBus.task_completed so this system (and ProgressionSystem) can apply
## the trust delta. Convenience wrapper for callers that don't want to touch
## EventBus directly.
func complete_task(task_id: StringName) -> void:
	if task_id == &"":
		return
	EventBus.task_completed.emit(task_id)


## Issues the player's wage for the day's worked shift. Idempotent — multiple
## calls within a single day will each pay; callers should gate on day_ended.
func issue_daily_wage() -> void:
	var amount: float = state.hourly_wage * HOURS_PER_SHIFT
	state.hours_worked_total += HOURS_PER_SHIFT
	if amount <= 0.0:
		return
	var economy: EconomySystem = GameManager.get_economy_system()
	if economy != null:
		economy.credit_wage(amount, REASON_DAILY_WAGE)
	else:
		EventBus.wage_issued.emit(amount)


# ── Internals ────────────────────────────────────────────────────────────────

func _connect_event_bus() -> void:
	_connect_signal(EventBus.customer_purchased, _on_customer_purchased)
	_connect_signal(EventBus.task_completed, _on_task_completed)
	_connect_signal(EventBus.day_started, _on_day_started)
	_connect_signal(EventBus.day_ended, _on_day_ended)


func _connect_signal(signal_ref: Signal, callable: Callable) -> void:
	if not signal_ref.is_connected(callable):
		signal_ref.connect(callable)


func _on_customer_purchased(
	_store_id: StringName,
	_item_id: StringName,
	_price: float,
	_customer_id: StringName,
) -> void:
	if not _employed:
		return
	apply_trust_delta(TRUST_DELTA_SATISFIED_CUSTOMER, REASON_SATISFIED_CUSTOMER)


func _on_task_completed(_task_id: StringName) -> void:
	if not _employed:
		return
	apply_trust_delta(TRUST_DELTA_TASK_COMPLETED, REASON_TASK_COMPLETED)


func _on_day_started(_day: int) -> void:
	_load_persisted_state()
	if _employed:
		_mirror_to_game_state()


func _on_day_ended(day: int) -> void:
	if _employed:
		issue_daily_wage()
	_persist_state()
	if _employed:
		_evaluate_outcome(day)


func _evaluate_outcome(day: int) -> void:
	if _evaluated_outcome:
		return
	if state.employee_trust < FIRING_FLOOR:
		_evaluated_outcome = true
		end_employment(EmploymentState.STATUS_FIRED)
		return
	if day < SEASON_LENGTH_DAYS:
		return
	_evaluated_outcome = true
	if state.employee_trust >= RETENTION_THRESHOLD:
		end_employment(EmploymentState.STATUS_RETAINED)
	else:
		end_employment(EmploymentState.STATUS_FIRED)


func _mirror_to_game_state() -> void:
	GameState.employee_trust = state.employee_trust
	GameState.manager_approval = state.manager_approval


# ── Persistence ──────────────────────────────────────────────────────────────

func _persist_state() -> void:
	var config: ConfigFile = ConfigFile.new()
	# Read-modify-write so we don't clobber unrelated user-config sections that
	# may share the file in the future. §F-127 — skip the read step when the
	# on-disk file is oversize, otherwise this path re-parses the malicious
	# payload _load_persisted_state already rejected before writing it back.
	if FileAccess.file_exists(SAVE_PATH):
		var probe: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if probe != null:
			var size: int = probe.get_length()
			probe.close()
			if size <= MAX_EMPLOYMENT_FILE_BYTES:
				config.load(SAVE_PATH)
	for key: String in state.get_save_data():
		config.set_value(SAVE_SECTION, key, state.get_save_data()[key])
	config.set_value(SAVE_SECTION, "employed", _employed)
	var err: int = config.save(SAVE_PATH)
	if err != OK:
		# §F-117 — wage / trust persistence is data integrity. Silent loss
		# means the next session resumes with a stale or default state, so
		# escalate to push_error rather than warning the player into
		# nothing.
		push_error(
			"EmploymentSystem: failed to persist state to %s (err=%d, %s)"
			% [SAVE_PATH, err, error_string(err)]
		)


func _load_persisted_state() -> void:
	# §F-127 — size-probe before parse. ConfigFile.load reads the entire file
	# into memory; an oversize hand-edited cfg would exhaust memory at
	# day_started before we can reject it. Treat oversize as "absent" — the
	# next _persist_state replaces it with a fresh, capped payload.
	if FileAccess.file_exists(SAVE_PATH):
		var probe: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if probe != null:
			var size: int = probe.get_length()
			probe.close()
			if size > MAX_EMPLOYMENT_FILE_BYTES:
				push_warning(
					"EmploymentSystem: '%s' exceeds maximum supported size (%d bytes) — using defaults"
					% [SAVE_PATH, MAX_EMPLOYMENT_FILE_BYTES]
				)
				return
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SAVE_PATH)
	# §F-118 — first-run / cleared-storage paths return ERR_FILE_NOT_FOUND or
	# ERR_FILE_CANT_OPEN; those are legit "no prior state" cases. Other
	# error codes indicate corruption and must surface so we don't silently
	# overwrite the file on the next _persist_state.
	if err == ERR_FILE_NOT_FOUND or err == ERR_FILE_CANT_OPEN:
		return
	if err != OK:
		push_error(
			"EmploymentSystem: failed to load persisted state from %s (err=%d, %s)"
			% [SAVE_PATH, err, error_string(err)]
		)
		return
	if not config.has_section(SAVE_SECTION):
		return
	var data: Dictionary = {}
	for key: String in config.get_section_keys(SAVE_SECTION):
		data[key] = config.get_value(SAVE_SECTION, key)
	state.load_save_data(data)
	if data.has("employed"):
		_employed = bool(data.get("employed", false))


## Test seam — clears the persisted file so deterministic tests can run.
func clear_persistent_storage() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
