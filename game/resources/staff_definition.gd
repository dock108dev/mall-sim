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
const DAILY_WAGE_BY_SKILL: Dictionary = {
	1: 30.0,
	2: 60.0,
	3: 110.0,
}


const SKILL_PERFORMANCE_MULTIPLIERS: Dictionary = {
	1: 1.0,
	2: 1.5,
	3: 2.0,
}


@export var staff_id: String = ""
@export var display_name: String = ""
@export var role: StaffRole = StaffRole.CASHIER
@export var skill_level: int = 1:
	set(value):
		skill_level = clampi(value, 1, 3)
		daily_wage = wage_for_skill(skill_level)
@export var hire_cost: float = 0.0
@export var morale: float = DEFAULT_MORALE:
	set(value):
		morale = clampf(value, MIN_MORALE, MAX_MORALE)
@export var morale_decay_per_day: float = DEFAULT_MORALE_DECAY
@export var daily_wage: float = 30.0
@export var skill_bonus: float = 0.0
@export var description: String = ""
@export var seniority_days: int = 0
@export var consecutive_low_morale_days: int = 0
@export var assigned_store_id: String = ""
## Coworker opinion of the player (0.0–1.0). Drives behavioral modifiers in
## StaffNPC — opinion >0.6 accelerates restock, opinion <0.3 slows it. Default
## 0.5 seats every staff member at neutral until player actions move it.
@export var player_opinion: float = 0.5:
	set(value):
		player_opinion = clampf(value, 0.0, 1.0)

var specialization: String:
	get:
		return ROLE_SPECIALIZATION_MAP.get(role, "pricing")

var name: String:
	get:
		return display_name


## Centralizes default wage derivation while allowing loaded content to override daily_wage.
static func wage_for_skill(skill: int) -> float:
	return DAILY_WAGE_BY_SKILL.get(clampi(skill, 1, 3), 30.0) as float


## Used by role-effect systems to scale staff impact from current morale
## and skill level. Skill 1=1.0x, skill 2=1.5x, skill 3=2.0x at full morale.
func performance_multiplier() -> float:
	var skill_factor: float = SKILL_PERFORMANCE_MULTIPLIERS.get(
		clampi(skill_level, 1, 3), 1.0
	) as float
	var morale_factor: float = clampf(
		PERFORMANCE_BASE + (morale * PERFORMANCE_MORALE_WEIGHT),
		PERFORMANCE_BASE,
		1.0,
	)
	return skill_factor * morale_factor