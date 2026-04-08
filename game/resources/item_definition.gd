## Data resource for a single inventory item type.
## See docs/architecture/DATA_MODEL.md for the canonical schema.
class_name ItemDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var category: String = ""
@export var subcategory: String = ""
@export var store_type: String = ""
@export var base_price: float = 0.0
@export var rarity: String = "common"  # common, uncommon, rare, very_rare, legendary
@export var condition_range: PackedStringArray = ["poor", "fair", "good", "near_mint", "mint"]
@export var icon_path: String = ""
@export var tags: PackedStringArray = []
@export var depreciates: bool = false
@export var appreciates: bool = false
