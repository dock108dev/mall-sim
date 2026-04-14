## Data resource for a supplier that provides items to a specific store type.
class_name SupplierDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var tier: int = 1
@export var store_type: String = ""
@export var lead_time_min: int = 1
@export var lead_time_max: int = 2
@export var reliability_rate: float = 1.0
@export var unlock_condition: Dictionary = {}
@export var catalog: Array[Dictionary] = []


## Returns the lead time range as a Dictionary with min/max keys.
func get_lead_time() -> Dictionary:
	return {"min": lead_time_min, "max": lead_time_max}


## Returns catalog entries for a specific item_id, or empty array.
func get_catalog_entry(item_id: String) -> Dictionary:
	for entry: Dictionary in catalog:
		if str(entry.get("item_id", "")) == item_id:
			return entry
	return {}


## Returns true if this supplier carries the given item.
func has_item(item_id: String) -> bool:
	return not get_catalog_entry(item_id).is_empty()
