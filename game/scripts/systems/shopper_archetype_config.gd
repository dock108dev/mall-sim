## Static configuration for shopper personality archetype spawn weights and defaults.
class_name ShopperArchetypeConfig
extends RefCounted

const PERSONALITY_CONFIG_PATH: String = "res://game/content/customers/personalities.json"

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
		"personality_type": "POWER_SHOPPER",
		"shop_weight": 1.5,
		"impulse_factor": 0.3,
		"hunger_rate_mult": 0.5,
		"energy_drain_mult": 0.667,
		"social_need_baseline": 0.1,
		"browse_duration_mult": 1.2,
		"min_budget": 80.0,
		"max_budget": 300.0,
		"avg_visit_minutes_min": 45.0,
		"avg_visit_minutes_max": 90.0,
	},
	PersonalityData.PersonalityType.WINDOW_BROWSER: {
		"personality_type": "WINDOW_BROWSER",
		"shop_weight": 0.8,
		"impulse_factor": 0.1,
		"hunger_rate_mult": 1.0,
		"energy_drain_mult": 0.333,
		"social_need_baseline": 0.3,
		"browse_duration_mult": 1.5,
		"min_budget": 15.0,
		"max_budget": 60.0,
		"avg_visit_minutes_min": 30.0,
		"avg_visit_minutes_max": 60.0,
	},
	PersonalityData.PersonalityType.FOOD_COURT_CAMPER: {
		"personality_type": "FOOD_COURT_CAMPER",
		"shop_weight": 0.3,
		"impulse_factor": 0.2,
		"hunger_rate_mult": 2.0,
		"energy_drain_mult": 0.167,
		"social_need_baseline": 0.7,
		"browse_duration_mult": 0.6,
		"min_budget": 15.0,
		"max_budget": 40.0,
		"avg_visit_minutes_min": 60.0,
		"avg_visit_minutes_max": 120.0,
	},
	PersonalityData.PersonalityType.SOCIAL_BUTTERFLY: {
		"personality_type": "SOCIAL_BUTTERFLY",
		"shop_weight": 0.6,
		"impulse_factor": 0.5,
		"hunger_rate_mult": 1.0,
		"energy_drain_mult": 0.333,
		"social_need_baseline": 0.9,
		"browse_duration_mult": 1.0,
		"min_budget": 30.0,
		"max_budget": 120.0,
		"avg_visit_minutes_min": 40.0,
		"avg_visit_minutes_max": 80.0,
	},
	PersonalityData.PersonalityType.RELUCTANT_COMPANION: {
		"personality_type": "RELUCTANT_COMPANION",
		"shop_weight": 0.2,
		"impulse_factor": 0.1,
		"hunger_rate_mult": 1.5,
		"energy_drain_mult": 1.0,
		"social_need_baseline": 0.2,
		"browse_duration_mult": 0.7,
		"min_budget": 10.0,
		"max_budget": 35.0,
		"avg_visit_minutes_min": 20.0,
		"avg_visit_minutes_max": 50.0,
	},
	PersonalityData.PersonalityType.IMPULSE_BUYER: {
		"personality_type": "IMPULSE_BUYER",
		"shop_weight": 1.2,
		"impulse_factor": 0.9,
		"hunger_rate_mult": 1.0,
		"energy_drain_mult": 0.667,
		"social_need_baseline": 0.4,
		"browse_duration_mult": 0.8,
		"min_budget": 50.0,
		"max_budget": 200.0,
		"avg_visit_minutes_min": 30.0,
		"avg_visit_minutes_max": 60.0,
	},
	PersonalityData.PersonalityType.SPEED_RUNNER: {
		"personality_type": "SPEED_RUNNER",
		"shop_weight": 1.0,
		"impulse_factor": 0.1,
		"hunger_rate_mult": 0.5,
		"energy_drain_mult": 0.333,
		"browse_duration_mult": 0.4,
		"min_budget": 40.0,
		"max_budget": 150.0,
		"avg_visit_minutes_min": 10.0,
		"avg_visit_minutes_max": 20.0,
	},
	PersonalityData.PersonalityType.TEEN_PACK_MEMBER: {
		"personality_type": "TEEN_PACK_MEMBER",
		"shop_weight": 0.5,
		"impulse_factor": 0.7,
		"hunger_rate_mult": 1.5,
		"energy_drain_mult": 0.167,
		"social_need_baseline": 0.95,
		"browse_duration_mult": 1.0,
		"min_budget": 5.0,
		"max_budget": 30.0,
		"avg_visit_minutes_min": 60.0,
		"avg_visit_minutes_max": 180.0,
	},
}

static var _personality_data_by_type: Dictionary = {}
static var _personality_data_loaded: bool = false


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
	var defaults: Dictionary = _get_personality_data(archetype)
	var personality: PersonalityData = PersonalityData.from_dictionary(defaults)
	personality.personality_type = archetype
	return personality


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


static func _get_personality_data(
	archetype: PersonalityData.PersonalityType,
) -> Dictionary:
	_ensure_personality_data_loaded()
	var from_json: Dictionary = _personality_data_by_type.get(archetype, {})
	if not from_json.is_empty():
		return from_json.duplicate(true)
	var fallback: Dictionary = ARCHETYPE_DEFAULTS.get(archetype, {})
	return fallback.duplicate(true)


static func _ensure_personality_data_loaded() -> void:
	if _personality_data_loaded:
		return
	_personality_data_loaded = true
	var file: FileAccess = FileAccess.open(PERSONALITY_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error(
			"ShopperArchetypeConfig: failed to open %s" % PERSONALITY_CONFIG_PATH
		)
		return
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(file.get_as_text())
	if parse_result != OK:
		push_error(
			"ShopperArchetypeConfig: failed to parse %s" % PERSONALITY_CONFIG_PATH
		)
		return
	if not (json.data is Dictionary):
		push_error(
			"ShopperArchetypeConfig: invalid root in %s" % PERSONALITY_CONFIG_PATH
		)
		return
	var root: Dictionary = json.data as Dictionary
	var entries: Array = root.get("personalities", [])
	for entry_value: Variant in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value as Dictionary
		var personality: PersonalityData = PersonalityData.from_dictionary(entry)
		_personality_data_by_type[personality.personality_type] = entry.duplicate(true)
