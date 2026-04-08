## Data resource for a single inventory item type.
class_name ItemDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var category: String = ""
@export var store_type: String = ""
@export var base_price: float = 0.0
@export var rarity: String = "common"  # common, uncommon, rare, legendary
@export var condition: String = "new"  # new, used, mint, damaged
@export var icon_path: String = ""
@export var tags: PackedStringArray = []
