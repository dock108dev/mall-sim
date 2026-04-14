## Data resource defining a store type and its properties.
class_name StoreDefinition
extends Resource

@export var id: String = ""
@export var store_name: String = ""
@export var store_type: String = ""
@export var description: String = ""
@export var scene_path: String = ""
@export var size_category: String = "small"
@export var starting_budget: float = 5000.0
@export var allowed_categories: PackedStringArray = []
@export var fixture_slots: int = 6
@export var max_employees: int = 2
@export var shelf_capacity: int = 0
@export var backroom_capacity: int = 0
@export var starting_cash: float = 0.0
@export var daily_rent: float = 0.0
@export var starting_inventory: PackedStringArray = []
@export var fixtures: Array[Dictionary] = []
@export var available_supplier_tiers: Array[int] = [1, 2, 3]
@export var base_foot_traffic: float = 0.0
@export var unique_mechanics: PackedStringArray = []
@export var aesthetic_tags: PackedStringArray = []
@export var recommended_markup_optimal_min: float = 0.0
@export var recommended_markup_optimal_max: float = 0.0
@export var recommended_markup_max_viable: float = 0.0
@export var ambient_sound: String = ""
@export var music: String = ""


## Returns true if this store has recommended markup ranges defined.
func has_recommended_markup() -> bool:
	return recommended_markup_max_viable > 0.0
