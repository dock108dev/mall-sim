## Static configuration for shopper personality archetype spawn weights and defaults.
class_name ShopperArchetypeConfig
extends RefCounted

const WEIGHTS_MORNING: Dictionary = {
	PersonalityData.PersonalityType.POWER_SHOPPER: 25,
	PersonalityData.PersonalityType.WINDOW_BROWSER: 15,
	PersonalityData.PersonalityType.FOOD_COURT_CAMPER: 5,
	PersonalityData.PersonalityType.SOCIAL_BUTTERFLY: 5,
	PersonalityData.PersonalityType.RELUCTANT_COMPANION: 10,
	PersonalityData.PersonalityType.IMPULSE_BUYER: 10,
	PersonalityData.PersonalityType.SPEED_RUNNER: 25,
	PersonalityData.PersonalityType.TEEN_PACK_MEMBER: 5,
}

const WEIGHTS_AFTERNOON: Dictionary = {
	PersonalityData.PersonalityType.POWER_SHOPPER: 15,
	PersonalityData.PersonalityType.WINDOW_BROWSER: 20,
	PersonalityData.PersonalityType.FOOD_COURT_CAMPER: 25,
	PersonalityData.PersonalityType.SOCIAL_BUTTERFLY: 10,
	PersonalityData.PersonalityType.RELUCTANT_COMPANION: 10,
	PersonalityData.PersonalityType.IMPULSE_BUYER: 10,
	PersonalityData.PersonalityType.SPEED_RUNNER: 5,
	PersonalityData.PersonalityType.TEEN_PACK_MEMBER: 5,
}

const WEIGHTS_EVENING: Dictionary = {
	PersonalityData.PersonalityType.POWER_SHOPPER: 10,
	PersonalityData.PersonalityType.WINDOW_BROWSER: 15,
	PersonalityData.PersonalityType.FOOD_COURT_CAMPER: 20,
	PersonalityData.PersonalityType.SOCIAL_BUTTERFLY: 15,
	PersonalityData.PersonalityType.RELUCTANT_COMPANION: 15,
	PersonalityData.PersonalityType.IMPULSE_BUYER: 10,
	PersonalityData.PersonalityType.SPEED_RUNNER: 5,
	PersonalityData.PersonalityType.TEEN_PACK_MEMBER: 10,
}

const GROUP_ARCHETYPES: Array[PersonalityData.PersonalityType] = [
	PersonalityData.PersonalityType.SOCIAL_BUTTERFLY,
	PersonalityData.PersonalityType.TEEN_PACK_MEMBER,
	PersonalityData.PersonalityType.FOOD_COURT_CAMPER,
]

const GROUP_SIZE_RANGES: Dictionary = {
	PersonalityData.PersonalityType.SOCIAL_BUTTERFLY: Vector2i(2, 4),
	PersonalityData.PersonalityType.TEEN_PACK_MEMBER: Vector2i(3, 8),
	PersonalityData.PersonalityType.FOOD_COURT_CAMPER: Vector2i(2, 4),
}

const ARCHETYPE_DEFAULTS: Dictionary = {
	PersonalityData.PersonalityType.POWER_SHOPPER: {
		"shop_weight": 1.5,
		"impulse_factor": 0.3,
		"social_need_baseline": 0.1,
		"browse_duration_mult": 1.2,
		"min_budget": 50.0,
		"max_budget": 200.0,
	},
	PersonalityData.PersonalityType.WINDOW_BROWSER: {
		"shop_weight": 0.8,
		"impulse_factor": 0.1,
		"social_need_baseline": 0.3,
		"browse_duration_mult": 1.5,
		"min_budget": 10.0,
		"max_budget": 50.0,
	},
	PersonalityData.PersonalityType.FOOD_COURT_CAMPER: {
		"shop_weight": 0.3,
		"impulse_factor": 0.2,
		"hunger_rate_mult": 1.5,
		"social_need_baseline": 0.7,
		"min_budget": 15.0,
		"max_budget": 40.0,
	},
	PersonalityData.PersonalityType.SOCIAL_BUTTERFLY: {
		"shop_weight": 0.6,
		"impulse_factor": 0.4,
		"social_need_baseline": 0.9,
		"min_budget": 20.0,
		"max_budget": 80.0,
	},
	PersonalityData.PersonalityType.RELUCTANT_COMPANION: {
		"shop_weight": 0.4,
		"impulse_factor": 0.1,
		"energy_drain_mult": 1.3,
		"social_need_baseline": 0.2,
		"min_budget": 10.0,
		"max_budget": 30.0,
	},
	PersonalityData.PersonalityType.IMPULSE_BUYER: {
		"shop_weight": 1.2,
		"impulse_factor": 0.8,
		"social_need_baseline": 0.4,
		"min_budget": 30.0,
		"max_budget": 150.0,
	},
	PersonalityData.PersonalityType.SPEED_RUNNER: {
		"shop_weight": 1.0,
		"impulse_factor": 0.2,
		"browse_duration_mult": 0.5,
		"energy_drain_mult": 0.8,
		"min_budget": 40.0,
		"max_budget": 120.0,
	},
	PersonalityData.PersonalityType.TEEN_PACK_MEMBER: {
		"shop_weight": 0.5,
		"impulse_factor": 0.7,
		"social_need_baseline": 0.95,
		"min_budget": 5.0,
		"max_budget": 40.0,
	},
}


static func get_weights_for_hour(
	hour: int,
) -> Dictionary:
	if hour < 12:
		return WEIGHTS_MORNING
	if hour < 18:
		return WEIGHTS_AFTERNOON
	return WEIGHTS_EVENING


static func get_weights_for_phase(
	phase: int,
) -> Dictionary:
	match phase:
		TimeSystem.DayPhase.PRE_OPEN, \
		TimeSystem.DayPhase.MORNING_RAMP:
			return WEIGHTS_MORNING
		TimeSystem.DayPhase.MIDDAY_RUSH, \
		TimeSystem.DayPhase.AFTERNOON:
			return WEIGHTS_AFTERNOON
		TimeSystem.DayPhase.EVENING:
			return WEIGHTS_EVENING
		_:
			return WEIGHTS_AFTERNOON


static func create_personality(
	archetype: PersonalityData.PersonalityType,
) -> PersonalityData:
	var pd: PersonalityData = PersonalityData.new()
	pd.personality_type = archetype
	var defaults: Dictionary = ARCHETYPE_DEFAULTS.get(archetype, {})
	pd.shop_weight = float(defaults.get("shop_weight", 1.0))
	pd.impulse_factor = float(defaults.get("impulse_factor", 0.3))
	pd.hunger_rate_mult = float(
		defaults.get("hunger_rate_mult", 1.0)
	)
	pd.energy_drain_mult = float(
		defaults.get("energy_drain_mult", 1.0)
	)
	pd.social_need_baseline = float(
		defaults.get("social_need_baseline", 0.5)
	)
	pd.browse_duration_mult = float(
		defaults.get("browse_duration_mult", 1.0)
	)
	pd.min_budget = float(defaults.get("min_budget", 20.0))
	pd.max_budget = float(defaults.get("max_budget", 100.0))
	return pd


static func is_group_archetype(
	archetype: PersonalityData.PersonalityType,
) -> bool:
	return archetype in GROUP_ARCHETYPES


static func get_group_size_range(
	archetype: PersonalityData.PersonalityType,
) -> Vector2i:
	return GROUP_SIZE_RANGES.get(archetype, Vector2i(1, 1))


static func weighted_random_select(
	weights: Dictionary,
) -> PersonalityData.PersonalityType:
	var total: int = 0
	for w: int in weights.values():
		total += w
	if total <= 0:
		return PersonalityData.PersonalityType.WINDOW_BROWSER
	var roll: int = randi_range(1, total)
	var cumulative: int = 0
	for archetype: PersonalityData.PersonalityType in weights:
		cumulative += weights[archetype] as int
		if roll <= cumulative:
			return archetype
	return PersonalityData.PersonalityType.WINDOW_BROWSER
