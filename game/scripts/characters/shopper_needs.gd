## Tracks a shopper's four core needs and applies per-second decay/growth rates.
class_name ShopperNeeds
extends RefCounted

const SHOPPING_DRAIN_BROWSING: float = -0.003
const SHOPPING_DRAIN_BUYING: float = -0.01
const HUNGER_GROWTH_PASSIVE: float = 0.002
const HUNGER_GROWTH_WALKING: float = 0.004
const HUNGER_RESTORE_EATING: float = -0.02
const ENERGY_DRAIN_IDLE: float = -0.001
const ENERGY_DRAIN_WALKING: float = -0.003
const ENERGY_RESTORE_SITTING: float = 0.015
const SOCIAL_DRIFT_RATE: float = 0.001
const SOCIAL_GAIN_SOCIALIZING: float = 0.01
const ACTION_NOISE: float = 0.1

var shopping: float = 1.0
var hunger: float = 0.0
var energy: float = 1.0
var social: float = 0.5


func initialize_from_personality(personality: PersonalityData) -> void:
	if personality:
		social = personality.social_need_baseline


func update(
	delta: float,
	is_moving: bool,
	state_name: String,
	personality: PersonalityData
) -> void:
	var hunger_mult: float = 1.0
	var energy_mult: float = 1.0
	if personality:
		hunger_mult = personality.hunger_rate_mult
		energy_mult = personality.energy_drain_mult

	match state_name:
		"BROWSING":
			shopping += SHOPPING_DRAIN_BROWSING * delta
		"BUYING":
			shopping += SHOPPING_DRAIN_BUYING * delta
		"EATING":
			hunger += HUNGER_RESTORE_EATING * delta
		"SITTING":
			energy += ENERGY_RESTORE_SITTING * delta
		"SOCIALIZING":
			social += SOCIAL_GAIN_SOCIALIZING * delta

	if is_moving:
		hunger += HUNGER_GROWTH_WALKING * hunger_mult * delta
		energy += ENERGY_DRAIN_WALKING * energy_mult * delta
	else:
		hunger += HUNGER_GROWTH_PASSIVE * hunger_mult * delta
		energy += ENERGY_DRAIN_IDLE * energy_mult * delta

	var social_baseline: float = 0.5
	if personality:
		social_baseline = personality.social_need_baseline
	if state_name != "SOCIALIZING":
		var drift: float = sign(social_baseline - social)
		social += drift * SOCIAL_DRIFT_RATE * delta

	shopping = clampf(shopping, 0.0, 1.0)
	hunger = clampf(hunger, 0.0, 1.0)
	energy = clampf(energy, 0.0, 1.0)
	social = clampf(social, 0.0, 1.0)


func get_dict() -> Dictionary:
	return {
		"shopping": shopping,
		"hunger": hunger,
		"energy": energy,
		"social": social,
	}


func score_action(action: String, personality: PersonalityData,
	store_appeal: float, food_proximity: float,
	bench_proximity: float, shopper_density: float,
	time_factor: float
) -> float:
	var score: float = 0.0
	var shop_w: float = 1.0
	var impulse_f: float = 0.3
	if personality:
		shop_w = personality.shop_weight
		impulse_f = personality.impulse_factor
	match action:
		"visit_store":
			score = shopping * shop_w * store_appeal
		"eat":
			score = hunger * food_proximity * 2.0
		"sit":
			score = (1.0 - energy) * bench_proximity * 1.5
		"window_shop":
			score = shopping * 0.6 * impulse_f
		"socialize":
			score = social * shopper_density * 0.3
		"leave":
			score = (1.0 - shopping) * time_factor
	score += randf_range(-ACTION_NOISE, ACTION_NOISE)
	return score
