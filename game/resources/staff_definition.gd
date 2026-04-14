## Persistent state for a single staff member — consumed by StaffManager and UI.
class_name StaffDefinition
extends Resource

enum StaffRole { CASHIER, STOCKER, GREETER }

const ROLE_SPECIALIZATION_MAP: Dictionary = {
	StaffRole.CASHIER: "pricing",
	StaffRole.STOCKER: "stocking",
	StaffRole.GREETER: "customer_service",
}

const DEFAULT_MORALE: float = 0.65
const DEFAULT_MORALE_DECAY: float = 0.02
const MIN_MORALE: float = 0.0
const MAX_MORALE: float = 1.0
const PERFORMANCE_BASE: float = 0.6
const PERFORMANCE_MORALE_WEIGHT: float = 0.4

@export var staff_id: String = ""
@export var display_name: String = ""
@export var role: StaffRole = StaffRole.CASHIER
@export var skill_level: int = 1:
	set(value):
		skill_level = clampi(value, 1, 3)
@export var hire_cost: float = 0.0
@export var morale: float = DEFAULT_MORALE:
	set(value):
		morale = clampf(value, MIN_MORALE, MAX_MORALE)
@export var morale_decay_per_day: float = DEFAULT_MORALE_DECAY
@export var daily_wage: float = 20.0
@export var skill_bonus: float = 0.0
@export var description: String = ""
@export var seniority_days: int = 0
@export var consecutive_low_morale_days: int = 0
@export var assigned_store_id: String = ""

var specialization: String:
	get:
		return ROLE_SPECIALIZATION_MAP.get(role, "pricing")

var name: String:
	get:
		return display_name


## Returns performance multiplier: 0.6 + (morale * 0.4), clamped [0.6, 1.0].
func performance_multiplier() -> float:
	return clampf(
		PERFORMANCE_BASE + (morale * PERFORMANCE_MORALE_WEIGHT),
		PERFORMANCE_BASE,
		1.0,
	)
