## Determines the current supplier tier based on reputation score.
## Provides tier configuration for wholesale pricing, rarity access,
## daily order caps, and delivery times.
class_name SupplierTierSystem
extends RefCounted


const TIERS: Dictionary = {
	1: {
		"wholesale": 0.75,
		"daily_limit": 250.0,
		"rarities": ["common", "uncommon"],
		"delivery_days": 1,
		"rep_threshold": 0.0,
		"name": "Tier 1",
	},
	2: {
		"wholesale": 0.65,
		"daily_limit": 600.0,
		"rarities": ["common", "uncommon", "rare"],
		"delivery_days": 1,
		"rep_threshold": 25.0,
		"name": "Tier 2",
	},
	3: {
		"wholesale": 0.55,
		"daily_limit": 1500.0,
		"rarities": ["common", "uncommon", "rare", "very_rare"],
		"delivery_days": 2,
		"rep_threshold": 50.0,
		"name": "Tier 3",
	},
}


## Returns the supplier tier (1-3) for a given reputation score.
static func get_tier_for_reputation(rep: float) -> int:
	if rep >= TIERS[3]["rep_threshold"]:
		return 3
	if rep >= TIERS[2]["rep_threshold"]:
		return 2
	return 1


## Returns the configuration dictionary for a given tier number.
static func get_config(tier: int) -> Dictionary:
	if not TIERS.has(tier):
		push_warning(
			"SupplierTierSystem: invalid tier %d, defaulting to 1"
			% tier
		)
		return TIERS[1]
	return TIERS[tier]


## Returns info about the next tier, or empty dict if at max.
static func get_next_tier_info(current_tier: int) -> Dictionary:
	if current_tier >= 3:
		return {}
	var next_tier: int = current_tier + 1
	var config: Dictionary = TIERS[next_tier]
	return {
		"tier": next_tier,
		"rep_required": config["rep_threshold"],
		"name": config["name"],
	}


## Returns true if the given rarity is available at the given tier.
static func is_rarity_available(
	rarity: String, tier: int
) -> bool:
	var config: Dictionary = get_config(tier)
	var allowed: Array = config["rarities"]
	return rarity in allowed
