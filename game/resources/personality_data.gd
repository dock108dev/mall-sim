## Resource defining a shopper personality archetype's behavioral parameters.
class_name PersonalityData
extends Resource

enum PersonalityType {
	POWER_SHOPPER,
	WINDOW_BROWSER,
	FOOD_COURT_CAMPER,
	SOCIAL_BUTTERFLY,
	RELUCTANT_COMPANION,
	IMPULSE_BUYER,
	SPEED_RUNNER,
	TEEN_PACK_MEMBER,
}

@export var personality_type: PersonalityType = PersonalityType.WINDOW_BROWSER
@export var shop_weight: float = 1.0
@export var impulse_factor: float = 0.3
@export var hunger_rate_mult: float = 1.0
@export var energy_drain_mult: float = 1.0
@export var social_need_baseline: float = 0.5
@export var browse_duration_mult: float = 1.0
@export var min_budget: float = 20.0
@export var max_budget: float = 100.0
@export var avg_visit_minutes_min: float = 30.0
@export var avg_visit_minutes_max: float = 60.0


static func from_dictionary(data: Dictionary) -> PersonalityData:
	var pd: PersonalityData = PersonalityData.new()
	pd.personality_type = _parse_type(data.get("personality_type", "WINDOW_BROWSER"))
	pd.shop_weight = float(data.get("shop_weight", 1.0))
	pd.impulse_factor = float(data.get("impulse_factor", 0.3))
	pd.hunger_rate_mult = float(data.get("hunger_rate_mult", 1.0))
	pd.energy_drain_mult = float(data.get("energy_drain_mult", 1.0))
	pd.social_need_baseline = float(data.get("social_need_baseline", 0.5))
	pd.browse_duration_mult = float(data.get("browse_duration_mult", 1.0))
	pd.min_budget = float(data.get("min_budget", 20.0))
	pd.max_budget = float(data.get("max_budget", 100.0))
	pd.avg_visit_minutes_min = float(data.get("avg_visit_minutes_min", 30.0))
	pd.avg_visit_minutes_max = float(data.get("avg_visit_minutes_max", 60.0))
	return pd


static func _parse_type(type_str: String) -> PersonalityType:
	match type_str.to_upper():
		"POWER_SHOPPER":
			return PersonalityType.POWER_SHOPPER
		"WINDOW_BROWSER":
			return PersonalityType.WINDOW_BROWSER
		"FOOD_COURT_CAMPER":
			return PersonalityType.FOOD_COURT_CAMPER
		"SOCIAL_BUTTERFLY":
			return PersonalityType.SOCIAL_BUTTERFLY
		"RELUCTANT_COMPANION":
			return PersonalityType.RELUCTANT_COMPANION
		"IMPULSE_BUYER":
			return PersonalityType.IMPULSE_BUYER
		"SPEED_RUNNER":
			return PersonalityType.SPEED_RUNNER
		"TEEN_PACK_MEMBER":
			return PersonalityType.TEEN_PACK_MEMBER
		_:
			push_error("PersonalityData: Unknown type '%s'" % type_str)
			return PersonalityType.WINDOW_BROWSER
