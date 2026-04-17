## Immutable template for an inventory item type, loaded from JSON content.
class_name ItemDefinition
extends Resource

const RARITY_ORDER: PackedStringArray = [
	"common", "uncommon", "rare", "very_rare", "legendary",
]
const CONDITION_ORDER: PackedStringArray = [
	"poor", "fair", "good", "near_mint", "mint",
]

@export var id: String = "":
	set(value):
		_id = String(value)
		_item_id = StringName(_id)
	get:
		return _id
@export var item_id: StringName = &"":
	set(value):
		_item_id = value
		_id = String(_item_id)
	get:
		return _item_id
@export var item_name: String = ""
@export var description: String = ""
@export var category: StringName = &"":
	set(value):
		_category = StringName(String(value))
	get:
		return _category
@export var subcategory: String = ""
@export var store_type: StringName = &"":
	set(value):
		_store_type = StringName(String(value))
	get:
		return _store_type
@export var base_price: float = 0.0
@export var rarity: String = "common":
	set(value):
		_rarity = str(value)
		_rarity_tier = rarity_to_tier(_rarity)
	get:
		return _rarity
@export var rarity_tier: int = 0:
	set(value):
		_rarity_tier = clampi(value, 0, RARITY_ORDER.size() - 1)
		rarity = RARITY_ORDER[_rarity_tier]
	get:
		return _rarity_tier
@export var condition_range: PackedStringArray = PackedStringArray():
	set(value):
		_condition_range = PackedStringArray(value)
		_condition_tier_range = _range_from_labels(_condition_range)
	get:
		return _condition_range
@export var condition_tier_range: Vector2 = Vector2.ZERO:
	set(value):
		_condition_tier_range = Vector2(
			clampf(value.x, 0.0, 4.0),
			clampf(value.y, 0.0, 4.0)
		)
		_condition_range = _labels_from_range(_condition_tier_range)
	get:
		return _condition_tier_range
@export var condition_value_multipliers: Dictionary = {}
@export var icon_path: String = ""
@export var tags: Array[StringName] = []:
	set(value):
		_tags = _normalize_string_name_array(value)
	get:
		return _tags
@export var set_name: String = ""
@export var depreciates: bool = false
@export var appreciates: bool = false
@export var rental_tier: String = ""
@export var rental_fee: float = 0.0
@export var rental_period_days: int = 0
@export var brand: String = ""
@export var product_line: String = ""
@export var generation: int = 0
@export var lifecycle_phase: String = ""
@export var launch_day: int = 0
@export var depreciation_rate: float = 0.0
@export var min_value_ratio: float = 0.1
@export var launch_demand_multiplier: float = 1.0
@export var launch_spike_days: int = 0
@export var can_be_demo_unit: bool = false
@export var monthly_depreciation_rate: float = 0.0
@export var launch_spike_eligible: bool = false
@export var launch_spike_multiplier: float = 1.0
@export var supplier_tier: int = 0
@export var platform: String = ""
@export var region: String = ""
@export var suspicious_chance: float = 0.0
@export var extra: Dictionary = {}

var name: String:
	get:
		return item_name

var _id: String = ""
var _item_id: StringName = &""
var _category: StringName = &""
var _store_type: StringName = &""
var _rarity: String = "common"
var _rarity_tier: int = 0
var _condition_range: PackedStringArray = PackedStringArray([
	"poor", "fair", "good", "near_mint", "mint",
])
var _condition_tier_range: Vector2 = Vector2(0.0, 4.0)
var _tags: Array[StringName] = []


func _init() -> void:
	condition_range = PackedStringArray([
		"poor", "fair", "good", "near_mint", "mint",
	])
	rarity = "common"
	rarity_tier = 0


func get_rarity_tier() -> int:
	return rarity_tier


func get_condition_tier_range() -> Vector2:
	return condition_tier_range


static func rarity_to_tier(rarity_name: String) -> int:
	return maxi(RARITY_ORDER.find(rarity_name), 0)


static func condition_to_tier(condition_name: String) -> int:
	return maxi(CONDITION_ORDER.find(condition_name), 0)


static func tier_to_condition(condition_tier: int) -> String:
	var index: int = clampi(condition_tier, 0, CONDITION_ORDER.size() - 1)
	return CONDITION_ORDER[index]


static func _normalize_string_name_array(values: Variant) -> Array[StringName]:
	var normalized: Array[StringName] = []
	if values is PackedStringArray:
		for entry: String in values:
			normalized.append(StringName(entry))
	elif values is Array:
		for entry: Variant in values:
			normalized.append(StringName(str(entry)))
	return normalized


static func _range_from_labels(labels: PackedStringArray) -> Vector2:
	if labels.is_empty():
		return Vector2.ZERO
	var first_index: int = condition_to_tier(labels[0])
	var last_index: int = condition_to_tier(labels[labels.size() - 1])
	return Vector2(first_index, last_index)


static func _labels_from_range(range_value: Vector2) -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	var min_index: int = clampi(int(range_value.x), 0, CONDITION_ORDER.size() - 1)
	var max_index: int = clampi(int(range_value.y), 0, CONDITION_ORDER.size() - 1)
	for index: int in range(min_index, max_index + 1):
		labels.append(CONDITION_ORDER[index])
	return labels
