## A specific item the player owns, with individual state.
## ItemDefinition is the template; ItemInstance is the concrete copy.
## See docs/architecture/DATA_MODEL.md for the canonical schema.
class_name ItemInstance
extends RefCounted

var definition: ItemDefinition
var condition: String = "good"  # poor, fair, good, near_mint, mint
var acquired_day: int = 0
var acquired_price: float = 0.0
var current_location: String = "backroom"  # "backroom", "shelf:<slot_id>", "sold"
var instance_id: String = ""


static func create(def: ItemDefinition, cond: String, day: int, price: float) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.definition = def
	inst.condition = cond
	inst.acquired_day = day
	inst.acquired_price = price
	inst.instance_id = "%s_%d_%d" % [def.id, day, randi()]
	return inst
