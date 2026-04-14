## Immutable template for an inventory item type, loaded from JSON.
class_name ItemDefinition
extends Resource

@export var id: String = ""
@export var item_name: String = ""
@export var description: String = ""
@export var category: String = ""
@export var subcategory: String = ""
@export var store_type: String = ""
@export var base_price: float = 0.0
@export var rarity: String = "common"
@export var condition_range: PackedStringArray = [
	"poor", "fair", "good", "near_mint", "mint"
]
@export var condition_value_multipliers: Dictionary = {}
@export var icon_path: String = ""
@export var tags: PackedStringArray = []
@export var set_name: String = ""
@export var depreciates: bool = false
@export var appreciates: bool = false
@export var rental_tier: String = ""
@export var rental_fee: float = 0.0
@export var rental_period_days: int = 0
@export var brand: String = ""
@export var product_line: String = ""
@export var generation: int = 0
@export var lifecycle_phase: String = ""
@export var launch_day: int = 0
@export var depreciation_rate: float = 0.0
@export var min_value_ratio: float = 0.1
@export var launch_demand_multiplier: float = 1.0
@export var launch_spike_days: int = 0
@export var platform: String = ""
@export var region: String = ""
@export var suspicious_chance: float = 0.0
@export var extra: Dictionary = {}
