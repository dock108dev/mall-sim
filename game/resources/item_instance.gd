## A specific item the player owns, with per-copy runtime state.
class_name ItemInstance
extends Resource

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

var definition: ItemDefinition = null:
	set(value):
		_definition = value
		definition_id = value.item_id if value else &""
	get:
		return _definition
var definition_id: StringName = &""
var condition: String = "good"
var condition_tier: int:
	get:
		return ItemDefinition.condition_to_tier(condition)
	set(value):
		condition = ItemDefinition.tier_to_condition(value)
var acquired_day: int = 0
var acquired_price: float = 0.0
var current_location: String = "backroom":
	set(value):
		_current_location = value
		_location = StringName(value)
	get:
		return _current_location
var location: StringName = &"":
	set(value):
		_location = value
		_current_location = String(value)
	get:
		return _location
var player_set_price: float = 0.0:
	set(value):
		_player_set_price = value
		_player_price = value
	get:
		return _player_set_price
var player_price: float = 0.0:
	set(value):
		_player_price = value
		_player_set_price = value
	get:
		return _player_price
var instance_id: StringName = &""
var tested: bool = false
var test_result: String = ""
var is_demo: bool = false
var demo_placed_day: int = 0
## Multiplier applied to a demo unit's value; decreases each day it is on display.
## 1.0 = full value; floors at ElectronicsStoreController.DEMO_DEPRECIATION_FLOOR.
var demo_depreciation_factor: float = 1.0
var authentication_status: String = "none":
	set(value):
		_authentication_status = value
		_is_authenticated = _authentication_status == "authenticated"
	get:
		return _authentication_status
var is_authenticated: bool = false:
	set(value):
		_is_authenticated = value
		if value:
			_authentication_status = "authenticated"
		elif _authentication_status == "authenticated":
			_authentication_status = "none"
	get:
		return _is_authenticated
var rental_due_day: int = -1
var is_graded: bool = false
## Numeric grade index into PriceResolver.GRADE_ORDER (0=F … 5=S); -1 if ungraded.
var grade_value: int = -1
## Letter grade assigned by authentication (F/D/C/B/A/S); empty if ungraded.
var card_grade: String = ""
## ACC 1–10 numeric grade returned by the grading service; -1 if not graded.
var numeric_grade: int = -1
## True while card is submitted for ACC grading and awaiting a result.
var is_grading_pending: bool = false
## Hidden ground-truth authenticity ("authentic" | "questionable" | "fake").
## Derived from definition.provenance_score via derive_true_authenticity().
## Never shown to the player directly — revealed only via probabilistic grading hints.
var true_authenticity: String = ""
## Player-visible best guess of authenticity. "unknown" until a grading hint runs;
## thereafter holds the last hint ("authentic" | "questionable" | "fake"). The
## hint is probabilistic, so this value may disagree with true_authenticity.
var revealed_authenticity: String = "unknown"

var _definition: ItemDefinition = null
var _current_location: String = "backroom"
var _location: StringName = &"backroom"
var _player_set_price: float = 0.0
var _player_price: float = 0.0
var _authentication_status: String = "none"
var _is_authenticated: bool = false


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
	inst.player_price = 0.0
	inst.location = &"backroom"
	inst.true_authenticity = derive_true_authenticity(def)
	return inst


## Maps a definition's provenance_score to the hidden true-authenticity state.
## >= 0.75 → authentic, >= 0.5 → questionable, else → fake. Returns "" when the
## definition has no provenance_score (non-memorabilia items).
static func derive_true_authenticity(def: ItemDefinition) -> String:
	if not def or not ("provenance_score" in def):
		return ""
	var score: float = def.provenance_score
	if score <= 0.0:
		return ""
	if score >= 0.75:
		return "authentic"
	if score >= 0.5:
		return "questionable"
	return "fake"


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
	inst.player_price = 0.0
	inst.location = &"backroom"
	inst.true_authenticity = derive_true_authenticity(def)
	return inst


## Diminishing returns on rarity for expensive items.
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


static func _generate_id(base: String) -> StringName:
	_next_id += 1
	return StringName("%s_%d" % [base, _next_id])


static func _resolve_condition(def: ItemDefinition, cond: String) -> String:
	if cond != "":
		return cond
	if def.condition_range.size() > 0:
		return def.condition_range[randi() % def.condition_range.size()]
	return "good"
