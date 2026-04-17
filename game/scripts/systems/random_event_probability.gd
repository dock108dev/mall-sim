## Utility helpers for random event probability and config lookups.
class_name RandomEventProbability
extends RefCounted


static func event_probability(
	def: RandomEventDefinition, event_pool: Array[Dictionary]
) -> float:
	var config: Dictionary = event_pool_config(def.id, event_pool)
	var raw_probability: float = def.probability_weight
	if config.has("base_probability"):
		raw_probability = float(config["base_probability"])
	elif config.has("probability"):
		raw_probability = float(config["probability"])
	return clampf(raw_probability, 0.0, 1.0)


static func event_pool_config(
	event_id: String, event_pool: Array[Dictionary]
) -> Dictionary:
	for config: Dictionary in event_pool:
		if str(config.get("id", "")) == event_id:
			return config
	return {}


static func definition_to_config(def: RandomEventDefinition) -> Dictionary:
	return {
		"id": def.id,
		"name": def.name,
		"description": def.description,
		"effect_type": def.effect_type,
		"duration_days": def.duration_days,
		"severity": def.severity,
		"cooldown_days": def.cooldown_days,
		"probability_weight": def.probability_weight,
		"target_category": def.target_category,
		"target_item_id": def.target_item_id,
		"notification_text": def.notification_text,
		"resolution_text": def.resolution_text,
		"toast_message": def.toast_message,
		"time_window_start": def.time_window_start,
		"time_window_end": def.time_window_end,
	}
