## Immutable definition of a scheduled PocketCreatures tournament loaded from JSON.
class_name TournamentEventDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var card_category: String = ""
@export var creature_type_focus: String = ""
@export var start_day: int = 0
@export var duration_days: int = 1
@export var telegraph_days: int = 1
@export var demand_multiplier: float = 1.0
@export var price_spike_multiplier: float = 1.0
@export var traffic_multiplier: float = 1.0
@export var announcement_text: String = ""
@export var active_text: String = ""
@export var notification_day: int = -1
