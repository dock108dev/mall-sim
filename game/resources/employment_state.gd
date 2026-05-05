## Per-run employment relationship state. Owned by EmploymentSystem; written
## only by that system. Other readers should treat the fields as read-only.
##
## Trust starts at 50.0 (mid-range, well above the 15.0 firing floor) so an
## early stray complaint cannot trigger immediate dismissal on Day 1.
## manager_approval starts at 0.5 — a neutral placeholder for the first
## manager event. employment_status starts at &"active".
class_name EmploymentState
extends Resource

## Setter contract: clamp to [0,100]; emit only when the *clamped* value
## differs from the stored one. A delta that pushes against an already-saturated
## boundary is a no-op (no signal). Same contract for manager_approval.
signal trust_changed(new_trust: float)
signal manager_approval_changed(new_approval: float)


const STATUS_ACTIVE: StringName = &"active"
const STATUS_PROBATION: StringName = &"probation"
const STATUS_AT_RISK: StringName = &"at_risk"
const STATUS_FIRED: StringName = &"fired"
const STATUS_RETAINED: StringName = &"retained"

const TRUST_MIN: float = 0.0
const TRUST_MAX: float = 100.0
const APPROVAL_MIN: float = 0.0
const APPROVAL_MAX: float = 100.0

const DEFAULT_TRUST: float = 50.0
const DEFAULT_APPROVAL: float = 0.5
const DEFAULT_STATUS: StringName = STATUS_ACTIVE
const DEFAULT_HOURLY_WAGE: float = 10.0


@export var employer_store_id: StringName = &""
@export var season_number: int = 1
@export var hourly_wage: float = DEFAULT_HOURLY_WAGE
@export var hours_worked_total: float = 0.0
@export var employment_status: StringName = DEFAULT_STATUS

@export var employee_trust: float = DEFAULT_TRUST:
	set(value):
		var clamped: float = clampf(value, TRUST_MIN, TRUST_MAX)
		if is_equal_approx(clamped, employee_trust):
			return
		employee_trust = clamped
		trust_changed.emit(employee_trust)

@export var manager_approval: float = DEFAULT_APPROVAL:
	set(value):
		var clamped: float = clampf(value, APPROVAL_MIN, APPROVAL_MAX)
		if is_equal_approx(clamped, manager_approval):
			return
		manager_approval = clamped
		manager_approval_changed.emit(manager_approval)


## Resets all fields to the documented Day-1 defaults. Used by EmploymentSystem
## when a new season begins.
func reset_to_defaults(store_id: StringName = &"") -> void:
	employer_store_id = store_id
	season_number = 1
	hourly_wage = DEFAULT_HOURLY_WAGE
	hours_worked_total = 0.0
	employment_status = DEFAULT_STATUS
	employee_trust = DEFAULT_TRUST
	manager_approval = DEFAULT_APPROVAL


## Returns a JSON-safe snapshot of the persistent fields. The save payload
## is intentionally minimal per the issue spec; season_number / employer_store_id
## / hourly_wage are included so multi-session campaigns can resume mid-season.
func get_save_data() -> Dictionary:
	return {
		"employee_trust": employee_trust,
		"manager_approval": manager_approval,
		"employment_status": String(employment_status),
		"hours_worked_total": hours_worked_total,
		"employer_store_id": String(employer_store_id),
		"season_number": season_number,
		"hourly_wage": hourly_wage,
	}


## Restores values from a save payload. Missing keys fall back to the
## documented defaults (trust=50.0, approval=0.5, status=active) so
## hand-edited or legacy saves cannot leave the player below the firing floor.
func load_save_data(data: Dictionary) -> void:
	employee_trust = clampf(
		_safe_float(data, "employee_trust", DEFAULT_TRUST),
		TRUST_MIN, TRUST_MAX
	)
	manager_approval = clampf(
		_safe_float(data, "manager_approval", DEFAULT_APPROVAL),
		APPROVAL_MIN, APPROVAL_MAX
	)
	hours_worked_total = max(
		_safe_float(data, "hours_worked_total", 0.0),
		0.0
	)
	hourly_wage = max(
		_safe_float(data, "hourly_wage", DEFAULT_HOURLY_WAGE),
		0.0
	)
	season_number = max(int(data.get("season_number", 1)), 1)
	var raw_status: String = str(data.get("employment_status", String(DEFAULT_STATUS)))
	employment_status = (
		StringName(raw_status) if not raw_status.is_empty() else DEFAULT_STATUS
	)
	var raw_store: String = str(data.get("employer_store_id", ""))
	employer_store_id = StringName(raw_store)


func _safe_float(data: Dictionary, key: String, default_value: float) -> float:
	var raw: Variant = data.get(key, default_value)
	if raw is float:
		var f: float = raw as float
		if is_nan(f) or is_inf(f):
			return default_value
		return f
	if raw is int:
		return float(raw as int)
	return default_value
