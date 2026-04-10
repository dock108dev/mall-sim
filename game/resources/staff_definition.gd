## Immutable template for a staff archetype loaded from JSON.
class_name StaffDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var daily_wage: float = 20.0
@export var skill_level: int = 1
@export var specialization: String = "stocking"
@export var description: String = ""
