## Data resource for global economy multipliers and starting values.
class_name EconomyConfig
extends Resource

@export var starting_cash: float = 500.0
@export var daily_rent_base: float = 30.0
@export var daily_rent_multipliers: Dictionary = {}
@export var rarity_multipliers: Array[float] = []
@export var condition_multipliers: Array[float] = []
@export var haggle_floor_ratio: float = 0.5
@export var haggle_max_rounds: int = 3
@export var authentication_price_bonus: float = 0.25
@export var late_fee_per_day: float = 2.0
@export var reputation_tiers: Dictionary = {}
@export var markup_ranges: Dictionary = {}
@export var demand_modifiers: Dictionary = {}
@export var daily_rent_per_size: Dictionary = {}
@export var supplier_tiers: Array[Dictionary] = []
@export var price_ratio_reputation_deltas: Dictionary = {}
@export var reputation_decay: Dictionary = {}


## Returns the daily rent for a given store ID, applying the store multiplier.
func get_daily_rent(store_id: String) -> float:
	var multiplier: float = daily_rent_multipliers.get(store_id, 1.0)
	return daily_rent_base * multiplier
