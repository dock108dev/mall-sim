## Data resource defining a store type, starter stock, and interior scene.
class_name StoreDefinition
extends Resource

@export var id: String = "":
	set(value):
		_id = String(value)
		_store_id = StringName(_id)
	get:
		return _id
@export var store_id: StringName = &"":
	set(value):
		_store_id = value
		_id = String(_store_id)
	get:
		return _store_id
@export var store_name: String = "":
	set(value):
		_store_name = value
		_display_name = value
	get:
		return _store_name
@export var display_name: String = "":
	set(value):
		_display_name = value
		_store_name = value
	get:
		return _display_name
@export var store_type: StringName = &"":
	set(value):
		_store_type = StringName(String(value))
	get:
		return _store_type
@export var description: String = ""
@export var scene_path: String = ""
@export var inventory_type: StringName = &"":
	set(value):
		_inventory_type = StringName(String(value))
	get:
		return _inventory_type
@export var interaction_set_id: StringName = &"":
	set(value):
		_interaction_set_id = StringName(String(value))
	get:
		return _interaction_set_id
@export var tutorial_context_id: StringName = &"":
	set(value):
		_tutorial_context_id = StringName(String(value))
	get:
		return _tutorial_context_id
@export var size_category: String = "small"
@export var starting_budget: float = 5000.0
@export var allowed_categories: PackedStringArray = []
@export var fixture_slots: int = 6
@export var max_employees: int = 2
@export var shelf_capacity: int = 0
@export var backroom_capacity: int = 0
@export var starting_cash: float = 0.0
@export var daily_rent: float = 0.0
@export var starting_inventory: PackedStringArray = []:
	set(value):
		_starting_inventory = PackedStringArray(value)
		_starter_inventory = _starter_entries_from_ids(_starting_inventory)
	get:
		return _starting_inventory
@export var starter_inventory: Array[Dictionary] = []:
	set(value):
		_starter_inventory = _normalize_starter_inventory(value)
		_starting_inventory = _starter_ids_from_entries(_starter_inventory)
	get:
		return _starter_inventory
@export var fixtures: Array[Dictionary] = []
@export var available_supplier_tiers: Array[int] = [1, 2, 3]
@export var base_foot_traffic: float = 0.0
@export var unique_mechanics: PackedStringArray = []
@export var aesthetic_tags: PackedStringArray = []
@export var recommended_markup_optimal_min: float = 0.0
@export var recommended_markup_optimal_max: float = 0.0
@export var recommended_markup_max_viable: float = 0.0
@export var ambient_sound: String = ""
@export var music: String = ""
@export var upgrade_ids: Array[StringName] = []:
	set(value):
		_upgrade_ids = _normalize_string_name_array(value)
	get:
		return _upgrade_ids

var name: String:
	get:
		return display_name

var _id: String = ""
var _store_id: StringName = &""
var _store_name: String = ""
var _display_name: String = ""
var _store_type: StringName = &""
var _inventory_type: StringName = &""
var _interaction_set_id: StringName = &""
var _tutorial_context_id: StringName = &""
var _starting_inventory: PackedStringArray = []
var _starter_inventory: Array[Dictionary] = []
var _upgrade_ids: Array[StringName] = []


## Returns true if this store has recommended markup ranges defined.
func has_recommended_markup() -> bool:
	return recommended_markup_max_viable > 0.0


static func _normalize_string_name_array(values: Variant) -> Array[StringName]:
	var normalized: Array[StringName] = []
	if values is PackedStringArray:
		for entry: String in values:
			normalized.append(StringName(entry))
	elif values is Array:
		for entry: Variant in values:
			normalized.append(StringName(str(entry)))
	return normalized


static func _normalize_starter_inventory(values: Variant) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	if values is not Array:
		return normalized
	for entry: Variant in values:
		if entry is Dictionary:
			normalized.append((entry as Dictionary).duplicate(true))
	return normalized


static func _starter_entries_from_ids(ids: PackedStringArray) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for item_id: String in ids:
		entries.append({"item_id": StringName(item_id)})
	return entries


static func _starter_ids_from_entries(entries: Array[Dictionary]) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		var raw_item_id: Variant = entry.get("item_id", entry.get("id", ""))
		var item_id: String = str(raw_item_id)
		if not item_id.is_empty():
			ids.append(item_id)
	return ids
