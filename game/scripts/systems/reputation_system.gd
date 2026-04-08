## Tracks store reputation per store, affecting customer flow and pricing tolerance.
class_name ReputationSystem
extends Node

# store_id -> reputation (0.0 to 100.0)
var _reputations: Dictionary = {}


func get_reputation(store_id: String) -> float:
	return _reputations.get(store_id, 50.0)


func modify_reputation(store_id: String, delta: float) -> void:
	var current := get_reputation(store_id)
	_reputations[store_id] = clampf(current + delta, 0.0, 100.0)
