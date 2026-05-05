## Per-session runtime state for a single platform. Owned by PlatformSystem;
## mutated only by the daily tick / restock helpers there. Other systems should
## treat the fields as read-only.
##
## Stored as a Resource so it can be inspected in saves and tests; a plain
## RefCounted would also work but Resource is the codebase convention for
## state objects (see EmploymentState).
class_name PlatformInventoryState
extends Resource


@export var platform: PlatformDefinition = null
@export var units_in_stock: int = 0
@export var hype_level: float = 0.0
@export var shortage_days: int = 0
@export var current_sell_price: float = 0.0
## True after the most recent shortage/recovery transition, used by PlatformSystem
## to fire shortage_started / shortage_ended exactly on the boundary.
@export var in_shortage: bool = false
@export var total_units_sold: int = 0
@export var total_revenue: float = 0.0


## Resets the runtime state to "fresh launch" defaults derived from the
## definition. Used by PlatformSystem.initialize and tests.
func reset_to_defaults(definition: PlatformDefinition) -> void:
	platform = definition
	units_in_stock = definition.initial_stock if definition != null else 0
	hype_level = 0.0
	shortage_days = 0
	in_shortage = false
	total_units_sold = 0
	total_revenue = 0.0
	current_sell_price = (
		definition.base_price if definition != null else 0.0
	)
