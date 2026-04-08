## Tracks player progression — unlocks, milestones, and store expansion.
class_name ProgressionSystem
extends Node

# Stub — will manage unlock conditions, XP/level systems, and expansion gates.

var unlocked_store_types: PackedStringArray = ["sports"]

func is_unlocked(store_type: String) -> bool:
	return store_type in unlocked_store_types
