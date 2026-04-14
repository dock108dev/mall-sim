## Data resource for a fixture type that can be placed in a store.
class_name FixtureDefinition
extends Resource

enum TierLevel { BASIC = 1, IMPROVED = 2, PREMIUM = 3 }

const TIER_NAMES: Dictionary = {
	TierLevel.BASIC: "Basic",
	TierLevel.IMPROVED: "Improved",
	TierLevel.PREMIUM: "Premium",
}

const UPGRADE_COST_MULTIPLIERS: Dictionary = {
	TierLevel.IMPROVED: 1.5,
	TierLevel.PREMIUM: 2.5,
}

const TIER_SLOT_BONUS: Dictionary = {
	TierLevel.BASIC: 0,
	TierLevel.IMPROVED: 2,
	TierLevel.PREMIUM: 4,
}

const TIER_PURCHASE_PROB_BONUS: Dictionary = {
	TierLevel.BASIC: 0.0,
	TierLevel.IMPROVED: 0.1,
	TierLevel.PREMIUM: 0.2,
}

const TIER_REP_REQUIREMENTS: Dictionary = {
	TierLevel.IMPROVED: 15.0,
	TierLevel.PREMIUM: 40.0,
}

const SELLBACK_RATE: float = 0.5

@export var id: String = ""
@export var name: String = ""
@export var display_name: String = ""
@export var category: String = "universal"
@export var price: float = 0.0
@export var cost: float = 0.0
@export var grid_size: Vector2i = Vector2i(1, 1)
@export var footprint_cells: Array[Vector2i] = []
@export var slot_count: int = 0
@export var rotation_support: bool = false
@export var store_type_restriction: String = ""
@export var unlock_rep: float = 0.0
@export var unlock_day: int = 0
@export var unlock_condition: Dictionary = {}
@export var store_types: PackedStringArray = []
@export var requires_wall: bool = false
@export var description: String = ""
@export var visual_category: String = ""
@export var scene_path: String = ""
@export var tier_data: Dictionary = {}


## Returns the sell-back value (50% of purchase cost).
func get_sellback_price() -> float:
	return cost * SELLBACK_RATE


## Returns the slot count for a given tier level.
func get_slots_for_tier(tier: int) -> int:
	return slot_count + TIER_SLOT_BONUS.get(tier, 0)


## Returns the purchase probability bonus for a given tier level.
func get_purchase_prob_bonus(tier: int) -> float:
	return TIER_PURCHASE_PROB_BONUS.get(tier, 0.0) as float


## Returns the upgrade cost to reach the given tier.
func get_upgrade_cost(tier: int) -> float:
	var multiplier: float = UPGRADE_COST_MULTIPLIERS.get(tier, 0.0)
	return cost * multiplier


## Returns the reputation required for a given tier.
static func get_rep_requirement(tier: int) -> float:
	return TIER_REP_REQUIREMENTS.get(tier, 0.0) as float


## Returns the display name for a tier level.
static func get_tier_name(tier: int) -> String:
	return TIER_NAMES.get(tier, "Unknown") as String
