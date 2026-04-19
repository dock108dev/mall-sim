## Immutable definition of a seasonal event loaded from JSON.
class_name SeasonalEventDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var name: String = ""
@export var description: String = ""
@export var start_day: int = 1
@export var store_type_multipliers: Dictionary = {}
@export var frequency_days: int = 30
@export var duration_days: int = 5
@export var offset_days: int = 0
@export var customer_traffic_multiplier: float = 1.0
@export var spending_multiplier: float = 1.0
@export var customer_type_weights: Dictionary = {}
@export var target_categories: PackedStringArray = []
@export var announcement_text: String = ""
@export var active_text: String = ""
## Store IDs that this event applies a price multiplier to.
@export var affected_stores: PackedStringArray = []
## Price multiplier applied to items in affected_stores during this event.
@export var price_multiplier: float = 1.0
## Days before event_started that event_telegraphed fires.
@export var telegraph_days: int = 3
