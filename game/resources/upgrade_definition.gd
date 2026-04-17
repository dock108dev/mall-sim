## Data resource for a store upgrade that can be purchased once per store.
class_name UpgradeDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var cost: float = 0.0
@export var rep_required: float = 0.0
@export var store_type: String = ""
@export var effect_type: String = ""
@export var effect_value: float = 0.0
@export var one_time: bool = true


## Returns true if this upgrade is universal (available for all store types).
func is_universal() -> bool:
	return store_type.is_empty()
