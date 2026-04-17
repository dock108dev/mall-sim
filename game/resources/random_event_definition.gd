## Immutable definition of a random event loaded from JSON.
class_name RandomEventDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var name: String = ""
@export var description: String = ""
@export var trigger_probability: float = 1.0
@export var effect_type: String = ""
@export var effect_target: String = ""
@export var effect_magnitude: float = 1.0
@export var duration_days: int = 1
@export var severity: String = "medium"
@export var cooldown_days: int = 10
@export var probability_weight: float = 1.0
@export var target_category: String = ""
@export var target_item_id: String = ""
@export var notification_text: String = ""
@export var resolution_text: String = ""
@export var toast_message: String = ""
@export var time_window_start: int = -1
@export var time_window_end: int = -1
@export var bulk_order_quantity: int = 3
@export var bulk_order_price_multiplier: float = 1.2
