## Data resource defining a store type and its properties.
class_name StoreDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var store_type: String = ""  # sports, games, video_rental, fakemon, electronics
@export var description: String = ""
@export var size_category: String = "small"  # small, medium, large
@export var starting_budget: float = 5000.0
@export var allowed_categories: PackedStringArray = []
@export var fixture_slots: int = 6
@export var max_employees: int = 2
