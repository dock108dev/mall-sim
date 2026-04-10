## Immutable definition of a random event loaded from JSON.
class_name RandomEventDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var effect_type: String = ""
@export var duration_days: int = 1
@export var severity: String = "medium"
@export var cooldown_days: int = 10
@export var target_category: String = ""
@export var target_item_id: String = ""
@export var notification_text: String = ""
@export var resolution_text: String = ""
