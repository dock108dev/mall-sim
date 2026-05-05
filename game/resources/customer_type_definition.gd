## Data resource defining a customer archetype and its shopping profile.
class_name CustomerTypeDefinition
extends Resource

@export var id: String = "":
	set(value):
		_id = String(value)
		_type_id = StringName(_id)
	get:
		return _id
@export var type_id: StringName = &"":
	set(value):
		_type_id = value
		_id = String(_type_id)
	get:
		return _type_id
@export var customer_name: String = "":
	set(value):
		_customer_name = value
		_display_name = value
	get:
		return _customer_name
@export var display_name: String = "":
	set(value):
		_display_name = value
		_customer_name = value
	get:
		return _display_name
@export var description: String = ""
@export var store_types: PackedStringArray = []:
	set(value):
		_store_types = PackedStringArray(value)
		_store_affinity = _normalize_string_name_array(_store_types)
	get:
		return _store_types
@export var store_affinity: Array[StringName] = []:
	set(value):
		_store_affinity = _normalize_string_name_array(value)
		var resolved: PackedStringArray = PackedStringArray()
		for store_id: StringName in _store_affinity:
			resolved.append(String(store_id))
		_store_types = resolved
	get:
		return _store_affinity
@export var budget_range: Array[float] = [0.0, 0.0]:
	set(value):
		_budget_range = _normalize_float_array(value)
		_budget_range_vector = _vector_from_array(_budget_range)
	get:
		return _budget_range
@export var budget_range_vector: Vector2 = Vector2.ZERO:
	set(value):
		_budget_range_vector = _normalize_vector2(value)
		_budget_range = [_budget_range_vector.x, _budget_range_vector.y]
	get:
		return _budget_range_vector
@export var patience: float = 0.5
@export var price_sensitivity: float = 0.5
@export var preferred_categories: PackedStringArray = []
@export var preferred_tags: PackedStringArray = []
@export var preferred_rarities: PackedStringArray = []
@export var condition_preference: String = "good"
@export var browse_time_range: Array[float] = [30.0, 60.0]
@export var purchase_probability_base: float = 0.5
@export var impulse_buy_chance: float = 0.1
@export var visit_frequency: String = "medium"
@export var mood_tags: PackedStringArray = []
@export var spending_range: Array[float] = [0.0, 0.0]
@export var max_price_to_market_ratio: float = 1.0
@export var snack_purchase_probability: float = 0.0
@export var typical_rental_count: Array[int] = []
@export var leaves_if_unavailable: bool = false
@export var dialogue_pool: String = ""
@export var model_path: String = ""
@export var spawn_weight: float = 1.0
## Platforms this customer cares about. Read by PlatformSystem to apply
## shortage-driven spawn weight bonuses.
@export var platform_affinities: Array[StringName] = []
## How aggressively this customer chases scarcity. 0.0 = ignores shortage,
## 1.0 = will pay ceiling price for the rare unit.
@export var shortage_sensitivity: float = 0.0
## Cross-store archetype id this customer profile belongs to (matches an entry
## in archetypes.json). Drives conditional spawn rules (e.g. angry_return,
## shady_regular, hype_teen). Empty string means no archetype binding.
@export var archetype_id: StringName = &""

var name: String:
	get:
		return display_name

var _id: String = ""
var _type_id: StringName = &""
var _customer_name: String = ""
var _display_name: String = ""
var _store_types: PackedStringArray = []
var _store_affinity: Array[StringName] = []
var _budget_range: Array[float] = [0.0, 0.0]
var _budget_range_vector: Vector2 = Vector2.ZERO


static func _normalize_string_name_array(values: Variant) -> Array[StringName]:
	var normalized: Array[StringName] = []
	if values is PackedStringArray:
		for entry: String in values:
			normalized.append(StringName(entry))
	elif values is Array:
		for entry: Variant in values:
			normalized.append(StringName(str(entry)))
	return normalized


static func _normalize_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is PackedFloat32Array and (value as PackedFloat32Array).size() >= 2:
		var packed: PackedFloat32Array = value as PackedFloat32Array
		return Vector2(float(packed[0]), float(packed[1]))
	if value is Array and (value as Array).size() >= 2:
		var arr: Array = value as Array
		return Vector2(float(arr[0]), float(arr[1]))
	return Vector2.ZERO


static func _normalize_float_array(value: Variant) -> Array[float]:
	var result: Array[float] = [0.0, 0.0]
	if value is Vector2:
		var vector_value: Vector2 = value as Vector2
		result[0] = vector_value.x
		result[1] = vector_value.y
		return result
	if value is Array and (value as Array).size() >= 2:
		var arr: Array = value as Array
		result[0] = float(arr[0])
		result[1] = float(arr[1])
		return result
	return result


static func _vector_from_array(values: Array[float]) -> Vector2:
	if values.size() < 2:
		return Vector2.ZERO
	return Vector2(values[0], values[1])
