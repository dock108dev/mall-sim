## Immutable definition of a market event loaded from JSON.
class_name MarketEventDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var event_type: String = "boom"
@export var target_tags: PackedStringArray = []
@export var target_categories: PackedStringArray = []
@export var target_store_types: PackedStringArray = []
@export var magnitude: float = 1.0
@export var duration_days: int = 5
@export var announcement_days: int = 2
@export var ramp_up_days: int = 1
@export var ramp_down_days: int = 1
@export var cooldown_days: int = 15
@export var weight: float = 1.0
@export var announcement_text: String = ""
@export var active_text: String = ""
