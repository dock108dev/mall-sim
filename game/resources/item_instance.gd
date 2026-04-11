## A specific item the player owns, with individual state.
## ItemDefinition is the template; ItemInstance is the concrete copy.
## See docs/architecture/DATA_MODEL.md for the canonical schema.
class_name ItemInstance
extends RefCounted

const CONDITION_MULTIPLIERS: Dictionary = {
	"mint": 2.0,
	"near_mint": 1.5,
	"good": 1.0,
	"fair": 0.5,
	"poor": 0.25,
}

const RARITY_MULTIPLIERS: Dictionary = {
	"legendary": 40.0,
	"very_rare": 15.0,
	"rare": 6.0,
	"uncommon": 2.5,
	"common": 1.0,
}

## Low-price items get full rarity scaling; expensive items get diminishing returns.
const RARITY_REFERENCE_PRICE: float = 5.0

static var _next_id: int = 0

var definition: ItemDefinition
var condition: String = "good"
var acquired_day: int = 0
var acquired_price: float = 0.0
var current_location: String = "backroom"
var set_price: float = 0.0
var instance_id: String = ""
var tested: bool = false
var is_demo: bool = false
var demo_placed_day: int = 0
var authentication_status: String = "none"


## Creates an ItemInstance from an ItemDefinition with a specific condition.
static func create_from_definition(
	def: ItemDefinition, cond: String = ""
) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.definition = def
	inst.condition = _resolve_condition(def, cond)
	inst.acquired_day = 0
	inst.acquired_price = def.base_price
	inst.instance_id = _generate_id(def.id)
	return inst


## Creates an ItemInstance with full control over all fields.
static func create(
	def: ItemDefinition, cond: String, day: int, price: float
) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.definition = def
	inst.condition = cond
	inst.acquired_day = day
	inst.acquired_price = price
	inst.instance_id = _generate_id(def.id)
	return inst


## Diminishing returns on rarity for expensive items.
## Cheap items (at or below reference_price) get the full rarity multiplier.
## Expensive items converge toward 1.0 as base_price grows.
static func calculate_effective_rarity(
	base_price: float, rarity: String
) -> float:
	var raw_mult: float = RARITY_MULTIPLIERS.get(rarity, 1.0)
	if raw_mult <= 1.0:
		return raw_mult
	var ref: float = RARITY_REFERENCE_PRICE
	var effective: float = 1.0 + (raw_mult - 1.0) * (
		ref / maxf(base_price, ref)
	)
	return effective


## Returns base_price * condition_multiplier * effective_rarity_multiplier.
func get_current_value() -> float:
	if not definition:
		return 0.0
	var cond_mult: float = CONDITION_MULTIPLIERS.get(condition, 1.0)
	var rarity_mult: float = calculate_effective_rarity(
		definition.base_price, definition.rarity
	)
	return definition.base_price * cond_mult * rarity_mult


static func _generate_id(base: String) -> String:
	_next_id += 1
	return "%s_%d" % [base, _next_id]


static func _resolve_condition(def: ItemDefinition, cond: String) -> String:
	if cond != "" and cond in CONDITION_MULTIPLIERS:
		return cond
	if def.condition_range.size() > 0:
		return def.condition_range[randi() % def.condition_range.size()]
	return "good"
